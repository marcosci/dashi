//! `dashictl item delete` — partial stub. Implements the dry-run
//! discovery (STAC item lookup + asset enumeration) so operators can
//! preview what *would* be deleted; the destructive `--apply` path is
//! held back until the cascade is fully tested against a sacrificial
//! collection.

use anyhow::{Context, Result};
use serde_json::Value;

use crate::cli::ItemCmd;
use crate::config::Config;

pub async fn run(cfg: &Config, json_out: bool, cmd: &ItemCmd) -> Result<()> {
    match cmd {
        ItemCmd::Delete { target, apply } => {
            let (collection, item_id) = target
                .split_once('/')
                .with_context(|| format!("expected <collection>/<item_id>, got '{target}'"))?;
            let item = fetch_item(cfg, collection, item_id).await?;

            if json_out {
                println!("{}", serde_json::to_string_pretty(&item)?);
            } else {
                print_summary(&item);
            }

            if !apply {
                eprintln!(
                    "\n  (dry-run — re-run with --apply to delete S3 assets, \
                     STAC record, and Iceberg snapshot. Cascade is one-way.)"
                );
                return Ok(());
            }

            anyhow::bail!(
                "`item delete --apply` is held back until the cascade is hardened. \
                 Manual workflow until then:\n  \
                 1. aws s3 rm <s3_uri> --recursive   (per asset.href)\n  \
                 2. curl -X DELETE {}/collections/{collection}/items/{item_id}\n  \
                 3. iceberg-rest DELETE on the table partition (if promoted).",
                cfg.stac_url
            );
        }
    }
}

async fn fetch_item(cfg: &Config, collection: &str, item_id: &str) -> Result<Value> {
    let url = format!(
        "{}/collections/{}/items/{}",
        cfg.stac_url, collection, item_id
    );
    let client = reqwest::Client::new();
    let resp = client
        .get(&url)
        .send()
        .await
        .with_context(|| format!("GET {url}"))?;
    if resp.status() == reqwest::StatusCode::NOT_FOUND {
        anyhow::bail!("item '{collection}/{item_id}' not found");
    }
    Ok(resp.error_for_status()?.json().await?)
}

fn print_summary(item: &Value) {
    let id = item.get("id").and_then(|v| v.as_str()).unwrap_or("?");
    let coll = item
        .get("collection")
        .and_then(|v| v.as_str())
        .unwrap_or("?");
    println!("would delete:");
    println!("  STAC      {coll}/{id}");
    if let Some(assets) = item.get("assets").and_then(|a| a.as_object()) {
        for (name, a) in assets {
            let href = a.get("href").and_then(|v| v.as_str()).unwrap_or("?");
            println!("  S3 asset  {name:>12} → {href}");
        }
    }
    if let Some(props) = item.get("properties").and_then(|p| p.as_object()) {
        if let Some(table) = props.get("dashi:iceberg_table").and_then(|v| v.as_str()) {
            println!("  Iceberg   {table}");
        }
    }
}
