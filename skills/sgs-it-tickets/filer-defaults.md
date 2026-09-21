# ServiceNow filer defaults (Logan Bishop)

> Personal CMDB / catalog picker values for this filer only. Agents: read when
> an Access Request or Azure catalog form asks for **Application** / **Project
> or Application** and the draft does not already specify a value. Do **not**
> copy this into `ehs_dashboard/CONTEXT/sgs-it.md` — that file is team IAM
> cases, not filer-specific picker memory.

## Project or Application (Azure resource requests)

| Catalog item | Field label | Value | Evidence |
|---|---|---|---|
| Request a new Azure Web App | **Project or Application** | `Generative AI Lab Reports - GLOBAL` | [RITM0953558](https://sgs.service-now.com/sp?id=ticket&table=sc_req_item&sys_id=9ae8652e2b8c0f105d45f6716e91bffe) → **Additional Details** (closed, ~2026-04). Deployed `us-ehs-certis`. |
| Request a new Azure Function App | **Project or Application** | *(likely same — verify on next function-app ticket)* | RITM0929379 (EHS Cloud reporting) — open **Additional Details** if this drifts. |
| **Access Request** (`d9d3e9d8…`) | **Application** | **`Generative AI Lab Reports - GLOBAL` does not appear** in this select2 (verified 2026-09-21). Use **`Azure DevOps`** if the form requires a picker value, or leave blank; put the CMDB name in **Business Reason**. | Web App *Project or Application* ≠ Access Request *Application* reference table. |

Related fields on RITM0953558 (for orientation, not necessarily copied to Access Request):

- **Wished Name of the Azure Resource:** `us-ehs-certis` (that ticket; TV Reports stack is `US-EHS-TV-REPORTS` / `rg-use-genailabreport-nonprod`)
- **AAD/AD Group:** `SGS-Global-USEHSCERTBOT-Prod` (certis-era group — do not reuse blindly for RBAC tickets)
- **Azure Region:** East US
- **What type of environment?:** Production

## How to refresh these values

See [SKILL.md](SKILL.md) § “Recover filer-specific catalog pickers” — not repeated here.
