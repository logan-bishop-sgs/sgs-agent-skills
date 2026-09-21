---
name: sgs-it-tickets
description: >-
  Drafts SGS ServiceNow / IAM tickets; opens dedicated Edge on CDP port 9223
  (same pattern as Workday expenses on 9222); fills catalog forms via Playwright
  but never submits. User signs in and clicks Submit in that Edge window.
  Use for ServiceNow, IAM, Entra App Registration, RITM.
---

# SGS IT tickets (ServiceNow)

**Talk to the user** with `.cursor/library-notes/voice.md`. Same browser
model as **reimbursements**: dedicated **Edge** on a debug port, not
Cursor’s chat Browser (see [login.md](login.md), [browser.md](browser.md)).
**They sign in and Submit in that Edge window.** You run the fill script —
**never Submit.**

Canonical playbook when working on **ehs_dashboard**:
`ehs_dashboard/CONTEXT/sgs-it.md` (read it first; code beats stale copy).
This skill carries the catalog links and templates so other repos still work.

## What you do vs what they do

| You | Them |
|-----|------|
| Pick catalog item + request type | Sign in to ServiceNow (SGS account, MFA) |
| Run Edge open + fill scripts | Sign in in **ServiceNow Edge**; review fields; fix typos |
| Put full draft on clipboard when fill fails | **You** click **Submit** / **Order Now** only |
| Warn about duplicate-ticket traps | Save **RITM** / **REQ** number and paste it back to you |

Never put client secrets, passwords, or PATs in the ticket body.

## Workflow

### 1. Classify the request

| Type | When | Catalog / action |
|------|------|------------------|
| **A. New Entra app** | No registration yet; IAM said create one first | [Entra App Registration (current)](catalog-items.md#entra-app-registration-current) |
| **B. Graph on existing app** | Registration exists; need admin consent / more scopes | **Reply on the open IAM ticket** — do not open a new catalog item unless IAM names one |
| **C. Wrong intake bounced** | IAM closed ticket: "no App Registration" | Usually **A**, then **B** on the original Graph ticket with the new client ID |
| **D. General IT** | Not Entra/Graph (VPN, software, access) | ServiceNow portal search — you draft text; they pick the item IAM names |
| **E. Firewall / endpoint / GPO** | Src/dst IP, ports, IAM security | Often [Other IAM `7dec6166…`](catalog-items.md#other-iam-request-gpo--firewall) — **verify title**; search for Azure/hybrid-specific catalog first |
| **F. Teodore “future apps” link** | Email pointed at `7dec6166…` | Opens **Other IAM**, not Entra — use [`01714e3e…`](catalog-items.md#create-azure-ad-application-registration-entra) for registrations until IAM fixes mapping |

Full catalog playbook: [catalog-items.md](catalog-items.md) (discovery, field ids, dumps).

If they already have a **RITM** for the same grant, **stop**. Draft a
**reply** instead of a fourth intake (see [Anti-patterns](#anti-patterns)).

### 2. Gather facts (ask only what you cannot infer)

From the user, repo `CONTEXT/`, or Azure docs:

- **Azure resource** name(s), resource group, subscription if known
- **Daemon vs user SSO** (client credentials vs redirect URI + delegated scopes)
- **Graph permissions** — list each as **application** or **delegated**
- **What must NOT change** (e.g. keep Web App system-assigned managed identity; no Easy Auth)
- **Environment** (Production / Non-production)
- **Owner** — filer's name + `@sgs.com` email
- **Application URL** if the form asks (dashboard prod URL or "N/A — daemon")

For Graph wording, see [templates.md](templates.md).

### 3. Write the ticket draft

Use the field tables in [templates.md](templates.md). Output for the user:

1. **Short summary** (one sentence they can skim)
2. **Catalog link** (clickable)
3. **Per-field copy** (markdown table)
4. **Description** (single fenced `text` block they paste wholesale)

Timezone-stamp any "Status follow-up" notes you keep locally in their
`CONTEXT/work-log.md` — not in ServiceNow unless they ask.

### 4. Open ServiceNow (dedicated Edge — default)

Same shape as expenses § “Start here”:

1. Open catalog in Edge (once per session):

   ```powershell
   powershell -File .cursor/skills/sgs-it-tickets/scripts/Open-ServiceNow-Edge.ps1
   ```

2. User signs in in **that Edge window** (Use external login → MFA). If
   fill returns exit **20**, they finish login and you re-run fill.
3. Fill from draft (does not Submit):

   ```powershell
   powershell -File .cursor/skills/sgs-it-tickets/scripts/run-servicenow-fill.ps1 -Draft path\to\draft.txt
   ```

4. User reviews and **Submit** in Edge; they send you the **RITM**.

Do **not** use cursor-ide-browser for filing unless Edge is blocked.
`Open-ServiceNow.ps1 -UseSystemBrowser` is last resort only.

### 5. After they submit

- Record **RITM / REQ / SCTASK** in `CONTEXT/work-log.md` once they paste it.
- On **ehs_dashboard**, add a dated case section to `CONTEXT/sgs-it.md`
  when IAM teaches something new (catalog URL, field copy that worked,
  what not to do).
- **Requester cannot assign** tickets to IAM — if IAM already named the
  item and permissions, draft a polite reply asking them to assign and
  link tickets (see [examples.md](examples.md)).

## IAM language cheatsheet

Write the way IAM engineers scan tickets:

- Name the **Azure resource** and **resource group** in the first paragraph.
- State **confidential daemon** vs **user-facing SSO** explicitly.
- List **Microsoft Graph** permissions with **application** vs **delegated** and note **admin consent**.
- Say **single-tenant SGS** (`sgs.onmicrosoft.com`) when relevant.
- Quote IAM's last email (ticket number + what they asked for) so a new
  queue does not re-litigate.
- **Deliverables:** client ID, tenant ID, secret or cert — and where
  secrets will live (Key Vault name, never literal secrets in SN).

Tenant facts (do not drift):

- You cannot self-create Entra apps (`allowedToCreateApps` is false).
- User consent is limited; Mail/Calendar/Teams usually need admin consent.
- Graph on a Web App **managed identity alone** will bounce — needs an
  App Registration (credentials in Key Vault / app settings), not MI replacement.

## Anti-patterns

- **Duplicate catalog intakes** for one grant (Graph case: three tickets
  for one daemon app). Prefer one registration ticket + reply on Graph ticket.
- **Mail.Send** for unattended dashboard mail — EHS uses SGS Email API; do
  not file Graph send for that backlog note.
- **Reopening closed Graph grant** when `sgs-it.md` says consent is live
  (e.g. `Presence.Read.All` + `User.Read.All` for absence — done 2026-09-19).
- Putting **secrets** in ServiceNow description or chat.
- **Clicking Submit / Order Now** — fill only; user submits.

## More

- Background browser + login: [browser.md](browser.md)
- Catalog URLs and `sys_id` values: [catalog-items.md](catalog-items.md)
- Field tables and description blocks: [templates.md](templates.md)
- Real RITM story + reply templates: [examples.md](examples.md)
