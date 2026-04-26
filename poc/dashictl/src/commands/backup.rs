//! `dashictl backup verify` — partial stub. Lists pg_dump objects in
//! the `backups` bucket and reports the freshest one. Restore-test
//! against a sacrificial Postgres is a future enhancement.

use anyhow::{Context, Result};
use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};
use std::time::Duration;

use crate::cli::BackupCmd;
use crate::config::Config;

const PRESIGN_TTL: Duration = Duration::from_secs(60);
const BACKUPS_BUCKET: &str = "backups";

pub async fn run(cfg: &Config, _json_out: bool, cmd: &BackupCmd) -> Result<()> {
    match cmd {
        BackupCmd::Verify => verify(cfg).await,
    }
}

async fn verify(cfg: &Config) -> Result<()> {
    let endpoint_url = url::Url::parse(&cfg.s3.endpoint)
        .with_context(|| format!("parse s3 endpoint {}", cfg.s3.endpoint))?;
    let bucket = Bucket::new(
        endpoint_url,
        UrlStyle::Path,
        BACKUPS_BUCKET,
        cfg.s3.region.clone(),
    )
    .with_context(|| format!("build bucket handle for {BACKUPS_BUCKET}"))?;

    let creds = Credentials::new(cfg.s3.access_key.clone(), cfg.s3.secret_key.clone());
    let action = bucket.list_objects_v2(Some(&creds));
    let url = action.sign(PRESIGN_TTL);

    let body = reqwest::get(url)
        .await
        .with_context(|| format!("LIST {BACKUPS_BUCKET}"))?
        .error_for_status()?
        .text()
        .await?;

    let keys: Vec<String> = body
        .split("<Key>")
        .skip(1)
        .filter_map(|c| c.split("</Key>").next().map(|s| s.to_string()))
        .collect();

    if keys.is_empty() {
        anyhow::bail!(
            "no backups found in s3://{}/. CronJob may be failing — \
             check `kubectl -n dashi-backup logs job/<latest>`.",
            BACKUPS_BUCKET
        );
    }

    // Newest-first by lexicographic key (we name backups
    // pg_<db>_YYYYMMDDTHHMMSSZ.dump.gz so lex order = chronological).
    let mut sorted = keys.clone();
    sorted.sort_unstable();
    sorted.reverse();

    println!("found {} backup object(s); newest 5:", keys.len());
    for k in sorted.iter().take(5) {
        println!("  {k}");
    }
    eprintln!(
        "\n  (verify only checks listing freshness. Restore-test against a \
         sacrificial Postgres is not yet implemented — track: \
         https://github.com/marcosci/dashi/issues, label: cli, backup.)"
    );
    Ok(())
}
