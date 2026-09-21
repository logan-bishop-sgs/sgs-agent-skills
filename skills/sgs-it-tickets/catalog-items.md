# ServiceNow catalog items (SGS)

> Last verified: 2026-09-21. When IAM names a new `sys_id`, update this
> file and `ehs_dashboard/CONTEXT/sgs-it.md`.

Base portal: https://sgs.service-now.com/sp

## Create Azure AD Application registration (use for Entra apps)

**Verified 2026-09-21:** form fields `app_name`, `scope`, `env_type`, etc.
Selectors: `selectors.json`. Fill: `run-servicenow-fill.ps1`.

- **sys_id:** `01714e3edb523f404ee710284b961975`
- **URL:** https://sgs.service-now.com/sp?id=sc_cat_item&sys_id=01714e3edb523f404ee710284b961975
- **Script key:** `entra-app-registration-legacy` (default in `Open-ServiceNow-Edge.ps1`)

## Catalog `7dec6166…` (IAM “new” link — wrong form as of 2026-09-21)

Teodore named `7dec6166477f8594a1a7efb2e36d43de` for future apps (2026-09-18), but it
opens **Other IAM request** (GPO / firewall), not Entra registration. Do **not** file
Entra apps there until IAM fixes the catalog mapping.

- **sys_id:** `7dec6166477f8594a1a7efb2e36d43de`
- **Script key:** `entra-app-registration` (avoid for Entra until corrected)

## Graph / API permissions on existing registration

There is **no stable public sys_id** in our docs. IAM opens a ticket
against the Web App or registration when you ask.

**Process:** After the app exists, **reply on the existing Graph /
permissions ticket** with the Application (client) ID. Do not file a
second catalog item unless IAM explicitly names one.

## Finding other items

1. Open portal (script key `portal`).
2. Search catalog for what IAM said (exact catalog title).
3. If unsure, draft the description anyway and ask the user to search
   — or reply on an open ticket quoting IAM's catalog name.
