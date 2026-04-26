//! `dashictl backfill` — STUB. Real implementation iterates a date
//! range (one day per Prefect run, params: `as_of=YYYY-MM-DD`) and
//! creates flow runs against an existing deployment. Held back until
//! the upstream flows accept a canonical `as_of` parameter — see
//! `dashi_ingest.flows.iceberg` for the first one to gain it.

use anyhow::Result;

use crate::cli::BackfillArgs;

pub async fn run(args: &BackfillArgs) -> Result<()> {
    eprintln!(
        "would backfill deployment '{}' from {} to {} ({})",
        args.deployment,
        args.from,
        args.to,
        if args.dry_run { "dry-run" } else { "apply" }
    );
    anyhow::bail!(
        "`backfill` not yet implemented — blocked on standardising an `as_of` \
         parameter across Prefect deployments. Track: \
         https://github.com/marcosci/dashi/issues (label: cli, prefect, backfill)."
    );
}
