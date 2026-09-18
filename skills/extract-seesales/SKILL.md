---
name: extract-seesales
description: >-
  Extracts Accutest SEE SALES from AniTa (use-idb057 / 10.149.0.5), emails
  the block, and lands it in us.ehs.datadrop@sgs.com so SharePoint / Power
  Automate can pick it up. Use when the user says extract seesales, pull
  SEE SALES, run AniTa sales export, pass a month range, extract by group,
  service group, or feed SeeSales to datadrop.
---

# Extract SEE SALES

**Talk to the user** with `.cursor/library-notes/voice.md`: short, no
engineering words. Do the work. Ask only lab + months. When done:
"Houston SEE SALES for this month is done. It should show on SharePoint
soon." This script is for you, not for them to run.

Run this on a Windows PC with AniTa installed. One **Export** is
**one calendar month**. September is only September — not YTD. The form
count (`1 of 210`) is months of history.

Pass the range to the script. Do not pixel-hunt Export.

## Left off 2026-09-18 (read this first)

**Proven today**

- **Login** (hidden window): wait until `login:` paints, `chars loganb`
  enter, wait for `Password:`, `chars` password enter, `y` if
  `REMOVE?`, then IFORMS user then password **from separate snaps**.
  Never `key 13` at Linux (hangs up). Never `AutoUser2=""` (blank
  Linux password). `AutoLogin=No`, AutoHost `ogin:`/`ord:` `%null%`.
  Dayton and Wheat Ridge both reached SEE SALES this way.
- **Down-arrow** (VK 40) walks older months even when the form opens
  `1 of 1`. Wheat Ridge went Sep 2026 → Feb 2025 (`20 of 20`).
- **F7** opens service Group. **Page Down** opens
  `Product for Service Group`.

**Not finished today**

- **Export `host '\x1b}s2,20\r'` did not email.** Same send as
  2026-09-14. No new `SEEGROUPPROD` mail after Logan's manual
  13:58 GMT+8 file. Do **not** add mouse/`sclick`/cell-probing.
  Use **one hidden session** and that send. Confirm Inbox\SeeSales
  and SharePoint, not a guess from the snap classifier (no tesseract).
- Jan–Feb 2025 product files for non-Dayton labs are still missing.
- Two AniTa windows may still be open (`use-idb057` Wheat Ridge with
  chrome, `use-idb059` Dayton hidden). Close extras before a new run.

## When it breaks (look, then pick up)

Run hands-off. Do **not** watch every key. The script now **stops**
instead of walking a dead session:

- login / invalid password painted
- **COMPANY WIDE** (F11)
- title **Disconnected**
- form stays on the same month after Down-arrow (date did not change)
- Export wait with no `SEE GROUP PROD DONE` and no new
  `seesales-seegroupprod-loganb.xls` mail

Never type Invoice, `g`, or Export on **Please Log On**. User ID is
`loganb` only; password only on the password line. Two failed IFORMS
logons hang up. The runner **revives** a failed lab: close that host,
log in again, retry up to `-Retries` (default 3). A `1 of 1` form
is only the starting view — **Down-arrow** loads older months
(count grows `2 of 2`, `3 of 3`, …). Then **you** look at
the last snap in `%LOCALAPPDATA%\Temp\anita-capture\` only if
retries are exhausted. Relogin, **no F11**. Do not keep Down-arrowing
on a dead session. Logan's manual Wheat Ridge Export (2026-09-18
13:58 GMT+8) landed a real product file (`SEEGROUPPROD`, SEP-2026,
7.8 KB) in Inbox and SharePoint. F11 dumped the session.

## Hands-off (lab + months, no agent watching)

One script logs in, opens SEE SALES, walks groups, emails, and stamps
SharePoint. Run on this PC with VPN + AniTa. It does not steal focus.

```powershell
powershell -File .cursor/skills/extract-seesales/scripts/run-seesales-extract.ps1 -Lab orlando -ThisMonth
powershell -File .cursor/skills/extract-seesales/scripts/run-seesales-extract.ps1 -Lab houston -From 2026-01 -To 2026-09
powershell -File .cursor/skills/extract-seesales/scripts/run-seesales-extract.ps1 -Lab scott -Ytd
powershell -File .cursor/skills/extract-seesales/scripts/run-seesales-extract.ps1 -Lab houston,scott -ThisMonth
powershell -File .cursor/skills/extract-seesales/scripts/run-seesales-extract.ps1 -Lab all -ThisMonth
# Labs: wheatridge, dayton, orlando, scott, houston (or 057/059/066/062/064)
# -Lab all (or a comma list) logs in sequentially — one AniTa host at a time.
# Do not pass -ExpandHistory. F11 is company-wide and dumps the session.
```

`-ThisMonth` is the default if you omit a range. Group walk order is
built in per lab. Override with `-Groups` only when the form order
changed.

## Timeframe script (already on the form)

AniTa must already be on the SEE SALES **month list**, cursor on
**Month** (how the form opens). Do **not** press F11. It opens
COMPANY WIDE (empty / accunj errors) and can dump the login. If the
form opens `1 of 1`, **Down-arrow** still walks older months. Do not
stop and do not use F11.

```powershell
# Current calendar year through this month (e.g. 2026-01 .. 2026-09)
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-range.ps1 -Ytd

# Explicit inclusive range (YYYY-MM)
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-range.ps1 -From 2026-01 -To 2026-09

# This month only
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-range.ps1 -ThisMonth

# Form is not on the current calendar month — tell the script what is showing
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-range.ps1 -From 2025-01 -To 2025-12 -OnMonth 2026-09

# Print the walk without sending keys
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-range.ps1 -From 2026-01 -To 2026-09 -WhatIf
```

What it does, newest month first:

1. Down-arrow (older) or Up-arrow (newer) from `-OnMonth` (default:
   today's calendar month) to `-To`.
2. For each month: send AniTa Export cell **2,20**
   (`ESC } s 2,20 CR` via `SendMessage` — no focus steal).
3. Wait `-ExportWaitSeconds` (default 35). DONE is painted on the
   canvas, not the Windows status bar (`Connected` only). Confirm
   from the snap or SharePoint.
4. Down-arrow to the next older month. Repeat through `-From`.
5. Unless `-SkipSharePoint`, wait 90s and list today's
   `Power Automate Updates` folder.

Confirm on SharePoint, not Inbox:

```powershell
& 'C:\Program Files\Python311\python.exe' .cursor/skills/extract-seesales/scripts/check-sharepoint-seesales.py --expect 9
& 'C:\Program Files\Python311\python.exe' .cursor/skills/extract-seesales/scripts/check-sharepoint-seesales.py --date 2026-09-14 --after 2026-09-14T07:00:00Z
```

A manual AniTa **account** export lands as `seesales-seesales-loganb_*.xls`
under `EHS KPI Data/Power Automate Updates/<YYYY-MM-DD>/`. A **service
group** export lands as `seesales-seegroup-loganb_*.xls`. Daily LIMS lab
files are `seesales-<DD-Mon-YY>-{nj|fla|co|la}_*.xls` (~06:56 UTC).
TX has no daily seesales file.

## By group (Navigate → service Group → Page Down to products)

Same SEE SALES session. Group count is **`1 of M`** on the form and
usually **4–12**, depending on location. The group list itself is
**not** the extract. For each group: **Page Down** (product breakout)
→ Export → **Page Up** (back to the group list) → Down to the next
group → repeat. Status on a good export is
`SEE GROUP PROD DONE`. Files are `seesales-seegroupprod-loganb_*.xls`.
The earlier `seesales-seegroup-loganb_*.xls` files (uniform ~799 bytes)
were group totals — wrong grain. Do not use those.

The AniTa email and `.xls` do **not** name location or group. Walk
order is the classifier. Pass `-Location` (and `-Groups` if this lab
is not the default 9). After Power Automate drops the raw
`seesales-seegroupprod-loganb_*` files, `stamp-seegroupprod.py`
renames them in time order to
`seesales-seegroupprod-{location}-{group}-{yyyy-MM}_{stamp}.xls`
(e.g. `seesales-seegroupprod-wheatridge-MET-2026-09_*.xls`).
Optional `-StampOutlook` saves each new mail, renames the attachment,
and sends it to `us.ehs.datadrop@sgs.com` — use that when Logan's
Inbox is actually receiving the host mail (this OST has been stale).

```powershell
# Month currently on the form. Filename uses the lab name (wheatridge, not co).
# Default groups = MET,GEN,MSS,MSU,GCS,SUB,MISC,GCU,FLD
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-groups.ps1 -Location wheatridge

# Another lab's group list
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-groups.ps1 -Location fla -Groups MET,GEN,MSS,GCS

# Any inclusive month range (same flags as the account script)
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-groups.ps1 -Location nj -Ytd
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-groups.ps1 -Location nj -From 2026-01 -To 2026-09
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-groups.ps1 -Location nj -ThisMonth

# Already inside the Service Group block (single month only)
powershell -File .cursor/skills/extract-seesales/scripts/export-seesales-groups.ps1 -Location nj -AlreadyOnGroups

# Stamp files that already landed unstamped (dry-run, then --apply)
& 'C:\Program Files\Python311\python.exe' .cursor/skills/extract-seesales/scripts/stamp-seegroupprod.py --location wheatridge --month 2026-09 --after 2026-09-14T08:53:00Z
```

What it does:

1. If you passed `-From`/`-To`/`-Ytd`/`-ThisMonth`, walk to `-To` first
   (Down older / Up newer from `-OnMonth`).
2. Navigate hotspot cell **1,2** (not 2,1 — that is Key Menu).
3. Type **`g`** (service Group). Status becomes a group list.
4. For each group: **Page Down** (VK 34) into
   `Product for Service Group` → Export cell **2,20** → wait for
   `SEE GROUP PROD DONE: Emailed to logan.bishop@sgs.com` →
   **Page Up** (VK 33) back to the group list → **Down** to the next
   group. Repeat through `-Count`.
5. More months: Navigate **1,2** → **`s`** (See sales) → Down to the
   next older month → open groups again. Do **not** press F11.
6. Confirm `seesales-seegroupprod-loganb_*.xls` with
   `check-sharepoint-seesales.py --kind group`. Expect
   `Count × months` files. Same `-Count` is used every month — if a
   month has fewer groups, extra Downs can wrap.

**Verified 2026-09-14 product breakout (SharePoint stamped names):**

| Lab | Host | Groups (walk order) | Files |
|---|---|---|---|
| Wheat Ridge | `use-idb057` | MET,GEN,MSS,MSU,GCS,SUB,MISC,GCU,FLD | 9, `08:54`–`08:59` UTC |
| Dayton | `use-idb059` | GEN,GCS,MSU,LCMS,MSS,MET,MSA,MISC,SUB,GCU | 10, `09:38`–`09:44` UTC |
| Orlando | `use-idb066` | LCMS,MSU,MSS,GCU,GCS,MET,GEN,MISC,SUB,FLD | 10; Export **2,20** emails when the session is healthy |
| Scott | `use-idb062` | MSS,MSU,GEN,MET,GCS,MISC,GCU,LCMS,SUB | 9, `14:43`–`14:48` UTC |
| Houston | `use-idb064` | MSA,MSU,MISC,GEN,GCA | 5, `14:23`–`14:26` UTC |

Each lab is a **separate AniTa host**. Do not change location on the
Wheat Ridge form. Open a new AniTa window (copy `seesales-login.wcf`,
set `HostName`, `TelnetOptionsInit=Yes`, `PromptForHost=No`,
`MaxInstance=8`) and log in again. Drive that window with
`anita-bg.exe … use-idb0XX` so keys do not hit another session.

| Lab | Host | IP | Filename slug | IFORMS company |
|---|---|---|---|---|
| Wheat Ridge | `use-idb057` | 10.149.0.5 | `wheatridge` | accuco |
| Dayton | `use-idb059` | 10.149.0.5 | `dayton` | accunj |
| Orlando | `use-idb066` | 10.149.0.26 | `orlando` | accufla |
| Scott | `use-idb062` | 10.149.0.28 | `scott` | accula |
| Houston | `use-idb064` | 10.149.0.24 | `houston` | accutx |

**F7** opens the service Group list on Orlando (Navigate **1,2** + `g`
misses on accufla). Other labs use **1,2** + `g`. Group count is
**`1 of M`**. accutx/accula Invoice hotkey is uppercase **`I`**.

Do not press F11 (company-wide; dumps the session). Do not
`SetWindowPos` at `Password:`. Do not ask Logan to type login.
`use-idb064` is Houston (accutx), not Scott.

**Verified 2026-09-14 (UTC+8 afternoon):** Jan–Sep 2026 = 9 Exports,
all DONE. SharePoint that day had **9 new** loganb files
(`2026-09-14 07:30:57`–`07:33:15 UTC`) plus 1 morning leftover
(`03:58:17 UTC`). That is the range the script is built to repeat.

If the user does not name a range, ask: **YTD** vs **full history** vs
an explicit `-From`/`-To`. Do not assume one September file finished
the job.

## Credentials

Read from process or User env (also gitignored repo `.env`). **Never**
write the password into this skill, chat logs you commit, or git.

| Var | Meaning |
|---|---|
| `ANITA_USER` | host login (e.g. `loganb`) |
| `ANITA_PASSWORD` | host password |
| `ANITA_HOST` | default `10.149.0.5` (`use-idb057`) |
| `DATADROP_TO` | `us.ehs.datadrop@sgs.com` |

If env is empty, load `.env` at the repo root. Do not prompt the user to
paste the password into chat.

## Do not

- `BM_CLICK` **Export**. It is paint on the AniTa canvas, not a Windows
  `Button`. Only **Select settings → OK** is a real button.
- Pixel-hunt Export on a window titled `Disconnected`.
- Replay a `.trc` that includes session close (playback will hang up).
- Commit `*.trc` files (they contain keystrokes).
- Treat repo `anita.wcf` (two-line stub) or `C:\sgs\Logan_Bishop` as
  SEE SALES source. The form lives on the host.
- Press **F11** (company-wide; dumps the session).
- Use `Esc+PgDn` to change month (that drills into accounts).
- Use SendKeys / SendInput / `SetForegroundWindow` (Logan uses the PC).
- Type the password at Linux `login:` or IFORMS `Enter user ID`.

## Get onto SEE SALES (once per session)

The range script does **not** log in. Do this first, then pass the
timeframe.

1. Copy `C:\Program Files (x86)\AniTa\anita.wcf` to
   `%TEMP%\seesales.wcf` (short path). Set `TelnetOptionsInit=Yes`,
   `HostName="use-idb057"`, `PromptForHost=No`. Do **not** start with
   `/c` (`anita_c.wcf` has `TelnetOptionsInit=No` → immediate
   Disconnected). Default install `anita.wcf` points at `accunj`.
2. Launch via `launch-anita-hidden.ps1` (no titlebar/menu/toolbar, no
   host-picker popup, `PromptForHost=No`, `BlankScreenTimeout=0`,
   **AutoLogin=No**). Do **not** leave `AutoUser2=""` — that sends a
   blank Linux password and the session desyncs. Type `loganb` at
   `login:`, password only at `Password:`. Never `SetForegroundWindow`.
   `anita-bg park` is **after IFORMS only** (bottom-right,
   `HWND_BOTTOM`). Moving the window at `login:` / `Password:`
   disconnects. True headless is not possible. Do **not** park fully
   off-screen, minimize, or use layered alpha=0/1. Title:
   `use-idb0XX (label)` **without** Disconnected. Headerless snaps
   look blank until inverted — the canvas is dark blue.
3. Drive the `AniTa` canvas with
   `.cursor/skills/extract-seesales/scripts/anita-bg.cs` (compiled by
   the range script to `%LOCALAPPDATA%\Temp\anita-capture\anita-bg.exe`).
   Commands: `status`, `snap`, `type`, `key`, `host`.
   `key` skips WM_CHAR for Backspace / PgUp-PgDn / Home / arrows /
   Insert / Delete (those VKs used to type `$!$-.%`). End still
   sends CHAR. Dates: `chars`, not `type` (hyphen is Insert).
4. **Hand path (walked 2026-09-18, Wheat Ridge).** Wait until
   `use-idb0XX login:` is painted (first snap is often blank). `chars`
   `loganb` + WM_CHAR Enter. Wait until `Password:` paints. `chars`
   password + Enter. If `REMOVE?`, `chars y` + Enter, then **wait** —
   do not type IFORMS yet. On `Please Log On`: `chars loganb`, confirm
   echo, WM_CHAR Enter, wait for `Enter password:`, then password.
   Never `key 13` (Linux hang-up). Never `type` (KEYDOWN). Never send
   user and password from the same snap. Two failed IFORMS logons hang
   up. AniTa `AutoHost1=ogin:` / `AutoHost2=ord:` + empty `AutoUser2`
   submitted a blank IFORMS password — those must stay `%null%`.
5. ACCULIMS Main Menu (olive box) → `chars i` (Invoice; uppercase `I`
   on Scott / Houston) → WM_CHAR Enter on **See Sales**.
6. Stay on the month list (`N of 210` or `1 of 1`). Cursor lands on Month.

Helpers: `anita-bg.exe host '\x1b}s2,20\r'` is Export.
`anita-bg.exe key 40` is Down (older month). `key 38` is Up.
Raw telnet can log in but Export needs AniTa (`ITERM_TERM=ansi-anita`);
otherwise IFORMS treats the mouse sequence as typed text
(`Field is protected`).

Play of a recording is fallback only
(`scripts/play-seesales.ps1`). A `.trc` that ends in CLOSE/EXIT
disconnects. Recut if you use this path: record Export once, **Special
→ stop recording** before hangup.

## Outlook / datadrop

SeeSales mail is **not** meant to stay in Inbox. File it to
`Inbox\SeeSales` (never Deleted Items). SharePoint is a **separate**
path: an Outlook rule must **forward** the same mail to
`us.ehs.datadrop@sgs.com`. Without that forward, files never appear
in Power Automate Updates. The agent can set the rule up —
`.cursor/skills/outlook-datadrop-rule/` (`ensure-datadrop-rule.ps1`).

https://sgs.sharepoint.com/sites/reg-nam-fin-teamsite/NAMFINBIUploads/LIMSBISynergy/EHS%20KPI%20Data/Forms/AllItems.aspx?id=%2Fsites%2Freg%2Dnam%2Dfin%2Dteamsite%2FNAMFINBIUploads%2FLIMSBISynergy%2FEHS%20KPI%20Data%2FPower%20Automate%20Updates&sortField=Modified&isAscending=false&viewid=a9210459%2D53f5%2D49c8%2Daeb9%2D25717d7b12d9

| Sender | Client rule |
|---|---|
| `seed2@use-idb0XX.amr.global.sgs.com` | Forward to datadrop. Optional Move to `Inbox\SeeSales`. Delete off. |
| `EHS.Accutest.LIMS` / `ehs.accutest.lims@sgs.com` | Same. |

Outlook COM has resolved Forward to the wrong mailbox before. The
ensure script adds `us.ehs.datadrop@sgs.com` and the checker prints
the recipient — if it is wrong, fix it in File → Manage Rules. Do
**not** re-enable Move to Deleted Items. Sweep leftovers with
`scripts/file-seesales-inbox.ps1`. Confirm files on SharePoint, not
Inbox.

## AniTa facts (needed to not break the session)

- Install: `C:\Program Files (x86)\AniTa\Anita.exe` (v8.1).
- Working host: **`use-idb057`** (DNS; `.env` `ANITA_HOST=10.149.0.5`).
- Window children: `AniTa` canvas, toolbar, status bar only.
- Display is 150% DPI. Window **765×659**. `SendMessage` to the canvas
  works without focus.
- Export is AniTa `MouseClick="<esc>}s%row%,%col%<cr>"` at cell
  **2,20**. Too far right of the painted Export hotspot is Main Menu
  and dumps the form.
- Clicking the telnet canvas on Linux `login:` can hang up the host.
- Do not commit `.trc`, temp `wcf`, or `anita-bg.exe`.

## Done when

- [ ] Every requested month showed Export DONE / emailed
- [ ] That day's `Power Automate Updates` folder has one new
      `seesales-seesales-loganb_*.xls` per month (PA lags a few minutes)
- [ ] Outlook rule is forward-to-datadrop, not delete
- [ ] No password or `.trc` staged for git
