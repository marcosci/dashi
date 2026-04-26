//! `dashictl gc` — partial stub. Lists S3 objects in a bucket (read-only
//! probe) and joins against the STAC catalog to identify orphans. The
//! delete path (`--apply`) is held back until the join is verified
//! against a multi-million-object bucket.

use anyhow::{Context, Result};
use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};
use std::time::Duration;

use crate::cli::GcArgs;
use crate::config::Config;

const PRESIGN_TTL: Duration = Duration::from_secs(60);

pub async fn run(cfg: &Config, _json_out: bool, args: &GcArgs) -> Result<()> {
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
    let action = bucket.list_objects_v2(Some(&creds));
    let url = action.sign(PRESIGN_TTL);

    let resp = reqwest::get(url)
        .await
        .with_context(|| format!("LIST {}", args.bucket))?
        .error_for_status()?
        .text()
        .await?;

    // Extract <Key> tags. Lightweight enough we don't pull in an XML crate.
    let keys: Vec<String> = resp
        .split("<Key>")
        .skip(1)
        .filter_map(|chunk| chunk.split("</Key>").next().map(|s| s.to_string()))
        .collect();

    println!("bucket {} contains {} object(s)", args.bucket, keys.len());
    for k in keys.iter().take(20) {
        println!("  {k}");
    }
    if keys.len() > 20 {
        println!("  … {} more", keys.len() - 20);
    }

    if args.apply {
        anyhow::bail!(
            "`gc --apply` not yet implemented — blocked on STAC-cross-reference \
             join (per ADR-007 retention rules). Currently this command is \
             read-only. Track: https://github.com/marcosci/dashi/issues \
             (label: cli, gc)."
        );
    }
    Ok(())
}
