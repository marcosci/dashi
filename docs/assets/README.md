# Assets

Static assets referenced by the MkDocs Material site.

## Brand files

| File | Purpose |
|------|---------|
| `dashi-logo.svg` | Primary site logo + index hero. Concentric rings with amber accent on cream. Source spec: `dashi-v3-system.jsx` (72/54/38/24/10 ring radii, 3/2/1.4/1.1 stroke weights). |
| `dashi-logo-mono.svg` | Monochrome fallback — no accent, no broth haze. For on-dark use or single-colour print. |
| `dashi-favicon.svg` | Favicon with rounded corners, higher-contrast amber, scaled for 64×64 and smaller. |
| `legacy-miso-logo.png` | First-draft ramen-bowl logo from the pre-rebrand MISO era. Filename retained verbatim for historical traceability; not used on the live site. |

## Brand tokens (mirror of `docs/stylesheets/dashi.css`)

| Token | Hex | Role |
|-------|-----|------|
| ink | `#1a1612` | Text + outer rim stroke |
| paper | `#faf6ee` | Off-white surface |
| cream | `#f4ede1` | Page background |
| cream-deep | `#ebe1cb` | Card background + code blocks |
| amber | `#c8821f` | Primary accent (drop + amber ring) |
| amber-light | `#e8a547` | On-dark accent |
| amber-deep | `#8a5410` | Link underline, deep emphasis |
| kombu | `#3d5a3a` | Muted green accent |
| seal | `#b8421f` | Warning / construction-guide red |

## Typography

- **Body / wordmark:** Inter (weight 400 body, 600 @ `-0.04em` for wordmark)
- **Accent italics:** Fraunces Italic (headline emphasis via `<em>` inside `h1`/`h2`)
- **Code:** JetBrains Mono

Fraunces is loaded from Google Fonts via `@import` in `docs/stylesheets/dashi.css`; Inter + JetBrains Mono ship with Material as `theme.font`.
