//! dashictl — admin CLI entry point. The whole binary is async so the
//! HTTP-driven subcommands (STAC, Prefect, Loki) share one tokio
//! runtime; the few subcommands that don't need it just don't await.

mod cli;
mod commands;
mod config;
mod output;
mod splash;

use anyhow::Result;
use clap::Parser;
use is_terminal::IsTerminal;

use crate::cli::{Cli, Command};

#[tokio::main]
async fn main() {
    // Splash policy: only print on top-level help / no-subcommand /
    // version-only invocations, and only when stderr is a TTY. Pipes,
    // CI, and `2>/dev/null` all suppress automatically.
    maybe_splash();

    let cli = Cli::parse();

    if let Err(err) = run(cli).await {
        eprintln!("error: {err:#}");
        std::process::exit(1);
    }
}

fn maybe_splash() {
    if !std::io::stderr().is_terminal() {
        return;
    }
    let args: Vec<String> = std::env::args().collect();
    let no_subcommand = args.len() == 1;
    let asking_help = args
        .iter()
        .skip(1)
        .any(|a| a == "--help" || a == "-h" || a == "help");
    let asking_version = args.iter().skip(1).any(|a| a == "--version" || a == "-V");
    if no_subcommand || asking_help || asking_version {
        splash::maybe_print();
    }
}

async fn run(cli: Cli) -> Result<()> {
    let cfg = config::load(cli.context.as_deref())?;

    match &cli.command {
        Command::Domain { cmd } => commands::domain::run(&cfg, cli.json, cmd).await,
        Command::User { cmd } => commands::user::run(cmd).await,
        Command::Item { cmd } => commands::item::run(&cfg, cli.json, cmd).await,
        Command::Backfill(args) => commands::backfill::run(args).await,
        Command::Gc(args) => commands::gc::run(&cfg, cli.json, args).await,
        Command::Audit { cmd } => commands::audit::run(&cfg, cli.json, cmd).await,
        Command::Backup { cmd } => commands::backup::run(&cfg, cli.json, cmd).await,
        Command::Runs(args) => commands::runs::run(&cfg, cli.json, args).await,
        Command::Config => print_config(&cfg, cli.json),
    }
}

fn print_config(cfg: &config::Config, json_out: bool) -> Result<()> {
    if json_out {
        let v = serde_json::json!({
            "context": cfg.context,
            "stac_url": cfg.stac_url,
            "prefect_url": cfg.prefect_url,
            "loki_url": cfg.loki_url,
            "s3": {
                "endpoint": cfg.s3.endpoint,
                "region": cfg.s3.region,
                "landing_bucket": cfg.s3.landing_bucket,
                "processed_bucket": cfg.s3.processed_bucket,
                "curated_bucket": cfg.s3.curated_bucket,
                "access_key_set": !cfg.s3.access_key.is_empty(),
                "secret_key_set": !cfg.s3.secret_key.is_empty(),
            },
        });
        println!("{}", serde_json::to_string_pretty(&v)?);
        return Ok(());
    }

    println!("context        {}", cfg.context);
    println!("stac_url       {}", cfg.stac_url);
    println!("prefect_url    {}", cfg.prefect_url);
    println!(
        "loki_url       {}",
        cfg.loki_url.as_deref().unwrap_or("(unset)")
    );
    println!("s3.endpoint    {}", cfg.s3.endpoint);
    println!("s3.region      {}", cfg.s3.region);
    println!("s3.access_key  {}", mask(&cfg.s3.access_key));
    println!("s3.secret_key  {}", mask(&cfg.s3.secret_key));
    println!("s3.landing     {}", cfg.s3.landing_bucket);
    println!("s3.processed   {}", cfg.s3.processed_bucket);
    println!("s3.curated     {}", cfg.s3.curated_bucket);
    Ok(())
}

fn mask(s: &str) -> String {
    if s.is_empty() {
        return "(unset)".into();
    }
    let visible = s.chars().take(4).collect::<String>();
    format!("{visible}…")
}
