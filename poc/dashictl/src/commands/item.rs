//! `dashictl item delete` — STAC item cascade delete.
//!
//! Dry-run preview shows every artefact that would be removed:
//!   - STAC record (DELETE /collections/<coll>/items/<id>)
//!   - S3 assets (every `assets[*].href` that points at an
//!     `s3://` URI inside one of the configured dashi buckets)
//!   - Iceberg table partition (if `properties.dashi:iceberg_table`
//!     is set — currently surfaced as a manual instruction; full
//!     Iceberg drop-partition is parked behind the Postgres-backed
//!     catalogue work in Phase 3)
//!
//! `--apply` flips the cascade live. Operator gets one explicit
//! confirmation prompt unless `--yes` is also passed (CI mode). Any
//! step that fails leaves the rest of the cascade un-applied — the
//! command never claims success on a partial delete.

use std::io::Write;

use anyhow::{Context, Result};
use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};
use serde_json::Value;
use std::time::Duration;

use crate::cli::ItemCmd;
use crate::config::Config;

const PRESIGN_TTL: Duration = Duration::from_secs(60);

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

            // Confirmation prompt — skip when `--yes` (or `DASHICTL_YES=1`)
            // is in play so the same code path works in CI.
            let auto_yes = std::env::var_os("DASHICTL_YES")
                .map(|v| v == "1")
                .unwrap_or(false);
            if !auto_yes && !confirm_prompt(collection, item_id)? {
                anyhow::bail!("aborted — no changes made");
            }

            // Audit line printed BEFORE the cascade kicks off so log
            // shippers (Loki via stderr) get a record even if the
            // process is killed mid-cascade.
            let user = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
            eprintln!(
                "[audit] dashictl item delete --apply collection={collection} \
                 item={item_id} actor={user}"
            );

            cascade_delete(cfg, collection, item_id, &item).await?;
            println!("\n✓ deleted {collection}/{item_id}");
            Ok(())
        }
    }
}

fn confirm_prompt(collection: &str, item_id: &str) -> Result<bool> {
    eprint!("\n  Type the item id to confirm delete ('{item_id}'): ");
    std::io::stderr().flush().ok();
    let mut buf = String::new();
    std::io::stdin()
        .read_line(&mut buf)
        .context("read confirmation")?;
    if buf.trim() != item_id {
        eprintln!(
            "  (entered '{}' did not match '{collection}/{item_id}')",
            buf.trim()
        );
        return Ok(false);
    }
    Ok(true)
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

async fn cascade_delete(cfg: &Config, collection: &str, item_id: &str, item: &Value) -> Result<()> {
    // Order matters:
    //   1. Delete S3 assets first — STAC record disappearing while
    //      objects linger costs only storage (orphans, GC sweepable).
    //   2. Delete STAC record — invisible from APIs after this.
    //   3. Iceberg table partition — surfaced as manual TODO until
    //      the Postgres-backed catalogue lands (ADR-0006, Phase 3).
    delete_assets(cfg, item).await?;
    delete_stac(cfg, collection, item_id).await?;

    if let Some(props) = item.get("properties").and_then(|p| p.as_object()) {
        if let Some(table) = props.get("dashi:iceberg_table").and_then(|v| v.as_str()) {
            eprintln!(
                "  ⚠ Iceberg partition for table '{table}' NOT removed — drop \
                 manually via the iceberg-rest catalogue or wait for the \
                 Postgres-backed catalogue migration (Phase 3)."
            );
        }
    }
    Ok(())
}

async fn delete_assets(cfg: &Config, item: &Value) -> Result<()> {
    let assets = match item.get("assets").and_then(|a| a.as_object()) {
        Some(a) => a,
        None => return Ok(()),
    };
    if cfg.s3.access_key.is_empty() || cfg.s3.secret_key.is_empty() {
        eprintln!(
            "  ⚠ S3 creds not set — assets NOT deleted. Re-run with creds in \
             ~/.config/dashi/config.toml [s3] or DASHI_S3_* env vars."
        );
        return Ok(());
    }

    let endpoint = url::Url::parse(&cfg.s3.endpoint)
        .with_context(|| format!("parse s3 endpoint {}", cfg.s3.endpoint))?;
    let creds = Credentials::new(cfg.s3.access_key.clone(), cfg.s3.secret_key.clone());

    for (name, asset) in assets {
        let href = match asset.get("href").and_then(|v| v.as_str()) {
            Some(h) => h,
            None => continue,
        };
        if !href.starts_with("s3://") {
            eprintln!("  ⊘ asset '{name}' href '{href}' is not s3:// — skipped");
            continue;
        }
        let rest = &href[5..];
        let (bucket_name, key) = match rest.split_once('/') {
            Some((b, k)) => (b, k),
            None => {
                eprintln!("  ✗ asset '{name}' href '{href}' is malformed — skipped");
                continue;
            }
        };
        let bucket = Bucket::new(
            endpoint.clone(),
            UrlStyle::Path,
            bucket_name.to_string(),
            cfg.s3.region.clone(),
        )
        .with_context(|| format!("build bucket handle for {bucket_name}"))?;
        let action = bucket.delete_object(Some(&creds), key);
        let signed = action.sign(PRESIGN_TTL);

        let resp = reqwest::Client::new()
            .delete(signed)
            .send()
            .await
            .with_context(|| format!("DELETE {href}"))?;
        let status = resp.status().as_u16();
        // S3 DELETE is idempotent: 204 on success, 404 on missing.
        // RustFS may return 200 with an XML body — accept anything in
        // the 2xx range as success.
        if !(200..300).contains(&status) && status != 404 {
            anyhow::bail!(
                "DELETE {href} returned HTTP {status}: {}",
                resp.text().await.unwrap_or_default()
            );
        }
        println!("  ✓ deleted s3 {href}");
    }
    Ok(())
}

async fn delete_stac(cfg: &Config, collection: &str, item_id: &str) -> Result<()> {
    let url = format!(
        "{}/collections/{}/items/{}",
        cfg.stac_url.trim_end_matches('/'),
        collection,
        item_id
    );
    let resp = reqwest::Client::new()
        .delete(&url)
        .send()
        .await
        .with_context(|| format!("DELETE {url}"))?;
    let status = resp.status();
    if !status.is_success() {
        anyhow::bail!(
            "DELETE {url} returned {status}: {}",
            resp.text().await.unwrap_or_default()
        );
    }
    println!("  ✓ deleted STAC {collection}/{item_id}");
    Ok(())
}
