# ServiceNow sign-in (SGS)

## Use dedicated Edge, not Cursor’s browser

Expenses use **real Edge** on port **9222**. ServiceNow uses the **same
pattern** on port **9223** so Workday and ServiceNow can stay open at
once without fighting for the debug port.

```powershell
powershell -File .cursor/skills/sgs-it-tickets/scripts/Open-ServiceNow-Edge.ps1
```

That opens (or reuses) an Edge window with profile `%LOCALAPPDATA%\SgsServiceNowEdge`.
You sign in there — Microsoft + Authenticator — same as any SGS site.

Cursor’s chat **Browser** tab and **Simple Browser** are **different
sessions**. The agent only drives the **Edge window** above via CDP.

## Agent steps

1. Run `Open-ServiceNow-Edge.ps1`.
2. If Edge shows ServiceNow local login, click **Use external login**.
3. User finishes Microsoft MFA in **that Edge window**.
4. Run fill (does not Submit):

   ```powershell
   powershell -File .cursor/skills/sgs-it-tickets/scripts/run-servicenow-fill.ps1
   ```

5. Exit code **20** → still need login in Edge; user signs in, re-run fill.
6. User reviews and clicks **Submit** in Edge.

## Ports

| App | CDP port | Profile folder |
|-----|----------|----------------|
| Workday expenses | 9222 | `SgsWorkdayEdge` |
| ServiceNow IT tickets | 9223 | `SgsServiceNowEdge` |

Override with env `SERVICENOW_CDP_PORT` if needed.
