# ServiceNow browser (dedicated Edge — same as expenses)

## Default: `Open-ServiceNow-Edge.ps1`

Do **not** use Cursor’s chat Browser or Simple Browser for filing. They are
separate sessions and confused login with the agent.

Use the **same pattern as Workday reimbursements**:

| | Expenses | ServiceNow IT tickets |
|---|----------|------------------------|
| Script | `reimbursements/scripts/Open-Workday-Edge.ps1` | `sgs-it-tickets/scripts/Open-ServiceNow-Edge.ps1` |
| CDP port | 9222 | 9223 |
| Edge profile | `SgsWorkdayEdge` | `SgsServiceNowEdge` |
| Fill | `run-expense-draft.ps1` + Python | `run-servicenow-fill.ps1` + Python |
| Submit | User only | User only |

See [login.md](login.md).

## Agent workflow

1. `Open-ServiceNow-Edge.ps1` — one Edge window for ServiceNow.
2. User signs in in **that** Edge (external login → Microsoft MFA).
3. `run-servicenow-fill.ps1` — Playwright attaches to port 9223, fills fields.
4. User reviews and **Submit** in Edge.

Exit **20** from fill script = still need login in Edge.

## Escape hatches

- `Open-ServiceNow.ps1 -UseSystemBrowser` — one-shot default browser (no CDP).
- cursor-ide-browser MCP — avoid unless debugging; not the filing path.
