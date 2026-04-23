# Assets

Static assets referenced by the MkDocs Material site.

## Required files

| File | Purpose | Status |
|------|---------|--------|
| `miso-logo.png` | Site logo (header + index hero) and favicon | ⚠️ **To be placed manually** — see below |

## How to add the logo

The MISO logo (ramen bowl with map-lines in broth, chopsticks reading "MISO / Map Infrastructure & Spatial Orchestration") lives outside this repo today. Place it here:

```
docs/assets/miso-logo.png
```

- Recommended format: PNG with transparent background, ≥1024×1024 for retina
- Referenced from `mkdocs.yml` as both `theme.logo` and `theme.favicon`
- Also referenced in `docs/index.md` hero section via `<img src="assets/miso-logo.png">`

If the image is missing at build time, MkDocs emits a warning but the site still builds.
