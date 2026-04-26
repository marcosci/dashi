//! `dashictl domain ...` — STAC collection CRUD.
//!
//! Mapping:
//!   list        → GET    /collections
//!   show <id>   → GET    /collections/{id}
//!   create <id> → PUT    /collections/{id}   (idempotent upsert)
//!
//! Classification ceiling lives in `extra_fields.dashi:max_classification`
//! per ADR-006 and is enforced server-side by the ingest API at
//! /trigger.

use anyhow::{Context, Result};
use serde_json::{json, Value};

use crate::cli::DomainCmd;
use crate::config::Config;
use crate::output::{print_json, table};

pub async fn run(cfg: &Config, json_out: bool, cmd: &DomainCmd) -> Result<()> {
    let client = reqwest::Client::new();
    match cmd {
        DomainCmd::List => list(&client, cfg, json_out).await,
        DomainCmd::Show { id } => show(&client, cfg, json_out, id).await,
        DomainCmd::Create {
            id,
            title,
            description,
            max_classification,
            retention,
        } => {
            create(
                &client,
                cfg,
                json_out,
                id,
                title,
                description.as_deref(),
                max_classification,
                retention,
            )
            .await
        }
    }
}

async fn list(client: &reqwest::Client, cfg: &Config, json_out: bool) -> Result<()> {
    let url = format!("{}/collections", cfg.stac_url);
    let resp: Value = client
        .get(&url)
        .send()
        .await
        .with_context(|| format!("GET {url}"))?
        .error_for_status()?
        .json()
        .await?;

    let collections = resp
        .get("collections")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    if json_out {
        return print_json(&collections);
    }

    let mut t = table(&["id", "title", "max_classification", "retention", "items"]);
    for c in collections {
        let id = c.get("id").and_then(|v| v.as_str()).unwrap_or("?");
        let title = c.get("title").and_then(|v| v.as_str()).unwrap_or("");
        // pgstac stores extras either inline or under extra_fields.
        let extra = c.get("extra_fields").unwrap_or(&c);
        let max_cls = extra
            .get("dashi:max_classification")
            .and_then(|v| v.as_str())
            .unwrap_or("int");
        let retention = extra
            .get("dashi:retention")
            .and_then(|v| v.as_str())
            .unwrap_or("indefinite");
        let item_count = c
            .get("summaries")
            .and_then(|s| s.get("dashi:item_count"))
            .and_then(|v| v.as_u64())
            .map(|n| n.to_string())
            .unwrap_or_else(|| "—".into());
        t.add_row(vec![id, title, max_cls, retention, &item_count]);
    }
    println!("{t}");
    Ok(())
}

async fn show(client: &reqwest::Client, cfg: &Config, json_out: bool, id: &str) -> Result<()> {
    let url = format!("{}/collections/{}", cfg.stac_url, id);
    let resp = client
        .get(&url)
        .send()
        .await
        .with_context(|| format!("GET {url}"))?;
    if resp.status() == reqwest::StatusCode::NOT_FOUND {
        anyhow::bail!("collection '{id}' not found in STAC");
    }
    let body: Value = resp.error_for_status()?.json().await?;

    if json_out {
        return print_json(&body);
    }
    println!("{}", serde_json::to_string_pretty(&body)?);
    Ok(())
}

#[allow(clippy::too_many_arguments)]
async fn create(
    client: &reqwest::Client,
    cfg: &Config,
    json_out: bool,
    id: &str,
    title: &str,
    description: Option<&str>,
    max_classification: &str,
    retention: &str,
) -> Result<()> {
    let body = json!({
        "type": "Collection",
        "id": id,
        "stac_version": "1.0.0",
        "title": title,
        "description": description.unwrap_or(title),
        "license": "various",
        // pgstac requires `links` to be present (may be empty); the
        // catalog will materialise the canonical self/parent/items links
        // server-side once the collection lands.
        "links": [],
        "extent": {
            "spatial": {"bbox": [[-180.0, -90.0, 180.0, 90.0]]},
            "temporal": {"interval": [[null, null]]}
        },
        "extra_fields": {
            "dashi:max_classification": max_classification,
            "dashi:retention": retention,
        },
    });

    // pgstac accepts POST /collections for both create and upsert.
    let url = format!("{}/collections", cfg.stac_url);
    let resp = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();

    if !status.is_success() {
        anyhow::bail!(
            "STAC rejected create for '{id}' ({status}): {}",
            text.chars().take(400).collect::<String>()
        );
    }

    if json_out {
        // Re-fetch + print canonical form.
        return show(client, cfg, true, id).await;
    }
    println!(
        "✓ created/updated collection '{id}' (title='{title}', \
         ceiling={max_classification}, retention={retention})"
    );
    Ok(())
}
