# Public launch checklist

One-time tasks before the first external announcement. Not all of these can be automated — the GitHub repo settings need maintainer access.

## In the repo (already done)

- [x] LICENSE — Apache-2.0
- [x] CONTRIBUTING.md
- [x] CODE_OF_CONDUCT.md
- [x] SECURITY.md
- [x] `.github/ISSUE_TEMPLATE/{bug_report.md, feature_request.md, config.yml}`
- [x] `.github/pull_request_template.md`
- [x] `.github/workflows/ci.yml` — lint + manifests + docs + viewer
- [x] `.github/workflows/docs.yml` — Pages deploy on `main`
- [x] README badges (CI, docs, license, contributions, discussions)

## On github.com (manual — needs maintainer)

- [ ] Settings → Features → enable **Discussions**
- [ ] Settings → General → set repo description: _A cloud-native spatial data lake — STAC catalog, COG/GeoParquet/COPC/PMTiles, served by TiTiler / Martin / TiPG / DuckDB. Apache-2.0._
- [ ] Settings → General → set homepage: <https://marcosci.github.io/dashi/>
- [ ] About → topics: `gis`, `geospatial`, `data-lake`, `kubernetes`, `stac`, `cog`, `geoparquet`, `copc`, `pmtiles`, `martin`, `titiler`, `tipg`, `prefect`, `rustfs`, `lidar`, `point-cloud`, `apache-2`
- [ ] Settings → Branches → `main`: require PR review + passing CI before merge
- [ ] Settings → Pages → confirm GitHub Actions source + custom domain (if any)
- [ ] Settings → Code security → enable Dependabot version updates + secret scanning
- [ ] Releases → tag `v0.1.0` once the bundled smoke is reproducible by a fresh clone

## Announcement post (template)

`docs/LAUNCH-POST.md` carries the long-form announcement, ready to copy-paste into:

- a personal blog or kaldera.dev
- HackerNews `Show HN`
- the `r/gis` subreddit
- Mastodon (`@opengeohub` etc.)
- GIS Stack Exchange `meta` thread (if a fit)

## Post-launch (first month)

- [ ] Watch GitHub Issues — triage every bug within 5 working days
- [ ] Open Discussion `Welcome — what would you build with dashi?` to seed conversation
- [ ] Add 3+ external integrations to the README (e.g. screenshots from CesiumJS / iTowns / QGIS connecting to the running PoC)
