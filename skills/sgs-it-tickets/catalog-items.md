# ServiceNow catalog items (SGS)

> Last verified: 2026-09-21. When IAM names a new `sys_id`, update this
> file and `ehs_dashboard/CONTEXT/sgs-it.md`.

Base portal: https://sgs.service-now.com/sp

**NAM email intake (not a catalog item):** `nam.it.support@sgs.com` can
auto-open ServiceNow for **email access** requests (2026-09-21). Other
types unverified — see `ehs_dashboard/CONTEXT/sgs-it.md`.

Mirror form dumps (field ids for agents): `ehs_dashboard/CONTEXT/drafts/servicenow-entra-form-dump.json`, `servicenow-form-dump.json`.

## How to find and verify a catalog item

Hardest step is often **picking the right `sc_cat_item`**, not writing the description.

1. **Ask IAM** on an open ticket if they already named a catalog title — use their exact words in portal search.
2. **Portal search** (logged-in ServiceNow Edge, CDP 9223):
   - UI: Service Portal → search box, scope **Service Catalog**.
   - URL pattern: `https://sgs.service-now.com/sp?id=search&spa=1&t=sc&q=<query>` (URL-encode spaces).
   - Script: `scripts/search_servicenow_catalog.py` (exit **20** = not signed in; finish login in Edge, re-run). Uses `load` not `networkidle` — SN SPA may hang on `networkidle`.
3. **Verify before filing:** open the item and check the **browser tab title** matches what you expect (e.g. “Create Azure AD Application registration”, not “Other IAM request”).
4. **Dump fields** while the form is open: `python scripts/dump_servicenow_form.py` — today it defaults to Entra `01714e3e…`; for another item, navigate Edge to that `sc_cat_item` URL first, then dump (or extend the script with `--url`).
5. **Record here:** `sys_id`, portal title, when to use / when **not** to use, stable field ids (`sp_formfield_*`), whether Playwright fill exists (`selectors.json` + `run-servicenow-fill.ps1`).

**Deep link shape:** `https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=<32-char hex>`

**Open Edge:**

```powershell
powershell -File .cursor/skills/sgs-it-tickets/scripts/Open-ServiceNow-Edge.ps1 -Catalog portal
# or -Url 'https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=...'
```

Script keys in `Open-ServiceNow-Edge.ps1`: `portal`, `entra-app-registration-legacy`, `entra-app-registration`.

## Request type → catalog (quick map)

| You need… | Catalog | Action if unsure |
|-----------|---------|------------------|
| New Entra app registration (SSO or daemon) | [Entra registration `01714e3e…`](#create-azure-ad-application-registration-entra) | Do **not** use Teodore’s `7dec6166…` link until IAM fixes mapping |
| Graph admin consent on **existing** registration | *(no stable sys_id)* | Reply on IAM’s open ticket with client ID |
| Endpoint / firewall / GPO-style IAM | [Other IAM `7dec6166…`](#other-iam-request-gpo--firewall) | Confirm title in browser; may be wrong for **Azure platform** plumbing — search “azure”, “hybrid”, “network” first |
| VPN, software, general IT | Portal search | Draft text; user or IAM picks item |
| Azure RBAC / subscription / RG access (Contributor, `az login` ops) | [Access Request `d9d3e9d8…`](#access-request-azure-rbac--platform) | Verified 2026-09-21 via portal search “cloud platform access”; if IAM reroutes, record the correct sys_id here |
| Azure platform ask with no clear catalog | [Other IAM `7dec6166…`](#other-iam-request-gpo--firewall) | Narrative in Description; ask reroute |
| Corporate DNS **`xxxx.sgs.com`** for Azure App Service | [DNS subdomain `68d0954c…`](#dns-subdomain-xxxxsgscom) | **Use this** for `intelligence.sgs.com` — not domain registration |
| Register/transfer whole domain (e.g. `something.com`) | [Domain Name Request Form `9d0cdae3…`](#domain-name-request-form) | **Not** for `*.sgs.com` subdomains — form text links to subdomain item |

## DNS subdomain (`xxxx.sgs.com`)

**Portal title:** varies — opened from **Domain Name Request Form** help text when type is registration.

**Use for:** new **subdomains under `sgs.com`** (CNAME/alias to Azure App Service, etc.). Example: `intelligence.sgs.com` → `us-ehs-tv-reports-….azurewebsites.net`.

- **sys_id:** `68d0954c1b92e01040b0eb186e4bcb83`
- **URL:** https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=68d0954c1b92e01040b0eb186e4bcb83&sysparm_category=7c2e77891b33f01040b0eb186e4bcb72
- **Draft:** `ehs_dashboard/CONTEXT/drafts/servicenow-custom-domain-ehs-dashboard-2026-09-22.txt`

## Domain Name Request Form

**Portal title:** `Domain Name Request Form - Service Portal`

**Use for:** **register / transfer / decommission a domain** — **not** `xxxx.sgs.com` subdomains (form points to `68d0954c…` above).

- **sys_id:** `9d0cdae3476a9910a1a7efb2e36d43ed`
- **URL:** https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=9d0cdae3476a9910a1a7efb2e36d43ed

## Access Request (Azure RBAC / platform)

**Portal title:** `Access Request - Service Portal`

**Use for:** Azure Resource Manager role grants, subscription/RG operational access,
`az login` parity for a team — **not** Entra app registration (use `01714e3e…`) and
**not** firewall/GPO (use Other IAM unless IAM says otherwise).

- **sys_id:** `d9d3e9d81b608950b1fc740e1d4bcbce`
- **URL:** https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=d9d3e9d81b608950b1fc740e1d4bcbce
- **Script key:** `access-request` in `Open-ServiceNow-Edge.ps1`
- **Automated fill (partial):** `fill_servicenow_access_request.py` +
  `run-servicenow-fill-access-request.ps1` — fills Roles, environment detail,
  Business Reason, first affected email, watch list. **You** still pick Type of
  action, Business Service, Application, Environment in the UI.
- **Draft example:** `ehs_dashboard/CONTEXT/drafts/servicenow-azure-rbac-team-access-2026-09-21.txt`
- **Form dump:** `ehs_dashboard/CONTEXT/drafts/servicenow-access-request-form-dump.json`

| Label (UI) | `name` / `id` | Notes |
|------------|---------------|--------|
| Requested for | `requested_for` / `sp_formfield_requested_for` | User picker |
| Type of action | `type_of_action` / `sp_formfield_type_of_action` | Select — manual |
| Business Service | (select2) | Manual |
| Application | (select2) | **Not** the same list as Azure Web App *Project or Application* — `Generative AI Lab Reports - GLOBAL` (RITM0953558) is **missing** here (2026-09-21). Use **Azure DevOps** or leave blank; put CMDB name in Business Reason — [filer-defaults.md](filer-defaults.md) |
| Environment | (select) | Manual — prod + nonprod |
| Please add here the environment needed | `please_complete_here_the_enviroment_needed` / `sp_formfield_please_complete_here_the_enviroment_needed` | Subscription + RG text |
| Roles | `roles` / `sp_formfield_roles` | e.g. Contributor @ RG scope |
| Business Reason | `business_reason` / `sp_formfield_business_reason` | **Main narrative** |
| Affected User Email | `affected_user_email` / `sp_formfield_affected_user_email` | One email per ticket if IAM requires split |
| Watch List | `watch_list` / `sp_formfield_watch_list` | select2 click-to-add |

**Note:** `General Identity Governance and Administration request`
(`0107280693c2c750fd15f5d8b903d67d`) dumped the same field set (2026-09-21) —
prefer **Access Request** unless IAM names IGA.

## Create Azure AD Application registration (Entra)

**Portal title:** `Create Azure AD Application registration - Service Portal`

**Use for:** new Microsoft Entra Application Registrations (daemon **or** user SSO). IAM used this for RITM1077272; verified again for SSO draft 2026-09-21.

- **sys_id:** `01714e3edb523f404ee710284b961975`
- **URL:** https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=01714e3edb523f404ee710284b961975
- **Script key:** `entra-app-registration-legacy` (default in `Open-ServiceNow-Edge.ps1`)
- **Automated fill:** `selectors.json` + `run-servicenow-fill.ps1` + draft `.txt` (see `templates.md`)

| Label (UI) | `name` / `id` | Notes |
|------------|---------------|--------|
| ApplicationName | `app_name` / `sp_formfield_app_name` | e.g. `SGS-US-EHS-DASHBOARD-SSO-PROD` |
| Scope | `scope` / `sp_formfield_scope` | Free text; list Graph perms + Internal/External if asked |
| Short Description | `var_short_description` / `sp_formfield_var_short_description` | One-line summary |
| Environment | `env_type` / `sp_formfield_env_type` | Select: `prod`, `dev`, `test`, `uat`, `nonprod` (fill script maps “Production” → `prod`) |
| Application URL | `app_url` / `sp_formfield_app_url` | Prod or dev slot URL |
| Owner | `owner` / `sp_formfield_owner` | Name / email |
| Description | `description` / `sp_formfield_description` | Large textarea |
| Watch List | `watch_list` / `sp_formfield_watch_list` | Select2 — type email, **click** the matching result (Enter alone may not stick) |
| Business service / Service offering | `sp_formfield_business_service`, `sp_formfield_service_offering` | Often pre-filled (~32 chars); usually leave as-is |

## Other IAM request (GPO / firewall)

**Portal title:** `Other IAM request - Service Portal`

**Use for:** IAM security intake with **firewall / endpoint / GPO** style fields (src/dst IP, ports, protocol). **Not** the Entra registration form.

**Trap:** Teodore DeCastro named `7dec6166477f8594a1a7efb2e36d43de` for *future new apps* (2026-09-18). That URL opens **this** form, not “Create Azure AD Application registration”. Until IAM fixes the catalog mapping, file Entra apps only on `01714e3e…`.

- **sys_id:** `7dec6166477f8594a1a7efb2e36d43de`
- **URL:** https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=7dec6166477f8594a1a7efb2e36d43de
- **Script key:** `entra-app-registration` (misleading name — opens Other IAM)
- **Automated fill:** `fill_servicenow_other_iam.py` + `run-servicenow-fill-other-iam.ps1` (short description, description, watch list — not Type of request / firewall sub-fields)

| Label (UI) | `name` / `id` | Notes |
|------------|---------------|--------|
| Type of request | `type_of_request` / `sp_formfield_type_of_request` | Select — drives which sub-fields show |
| Windows | `window` / `sp_formfield_window` | Select |
| Trusted Site | `trusted_site` / `sp_formfield_trusted_site` | |
| Short Description | `var_short_description` / `sp_formfield_var_short_description` | |
| Reference (SDEFW#) | `reference_i_e_sdefw` / `sp_formfield_reference_i_e_sdefw` | |
| UserAccountName | select2 + hidden select | User picker |
| Type of risk | `type_of_risk` / `sp_formfield_type_of_risk` | |
| Rationale | `rationale` / `sp_formfield_rationale` | |
| Src (remote) IP/s | `src_remote_ip_s` / `sp_formfield_src_remote_ip_s` | |
| Src (remote) port/s | `src_remote_port_s` / `sp_formfield_src_remote_port_s` | |
| Protocol | `protocol` / `sp_formfield_protocol` | |
| Dst (workstation) IP/s | `dst_workstation_ip_s` / `sp_formfield_dst_workstation_ip_s` | Wording is workstation-centric — for **Azure → corp** put Azure/outbound context in **Description** and ask IAM to route |
| Dst (workstation) port/s | `dst_workstation_port_s` / `sp_formfield_dst_workstation_port_s` | |
| Application | select2 | |
| Executable path | (see dump) | |
| Profile | select | |
| Region / Country | select fields | |
| IT Security Regional Manager | `it_security_regional_manager_useraccountname` | |
| Description of the request | `u_description_of_the_request` / `sp_formfield_u_description_of_the_request` | **Main narrative** for complex asks |
| Watch list | `watch_list` / `sp_formfield_watch_list` | Same select2 behavior as Entra |
| Priority | `u_priority` / `sp_formfield_u_priority` | |
| Business Service / Service Offering | pre-filled often | |

**Azure corp connectivity (2026-09-21):** no dedicated `sys_id` in our notes.
**Best guess:** file here anyway; narrative in `u_description_of_the_request`;
ask IAM to reroute to cloud/network if wrong. Draft:
`ehs_dashboard/CONTEXT/drafts/servicenow-azure-corp-network-2026-09-21.txt`.

## Graph / API permissions on existing registration

There is **no stable public sys_id** in our docs. IAM opens a ticket
against the Web App or registration when you ask.

**Process:** After the app exists, **reply on the existing Graph /
permissions ticket** with the Application (client) ID. Do not file a
second catalog item unless IAM explicitly names one.

## Anti-patterns (catalog)

- Filing Entra on `7dec6166…` because Teodore’s email said “future apps” — **verify tab title**.
- Opening a **second** catalog item for Graph consent when a ticket already exists — **reply** with client ID.
- Assuming **watch list** users get Graph or app access — watch list is **ticket visibility only** (state that in Entra description when relevant).
