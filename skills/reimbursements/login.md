# Workday sign-in (SGS)

## Address

- Tenant: `wd3.myworkday.com/sgs`
- Create expense report: `https://wd3.myworkday.com/sgs/d/task/2997$728.htmld`

That task URL **is** the start page. The draft script opens it. Override
with `EXPENSE_URL` in `.env` if SGS changes the task id.

## Use Edge, not Cursor’s window

Cursor’s helper window **cannot** finish SGS sign-in. After the username
it goes to `sso.sgs.net/adfs/ls/wia` and stays **blank/black**. Cookie
copy into that window is blocked.

Always open Workday in real Edge:

```powershell
powershell -File .cursor/skills/reimbursements/scripts/Open-Workday-Edge.ps1
```

That script starts Edge with a debug port (`9222`) so
`run-expense-draft.ps1` can talk to the **same** page (URLs +
`data-automation-id`), not a second browser.

Username is `EXPENSE_USERNAME` or `SGS_EMAIL` in `.env`. Do not store
the Microsoft password. One-time codes: use once, do not store.

## Agent steps

1. Run the Edge helper.
2. If the draft script exits `20` / `NEED_LOGIN`, they finish sign-in
   in Edge (email, Remember this device, phone check). Then re-run
   the **same** job. Do not recreate the report by hand.
3. If a phone / extra check appears, stop and ask them.
4. If Workday dumped them on the home page, the next script run goes
   to the create-report URL again.

## Old pattern (do not use)

<details>
<summary>Cursor helper window</summary>
Blank/black after username. Do not retry that window for expenses.
</details>
