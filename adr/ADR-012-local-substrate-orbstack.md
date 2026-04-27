# ADR-012 — Local Kubernetes substrate: OrbStack vanilla k8s over k3d-in-docker

**Status:** Accepted (2026-04-27)
**Supersedes:** the implicit "k3d on colima" baseline used through v0.1.0.

## Context

Through v0.1.0 the local development substrate was **k3d** (k3s in
Docker) on top of **colima** (Linux VM via lima/QEMU/VZ). That stack
gave us:

- A real Kubernetes API on macOS without Docker Desktop's licence.
- The same cluster surface (server + 2 agents + serverlb) as a
  small production deploy.
- `k3d image import` for fast local image cycles.

It also gave us a daily failure mode. On macOS Tahoe / Sequoia the
lima hostagent's SSH-based port forward — used for the host docker
socket and for every published TCP port (k8s API server, ingress,
etc.) — disconnects within seconds of any sustained workload. Symptoms
observed during the v0.1.1 cycle:

- `docker ps` returns "Cannot connect to the Docker daemon" minutes
  after `colima start` reports success.
- `kubectl` connection refused on the published API server port,
  even though the in-VM `dockerd` is healthy.
- `colima restart` succeeds, then drops again. The VZ disk file
  acquires a stale kernel-level lock that does not release until the
  Mac is rebooted.
- Errors in `~/.colima/_lima/colima/ha.stderr.log`:
  `failed to run [ssh ...]: exit status 255`

Workarounds attempted and discarded:

- Manual `ssh -fN -L` against lima's published SSH port, with watchdog
  respawn. Holds for ~30s then dies for the same reason as the
  built-in forward.
- Patching `port-forward-all.sh` to retry the precheck five times.
  Mitigates the symptom but does not address the underlying flap.
- Killing every `limactl` / `colima` process and clearing
  `~/.colima/_lima/colima/{ssh,ha}.sock`. macOS holds the disk via
  the kernel VZ subsystem; reboot required.

The friction made the substrate fundamentally unreliable for daily
work and impossible to recommend to a second adopter.

## Decision

Adopt **OrbStack's built-in vanilla Kubernetes** as the default local
development substrate on macOS. Drop the k3d-in-docker layer.

```toml
# OrbStack settings (already on disk; no extra config)
k8s.enable = true
```

Result:

- Single layer of virtualisation (OrbStack VM → kubelet directly), no
  nested k3d-in-docker.
- Docker socket via `~/.orbstack/run/docker.sock`, not SSH-forwarded.
- Kubernetes API at `https://localhost:<random>` reachable through
  the same shared docker daemon — no port-forward flapping.
- Locally-built `dashi/<svc>:dev` images are visible to OrbStack k8s
  without an explicit image-import step (shared containerd). The
  k3d-specific `k3d image import` calls in `serving-deploy.sh` and
  `web-ingest-deploy.sh` are now gated behind a `kubectl config
  current-context | grep ^k3d-` test and skipped on OrbStack.

The `k3d` path is preserved for anyone running on Linux without
OrbStack, and for the kind-based CI E2E job — both are real
non-OrbStack contexts.

## Consequences

Positive:

- Cluster stays Running across active workloads. The
  `port-forward-all.sh` "skip — svc/X not in dashi-Y" failure mode
  observed in v0.1.0 is gone.
- `make redeploy-all` reaches a green `dashictl doctor` end-to-end
  on a fresh machine without manual intervention.
- The substrate matches what an external adopter likely already has
  installed (OrbStack is the de facto Docker Desktop alternative on
  macOS in 2026).

Neutral:

- OrbStack is closed-source with a paid commercial tier (free for
  personal / open-source). Linux developers and CI use kind, so the
  project is not exclusively dependent on OrbStack.
- Image import semantics differ: OrbStack k8s shares the host docker
  daemon, k3d does not. Two scripts (`serving-deploy.sh`,
  `web-ingest-deploy.sh`) now branch on the active kubectl context.

Negative:

- One extra branch in two deploy scripts. Tested in CI via the
  `e2e-cluster` job (uses kind — the non-k3d path).
- Documentation now distinguishes between three local substrates
  (OrbStack k8s, kind, k3d). Acceptable cost for the stability gain.

## Alternatives considered

- **Docker Desktop + k3d.** Same SSH-forwarding issues are reported
  by Docker Desktop users on Apple silicon as of 2026. Not a real
  improvement.
- **Rancher Desktop with native k3s.** Stable, but adds yet another
  hypervisor on the developer's machine. OrbStack is already widely
  installed.
- **Stay on colima + reboot daily.** Untenable for a project that
  wants a second adopter. The reboot ritual is exactly the friction
  v0.1.1 set out to eliminate.
- **Lima native (no colima).** Would still use the same SSH-forward
  primitive, same flap.
- **Cloud dev environments (GitHub Codespaces, devcontainers in
  Codespaces with k3d).** Out of scope for a local-first PoC; revisit
  when the project graduates beyond solo development.

## References

- `poc/scripts/serving-deploy.sh` — context-conditional k3d import.
- `poc/scripts/web-ingest-deploy.sh` — same pattern.
- `poc/dashictl/src/commands/doctor.rs` — preflight check matrix that
  catches OrbStack-vs-k3d configuration mismatches.
- `.github/workflows/ci.yml` — `e2e-cluster` job uses kind, exercises
  the non-OrbStack path.
