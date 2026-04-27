//! `dashictl doctor` — preflight check matrix.
//!
//! Each check is one-shot, side-effect-free, and reports a single
//! pass/fail line. The whole suite exits non-zero if any required
//! check fails, so CI / `make` can use it as the success oracle for
//! a fresh cluster bringup.
//!
//! Optional checks (ingest-api, Loki) only count as warnings — those
//! services are not required for every dashi deployment.

use anyhow::Result;
use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};
use serde_json::Value;
use std::time::Duration;

use crate::cli::DoctorArgs;
use crate::config::Config;

const REQUEST_TIMEOUT: Duration = Duration::from_secs(5);
const PRESIGN_TTL: Duration = Duration::from_secs(60);

/// Check outcome — the `bool` is `true` when the check counts as a
/// hard failure (vs. an optional component being absent).
enum Status {
    Ok(String),
    Warn(String),
    Fail(String),
}

pub async fn run(cfg: &Config, args: &DoctorArgs) -> Result<()> {
    let mut hard_failures = 0;
    let mut warnings = 0;

    let client = reqwest::Client::builder()
        .timeout(REQUEST_TIMEOUT)
        .build()?;

    let checks: Vec<(&str, Status)> = vec![
        ("STAC reachable", check_stac(&client, cfg).await),
        (
            "STAC has at least one collection",
            check_stac_collections(&client, cfg).await,
        ),
        ("Prefect reachable", check_prefect(&client, cfg).await),
        (
            "Prefect dashi-ingest deployment registered",
            check_prefect_deployment(&client, cfg).await,
        ),
        ("Loki reachable", check_loki(&client, cfg).await),
        (
            "S3 (RustFS) reachable + buckets present",
            check_s3(cfg).await,
        ),
        (
            "ingest-api reachable",
            check_ingest_api(&client, &args.api_url).await,
        ),
    ];

    for (name, status) in checks {
        match status {
            Status::Ok(detail) => println!("  ✓ {name:<48}  {detail}"),
            Status::Warn(detail) => {
                println!("  ⚠ {name:<48}  {detail}");
                warnings += 1;
            }
            Status::Fail(detail) => {
                println!("  ✗ {name:<48}  {detail}");
                hard_failures += 1;
            }
        }
    }

    println!();
    println!(
        "  {} passed · {warnings} warning(s) · {hard_failures} failure(s)",
        7 - hard_failures - warnings
    );

    if hard_failures > 0 {
        std::process::exit(1);
    }
    Ok(())
}

async fn check_stac(client: &reqwest::Client, cfg: &Config) -> Status {
    let url = format!("{}/", cfg.stac_url.trim_end_matches('/'));
    match client.get(&url).send().await {
        Ok(r) if r.status().is_success() => Status::Ok(format!("HTTP {}", r.status().as_u16())),
        Ok(r) => Status::Fail(format!("HTTP {}", r.status().as_u16())),
        Err(e) => Status::Fail(short_err(&e.to_string())),
    }
}

async fn check_stac_collections(client: &reqwest::Client, cfg: &Config) -> Status {
    let url = format!("{}/collections", cfg.stac_url.trim_end_matches('/'));
    let resp = match client.get(&url).send().await {
        Ok(r) => r,
        Err(e) => return Status::Fail(short_err(&e.to_string())),
    };
    if !resp.status().is_success() {
        return Status::Fail(format!("HTTP {}", resp.status().as_u16()));
    }
    let body: Value = match resp.json().await {
        Ok(v) => v,
        Err(e) => return Status::Fail(short_err(&e.to_string())),
    };
    let count = body
        .get("collections")
        .and_then(|v| v.as_array())
        .map(|a| a.len())
        .unwrap_or(0);
    if count == 0 {
        Status::Warn("no collections — run `dashictl domain create <id>` to seed".into())
    } else {
        Status::Ok(format!("{count} collection(s)"))
    }
}

async fn check_prefect(client: &reqwest::Client, cfg: &Config) -> Status {
    let url = format!("{}/api/health", cfg.prefect_url.trim_end_matches('/'));
    match client.get(&url).send().await {
        Ok(r) if r.status().is_success() => Status::Ok(format!("HTTP {}", r.status().as_u16())),
        Ok(r) => Status::Fail(format!("HTTP {}", r.status().as_u16())),
        Err(e) => Status::Fail(short_err(&e.to_string())),
    }
}

async fn check_prefect_deployment(client: &reqwest::Client, cfg: &Config) -> Status {
    // Prefect 3 exposes deployment lookup via /api/deployments/name/<flow>/<deployment>
    let url = format!(
        "{}/api/deployments/name/dashi-ingest/main",
        cfg.prefect_url.trim_end_matches('/')
    );
    let resp = match client.get(&url).send().await {
        Ok(r) => r,
        Err(e) => return Status::Fail(short_err(&e.to_string())),
    };
    match resp.status().as_u16() {
        200 => Status::Ok("dashi-ingest/main found".into()),
        404 => Status::Fail("missing — run `make prefect-bootstrap`".into()),
        other => Status::Fail(format!("HTTP {other}")),
    }
}

async fn check_loki(client: &reqwest::Client, cfg: &Config) -> Status {
    let Some(loki) = cfg.loki_url.as_deref() else {
        return Status::Warn("loki_url not configured (optional)".into());
    };
    let url = format!("{}/ready", loki.trim_end_matches('/'));
    match client.get(&url).send().await {
        Ok(r) if r.status().is_success() => Status::Ok(format!("HTTP {}", r.status().as_u16())),
        Ok(r) => Status::Warn(format!(
            "HTTP {} — audit tail will fail",
            r.status().as_u16()
        )),
        Err(e) => Status::Warn(short_err(&e.to_string())),
    }
}

async fn check_s3(cfg: &Config) -> Status {
    if cfg.s3.access_key.is_empty() || cfg.s3.secret_key.is_empty() {
        return Status::Warn("S3 creds not set (gc/backup will fail)".into());
    }
    let endpoint = match url::Url::parse(&cfg.s3.endpoint) {
        Ok(u) => u,
        Err(e) => return Status::Fail(format!("bad endpoint: {e}")),
    };
    let mut found = Vec::new();
    let mut missing = Vec::new();
    let creds = Credentials::new(cfg.s3.access_key.clone(), cfg.s3.secret_key.clone());

    for name in [
        cfg.s3.landing_bucket.as_str(),
        cfg.s3.processed_bucket.as_str(),
        cfg.s3.curated_bucket.as_str(),
    ] {
        let bucket = match Bucket::new(
            endpoint.clone(),
            UrlStyle::Path,
            name.to_string(),
            cfg.s3.region.clone(),
        ) {
            Ok(b) => b,
            Err(e) => return Status::Fail(format!("bucket handle for {name}: {e}")),
        };
        let action = bucket.list_objects_v2(Some(&creds));
        // Mutating the URL query string after `sign(...)` invalidates
        // the SigV4 signature, so we send the LIST as-is. We don't
        // need pagination — first response confirms the bucket
        // exists and the creds are valid.
        let signed = action.sign(PRESIGN_TTL);
        match reqwest::get(signed).await {
            Ok(r) if r.status().is_success() => found.push(name.to_string()),
            _ => missing.push(name.to_string()),
        }
    }
    if missing.is_empty() {
        Status::Ok(format!("{} bucket(s)", found.len()))
    } else {
        Status::Fail(format!("missing/unreachable: {}", missing.join(", ")))
    }
}

async fn check_ingest_api(client: &reqwest::Client, api_url: &str) -> Status {
    let url = format!("{}/healthz", api_url.trim_end_matches('/'));
    match client.get(&url).send().await {
        Ok(r) if r.status().is_success() => Status::Ok(format!("HTTP {}", r.status().as_u16())),
        Ok(r) => Status::Warn(format!(
            "HTTP {} — `dashictl ingest` will fail",
            r.status().as_u16()
        )),
        Err(e) => Status::Warn(short_err(&e.to_string())),
    }
}

fn short_err(s: &str) -> String {
    // reqwest's chained error string is verbose; clip to one line.
    let first = s.split_once('\n').map(|p| p.0).unwrap_or(s);
    first.chars().take(80).collect()
}
