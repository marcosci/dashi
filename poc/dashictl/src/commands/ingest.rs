//! `dashictl ingest` — upload + scan + trigger pipeline driven by the
//! `ingest-api` shim. Mirrors what the web UI does, so a researcher
//! can replay any UI ingest from the shell.
//!
//! Routes used:
//!   POST /presign            — small files (single PUT)
//!   POST /multipart/start    — large files (>= threshold)
//!        per-part PUT to RustFS
//!   POST /multipart/complete — finalise multipart
//!   POST /register           — `s3://landing/...` URIs already in the bucket
//!   POST /scan               — detect kind, validate
//!   POST /trigger            — create Prefect flow run
//!
//! The CLI streams part PUTs sequentially (concurrency=1) — simpler
//! progress reporting and lets the operator Ctrl-C cleanly. The web UI
//! uses 4× concurrency for browser-side throughput.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::path::Path;

use crate::cli::IngestArgs;

/// Match the FastAPI shim's default upload cap (50 GiB) and multipart
/// threshold (500 MiB). These are upper bounds — if the API rejects
/// the request we surface the message verbatim.
const MULTIPART_THRESHOLD_BYTES: u64 = 500 * 1024 * 1024;

#[derive(Debug, Deserialize)]
struct PresignResponse {
    url: String,
    s3_uri: String,
}

#[derive(Debug, Deserialize)]
struct MultipartStartResponse {
    upload_id: String,
    bucket: String,
    key: String,
    s3_uri: String,
    part_size: u64,
    part_count: u32,
    urls: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct RegisterResponse {
    s3_uri: String,
    content_length: u64,
}

#[derive(Debug, Deserialize)]
struct ScanResponse {
    rows: Vec<ScanRow>,
    primary_count: u32,
    blocking_errors: u32,
}

#[derive(Debug, Deserialize)]
struct ScanRow {
    path: String,
    kind: String,
    driver: Option<String>,
    layer: Option<String>,
    ok: bool,
    errors: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct TriggerResponse {
    flow_run_id: String,
    flow_run_name: String,
    state: String,
    ui_url: String,
}

#[derive(Serialize)]
struct CompletePart {
    part_number: u32,
    etag: String,
}

pub async fn run(args: &IngestArgs) -> Result<()> {
    let client = reqwest::Client::builder()
        // Big PUTs of ≥500 MiB chunks need a generous timeout; 30 min
        // covers a 50 GiB upload at ~30 MB/s with comfortable headroom.
        .timeout(std::time::Duration::from_secs(30 * 60))
        .build()?;

    // 1. Get s3:// URI for the source. Either upload a local file or
    //    register an existing `s3://landing/...` object.
    let s3_uri = if args.source.starts_with("s3://") {
        register(&client, &args.api_url, &args.source).await?
    } else {
        upload(
            &client,
            &args.api_url,
            Path::new(&args.source),
            &args.domain,
        )
        .await?
    };
    eprintln!("✓ landed at {s3_uri}");

    // 2. Scan.
    let scan = scan(&client, &args.api_url, &s3_uri).await?;
    eprintln!(
        "✓ scan: {} primary, {} blocking error(s)",
        scan.primary_count, scan.blocking_errors
    );
    for r in &scan.rows {
        let kind = r.kind.as_str();
        let driver = r.driver.as_deref().unwrap_or("?");
        let layer = r.layer.as_deref().unwrap_or("");
        let ok = if r.ok { "✓" } else { "✗" };
        eprintln!(
            "  {ok} {kind:>10}  {driver:<14} {layer:<12} {path}",
            path = r.path
        );
        for e in &r.errors {
            eprintln!("       error: {e}");
        }
    }
    if scan.primary_count == 0 {
        anyhow::bail!("scan returned 0 primary detections — nothing to ingest");
    }
    if scan.blocking_errors > 0 {
        anyhow::bail!(
            "scan reported {} blocking error(s) — fix the source or pass a different file",
            scan.blocking_errors
        );
    }

    // 3. Trigger Prefect flow (unless --dry-run).
    if args.dry_run {
        eprintln!("(dry-run — skipping /trigger)");
        return Ok(());
    }
    let run = trigger(
        &client,
        &args.api_url,
        &s3_uri,
        &args.domain,
        &args.classification,
    )
    .await?;
    println!("flow_run_id   {}", run.flow_run_id);
    println!("flow_run_name {}", run.flow_run_name);
    println!("state         {}", run.state);
    println!("ui_url        {}", run.ui_url);
    Ok(())
}

async fn register(client: &reqwest::Client, api: &str, s3_uri: &str) -> Result<String> {
    let url = format!("{api}/register");
    let body = serde_json::json!({"s3_uri": s3_uri});
    let resp = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        anyhow::bail!("/register returned {status}: {text}");
    }
    let r: RegisterResponse = serde_json::from_str(&text).with_context(|| "parse /register")?;
    eprintln!("  · {} ({} bytes)", r.s3_uri, r.content_length);
    Ok(r.s3_uri)
}

async fn upload(client: &reqwest::Client, api: &str, path: &Path, domain: &str) -> Result<String> {
    let meta = std::fs::metadata(path).with_context(|| format!("stat {}", path.display()))?;
    let size = meta.len();
    let filename = path
        .file_name()
        .and_then(|n| n.to_str())
        .with_context(|| format!("filename invalid utf-8: {}", path.display()))?
        .to_string();
    let content_type = guess_content_type(&filename);
    eprintln!(
        "  · {} ({:.2} MiB, {})",
        filename,
        size as f64 / (1024.0 * 1024.0),
        content_type
    );

    if size >= MULTIPART_THRESHOLD_BYTES {
        upload_multipart(client, api, path, &filename, &content_type, size, domain).await
    } else {
        upload_single(client, api, path, &filename, &content_type, size, domain).await
    }
}

async fn upload_single(
    client: &reqwest::Client,
    api: &str,
    path: &Path,
    filename: &str,
    content_type: &str,
    size: u64,
    domain: &str,
) -> Result<String> {
    let presign_url = format!("{api}/presign");
    let body = serde_json::json!({
        "domain": domain,
        "filename": filename,
        "content_type": content_type,
        "content_length": size,
    });
    let resp = client
        .post(&presign_url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {presign_url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        anyhow::bail!("/presign returned {status}: {text}");
    }
    let pr: PresignResponse = serde_json::from_str(&text).context("parse /presign")?;

    let bytes = std::fs::read(path).with_context(|| format!("read {}", path.display()))?;
    let put = client
        .put(&pr.url)
        .header("Content-Type", content_type)
        .body(bytes)
        .send()
        .await
        .with_context(|| "presigned PUT")?;
    if !put.status().is_success() {
        anyhow::bail!(
            "presigned PUT failed: {} {}",
            put.status(),
            put.text().await.unwrap_or_default()
        );
    }
    Ok(pr.s3_uri)
}

async fn upload_multipart(
    client: &reqwest::Client,
    api: &str,
    path: &Path,
    filename: &str,
    content_type: &str,
    size: u64,
    domain: &str,
) -> Result<String> {
    use std::io::{Read, Seek, SeekFrom};

    let start_url = format!("{api}/multipart/start");
    let body = serde_json::json!({
        "domain": domain,
        "filename": filename,
        "content_type": content_type,
        "content_length": size,
    });
    let resp = client
        .post(&start_url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {start_url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        anyhow::bail!("/multipart/start returned {status}: {text}");
    }
    let init: MultipartStartResponse =
        serde_json::from_str(&text).context("parse /multipart/start")?;
    eprintln!(
        "  · multipart: {} parts × {:.1} MiB",
        init.part_count,
        init.part_size as f64 / (1024.0 * 1024.0)
    );

    let mut file = std::fs::File::open(path).with_context(|| format!("open {}", path.display()))?;
    let mut completed: Vec<CompletePart> = Vec::with_capacity(init.urls.len());
    let mut buf = vec![0u8; init.part_size as usize];

    for (i, url) in init.urls.iter().enumerate() {
        let part_number = (i as u32) + 1;
        let offset = (i as u64) * init.part_size;
        let to_read = std::cmp::min(init.part_size, size - offset) as usize;
        file.seek(SeekFrom::Start(offset))
            .with_context(|| format!("seek part {part_number}"))?;
        let read = file
            .read(&mut buf[..to_read])
            .with_context(|| format!("read part {part_number}"))?;
        if read != to_read {
            anyhow::bail!("short read on part {part_number}: {read}/{to_read}");
        }

        let part_bytes = buf[..to_read].to_vec();
        let resp = client
            .put(url)
            .body(part_bytes)
            .send()
            .await
            .with_context(|| format!("PUT part {part_number}"))?;
        if !resp.status().is_success() {
            // Best-effort abort.
            let _ = abort_multipart(client, api, &init.bucket, &init.key, &init.upload_id).await;
            anyhow::bail!(
                "PUT part {part_number} failed: {} {}",
                resp.status(),
                resp.text().await.unwrap_or_default()
            );
        }
        let etag = resp
            .headers()
            .get(reqwest::header::ETAG)
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string())
            .with_context(|| format!("missing ETag on part {part_number}"))?;
        completed.push(CompletePart { part_number, etag });

        let pct = ((i + 1) * 100) / init.urls.len();
        eprint!(
            "\r  · uploaded {}/{} parts ({pct}%)        ",
            i + 1,
            init.urls.len()
        );
        use std::io::Write;
        std::io::stderr().flush().ok();
    }
    eprintln!();

    let complete_url = format!("{api}/multipart/complete");
    let body = serde_json::json!({
        "bucket": init.bucket,
        "key": init.key,
        "upload_id": init.upload_id,
        "parts": completed,
    });
    let resp = client
        .post(&complete_url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {complete_url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        anyhow::bail!("/multipart/complete returned {status}: {text}");
    }
    Ok(init.s3_uri)
}

async fn abort_multipart(
    client: &reqwest::Client,
    api: &str,
    bucket: &str,
    key: &str,
    upload_id: &str,
) -> Result<()> {
    let url = format!("{api}/multipart/abort");
    client
        .post(&url)
        .json(&serde_json::json!({
            "bucket": bucket,
            "key": key,
            "upload_id": upload_id,
        }))
        .send()
        .await?;
    Ok(())
}

async fn scan(client: &reqwest::Client, api: &str, s3_uri: &str) -> Result<ScanResponse> {
    let url = format!("{api}/scan");
    let resp = client
        .post(&url)
        .json(&serde_json::json!({"s3_uri": s3_uri}))
        .send()
        .await
        .with_context(|| format!("POST {url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        anyhow::bail!("/scan returned {status}: {text}");
    }
    serde_json::from_str(&text).context("parse /scan")
}

async fn trigger(
    client: &reqwest::Client,
    api: &str,
    s3_uri: &str,
    domain: &str,
    classification: &str,
) -> Result<TriggerResponse> {
    let url = format!("{api}/trigger");
    let body = serde_json::json!({
        "s3_uri": s3_uri,
        "domain": domain,
        "classification": classification,
    });
    let resp = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .with_context(|| format!("POST {url}"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        anyhow::bail!("/trigger returned {status}: {text}");
    }
    let parsed: Value = serde_json::from_str(&text).context("parse /trigger")?;
    serde_json::from_value(parsed).context("/trigger response shape")
}

fn guess_content_type(filename: &str) -> String {
    let ext = filename
        .rsplit('.')
        .next()
        .unwrap_or("")
        .to_ascii_lowercase();
    match ext.as_str() {
        "tif" | "tiff" => "image/tiff".into(),
        "geojson" => "application/geo+json".into(),
        "json" => "application/json".into(),
        "gpkg" => "application/geopackage+sqlite3".into(),
        "shp" | "shx" | "dbf" => "application/octet-stream".into(),
        "zip" => "application/zip".into(),
        "laz" | "las" | "copc" => "application/octet-stream".into(),
        "fgb" => "application/octet-stream".into(),
        "parquet" => "application/octet-stream".into(),
        "nc" | "nc4" | "h5" | "hdf5" | "hdf" | "grib" | "grb" | "grb2" => {
            "application/octet-stream".into()
        }
        _ => "application/octet-stream".into(),
    }
}
