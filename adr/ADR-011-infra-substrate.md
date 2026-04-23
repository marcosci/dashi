# ADR-011 — Infrastruktur-Substrat: lokales k3s + GitHub (marcosci/dashi)

**Status:** ✅ Entschieden (PoC / Phase 1)

**Beschlossen:** 2026-04-23

## Kontext

Ursprüngliche Annahme aus §10.1 F-02 war eine Infrastrukturentscheidung zwischen Cloud, on-premise oder hybrid mit militärischer Beschaffungskette. Für den PoC wird dieser Weg verworfen — die Initiative läuft zunächst als interne Entwicklung im opendefense-Umfeld. Eine schnell verfügbare, reproduzierbare und produktionsnahe Substrat-Entscheidung wird benötigt.

Die Wahl muss:
- Kubernetes-Semantik abbilden (spätere Migration in militärische K8s-Infrastruktur ohne Architekturbruch)
- Lokal auf einer Entwickler-Maschine lauffähig sein
- Zum Produktivbetrieb kompatibel sein (keine Docker-Compose-only Pattern, die im Cluster brechen)
- GitHub Actions + Pages-tauglich sein (GitHub Repo (marcosci/dashi) ist die Zielplattform)

## Bewertete Alternativen

| Alternative | Vorteile | Nachteile |
|-------------|----------|-----------|
| **k3s (lokal)** | Voller K8s-API, leichtgewichtig, produktionsnah, in einem Binary | Höherer Einstiegsaufwand als compose |
| Docker Compose | Minimaler Setup-Aufwand | Compose-Pattern brechen bei Migration zu K8s |
| kind / minikube | K8s lokal | kind flüchtig (Container-in-Container), minikube schwergewichtig |
| Cloud-Managed K8s (GKE/EKS) | Produktionsnähe | Kostenpflichtig, Compliance-Bedenken für späteres Ziel |
| Bare-Metal-Kubeadm | Realität produktiver Deployments | Erheblicher Aufbau-Overhead für PoC |

## Entscheidung

**k3s als lokales Substrat für PoC und MVP.** Entwicklung im GitHub Repo (marcosci/dashi) mit CI/CD. Manifests (Helm oder reines YAML) gelten verbindlich für lokale und spätere produktive Umgebungen.

## Konsequenzen

- Alle Plattformkomponenten (RustFS, stac-fastapi, TiTiler, DuckDB-Query-Endpoint, Pipeline-Orchestrator) werden als K8s-Manifests gepackt
- Persistent Volumes für RustFS werden lokal gemappt — produktives Tiering (ADR-001 Konsequenz) bleibt offen
- GitHub Actions + Pages pipelines verifizieren Manifest-Rendering und Integrationstests vor Merge
- Keine Docker-Compose-Only-Tooling im Repo — entweder K8s-Manifest oder GitHub-Actions-Job
- Migrationspfad nach Phase 3 in eine produktive militärische K8s-Umgebung bleibt offen, aber die Manifests sind portierbar

## Offen / Nachgelagerte Entscheidungen

- Helm vs. reines kustomize — Entscheidung bis zum ersten Deployment
- Ingress-Controller (Traefik als k3s-Default behalten oder austauschen)
- Storage-Class für RustFS PVs in der Zielumgebung
- Secrets-Management (sealed-secrets / vault / GitHub Actions secrets) — Phase 2 Entscheidung
