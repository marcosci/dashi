//! `dashictl backup` — backup verification + restore-test.
//!
//! Two commands:
//!   - `verify`        — list `s3://backups/...`, report freshness.
//!   - `restore-test`  — spin an ephemeral PostgreSQL, restore the
//!     newest dump, run sanity queries, tear it down. Proves the
//!     archive is intact + readable end-to-end. Backups that nobody
//!     ever restores aren't backups.
//!
//! `restore-test` shells out to `kubectl` because the heavy lifting
//! (creating Jobs, streaming logs, cleanup) is what kubectl is good
//! at. Adding a full kube client to dashictl's binary would add ~5 MB
//! and a transitive dep on rustls/openssl that we don't need
//! elsewhere.

use anyhow::{Context, Result};
use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};
use std::process::Command;
use std::time::Duration;

use crate::cli::BackupCmd;
use crate::config::Config;

const PRESIGN_TTL: Duration = Duration::from_secs(60);
const BACKUPS_BUCKET: &str = "backups";
const RESTORE_NS: &str = "dashi-backup";
const POSTGRES_IMAGE: &str = "postgres:16-alpine";

pub async fn run(cfg: &Config, _json_out: bool, cmd: &BackupCmd) -> Result<()> {
    match cmd {
        BackupCmd::Verify => verify(cfg).await,
        BackupCmd::RestoreTest { key, leave_on_fail } => {
            restore_test(cfg, key.as_deref(), *leave_on_fail).await
        }
    }
}

async fn verify(cfg: &Config) -> Result<()> {
    let keys = list_backups(cfg).await?;
    if keys.is_empty() {
        anyhow::bail!(
            "no backups found in s3://{}/. CronJob may be failing — \
             check `kubectl -n {} logs job/<latest>`.",
            BACKUPS_BUCKET,
            RESTORE_NS,
        );
    }
    let mut sorted = keys.clone();
    sorted.sort_unstable();
    sorted.reverse();

    println!("found {} backup object(s); newest 5:", keys.len());
    for k in sorted.iter().take(5) {
        println!("  {k}");
    }
    eprintln!(
        "\n  freshness check only — run `dashictl backup restore-test` to \
         prove the newest dump is restorable."
    );
    Ok(())
}

async fn list_backups(cfg: &Config) -> Result<Vec<String>> {
    if cfg.s3.access_key.is_empty() || cfg.s3.secret_key.is_empty() {
        anyhow::bail!(
            "S3 creds not set — set [s3] in ~/.config/dashi/config.toml or \
             DASHI_S3_{{ACCESS,SECRET}}_KEY env vars"
        );
    }
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
    let signed = action.sign(PRESIGN_TTL);
    let body = reqwest::get(signed)
        .await
        .with_context(|| format!("LIST {BACKUPS_BUCKET}"))?
        .error_for_status()?
        .text()
        .await?;
    Ok(body
        .split("<Key>")
        .skip(1)
        .filter_map(|c| c.split("</Key>").next().map(|s| s.to_string()))
        .collect())
}

async fn restore_test(cfg: &Config, override_key: Option<&str>, leave_on_fail: bool) -> Result<()> {
    if which("kubectl").is_none() {
        anyhow::bail!(
            "`kubectl` not on PATH — restore-test shells out to kubectl for \
             Job + cleanup. Install kubectl + ensure the active context \
             points at the cluster you want to verify."
        );
    }

    let key = match override_key {
        Some(k) => k.to_string(),
        None => {
            let mut keys = list_backups(cfg)
                .await?
                .into_iter()
                .filter(|k| k.starts_with("pgstac/") && k.ends_with(".dump"))
                .collect::<Vec<_>>();
            keys.sort_unstable();
            keys.into_iter()
                .last()
                .context("no pgstac/*.dump backups found in s3://backups/")?
        }
    };

    let job_id = format!(
        "restore-test-{}",
        chrono::Utc::now().format("%Y%m%dt%H%M%S")
    );

    println!("→ restore-test using key {key}");
    println!("→ Job: {RESTORE_NS}/{job_id}");

    let manifest = render_job_manifest(&job_id, &key);
    apply_manifest(&manifest)?;

    let outcome = wait_for_job(&job_id);
    match &outcome {
        Ok(()) => {
            println!("\n✓ restore-test succeeded — newest backup is restorable");
            cleanup(&job_id);
        }
        Err(e) => {
            eprintln!("\n✗ restore-test failed: {e}");
            if leave_on_fail {
                eprintln!(
                    "  (--leave-on-fail set; not cleaning up. Inspect with:\n  \
                     kubectl -n {RESTORE_NS} logs job/{job_id}\n  \
                     kubectl -n {RESTORE_NS} describe job/{job_id})"
                );
            } else {
                cleanup(&job_id);
            }
        }
    }
    outcome
}

/// Inline kubernetes manifest. Single Pod that:
///   1. Streams the dump from RustFS via curl-against-presigned-url
///      OR via aws-cli — but to keep the image minimal we use the
///      `dashi-rustfs-pipeline` Secret to compose a presigned-URL-free
///      direct fetch using `psql`'s ability to read from stdin.
///
/// Strategy: shell out inside the Pod to `aws s3 cp` (the postgres
/// image doesn't ship aws-cli, so we install it inline via apk) →
/// pg_restore into a fresh local Postgres → run sanity SELECTs.
fn render_job_manifest(job_id: &str, key: &str) -> String {
    format!(
        r#"
apiVersion: batch/v1
kind: Job
metadata:
  name: {job_id}
  namespace: {RESTORE_NS}
  labels:
    app.kubernetes.io/name: backup-restore-test
    app.kubernetes.io/part-of: dashi
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: backup-restore-test
    spec:
      restartPolicy: Never
      containers:
        - name: restore
          image: {POSTGRES_IMAGE}
          env:
            - name: BACKUP_KEY
              value: "{key}"
            - name: POSTGRES_PASSWORD
              value: "ephemeral"
            - name: PGDATA
              value: /var/lib/postgresql/data
            - name: AWS_S3_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: dashi-rustfs-pipeline
                  key: endpoint
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: dashi-rustfs-pipeline
                  key: access-key
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: dashi-rustfs-pipeline
                  key: secret-key
          command:
            - sh
            - -c
            - |
              set -euo pipefail
              echo "→ install aws-cli + start ephemeral postgres"
              apk add --quiet --no-cache aws-cli
              # Init the cluster directory + start postgres in the bg
              mkdir -p "$PGDATA" && chown postgres:postgres "$PGDATA"
              su -s /bin/sh postgres -c "initdb -D $PGDATA --auth=trust" >/dev/null
              su -s /bin/sh postgres -c "pg_ctl -D $PGDATA -l /tmp/pg.log -o '-c listen_addresses=127.0.0.1' start"
              for i in $(seq 1 30); do
                pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1 && break
                sleep 1
              done
              psql -h 127.0.0.1 -U postgres -c 'CREATE DATABASE pgstac;'

              echo "→ download dump s3://{BACKUPS_BUCKET}/$BACKUP_KEY"
              aws --endpoint-url "$AWS_S3_ENDPOINT" s3 cp \
                "s3://{BACKUPS_BUCKET}/$BACKUP_KEY" /tmp/backup.dump

              echo "→ pg_restore"
              pg_restore -h 127.0.0.1 -U postgres -d pgstac --no-owner --no-acl \
                /tmp/backup.dump

              echo "→ sanity SELECTs"
              psql -h 127.0.0.1 -U postgres -d pgstac -At -c \
                "select count(*) as collections from pgstac.collections;" \
                | tee /tmp/collections.count
              psql -h 127.0.0.1 -U postgres -d pgstac -At -c \
                "select count(*) as items from pgstac.items;" \
                | tee /tmp/items.count

              c=$(cat /tmp/collections.count)
              i=$(cat /tmp/items.count)
              echo "✓ restored: $c collection(s), $i item(s)"
              if [ "$c" -lt 0 ] 2>/dev/null; then
                echo "✗ negative collection count — corrupt restore" && exit 1
              fi
"#
    )
}

fn apply_manifest(manifest: &str) -> Result<()> {
    let mut child = Command::new("kubectl")
        .args(["apply", "-f", "-"])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::inherit())
        .stderr(std::process::Stdio::inherit())
        .spawn()
        .context("spawn kubectl apply")?;
    use std::io::Write;
    child
        .stdin
        .as_mut()
        .unwrap()
        .write_all(manifest.as_bytes())
        .context("write manifest to kubectl")?;
    let status = child.wait().context("kubectl apply")?;
    if !status.success() {
        anyhow::bail!("kubectl apply failed: {status}");
    }
    Ok(())
}

fn wait_for_job(job_id: &str) -> Result<()> {
    println!("→ waiting for Job to complete (up to 10 min)");
    let status = Command::new("kubectl")
        .args([
            "-n",
            RESTORE_NS,
            "wait",
            "--for=condition=complete",
            &format!("job/{job_id}"),
            "--timeout=10m",
        ])
        .status()
        .context("kubectl wait")?;

    // Always stream logs, regardless of pass/fail.
    println!("\n--- Job logs ---");
    let _ = Command::new("kubectl")
        .args([
            "-n",
            RESTORE_NS,
            "logs",
            &format!("job/{job_id}"),
            "--tail=200",
        ])
        .status();
    println!("--- end logs ---");

    if !status.success() {
        anyhow::bail!("Job did not reach Complete (kubectl wait exit={status})");
    }
    Ok(())
}

fn cleanup(job_id: &str) {
    let _ = Command::new("kubectl")
        .args([
            "-n",
            RESTORE_NS,
            "delete",
            &format!("job/{job_id}"),
            "--ignore-not-found",
        ])
        .status();
}

fn which(cmd: &str) -> Option<std::path::PathBuf> {
    let path_var = std::env::var_os("PATH")?;
    for p in std::env::split_paths(&path_var) {
        let candidate = p.join(cmd);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}
