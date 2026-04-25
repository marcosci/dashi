# Security Policy

## Supported Versions

dashi is in active early development. Security fixes land on `main`. There are no LTS branches.

| Version | Supported |
| ------- | --------- |
| `main`  | ✅        |
| Older   | ❌        |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security findings.**

Email **marco@kaldera.dev** with:

- A description of the issue
- Steps to reproduce
- Affected component (manifest path, ingest module, ADR, …)
- Your assessment of severity and impact
- Optional: a suggested fix

You will receive an acknowledgement within 5 working days. We aim to triage within 14 days. If the report is accepted, we will work with you on a coordinated disclosure timeline (typically 30–90 days depending on severity).

## Out of scope

- Vulnerabilities in upstream dependencies — please report those to the upstream project. We will track the CVE and bump our pin once a fix is available.
- Issues that require physical access to a developer's machine.
- Self-inflicted misconfigurations of a local PoC cluster.

## Hardening notes

- Sample manifests use `CHANGE_ME_*` placeholder secrets — never deploy them as-is.
- The PoC NetworkPolicies assume a CNI that enforces them (Cilium, Calico). k3d/k3s default Flannel does **not** enforce — treat it as documentation, not isolation.
- RBAC bootstrap creates least-privilege per-zone IAM users in RustFS — rotate the seed credentials before production use.

## Disclosure

Once a fix is released we will publish a security advisory on the GitHub Security tab and credit the reporter unless they request anonymity.
