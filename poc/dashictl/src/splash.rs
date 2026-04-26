//! Splash banner. Renders the actual repo logo
//! (`docs/assets/dashi-logo.svg` → pre-rasterized to PNG, embedded at
//! compile time) when the host terminal supports an image protocol
//! (iTerm2, Kitty, sixel). Falls back to ANSI half-blocks otherwise.
//!
//! Suppressed when stderr is not a TTY so pipes / CI / `2>/dev/null`
//! stay clean.

use is_terminal::IsTerminal;
use owo_colors::OwoColorize;

/// Rasterized at build time from `docs/assets/dashi-logo.svg` via:
///   rsvg-convert -w 320 -h 320 docs/assets/dashi-logo.svg \
///     -o poc/dashictl/assets/dashi-logo.png
const LOGO_PNG: &[u8] = include_bytes!("../assets/dashi-logo.png");

const TAGLINE: &str = "spatial data lake · admin CLI";
const REPO: &str = "github.com/marcosci/dashi";

/// Print the splash to stderr if and only if stderr is a TTY.
pub fn maybe_print() {
    if !std::io::stderr().is_terminal() {
        return;
    }
    let version = env!("CARGO_PKG_VERSION");

    eprintln!();
    if !render_image() {
        // No image protocol available — viuer's half-block fallback also
        // failed to write to stderr. Use a minimal text marker so the
        // banner still shows.
        eprintln!("  {}", "● dashi".bright_yellow().bold());
    }
    eprintln!();
    eprintln!("  {}", TAGLINE.dimmed());
    eprintln!("  v{}  ·  {}", version.bright_yellow(), REPO.dimmed());
    eprintln!();
}

/// Decode the embedded PNG and let viuer render it via the best
/// protocol the terminal supports (Kitty / iTerm2 / sixel) or the
/// half-block fallback. Returns false when the image can't render at
/// all (e.g. the decode fails).
fn render_image() -> bool {
    let img = match image::load_from_memory(LOGO_PNG) {
        Ok(i) => i,
        Err(_) => return false,
    };
    // Compact size — fits next to the help text without dominating
    // the screen. width is in terminal cells, height in half-cells
    // (each glyph holds 2 vertical pixels in fallback mode).
    let cfg = viuer::Config {
        absolute_offset: false,
        x: 4,
        width: Some(20),
        height: Some(10),
        use_kitty: true,
        use_iterm: true,
        ..Default::default()
    };
    viuer::print(&img, &cfg).is_ok()
}
