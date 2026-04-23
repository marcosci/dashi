"""miso-ingest CLI — format-agnostic."""

from __future__ import annotations

import json
import logging
from pathlib import Path

import typer
from rich.console import Console
from rich.table import Table

from miso_ingest import detect, storage
from miso_ingest.runner import ingest_one

app = typer.Typer(add_completion=False, help="MISO ingestion pipeline — landing → processed + catalog.")
console = Console()


@app.command("scan")
def scan(path: Path = typer.Argument(..., exists=True, readable=True, file_okay=True, dir_okay=True)) -> None:
    """Classify every file under PATH without processing. Useful for dry-run."""
    detections = detect.discover(path)
    table = Table("path", "kind", "driver", "reason")
    for d in detections:
        table.add_row(str(d.path), d.kind, d.driver or "-", d.reason)
    console.print(table)


@app.command("ingest")
def ingest(
    path: Path = typer.Argument(..., exists=True, readable=True, file_okay=True, dir_okay=True),
    domain: str = typer.Option(..., "--domain", help="STAC collection / zone domain, e.g. gelaende-umwelt"),
    processed_bucket: str = typer.Option("processed", "--bucket", help="Target S3 bucket for processed data"),
    stac_url: str = typer.Option("http://localhost:18080", "--stac-url"),
    collection_description: str = typer.Option(
        "Domain data processed via MISO ingestion pipeline", "--collection-description"
    ),
    h3_resolution: int = typer.Option(7, "--h3-resolution"),
    log_level: str = typer.Option("INFO", "--log-level"),
) -> None:
    """Discover files under PATH, route to the right transform, upload, catalog."""
    logging.basicConfig(level=log_level.upper(), format="%(asctime)s %(levelname)s %(message)s")

    s3_cfg = storage.S3Config.from_env()

    outcomes = []
    detections = detect.discover(path)
    for d in detections:
        if d.kind == "unknown":
            continue  # sidecar or unreadable — skip silently
        outcome = ingest_one(
            d.path,
            domain=domain,
            processed_bucket=processed_bucket,
            stac_url=stac_url,
            collection_description=collection_description,
            s3_cfg=s3_cfg,
            h3_resolution=h3_resolution,
        )
        outcomes.append(outcome)
        status_color = {"ingested": "green", "rejected": "red", "skipped": "yellow"}.get(
            outcome.status, "white"
        )
        console.print(
            f"[{status_color}]{outcome.status}[/] {outcome.kind:6s}  {d.path}"
            + (f"  → {outcome.output_uri}" if outcome.output_uri else "")
            + (f"  ({outcome.reason})" if outcome.reason else "")
        )

    summary = {s: 0 for s in ("ingested", "rejected", "skipped")}
    for o in outcomes:
        summary[o.status] = summary.get(o.status, 0) + 1
    console.print()
    console.print(f"[bold]Summary:[/] {summary}")
    # machine-readable result
    result_path = Path(".miso-ingest-result.json")
    result_path.write_text(
        json.dumps([o.__dict__ for o in outcomes], indent=2, default=str)
    )
    console.print(f"[dim]wrote {result_path}[/]")


if __name__ == "__main__":
    app()
