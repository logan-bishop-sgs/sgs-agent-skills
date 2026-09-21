# Examples

## Example 1 — Daemon Graph app (shipped case, abbreviated)

**Situation:** Absence Teams lights need app-only Graph on a new registration;
Web App `US-EHS-TV-REPORTS` has managed identity only.

**Catalog:** `entra-app-registration` (current `7dec6166477f8594a1a7efb2e36d43de`)

**ApplicationName:** `SGS-US-EHS-DASHBOARD-GRAPH-PROD`

**Scope (field):** `Microsoft Graph application permissions: Presence.Read.All, User.Read.All (admin consent). Single-tenant SGS. No delegated permissions. No user sign-in.`

**Outcome:** RITM1077272 → admin consent 2026-09-19. Do not open another
ticket for that grant. Full field table lives in
`ehs_dashboard/CONTEXT/sgs-it.md` § Catalog-item fields.

## Example 2 — IAM bounced "grant Graph on Web App"

**Wrong:** New catalog item repeating the same permissions.

**Right:** Reply on IAM's ticket:

```text
IAM noted US-EHS-TV-REPORTS has no App Registration attached. We filed
RITM1077272 via catalog 7dec6166477f8594a1a7efb2e36d43de. Please assign
that RITM, link it to this ticket, and grant Presence.Read.All and
User.Read.All (application) with admin consent on the new registration.
We will supply GRAPH_CLIENT_ID in Key Vault — not replacing the Web App
managed identity.
```

## Example 3 — User asks for mail + calendar + Teams with consent popup

Classify as **template B** (user SSO + delegated Graph). Add delegated
scopes to Scope and Description. Remind them SGS usually requires **admin
consent** even after the user sees a consent screen. Separate daemon apps
(Absence presence) from interactive SSO apps unless IAM insists on one app.

## Example 4 — Agent handoff (dedicated Edge, fill only)

```powershell
powershell -File .cursor/skills/sgs-it-tickets/scripts/Open-ServiceNow-Edge.ps1
# user MFA in that Edge window
powershell -File .cursor/skills/sgs-it-tickets/scripts/run-servicenow-fill.ps1 -Draft ehs_dashboard/CONTEXT/drafts/servicenow-entra-sso-graph-2026-09-21.txt
```

User Submits in Edge → pastes RITM → update `sgs-it.md`. Same pattern as
`Open-Workday-Edge.ps1` + `run-expense-draft.ps1`.

## Example 5 — User SSO + delegated Graph (2026-09-21, NAM EHS)

**Catalog:** `entra-app-registration` — **one** ticket.

**ApplicationName:** `SGS-US-EHS-DASHBOARD-SSO-PROD` (separate from daemon
`SGS-US-EHS-DASHBOARD-GRAPH-PROD`).

**Delegated:** `User.Read`, `Mail.Read`, `Calendars.Read`, `Chat.Read` +
OIDC `openid`, `profile`, `offline_access`. No `Mail.Send`. Full copy:
`ehs_dashboard/CONTEXT/drafts/servicenow-entra-sso-graph-2026-09-21.txt` and
case section in `ehs_dashboard/CONTEXT/sgs-it.md`.
