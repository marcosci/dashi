# Contributing to dashi

Thanks for considering a contribution. dashi is a small open-source project — we keep the process light.

## TL;DR

1. Open an issue first if the change is non-trivial (anything beyond a typo, a one-file fix, or a docs update). Lets us flag duplicate work or scope concerns before you write code.
2. Fork, branch from `main`, do your thing.
3. `mkdocs build --strict` and (if you touched the PoC) `cd poc && make smoke` should be green before pushing.
4. Open a PR. Fill the template. Link the issue.

## What we welcome

- **Bug fixes** — every kind. Smallest reasonable patch wins.
- **Docs improvements** — typos, clarity, missing context, broken links, German translations of English-only sections.
- **PoC manifests** — reasonable production-hardening: probes, resource limits, NetworkPolicies, RBAC scoping.
- **Ingest format coverage** — new file kinds (NetCDF, Zarr, FlatGeobuf, …) via `dashi_ingest.detect` + a transform module. See `docs/FEATURE-IDEAS.md` for tracked candidates.
- **ADRs** — new architectural decisions or amendments to existing ones. Use `templates/adr.md`.
- **Feature ideas** — open a PR adding an entry to `docs/FEATURE-IDEAS.md`. No discussion required for `idea` state.

## What we are cautious about

- Large refactors without a prior issue or ADR — please open one first.
- New top-level dependencies without a clear case (every dependency is operational surface).
- Renaming public namespaces, env vars, or STAC property prefixes — these are interface contracts now that the rebrand has shipped.

## Local setup

### Docs

```bash
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r requirements-docs.txt
.venv-docs/bin/mkdocs serve   # http://localhost:8000
```

### PoC

Prereqs: Docker / OrbStack, k3d (macOS / Windows) or k3s (Linux), `kubectl`, `mc` (MinIO client), `helm` (optional).

```bash
cd poc
make k3s-up
make storage-deploy catalog-deploy serving-deploy
make prefect-up monitoring-up
make rbac-bootstrap network-policies-up
make ogc-deploy   # PMTiles + Martin
make smoke
```

Tear down with `make k3s-down`.

## Coding conventions

- **Python** ingest pipeline: `ruff` for lint + format. Type hints encouraged; we are not strict yet.
- **YAML manifests**: 2-space indent, kustomize-friendly. Keep one resource per file when readability allows.
- **Shell scripts**: `bash`, `set -euo pipefail`, `shellcheck`-clean.
- **Markdown**: 80-100 col soft wrap, ATX headings, fenced code blocks with language tags.
- **Commit messages**: imperative subject (under 70 chars), wrap body at ~72.

## Pull request checklist

- [ ] Branch is up to date with `main`.
- [ ] `mkdocs build --strict` is green.
- [ ] If PoC code or manifests touched: `cd poc && make smoke` is green against a local cluster.
- [ ] New behaviour is covered by an existing or new smoke test.
- [ ] `CHANGELOG`-worthy changes mentioned in the PR description.
- [ ] No secrets, no TODOs, no `console.log`-style debug noise.

## Issue reporting

Use the issue templates. For bugs include:

- What you ran (exact command).
- What you expected.
- What actually happened (paste the relevant log).
- Cluster + tool versions: `kubectl version --short`, `make` target used, dashi commit hash.

## Security

Do **not** open a public issue for security findings — see [SECURITY.md](SECURITY.md).

## Code of conduct

By participating you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Be kind. Disagree on the technical substance, not the person.

## License

By contributing you agree your contributions are licensed under the [Apache License 2.0](LICENSE) — same as the rest of the project.

## Maintainers

- Marco Sciaini · [@marcosci](https://github.com/marcosci)
- Johannes Schlund

Reviews are best-effort and may take a few days. Thanks for your patience.
