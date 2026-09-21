# Ticket field templates

Customize placeholders in ALL_CAPS. Keep Description blocks as plain `text`.

## A. New Entra app — daemon / Graph client credentials

Typical form fields (names may vary slightly in ServiceNow UI):

| Field | Value |
|-------|--------|
| ApplicationName | `SGS-US-EHS-…-PROD` (your app; unique, no spaces) |
| Scope | One line: `Microsoft Graph application permissions: PERM1, PERM2 (admin consent). Single-tenant SGS. No delegated permissions. No user sign-in.` Pick **Internal** if asked Internal/External. |
| Short Description | One line: purpose + "Not used for App Service login" if daemon. |
| Environment | `Production` or `Non-production` |
| Application URL | Prod dashboard URL, or `N/A — daemon (no redirect URI)` |
| Owner | Filer name + `@sgs.com` |
| Description | Paste block below |

```text
Create a confidential / daemon Microsoft Entra Application Registration for
Azure RESOURCE_TYPE RESOURCE_NAME (resource group RESOURCE_GROUP).

CONTEXT: IAM confirmed RESOURCE_NAME uses a system-assigned Managed Identity
and has no App Registration, so Graph permissions cannot attach to that
identity alone. This request creates the registration IAM needs.

Purpose: ONE_SENTENCE_BUSINESS_PURPOSE.

The app uses client credentials (MSAL), not a signed-in user.

Configuration:
- Accounts: SGS tenant only (sgs.onmicrosoft.com)
- Type: confidential client / daemon
- No redirect URI [OR list redirect URIs if user-facing SSO — see template B]
- Do not configure App Service Easy Auth on this registration unless requested
- Do not replace or disable the Web App system-assigned managed identity
  (Key Vault and Azure AD Postgres stay on that identity)

Microsoft Graph application permissions requested (admin consent):
- PERM1
- PERM2

After creation, please return:
1. Application (client) ID
2. Directory (tenant) ID
3. Client secret (or certificate if that is the IAM standard — note if cert-only)

We will store credentials in KEY_VAULT_NAME as APP_SETTING_NAMES (Key Vault
references on App Service / Function App). We will not paste secrets into
ServiceNow or git.

Contact: TEAM_NAME (filer).
```

## B. New Entra app — user sign-in (SSO) + delegated Graph

| Field | Value |
|-------|--------|
| ApplicationName | `SGS-US-EHS-…-SSO-PROD` |
| Scope | `Microsoft Graph delegated permissions: User.Read, … (admin consent). OIDC: openid, profile, offline_access. Single-tenant SGS. User sign-in via MSAL auth code + PKCE.` |
| Short Description | User-facing SSO for APPLICATION_NAME; not replacing managed identity for database. |
| Environment | Production / Non-production |
| Application URL | https://YOUR_APP_HOST/ |
| Owner | Filer |
| Description | Paste block below |

```text
Create a Microsoft Entra Application Registration for user sign-in (OIDC)
to APPLICATION_NAME.

Purpose: ONE_SENTENCE (e.g. Sign in with Microsoft for FEATURE).

Configuration:
- Accounts: SGS tenant only (sgs.onmicrosoft.com)
- Type: confidential client with redirect URIs:
  - https://PROD_HOST/auth/callback
  - https://DEV_SLOT_HOST/auth/callback (if applicable)
  - http://localhost:PORT/auth/callback (local dev, if IAM allows)
- Platform: Web
- Do not disable the App Service system-assigned managed identity used for
  Key Vault / Postgres

Microsoft Graph delegated permissions (admin consent expected):
- User.Read
- OPTIONAL: Mail.Read, Calendars.Read, Chat.Read, etc.

OIDC scopes: openid, profile, offline_access

After creation, please return client ID, tenant ID, and client secret
(or cert). We will store in KEY_VAULT_NAME.

MFA / Microsoft Authenticator is enforced by tenant Conditional Access;
no separate "Authenticator permission" is required.

Contact: TEAM_NAME (filer).
```

## C. Reply on existing ticket (Graph consent / link tickets)

Do not use the catalog. Paste into **Additional comments** on the open ticket:

```text
Follow-up on TICKET_NUMBER:

This is the Application Registration request IAM asked for on DATE.
Application (client) ID: CLIENT_ID_GUID

Please assign this RITM to the App Registration / IAM queue, link it to
the Graph permissions ticket TICKET_NUMBER_2, and complete admin consent
for:
- PERM1 (application)
- PERM2 (application)

We are not requesting a new intake for the same grant. Requester cannot
assign queues — please route internally.

Thank you,
NAME
```

## D. Delegated vs application (quick reference for Scope field)

| Need | Permission type | Example scopes |
|------|-----------------|----------------|
| Daemon Teams presence (all users) | Application | `Presence.Read.All`, `User.Read.All` |
| Signed-in user's profile | Delegated | `User.Read` |
| Signed-in user's mail | Delegated | `Mail.Read`, `Mail.Send` |
| Signed-in user's calendar | Delegated | `Calendars.Read`, `Calendars.ReadWrite` |
| Signed-in user's Teams chats | Delegated | `Chat.Read` |

Always say **admin consent** when IAM must tenant-consent (typical at SGS).
