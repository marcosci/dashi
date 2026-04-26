//! `dashictl runs` — list Prefect flow runs (admin view of the whole
//! cluster, not the per-user `Runs` tab in the web UI).

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde_json::{json, Value};

use crate::cli::RunsArgs;
use crate::config::Config;
use crate::output::{print_json, table};

pub async fn run(cfg: &Config, json_out: bool, args: &RunsArgs) -> Result<()> {
    let client = reqwest::Client::new();
    let url = format!("{}/api/flow_runs/filter", cfg.prefect_url);

    // Build a Prefect filter body. Prefect 3 wants a POST with JSON
    // criteria; the empty case `{"limit": N}` returns the most recent
    // runs across all deployments.
    let mut body = json!({
        "limit": args.limit,
        "sort": "EXPECTED_START_TIME_DESC",
    });
    if let Some(domain) = &args.domain {
        body["flow_runs"] = json!({
            "tags": {"all_": [format!("domain:{domain}")]}
        });
    }

    let resp: Vec<Value> = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {url}"))?
        .error_for_status()?
        .json()
        .await?;

    if json_out {
        return print_json(&resp);
    }

    let mut t = table(&["id", "name", "state", "domain", "started", "ended"]);
    for r in &resp {
        let id = r.get("id").and_then(|v| v.as_str()).unwrap_or("?");
        let name = r.get("name").and_then(|v| v.as_str()).unwrap_or("");
        let state = r
            .get("state")
            .and_then(|s| s.get("type"))
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let started = fmt_ts(r.get("start_time"));
        let ended = fmt_ts(r.get("end_time"));
        let domain = r
            .get("tags")
            .and_then(|v| v.as_array())
            .and_then(|tags| {
                tags.iter()
                    .filter_map(|t| t.as_str())
                    .find(|t| t.starts_with("domain:"))
            })
            .map(|t| t.trim_start_matches("domain:").to_string())
            .unwrap_or_else(|| "—".into());
        t.add_row(vec![
            &id[..8.min(id.len())],
            name,
            state,
            &domain,
            &started,
            &ended,
        ]);
    }
    println!("{t}");
    Ok(())
}

fn fmt_ts(v: Option<&Value>) -> String {
    v.and_then(|v| v.as_str())
        .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
        .map(|dt| {
            dt.with_timezone(&Utc)
                .to_rfc3339_opts(chrono::SecondsFormat::Secs, true)
        })
        .unwrap_or_else(|| "—".into())
}
