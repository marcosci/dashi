//! Configuration loader. Precedence (lowest → highest):
//!   1. compiled defaults (cluster-internal hostnames)
//!   2. `~/.config/dashi/config.toml` (or `$DASHI_CONFIG_HOME`)
//!   3. environment variables (`DASHI_*`)
//!   4. CLI flags (handled in `cli.rs`, applied on top of `Config`)
//!
//! Contexts (`[contexts.<name>]` blocks) let one config switch between
//! local k3d, staging, and prod without separate files. The active
//! context comes from `--context` or `DASHI_CONTEXT`.

use std::path::PathBuf;

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Clone)]
pub struct Config {
    pub stac_url: String,
    pub prefect_url: String,
    pub loki_url: Option<String>,
    pub s3: S3Config,
    pub context: String,
}

#[derive(Debug, Clone)]
pub struct S3Config {
    pub endpoint: String,
    pub region: String,
    pub access_key: String,
    pub secret_key: String,
    pub landing_bucket: String,
    pub processed_bucket: String,
    pub curated_bucket: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            // Defaults assume `port-forward-all.sh` is running. In-cluster
            // runs override these with cluster-internal Service URLs.
            stac_url: "http://localhost:8080".into(),
            prefect_url: "http://localhost:4200".into(),
            loki_url: Some("http://localhost:3100".into()),
            s3: S3Config {
                endpoint: "http://localhost:9000".into(),
                region: "us-east-1".into(),
                access_key: String::new(),
                secret_key: String::new(),
                landing_bucket: "landing".into(),
                processed_bucket: "processed".into(),
                curated_bucket: "curated".into(),
            },
            context: "default".into(),
        }
    }
}

#[derive(Debug, Default, Deserialize)]
struct RawConfig {
    stac_url: Option<String>,
    prefect_url: Option<String>,
    loki_url: Option<String>,
    #[serde(default)]
    s3: RawS3,
    #[serde(default)]
    contexts: std::collections::BTreeMap<String, RawContext>,
}

#[derive(Debug, Default, Deserialize)]
struct RawS3 {
    endpoint: Option<String>,
    region: Option<String>,
    access_key: Option<String>,
    secret_key: Option<String>,
    landing_bucket: Option<String>,
    processed_bucket: Option<String>,
    curated_bucket: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
struct RawContext {
    stac_url: Option<String>,
    prefect_url: Option<String>,
    loki_url: Option<String>,
    #[serde(default)]
    s3: RawS3,
}

fn config_path() -> PathBuf {
    if let Ok(p) = std::env::var("DASHI_CONFIG_HOME") {
        return PathBuf::from(p).join("config.toml");
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    PathBuf::from(home)
        .join(".config")
        .join("dashi")
        .join("config.toml")
}

pub fn load(context_override: Option<&str>) -> Result<Config> {
    let mut cfg = Config::default();

    let path = config_path();
    if path.exists() {
        let text = std::fs::read_to_string(&path)
            .with_context(|| format!("read config {}", path.display()))?;
        let raw: RawConfig =
            toml::from_str(&text).with_context(|| format!("parse {}", path.display()))?;
        apply_raw(&mut cfg, &raw);

        // Apply the requested context block (if any) on top.
        let ctx = context_override
            .map(|s| s.to_string())
            .or_else(|| std::env::var("DASHI_CONTEXT").ok())
            .unwrap_or_else(|| "default".into());
        if let Some(block) = raw.contexts.get(&ctx) {
            apply_context(&mut cfg, block);
            cfg.context = ctx;
        } else if context_override.is_some() {
            // Caller explicitly named a context that doesn't exist —
            // surface the error rather than silently using defaults.
            anyhow::bail!("context '{}' not found in {}", ctx, path.display(),);
        }
    }

    apply_env(&mut cfg);
    Ok(cfg)
}

fn apply_raw(cfg: &mut Config, raw: &RawConfig) {
    if let Some(v) = &raw.stac_url {
        cfg.stac_url = v.clone();
    }
    if let Some(v) = &raw.prefect_url {
        cfg.prefect_url = v.clone();
    }
    if let Some(v) = &raw.loki_url {
        cfg.loki_url = Some(v.clone());
    }
    apply_s3(&mut cfg.s3, &raw.s3);
}

fn apply_context(cfg: &mut Config, ctx: &RawContext) {
    if let Some(v) = &ctx.stac_url {
        cfg.stac_url = v.clone();
    }
    if let Some(v) = &ctx.prefect_url {
        cfg.prefect_url = v.clone();
    }
    if let Some(v) = &ctx.loki_url {
        cfg.loki_url = Some(v.clone());
    }
    apply_s3(&mut cfg.s3, &ctx.s3);
}

fn apply_s3(s3: &mut S3Config, raw: &RawS3) {
    if let Some(v) = &raw.endpoint {
        s3.endpoint = v.clone();
    }
    if let Some(v) = &raw.region {
        s3.region = v.clone();
    }
    if let Some(v) = &raw.access_key {
        s3.access_key = v.clone();
    }
    if let Some(v) = &raw.secret_key {
        s3.secret_key = v.clone();
    }
    if let Some(v) = &raw.landing_bucket {
        s3.landing_bucket = v.clone();
    }
    if let Some(v) = &raw.processed_bucket {
        s3.processed_bucket = v.clone();
    }
    if let Some(v) = &raw.curated_bucket {
        s3.curated_bucket = v.clone();
    }
}

fn apply_env(cfg: &mut Config) {
    if let Ok(v) = std::env::var("DASHI_STAC_URL") {
        cfg.stac_url = v;
    }
    if let Ok(v) = std::env::var("DASHI_PREFECT_URL") {
        cfg.prefect_url = v;
    }
    if let Ok(v) = std::env::var("DASHI_LOKI_URL") {
        cfg.loki_url = Some(v);
    }
    if let Ok(v) = std::env::var("DASHI_S3_ENDPOINT") {
        cfg.s3.endpoint = v;
    }
    if let Ok(v) = std::env::var("DASHI_S3_REGION") {
        cfg.s3.region = v;
    }
    if let Ok(v) = std::env::var("DASHI_S3_ACCESS_KEY") {
        cfg.s3.access_key = v;
    }
    if let Ok(v) = std::env::var("DASHI_S3_SECRET_KEY") {
        cfg.s3.secret_key = v;
    }
    if let Ok(v) = std::env::var("DASHI_LANDING_BUCKET") {
        cfg.s3.landing_bucket = v;
    }
    if let Ok(v) = std::env::var("DASHI_PROCESSED_BUCKET") {
        cfg.s3.processed_bucket = v;
    }
    if let Ok(v) = std::env::var("DASHI_CURATED_BUCKET") {
        cfg.s3.curated_bucket = v;
    }
}
