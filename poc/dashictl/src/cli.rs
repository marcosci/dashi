//! CLI surface — clap derive definitions only. Handlers live in
//! `commands::*` and are dispatched from `main`.

use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(
    name = "dashictl",
    version,
    about = "Admin CLI for the dashi spatial data lake",
    long_about = "Admin CLI for the dashi spatial data lake.\n\n\
                  Three-layer ops model:\n  \
                  · dashictl   — operator CLI (CRUD, GC, audit, backup, backfill)\n  \
                  · Grafana    — read-only dashboards (throughput, errors, sizes)\n  \
                  · Web UI     — researcher front door (ingest, browse, runs, viewer)\n\n\
                  Admin tasks NEVER grow into the web UI. If a workflow needs a\n\
                  button, build a `dashictl` subcommand instead.",
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
