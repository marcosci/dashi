# dashictl

Admin CLI for the dashi spatial data lake. Single static binary, written
in Rust.

```
     _           _     _
  __| | __ _ ___| |__ (_)
 / _` |/ _` / __| '_ \| |
| (_| | (_| \__ \ | | | |
 \__,_|\__,_|___/_| |_|_|

  spatial data lake · admin CLI
```

## Why a CLI

dashi splits ops into three layers and keeps each scoped:

| Layer       | Scope                                                              |
|-------------|--------------------------------------------------------------------|
| `dashictl`  | Operator CRUD, garbage collection, audit, backup, backfill         |
| Grafana     | Read-only dashboards (throughput, errors, queue depth, sizes)      |
| Web UI      | Researcher front door (ingest, register, catalog, runs, viewer)    |

Admin tasks NEVER grow into the web UI. If a workflow needs a button,
add a `dashictl` subcommand instead. CLI choice gives free audit trail,
composability with shell pipes, no UI auth surface to harden, and the
same tool runs in CI/CD for data migrations.

## Install

```sh
# from a clone of this repo
cd poc/dashictl
cargo install --path .
# binary lands in ~/.cargo/bin/dashictl
```

`rustup` (1.78+) is the only build dependency. Static binary; no shared
libraries beyond libc.

## Configuration

Lookup precedence (lowest → highest):

1. compiled defaults (assume `port-forward-all.sh` is running)
2. `~/.config/dashi/config.toml` (override path with `DASHI_CONFIG_HOME`)
3. environment variables (`DASHI_*`)
4. CLI flags

Example config:

```toml
# ~/.config/dashi/config.toml
stac_url = "http://localhost:8080"
prefect_url = "http://localhost:4200"
loki_url = "http://localhost:3100"

[s3]
endpoint        = "http://localhost:9000"
region          = "us-east-1"
access_key      = "<rustfs-access-key>"
secret_key      = "<rustfs-secret-key>"
landing_bucket  = "landing"
processed_bucket = "processed"
curated_bucket  = "curated"

[contexts.prod]
stac_url    = "https://stac.dashi.example.com"
prefect_url = "https://prefect.dashi.example.com"
loki_url    = "https://loki.dashi.example.com"
```

Switch contexts with `dashictl --context prod ...` or
`DASHI_CONTEXT=prod`.

## Subcommands

| Command                   | Status      | Notes                                        |
|---------------------------|-------------|----------------------------------------------|
| `domain list`             | ✓ live      | tabular STAC collections + ceiling           |
| `domain show <id>`        | ✓ live      | full STAC collection JSON                    |
| `domain create <id> ...`  | ✓ live      | upsert via POST /collections                 |
| `runs --limit N`          | ✓ live      | Prefect flow runs (admin view)               |
| `audit tail [--follow]`   | ✓ live      | Loki LogQL wrapper                           |
| `config`                  | ✓ live      | print resolved config (incl. context merge)  |
| `item delete <c>/<id>`    | ▴ dry-run   | preview; cascade `--apply` held back         |
| `gc --bucket <b>`         | ▴ list-only | scan path live; `--apply` held back          |
| `backup verify`           | ▴ partial   | freshness check; restore-test deferred       |
| `user grant <u> <d> <r>`  | ⊘ stub      | blocked on Authelia / Keycloak live (ADR-008)|
| `backfill <dep> ...`      | ⊘ stub      | blocked on standard `as_of` flow parameter   |

`✓ live` — fully implemented.
`▴` — partial; the destructive half is gated behind explicit hardening
work and currently exits non-zero with a pointer to manual workflow.
`⊘ stub` — exits non-zero with a tracking link.

## Conventions

* `--json` on any command emits machine-readable output for `jq` /
  scripts. Default is human-friendly tables.
* All commands use stderr for the splash and progress chatter; data
  goes to stdout. Pipes stay clean.
* Splash banner only prints when stderr is a TTY *and* the user runs
  `dashictl`, `dashictl --help`, or `dashictl --version`. Subcommand
  output never includes the splash.
* `NO_COLOR=1` disables every ANSI escape (per the no-color.org
  convention).

## Adding a subcommand

1. Add a variant to `Command` in `src/cli.rs`.
2. Add a module under `src/commands/` and register it in
   `src/commands/mod.rs`.
3. Dispatch from `run()` in `src/main.rs`.
4. Update the table above + `CHANGELOG.md`.

If your new command would be tempting to wire into the web UI instead,
re-read the rule at the top of this README first.
