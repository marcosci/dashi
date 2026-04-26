//! Splash banner. Procedurally renders the dashi logo (concentric
//! bowl rim, amber surface ring, two darker ripples, amber drop)
//! using ANSI half-block characters — `▀` = top pixel, `▄` = bottom
//! pixel, ` ` = empty. Each terminal cell carries 2 vertical pixels,
//! so one row of glyphs = two rows of the pixel grid.
//!
//! No raster image, no graphics protocol — looks identical in iTerm2,
//! Terminal.app, ssh, tmux. Transparent "pixels" use the terminal's
//! own background; nothing is composited against a checker-pattern.
//!
//! Suppressed when stderr is not a TTY (pipes, CI, `2>/dev/null`).

use is_terminal::IsTerminal;

/// Pixel grid dimensions. 30×30 keeps the splash compact (~15 lines)
/// while still showing all five concentric features clearly. Cols = 30
/// gives the bowl visible width; the half-block render below packs
/// two pixel rows into one terminal line, so the rendered banner is
/// ~15 lines tall.
const W: i32 = 30;
const H: i32 = 30;

/// Outer rim (dark ink, matches `#1a1612` in the SVG).
const INK: (u8, u8, u8) = (26, 22, 18);
/// Surface ring + drop (matches `#c8821f`).
const AMBER: (u8, u8, u8) = (200, 130, 31);

const TAGLINE: &str = "spatial data lake · admin CLI";
const REPO: &str = "github.com/marcosci/dashi";

/// One pixel after compositing — `None` = transparent (terminal bg).
#[derive(Copy, Clone, PartialEq, Eq)]
struct Pixel(Option<(u8, u8, u8)>);

impl Pixel {
    const NONE: Pixel = Pixel(None);
    fn ink(opacity: f32) -> Self {
        Pixel(Some(blend(INK, opacity)))
    }
    fn amber(opacity: f32) -> Self {
        Pixel(Some(blend(AMBER, opacity)))
    }
}

/// Approximate a transparent stroke against an unknown terminal
/// background by mixing toward mid-gray. Good enough for the dim
/// ripples (`stroke-opacity` 0.35–0.5 in the SVG).
fn blend(c: (u8, u8, u8), alpha: f32) -> (u8, u8, u8) {
    let mix = 110.0_f32; // perceptual mid-gray fallback
    let lerp = |x: u8| -> u8 { (alpha * x as f32 + (1.0 - alpha) * mix).round() as u8 };
    (lerp(c.0), lerp(c.1), lerp(c.2))
}

fn pixel_at(x: i32, y: i32) -> Pixel {
    // Center of the canvas. Float math; the discretisation back to
    // half-block glyphs handles the rest.
    let cx = (W - 1) as f32 / 2.0;
    let cy = (H - 1) as f32 / 2.0;
    let dx = x as f32 - cx;
    let dy = y as f32 - cy;
    let d = (dx * dx + dy * dy).sqrt();

    // Radii in the SVG are 72/54/38/24/10 over a 100-unit half-canvas.
    // Scale to our 14-unit max radius (W=30 → radius ~14 to the edge).
    let scale = 14.0 / 72.0;
    let r_rim = 72.0 * scale; // = 14.0
    let r_surf = 54.0 * scale; // ~10.5
    let r_rip1 = 38.0 * scale; // ~7.4
    let r_rip2 = 24.0 * scale; // ~4.7
    let r_drop = 10.0 * scale; // ~1.94

    // Filled amber drop in the middle.
    if d <= r_drop {
        return Pixel::amber(1.0);
    }
    // Concentric strokes — narrow tolerances mimic the SVG stroke
    // widths (3 / 2 / 1.4 / 1.1 px). At our scale, ±0.55 px catches a
    // 1-px-thick ring and ±0.7 catches the 3-px outer rim.
    if (d - r_rip2).abs() <= 0.55 {
        return Pixel::ink(0.35);
    }
    if (d - r_rip1).abs() <= 0.55 {
        return Pixel::ink(0.5);
    }
    if (d - r_surf).abs() <= 0.55 {
        return Pixel::amber(1.0);
    }
    if (d - r_rim).abs() <= 0.7 {
        return Pixel::ink(1.0);
    }
    Pixel::NONE
}

/// Print one row of glyphs for two pixel rows (`y_top`, `y_top+1`).
fn render_row(y_top: i32) -> String {
    let mut out = String::with_capacity(W as usize * 24);
    let mut current_fg: Option<(u8, u8, u8)> = None;
    let mut current_bg: Option<(u8, u8, u8)> = None;

    for x in 0..W {
        let top = pixel_at(x, y_top);
        let bot = pixel_at(x, y_top + 1);
        let (glyph, fg, bg) = match (top.0, bot.0) {
            (None, None) => (' ', None, None),
            (Some(t), None) => ('▀', Some(t), None),
            (None, Some(b)) => ('▄', Some(b), None),
            (Some(t), Some(b)) => ('▀', Some(t), Some(b)),
        };

        // Only emit colour escapes when they change — keeps lines short.
        if fg != current_fg {
            match fg {
                Some((r, g, b)) => out.push_str(&format!("\x1b[38;2;{r};{g};{b}m")),
                None => out.push_str("\x1b[39m"),
            }
            current_fg = fg;
        }
        if bg != current_bg {
            match bg {
                Some((r, g, b)) => out.push_str(&format!("\x1b[48;2;{r};{g};{b}m")),
                None => out.push_str("\x1b[49m"),
            }
            current_bg = bg;
        }
        out.push(glyph);
    }
    out.push_str("\x1b[0m");
    out
}

/// Print the splash to stderr if and only if stderr is a TTY.
pub fn maybe_print() {
    if !std::io::stderr().is_terminal() {
        return;
    }
    let no_color = std::env::var_os("NO_COLOR").is_some();
    let version = env!("CARGO_PKG_VERSION");

    eprintln!();
    if no_color {
        // Minimal text fallback — no escape sequences at all.
        eprintln!("  ● dashi");
    } else {
        let mut y = 0;
        while y < H {
            eprintln!("  {}", render_row(y));
            y += 2;
        }
    }
    eprintln!();
    eprintln!("  \x1b[2m{TAGLINE}\x1b[0m");
    eprintln!("  v\x1b[38;2;200;130;31m{version}\x1b[0m  ·  \x1b[2m{REPO}\x1b[0m");
    eprintln!();
}
