//! `dashictl user grant` — STUB. Real implementation depends on
//! Authelia + Keycloak being live (currently scaffolded but not yet
//! deployed; see ADR-008). Once OIDC is live this will:
//!   1. POST a Keycloak group-membership update
//!   2. PATCH STAC collection summaries with the new ACL hash
//!   3. Emit a structured audit event to Loki

use anyhow::Result;

use crate::cli::UserCmd;

pub async fn run(cmd: &UserCmd) -> Result<()> {
    match cmd {
        UserCmd::Grant { user, domain, role } => {
            anyhow::bail!(
                "`user grant` not yet implemented — blocked on Authelia / Keycloak \
                 live deployment (ADR-008). Planned: grant '{role}' on '{domain}' \
                 to '{user}' via Keycloak group sync + STAC ACL summary refresh. \
                 Track: https://github.com/marcosci/dashi/issues (label: cli, oidc)."
            );
        }
    }
}
