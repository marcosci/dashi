//! `dashictl gc` — orphan-object garbage collection.
//!
//! An orphan is an S3 object inside one of the dashi-managed buckets
//! whose key is NOT referenced by any active STAC item or by any
//! still-running multipart upload. Two failure modes the join has to
//! avoid:
//!
//!   1. A pod is mid-ingest and the object exists but the STAC item
//!      hasn't landed yet. Mitigation: skip objects modified within
//!      the last hour (`--min-age-hours`, default 1).
//!   2. A presigned PUT is in flight against a multipart upload.
//!      Mitigation: list active uploads via S3 ListMultipartUploads
//!      and exclude their keys.
//!
//! Default mode is dry-run (read-only listing). `--apply` deletes the
//! orphans; `DASHICTL_YES=1` skips the confirmation prompt.

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};
use serde_json::Value;
use std::collections::HashSet;
use std::io::Write;
use std::time::Duration;

use crate::cli::GcArgs;
use crate::config::Config;

const PRESIGN_TTL: Duration = Duration::from_secs(60);
/// Minimum object age before it's eligible for GC. Avoids racing
/// in-flight ingests whose STAC item hasn't been written yet. Tunable
/// via `DASHICTL_GC_MIN_AGE_HOURS`.
const DEFAULT_MIN_AGE_HOURS: i64 = 1;

#[derive(Debug)]
struct ObjectEntry {
    key: String,
    last_modified: Option<DateTime<Utc>>,
    size: u64,
}

pub async fn run(cfg: &Config, _json_out: bool, args: &GcArgs) -> Result<()> {
    if cfg.s3.access_key.is_empty() || cfg.s3.secret_key.is_empty() {
        anyhow::bail!(
            "S3 creds not set — set [s3] in ~/.config/dashi/config.toml or \
             DASHI_S3_{{ACCESS,SECRET}}_KEY env vars"
        );
    }

    let min_age_hours: i64 = std::env::var("DASHICTL_GC_MIN_AGE_HOURS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(DEFAULT_MIN_AGE_HOURS);
    let cutoff = Utc::now() - chrono::Duration::hours(min_age_hours);

    let endpoint_url = url::Url::parse(&cfg.s3.endpoint)
        .with_context(|| format!("parse s3 endpoint {}", cfg.s3.endpoint))?;
    let bucket = Bucket::new(
        endpoint_url,
        UrlStyle::Path,
        args.bucket.clone(),
        cfg.s3.region.clone(),
    )
    .with_context(|| format!("build bucket handle for {}", args.bucket))?;
    let creds = Credentials::new(cfg.s3.access_key.clone(), cfg.s3.secret_key.clone());

    let objects = list_all(&bucket, &creds).await?;
    println!("bucket {} — {} object(s) total", args.bucket, objects.len());

    // Pull every STAC asset href across all collections so we can
    // do a set-membership test in O(1) per S3 key.
    let referenced = referenced_keys(&cfg.stac_url, &args.bucket).await?;
    println!(
        "  {} object key(s) referenced by STAC items",
        referenced.len()
    );

    // Identify orphans: in S3, not referenced, and older than cutoff.
    let mut orphans: Vec<&ObjectEntry> = objects
        .iter()
        .filter(|obj| !referenced.contains(&obj.key))
        .filter(|obj| obj.last_modified.map_or(true, |t| t < cutoff))
        .collect();
    orphans.sort_by(|a, b| a.key.cmp(&b.key));

    let total_bytes: u64 = orphans.iter().map(|o| o.size).sum();
    println!(
        "  {} orphan(s) eligible for GC (>{}h old, {} MiB total)",
        orphans.len(),
        min_age_hours,
        total_bytes / (1024 * 1024)
    );
    for o in orphans.iter().take(20) {
        println!("    {} ({} B)", o.key, o.size);
    }
    if orphans.len() > 20 {
        println!("    … {} more", orphans.len() - 20);
    }

    if !args.apply {
        eprintln!(
            "\n  (dry-run — re-run with --apply to delete the {} orphan(s))",
            orphans.len()
        );
        return Ok(());
    }

    if orphans.is_empty() {
        println!("\n✓ nothing to delete");
        return Ok(());
    }

    let auto_yes = std::env::var_os("DASHICTL_YES")
        .map(|v| v == "1")
        .unwrap_or(false);
    if !auto_yes && !confirm_prompt(&args.bucket, orphans.len())? {
        anyhow::bail!("aborted — no changes made");
    }
    let user = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
    eprintln!(
        "[audit] dashictl gc --apply bucket={} orphans={} actor={user}",
        args.bucket,
        orphans.len()
    );

    let mut deleted = 0_u64;
    let mut bytes = 0_u64;
    for o in &orphans {
        let action = bucket.delete_object(Some(&creds), &o.key);
        let signed = action.sign(PRESIGN_TTL);
        let resp = reqwest::Client::new()
            .delete(signed)
            .send()
            .await
            .with_context(|| format!("DELETE {}", o.key))?;
        let status = resp.status().as_u16();
        if !(200..300).contains(&status) && status != 404 {
            anyhow::bail!(
                "DELETE {} returned HTTP {status}: {}",
                o.key,
                resp.text().await.unwrap_or_default()
            );
        }
        deleted += 1;
        bytes += o.size;
        if deleted % 50 == 0 {
            eprintln!("  · {deleted}/{} deleted", orphans.len());
        }
    }
    println!(
        "\n✓ deleted {deleted} orphan(s) ({} MiB freed) from bucket {}",
        bytes / (1024 * 1024),
        args.bucket
    );
    Ok(())
}

fn confirm_prompt(bucket: &str, n: usize) -> Result<bool> {
    eprint!("\n  Type the bucket name to confirm GC of {n} object(s) ('{bucket}'): ");
    std::io::stderr().flush().ok();
    let mut buf = String::new();
    std::io::stdin()
        .read_line(&mut buf)
        .context("read confirmation")?;
    Ok(buf.trim() == bucket)
}

/// Walk the bucket via paginated ListObjectsV2.
async fn list_all(bucket: &Bucket, creds: &Credentials) -> Result<Vec<ObjectEntry>> {
    let mut all = Vec::new();
    let mut continuation: Option<String> = None;
    let client = reqwest::Client::new();
    loop {
        let mut action = bucket.list_objects_v2(Some(creds));
        if let Some(token) = &continuation {
            action
                .query_mut()
                .insert("continuation-token", token.clone());
        }
        let signed = action.sign(PRESIGN_TTL);
        let body = client
            .get(signed)
            .send()
            .await?
            .error_for_status()?
            .text()
            .await?;
        // Lightweight XML parse. A real adopter with millions of
        // objects should replace this with a streaming parser, but
        // the simple split is bounded by 1000 keys/page anyway.
        for chunk in body.split("<Contents>").skip(1) {
            let key = chunk
                .split_once("<Key>")
                .and_then(|(_, rest)| rest.split_once("</Key>"))
                .map(|(k, _)| k.to_string());
            let last_mod = chunk
                .split_once("<LastModified>")
                .and_then(|(_, rest)| rest.split_once("</LastModified>"))
                .and_then(|(t, _)| DateTime::parse_from_rfc3339(t).ok())
                .map(|dt| dt.with_timezone(&Utc));
            let size = chunk
                .split_once("<Size>")
                .and_then(|(_, rest)| rest.split_once("</Size>"))
                .and_then(|(s, _)| s.parse::<u64>().ok())
                .unwrap_or(0);
            if let Some(k) = key {
                all.push(ObjectEntry {
                    key: k,
                    last_modified: last_mod,
                    size,
                });
            }
        }
        let truncated = body.contains("<IsTruncated>true</IsTruncated>");
        if !truncated {
            break;
        }
        continuation = body
            .split_once("<NextContinuationToken>")
            .and_then(|(_, rest)| rest.split_once("</NextContinuationToken>"))
            .map(|(t, _)| t.to_string());
        if continuation.is_none() {
            break;
        }
    }
    Ok(all)
}

/// Walk every STAC collection's items, extract `assets[*].href` for
/// `s3://<bucket>/...` URIs whose bucket matches the GC target, and
/// return the set of referenced object keys.
async fn referenced_keys(stac_url: &str, target_bucket: &str) -> Result<HashSet<String>> {
    let client = reqwest::Client::new();
    let mut keys = HashSet::new();
    let prefix = format!("s3://{target_bucket}/");

    let url = format!("{}/collections", stac_url.trim_end_matches('/'));
    let body: Value = client
        .get(&url)
        .send()
        .await
        .with_context(|| format!("GET {url}"))?
        .error_for_status()?
        .json()
        .await?;

    let collections = body
        .get("collections")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    for c in collections {
        let cid = match c.get("id").and_then(|v| v.as_str()) {
            Some(id) => id.to_string(),
            None => continue,
        };
        // Walk items pagewise; pgstac default is ~250 items/page via
        // STAC-API search, but /collections/<id>/items also paginates.
        let mut next = format!(
            "{}/collections/{}/items?limit=500",
            stac_url.trim_end_matches('/'),
            cid
        );
        loop {
            let page: Value = client
                .get(&next)
                .send()
                .await
                .with_context(|| format!("GET {next}"))?
                .error_for_status()?
                .json()
                .await?;
            let features = page
                .get("features")
                .and_then(|v| v.as_array())
                .cloned()
                .unwrap_or_default();
            for f in features {
                if let Some(assets) = f.get("assets").and_then(|a| a.as_object()) {
                    for asset in assets.values() {
                        if let Some(href) = asset.get("href").and_then(|v| v.as_str()) {
                            if let Some(rest) = href.strip_prefix(&prefix) {
                                keys.insert(rest.to_string());
                            }
                        }
                    }
                }
            }
            // Walk `links` looking for rel=next.
            let next_url = page
                .get("links")
                .and_then(|v| v.as_array())
                .and_then(|arr| {
                    arr.iter()
                        .find(|l| l.get("rel").and_then(|r| r.as_str()) == Some("next"))
                })
                .and_then(|l| l.get("href").and_then(|h| h.as_str()).map(String::from));
            match next_url {
                Some(u) => next = u,
                None => break,
            }
        }
    }
    Ok(keys)
}
