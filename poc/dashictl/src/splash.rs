//! Splash banner. Shown once on `dashictl` (no args) and on top-level
//! `--help` / `--version`. Suppressed when stderr is not a TTY so pipes,
//! CI, and `2>/dev/null` stay clean.
//!
//! The artwork is an ASCII translation of `docs/assets/dashi-logo.svg`:
//! the outer bowl rim (dark ink), an inner ripple ring (amber), and the
//! amber surface drop in the centre. owo-colors auto-disables under
//! `NO_COLOR=1` and on non-TTY stderr.

use is_terminal::IsTerminal;
use owo_colors::OwoColorize;

/// Each tuple = (line, tone). Lines are exactly 25 chars wide so the
/// whole banner aligns regardless of terminal background.
const LOGO: &[(&str, Tone)] = &[
    ("     _______________     ", Tone::Rim),
    ("   ,'                 `.  ", Tone::Rim),
    ("  /     _________     \\  ", Tone::Amber),
    (" |    ,'         `.    | ", Tone::Amber),
    (" |    |    ●●●    |    | ", Tone::AmberBold),
    (" |    `.         .'    | ", Tone::Amber),
    ("  \\     `-------'     /  ", Tone::Amber),
    ("   `.                 .'  ", Tone::Rim),
    ("    `---------------'    ", Tone::Rim),
];

#[derive(Clone, Copy)]
enum Tone {
    /// Outer rim — dim default-fg (matches SVG ink #1a1612).
    Rim,
    /// Inner ripple + amber surface ring (matches SVG #c8821f).
    Amber,
    /// Amber drop in the centre — bold for emphasis.
    AmberBold,
}

const TAGLINE: &str = "spatial data lake · admin CLI";
const REPO: &str = "github.com/marcosci/dashi";

/// Print the splash to stderr if and only if stderr is a TTY.
pub fn maybe_print() {
    if !std::io::stderr().is_terminal() {
        return;
    }

    let version = env!("CARGO_PKG_VERSION");

    eprintln!();
    for (line, tone) in LOGO {
        match tone {
            Tone::Rim => eprintln!("{}", line.dimmed()),
            Tone::Amber => eprintln!("{}", line.bright_yellow()),
            Tone::AmberBold => eprintln!("{}", line.bright_yellow().bold()),
        }
    }
    eprintln!();
    eprintln!("        {}", "d a s h i".bright_yellow().bold());
    eprintln!("  {}", TAGLINE.dimmed());
    eprintln!("  v{}  ·  {}", version.bright_yellow(), REPO.dimmed());
    eprintln!();
}
