//! `dashictl audit tail` — wrap Loki's query / query_range endpoints.
//!
//! Loki returns a streams-of-streams JSON shape; we flatten it into one
//! event per line ordered by timestamp. `--follow` polls every 2 s with
//! `start = last_seen_ts + 1ns` so events emit in monotonic order even
//! across re-fetches.

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::Deserialize;

use crate::cli::AuditCmd;
use crate::config::Config;

const POLL_INTERVAL_MS: u64 = 2_000;

#[derive(Debug, Deserialize)]
struct LokiResp {
    data: LokiData,
}

#[derive(Debug, Deserialize)]
struct LokiData {
    result: Vec<LokiStream>,
}

#[derive(Debug, Deserialize)]
struct LokiStream {
    stream: std::collections::BTreeMap<String, String>,
    /// Each value is `[ts_ns_string, line]`.
    values: Vec<[String; 2]>,
}

pub async fn run(cfg: &Config, json_out: bool, cmd: &AuditCmd) -> Result<()> {
    let loki = cfg.loki_url.as_deref().context(
        "loki_url not configured — set DASHI_LOKI_URL or add it to ~/.config/dashi/config.toml",
    )?;
    match cmd {
        AuditCmd::Tail {
            query,
            limit,
            follow,
        } => tail(loki, json_out, query, *limit, *follow).await,
    }
}

async fn tail(loki: &str, json_out: bool, query: &str, limit: u32, follow: bool) -> Result<()> {
    let client = reqwest::Client::new();
    let mut last_ts_ns: Option<u128> = None;

    loop {
        let url = format!("{loki}/loki/api/v1/query_range");
        let mut req = client.get(&url).query(&[
            ("query", query),
            ("limit", &limit.to_string()),
            ("direction", "forward"),
        ]);
        if let Some(ts) = last_ts_ns {
            // +1 ns avoids re-emitting the most recent line on the next poll.
            req = req.query(&[("start", &(ts + 1).to_string())]);
        } else {
            // First fetch: last 5 minutes.
            let start_ns = (Utc::now() - chrono::Duration::minutes(5))
                .timestamp_nanos_opt()
                .unwrap_or(0);
            req = req.query(&[("start", &start_ns.to_string())]);
        }

        let resp: LokiResp = req
            .send()
            .await
            .with_context(|| format!("GET {url}"))?
            .error_for_status()?
            .json()
            .await?;

        // Flatten + sort by ts ascending. Loki returns one entry per
        // stream; we want a single chronologically-ordered tail.
        let mut events: Vec<(u128, String, String)> = Vec::new();
        for s in resp.data.result {
            let ns_label = s
                .stream
                .iter()
                .map(|(k, v)| format!("{k}={v}"))
                .collect::<Vec<_>>()
                .join(",");
            for [ts, line] in s.values {
                let ts_ns: u128 = ts.parse().unwrap_or(0);
                events.push((ts_ns, ns_label.clone(), line));
            }
        }
        events.sort_by_key(|(ts, _, _)| *ts);

        for (ts_ns, label, line) in &events {
            if json_out {
                let v = serde_json::json!({
                    "ts_ns": ts_ns.to_string(),
                    "stream": label,
                    "line": line,
                });
                println!("{}", serde_json::to_string(&v)?);
            } else {
                let ts = ns_to_iso(*ts_ns);
                // Clip very long log lines so the terminal stays readable —
                // operators can re-fetch in JSON for full inspection.
                let clipped: String = line.chars().take(400).collect();
                println!("{ts}  {label}  {clipped}");
            }
        }

        if let Some((max_ts, _, _)) = events.last() {
            last_ts_ns = Some(*max_ts);
        }

        if !follow {
            return Ok(());
        }
        tokio::time::sleep(std::time::Duration::from_millis(POLL_INTERVAL_MS)).await;
    }
}

fn ns_to_iso(ns: u128) -> String {
    let secs = (ns / 1_000_000_000) as i64;
    let sub_ns = (ns % 1_000_000_000) as u32;
    DateTime::<Utc>::from_timestamp(secs, sub_ns)
        .map(|dt| dt.to_rfc3339_opts(chrono::SecondsFormat::Millis, true))
        .unwrap_or_else(|| ns.to_string())
}
