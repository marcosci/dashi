//! CLI surface — clap derive definitions only. Handlers live in
//! `commands::*` and are dispatched from `main`.

use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(
    name = "dashictl",
    version,
    about = "Admin CLI for the dashi spatial data lake",
    propagate_version = true,
    subcommand_required = true,
    arg_required_else_help = true
)]
pub struct Cli {
    /// Active config context (matches a `[contexts.<name>]` block in
    /// ~/.config/dashi/config.toml). Default: `default` or
    /// `$DASHI_CONTEXT`.
    #[arg(long, global = true, env = "DASHI_CONTEXT")]
    pub context: Option<String>,

    /// Emit JSON instead of human-readable tables. Useful for piping
    /// into `jq` or downstream tooling.
    #[arg(long, global = true)]
    pub json: bool,

    /// Print every HTTP request before sending. Off by default; turn on
    /// for debugging an unhappy cluster.
    #[arg(short, long, global = true)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand, Debug)]
pub enum Command {
    /// STAC collection (= dashi domain) management.
    Domain {
        #[command(subcommand)]
        cmd: DomainCmd,
    },
    /// Grant/revoke OIDC roles per user × domain.
    User {
        #[command(subcommand)]
        cmd: UserCmd,
    },
    /// STAC item operations (cascade delete across S3 + STAC + Iceberg).
    Item {
        #[command(subcommand)]
        cmd: ItemCmd,
    },
    /// Replay a Prefect deployment over a date range.
    Backfill(BackfillArgs),
    /// Garbage-collect orphan S3 objects vs. STAC catalog.
    Gc(GcArgs),
    /// Tail / query the audit log via Loki.
    Audit {
        #[command(subcommand)]
        cmd: AuditCmd,
    },
    /// Backup + restore verification.
    Backup {
        #[command(subcommand)]
        cmd: BackupCmd,
    },
    /// Inspect Prefect flow runs.
    Runs(RunsArgs),
    /// Upload + scan + trigger an ingest. Same pipeline the web UI uses.
    Ingest(IngestArgs),
    /// Preflight checks — verify the cluster + APIs are reachable and
    /// the bootstrap is in a sane state. Exits non-zero on any failure
    /// so it's CI-friendly. Use as the success oracle for fresh-cluster
    /// bringups.
    Doctor(DoctorArgs),
    /// Print resolved configuration (after context + env merge).
    Config,
}

#[derive(Subcommand, Debug)]
pub enum DomainCmd {
    /// List all domains (= STAC collections).
    List,
    /// Show one domain's full STAC collection JSON.
    Show {
        /// Collection id (e.g. `gelaende_umwelt`).
        id: String,
    },
    /// Create a new domain. Idempotent — re-running with same id
    /// updates the title / description / classification ceiling.
    Create {
        /// Lowercase, dash-or-underscore-separated id.
        id: String,
        /// Human-readable title.
        #[arg(long)]
        title: String,
        /// One-line description.
        #[arg(long)]
        description: Option<String>,
        /// Classification ceiling. Items submitted at a higher tier are
        /// rejected at trigger time. One of: pub, int, rst, cnf.
        #[arg(long, default_value = "int", value_parser = ["pub", "int", "rst", "cnf"])]
        max_classification: String,
        /// Retention policy hint stored in extra_fields.
        #[arg(long, default_value = "indefinite")]
        retention: String,
    },
}

#[derive(Subcommand, Debug)]
pub enum UserCmd {
    /// Grant a role to a user on a specific domain.
    Grant {
        user: String,
        domain: String,
        /// One of: reader, writer, admin.
        role: String,
    },
}

#[derive(Subcommand, Debug)]
pub enum ItemCmd {
    /// Delete a STAC item and all of its S3 / Iceberg references.
    /// Dry-run by default — pass `--apply` to actually delete.
    Delete {
        /// `<collection>/<item_id>` form.
        target: String,
        /// Actually perform the delete. Without this flag the command
        /// prints what would happen and exits 0.
        #[arg(long)]
        apply: bool,
    },
}

#[derive(Parser, Debug)]
pub struct BackfillArgs {
    /// Prefect deployment name in `<flow>/<deployment>` form.
    pub deployment: String,
    /// ISO-8601 start (inclusive).
    #[arg(long)]
    pub from: String,
    /// ISO-8601 end (exclusive).
    #[arg(long)]
    pub to: String,
    /// Print the plan without creating any flow runs.
    #[arg(long)]
    pub dry_run: bool,
}

#[derive(Parser, Debug)]
pub struct GcArgs {
    /// Bucket to scan. Defaults to `landing` since orphans are cheapest
    /// to identify there.
    #[arg(long, default_value = "landing")]
    pub bucket: String,
    /// Actually delete orphans. Without this flag the command lists
    /// candidates only.
    #[arg(long)]
    pub apply: bool,
}

#[derive(Subcommand, Debug)]
pub enum AuditCmd {
    /// Stream audit log entries from Loki.
    Tail {
        /// Loki LogQL filter. Default tails every dashi service.
        #[arg(long, default_value = "{namespace=~\"dashi-.*\"}")]
        query: String,
        /// Maximum events per fetch.
        #[arg(long, default_value_t = 100)]
        limit: u32,
        /// Stream forever vs. one-shot fetch.
        #[arg(long)]
        follow: bool,
    },
}

#[derive(Subcommand, Debug)]
pub enum BackupCmd {
    /// Verify the most recent pg_dump can be inspected. Does NOT
    /// restore — only checks the archive header + size sanity.
    Verify,
    /// Restore the most recent backup into an ephemeral PostgreSQL,
    /// run a small set of sanity queries, and tear down. Proves the
    /// dump is intact + readable end-to-end. Requires kubectl on PATH
    /// + RBAC to create Jobs in the `dashi-backup` namespace.
    RestoreTest {
        /// Override which backup to restore. Defaults to the newest
        /// `pgstac/*.dump` found in s3://backups/.
        #[arg(long)]
        key: Option<String>,
        /// Skip the cleanup step on failure (leave the ephemeral
        /// Postgres + Job in-cluster for post-mortem). Always cleans
        /// up on success.
        #[arg(long)]
        leave_on_fail: bool,
    },
}

#[derive(Parser, Debug)]
pub struct RunsArgs {
    /// Filter by domain tag.
    #[arg(long)]
    pub domain: Option<String>,
    /// Limit returned rows.
    #[arg(long, default_value_t = 50)]
    pub limit: u32,
}

#[derive(Parser, Debug)]
pub struct DoctorArgs {
    /// ingest-api base URL (only checked if reachable; failure is
    /// non-fatal because the API is optional outside web ingest).
    #[arg(long, default_value = "http://localhost:8088")]
    pub api_url: String,
}

#[derive(Parser, Debug)]
pub struct IngestArgs {
    /// Local file or already-staged `s3://landing/...` URI. When given a
    /// local path the file is uploaded via /presign (single-PUT) or
    /// /multipart/* (chunked) depending on size; an s3:// URI is
    /// validated via /register and the upload step is skipped.
    pub source: String,
    /// Target domain (= STAC collection id). Must already exist.
    #[arg(long)]
    pub domain: String,
    /// Classification tier. One of: pub, int, rst, cnf.
    #[arg(long, default_value = "int", value_parser = ["pub", "int", "rst", "cnf"])]
    pub classification: String,
    /// ingest-api base URL. Defaults to `http://localhost:8088` (the
    /// stable port-forward set up by `port-forward-all.sh`).
    #[arg(long, default_value = "http://localhost:8088")]
    pub api_url: String,
    /// Skip the Prefect trigger — upload + scan only. Useful for
    /// validating a file before committing to a flow run.
    #[arg(long)]
    pub dry_run: bool,
}
