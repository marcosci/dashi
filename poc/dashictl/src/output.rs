//! Output helpers — table rendering + JSON pass-through. Every command
//! decides between human and machine output via the global `--json`
//! flag (passed in `Cli::json`). Tables use a mono-spaced ASCII style
//! that survives copy-paste into chat / tickets / git commits.

use comfy_table::presets::UTF8_BORDERS_ONLY;
use comfy_table::{Cell, Table};

pub fn table(headers: &[&str]) -> Table {
    let mut t = Table::new();
    t.load_preset(UTF8_BORDERS_ONLY);
    t.set_header(headers.iter().copied().map(Cell::new));
    t
}

pub fn print_json<T: serde::Serialize>(value: &T) -> anyhow::Result<()> {
    let s = serde_json::to_string_pretty(value)?;
    println!("{s}");
    Ok(())
}
