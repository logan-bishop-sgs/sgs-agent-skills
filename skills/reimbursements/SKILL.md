---
name: reimbursements
description: >-
  Create and complete SGS expense reports in Workday. Covers corporate
  card charges and out-of-pocket reimbursement, receipts, memos, and
  foreign-currency amounts. Use when the user mentions expenses,
  expense reports, Workday expenses, corporate card, receipts,
  reimbursement, or filing a report in Workday.
---

# Workday expense reports (SGS)

**Talk to the user** with `.cursor/library-notes/voice.md`. Do the
report yourself. Leave a **draft**. They submit.

Same shape as the LIMS skills: **you write a job and run a script**.
You do **not** drive Workday click-by-click in Cursor’s helper window
(that window cannot finish `sso.sgs.net`, and it is slow).

Workday is a web page, not AniTa. There is no cell `2,20`. The closed
path is: open the **Create Expense Report URL** in real Edge, then
click/fill **named page elements** (`data-automation-id`, labels).
Those names live in `selectors.json` plus a local overlay.

Personal facts (name, memo style, cost center, receipts folder) live
in **this working folder’s** notes (`CONTEXT/` or `context/`), not
in this skill. Do not invent amounts, vendors, cost centers, or policy.

## New report, not an old one

If they ask you to file expenses, **start Create Expense Report**.
That makes a report dated **today**. Do **not** open a sent-back,
Saved for Later, Waiting on Initiator, or Paid report and add lines
to it — even if the memo looks the same (“software”, Cursor).

Reuse an existing report **only** when they name it (`WDERUS_…`) or
say “add this to that draft.” Put that id in the job as
`existing_report`. Otherwise the job is a new report.

**2026-09-19 (Logan, Cursor invoices):** the agent put September
Cursor receipts on `WDERUS_10002505`, an August 24 send-back that
still had a July 2 line. Workday kept **July 2** on six of seven
lines and the **report date stayed Aug 24**. Finance paid $1,146.61
anyway. Logan could not find “yesterday’s $1,000+ Cursor report”
because it looked like last month. The leftover $278.31 sat in My
Tasks on another old report. That was the skill being wrong, not
Logan.

## Dates

| What | Date to use |
|------|-------------|
| New report (header / report date) | **Today** — the day you are filing |
| Each line | The **receipt** (invoice date of issue / amount-due date). No receipt: the card charge date. Neither: **today**. |

Never copy a date from another report or from a leftover Workday
line. `fill()` on the month/day/year boxes often **looks** done and
then snaps back to the old date. **Type** the digits (select all,
type), then **read the three boxes**. If they are not the receipt
date, it is not done — heal and retry. Do not save and walk away.

SGS (2026): expenses on or before **July 20** belong in Oracle, not
Workday. A leftover July date can send the report back or file it
in the wrong system.

## Start here (hands-off)

1. Open Workday in Edge (once per session):

   ```powershell
   powershell -File .cursor/skills/reimbursements/scripts/Open-Workday-Edge.ps1
   ```

2. If Edge shows SGS sign-in or a phone check, **stop and ask them**.
   Do not try Cursor’s window. See [login.md](login.md).
3. Write a job JSON (receipts + lines). Use
   `scripts/job.example.json` as the shape. Amounts and merchants come
   from the card charge or the receipt — never guessed.
4. Run the draft script. Do not pixel-hunt.

   ```powershell
   powershell -File .cursor/skills/reimbursements/scripts/run-expense-draft.ps1 -Job .cursor/skills/reimbursements/scripts/job.json
   ```

5. **Before you say it is done**, check Workday for errors:

   ```powershell
   python .cursor/skills/reimbursements/scripts/fill_oop_line.py --check-only
   ```

   Exit `40` / `WORKDAY_ERRORS` means it is **not** done. Fix the
   listed errors (usually an incomplete $0 line, Paid with Corporate
   Card still on, or a required field). Re-check. Only then summarize.
   **Do not click Submit.**

Exit codes you must honor:

| Code | Meaning | What you do |
|------|---------|-------------|
| 0 | Draft lines filled **and** error bar empty | Summarize. They review. |
| 20 | `NEED_LOGIN` | Ask them to finish Edge sign-in. Re-run the same job. |
| 30 | `HEAL` | Locator missed. Do **not** start clicking the whole report. Read `%LOCALAPPDATA%\sgs-workday-expense\last-fail.json`, patch `CONTEXT/workday-selectors.json`, retry **once**. |
| 40 | Workday error | Read the dump. Ask them if it is a real Workday message. |
| 50 | Edge / Playwright missing | Open Edge with the helper. `pip install playwright` if needed. No `playwright install` — CDP uses the Edge that is already open. |

## What the script talks to

- **URL:** `https://wd3.myworkday.com/sgs/d/task/2997$728.htmld`
  (`EXPENSE_URL` in `.env` overrides). That *is* Create Expense Report.
  Do not walk hamburger → Personal → Expenses Hub unless the URL fails.
- **Elements:** `selectors.json` keys (`header_memo`, `header_ok`,
  `credit_card_transactions`, `paid_with_card`, `expense_item_prompt`,
  `line_done`, …). Prefer `data-automation-id`. Then label. Then
  visible text. Never Escape. Never the line **X**. Never **Submit**.

Expense type: use the **exact** `US_*` string from
[expense-items.json](expense-items.json) (dumped from the prompt DOM).
Software / Cursor is `US_IT SUPPLIES`. Do not scroll the picker looking
for a name. Refresh the dump with
`python .cursor/skills/reimbursements/scripts/dump_expense_items.py`.

**Add vs New Expense:** Expense Lines **Add** opens a menu.
**New Expense** = they paid themselves (these Cursor invoices).
**Credit Card Transactions** = pick a charge already on the SGS
Citibank card. Do not use that for receipts that are not on the card
grid. The script clicks **New Expense** only.

Out-of-pocket line (this is the error if you skip it): **uncheck**
Paid with Corporate Card (`data-automation-id="checkbox"` on that `li`,
`data-automationcheckboxchecked` must be `false`). Then fill Expense
Date (MM / DD / YYYY widgets), Expense Item, Quantity (usually `1`),
Per Unit Amount, Currency (almost always USD), Memo. Total Amount is
qty × per-unit — do not invent it.

## What to guess vs ask

| Field | Rule |
|-------|------|
| Memo | Guess a short business reason from the merchant, date, and anything they said. Ask if it could be personal, client-sensitive, or unclear. |
| Expense type | Guess from the merchant and receipt (meal, hotel, taxi, flight). Ask if two types could both fit. Put the **exact Workday label** in the job. |
| Date | Receipt date when you have a receipt. Else card charge date. Else today. Never an old report’s date. After fill, read the widgets. |
| Amount / merchant | Never guess. Use the card charge or receipt. Foreign currency: USD amount Workday showed; local total in the memo. |
| Cost center / extra coding | Leave Workday defaults unless their notes say otherwise. |

## Corporate card vs out of pocket

- **Card:** `kind: card`. Charge is already in Workday. Script matches
  merchant + amount (+ date) on the credit-card grid. Never add a
  second line for the same charge.
- **Out of pocket:** `kind: oop`. Script adds New Expense and **turns
  off** Paid with Corporate Card (`data-automationcheckboxchecked`,
  not a missing tick mark). If it stays on, reimbursement is wrong.

One PDF with several photos → one job line per receipt.

If they say **only file one page** (for example the second invoice in a
hotel PDF), split that page out and set `receipt` to **that page only**.
Do not attach the whole PDF. Do not file the skipped invoice, even if
it is a large hotel stay.

Before `kind: oop`, look at Credit Card Transactions for a matching
charge. If none, Cancel, then New Expense.

Adding to an **existing draft** (only if they asked): open that
report → Edit / Revise → Add. That screen may have **Save for Later**
and no line Done button. The script tries Done first, then Save for
Later. Still do **not** Submit. Still set each line date from the
receipt and read it back.

On a report that already has a converted foreign-currency line, reuse
that same USD rate for later tickets in the same currency.

## When the script breaks (self-heal)

Refresh skills **overwrites** `.cursor/skills/reimbursements/`. Heals
go in **this repo**:

`CONTEXT/workday-selectors.json` (or `context/`)

Overlay is merged on top of the library `selectors.json` (same key
wins). Example:

```json
{
  "header_ok": {
    "css": ["[data-automation-id='theNewOkId']"]
  }
}
```

1. Read `last-fail.json` (`step`, `url`, `automation` list, screenshot).
2. In the **already-open Edge** page, find the control’s new
   `data-automation-id` (or a stable label).
3. Patch **only that key** in the overlay.
4. Re-run the **same** job. If it fails a second time, stop and ask.
5. Append `CONTEXT/skill-issues.md` (old id → new id). Offer
   `report-skill-issue` so engineering can fold it into the library.

Do **not** PR `sgs-agent-skills` from a tech laptop. Do not rewrite
this SKILL.md to “just click it yourself.”

You may use Cursor’s browser tools **only** to read the dump / confirm
one element while healing. You may not file the whole report that way.

## After the report is filled

Tell them, in everyday words: memo, each line (date, merchant, type,
amount), that it is a **draft**, anything you guessed.

Write what worked in `CONTEXT/work-log.md`. Add a new memo/type
pattern to [examples.md](examples.md) only if it is useful for everyone.

## Stop and ask

- Sign-in or extra security check needs them
- Charge does not appear and they said it was on the card
- Receipt is missing or does not match the amount
- Workday shows an error, extra required field, or personal-expense flag
- You would have to invent a cost center, project, or guest name
- Two script retries already failed
