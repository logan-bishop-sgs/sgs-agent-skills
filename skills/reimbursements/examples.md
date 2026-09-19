# Memos and expense types

Fill this as real reports are done. Prefer copying what the person approved. Personal trip notes belong in their working-folder log, not here, unless the pattern is useful for everyone.

## Header memo

Short place + date is fine. Example: `bogota 7/26`.

## Line memos

Foreign-currency workaround: short what-it-was, then the ticket in local money, then that it was entered in USD because local currency left reimbursement at 0.

Example: `Dollarcity Bogota snacks. Ticket 113,000 COP (~$37.16 USD). Entered in USD because reimbursement stayed 0.00 when the line was in COP.`

Example: `Sheraton Bogota hotel laundry (Lavanderia). Ticket 913,920 COP (~$300.54 USD). Entered in USD because reimbursement stayed 0.00 when the line was in COP.`

## Expense types that have been used

Full list (118 `US_*` labels, dumped from the prompt HTML):
`expense-items.json`. Do not scroll the picker looking for a name — pick from that file.

| When it looks like | Type to pick in Workday |
|--------------------|-------------------------|
| Software / Cursor / IT tools | `US_IT SUPPLIES` |
| Cell / Verizon / international roaming | `US_CELL PHONE USAGE` |
| Meals / snacks / hotel restaurant | `US_MEALS (SELF, SGS EMP.)TIPS` |
| Hotel laundry / dry cleaning | `US_LAB CLOTHING - LAUNDRY/DRY CLEANING` |

## Dates

Line date comes from the receipt. Example Cursor invoice: “$193.20 USD
due September 15, 2026” → line date `2026-09-15`, not the day you
clicked Create, and not a leftover July date on an old report.

A new report’s header is **today**. Short memo can still name the
thing: `Cursor September`.

## What went wrong (2026-09-19)

Do **not** repeat this.

Logan asked to file September Cursor invoices. The agent opened
`WDERUS_10002505` (started Aug 24, leftover line **July 2**) and added
the new receipts there. Workday kept July 2 on most lines. The report
date stayed August 24. Finance paid $1,146.61. Logan looked for a
new $1,000+ report from yesterday and did not see it.

Correct move: **Create Expense Report** on Sept 18/19, one new report,
each line dated from its invoice.

## Do not do

- Do not treat another company’s Workday labels as SGS labels.
- Do not pick “personal” unless they said the charge was personal.
- Do not reuse a send-back or last month’s software report unless they named it.
