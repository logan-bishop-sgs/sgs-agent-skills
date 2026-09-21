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

> Last verified: 2026-09-22

## Left off 2026-09-21 (read this first)

**Proven today**

- **Login** (hidden window): **username, password, password** — Linux
  `loganb` + Enter, Linux password + Enter, then IFORMS **password only**
  + Enter (User ID usually prefilled; do not retype `loganb` on blue IFORMS).
  Same secret in `.env` as `ANITA_PASSWORD` / `ANITA_IFORMS_PASSWORD`. Fallback
  user+password if password-only does not reach menu. `y` if `REMOVE?`, then
  Invoice + See Sales.
  **Login stability (default):** one AniTa at a time — launch, log in, close,
  next lab. `scripts/test-seesales-login.ps1 -Passes 2 -Lab all` (10 attempts,
  no export). **Five on SEE SALES at once (serial logins, windows stay open):**
  `test-seesales-login.ps1 -KeepAllWindowsOpen -Passes 1 -Lab all`. Optional
  stress test only:
  `test-seesales-login-parallel.ps1` (five windows; idle `login:` hosts often
  disconnect while waiting — prefer serial for a green gate). Do not type into
  five canvases at once — concurrent WM_CHAR drops telnet.
  Never `key 13` at Linux (hangs up). Never `AutoUser2=""` (blank
  Linux password). `AutoLogin=No`, AutoHost `ogin:`/`ord:` `%null%`.
  Dayton and Wheat Ridge both reached SEE SALES this way.
- **Down-arrow** (VK 40) walks older months even when the form opens
  `1 of 1`. Wheat Ridge went Sep 2026 → Feb 2025 (`20 of 20`).
- **F7** opens service Group. **Page Down** opens
  `Product for Service Group`.

**Proven 2026-09-21 (Wheat Ridge one group)**

- **MET / Sep 2026 product export emailed** after Navigate **1,2** → **`s`**
  (back to month list if Account View was set) → **1,2** → **`g`** → Page Down
  → **`host '\x1b}s2,20\r'`**. Banner:
  `SEEGROUPPROD DONE: Emailed to logan.bishop@sgs.com`.
  Stamped + datadrop:
  `seesales-seegroupprod-wheatridge-MET-2026-09_*.xls`.
- **`export-seesales-groups.ps1`:** do not trust heuristic `KEYS=groups` on the
  main menu (false positive). Open groups with **Navigate+g first**; reset
  account drill-down with **Navigate+s** when OCR/`accountview` says so.
- **PowerShell 5.1:** UTF-8 **em dash inside double-quoted** strings breaks
  parse (use ASCII `-` or single quotes). **`read-anita-screen.py`** tags
  `done` without tesseract when the DONE banner is on screen.

**Still open**

- **Fast second group (same session):** stay on `use-idb057`, Navigate **s** → **g**,
  Down to the target code, then
  `export-seesales-groups.ps1 -AlreadyOnGroups -Groups GEN -Count 1 -ThisMonth
  -SkipSharePoint -StampOutlook` (~45s). Do not trust a leftover DONE banner —
  stamp with `-After` run start; script clears stale DONE before Export as of
  2026-09-21.
- **Jan–Feb 2025 group-product backfill** shipped 2026-09-22 (Houston, Orlando, Scott, Wheat Ridge → datadrop). Confirm SharePoint ingest before treating DB as complete.
- Two AniTa windows may still be open (`use-idb057` Wheat Ridge with
  chrome, `use-idb059` Dayton hidden). Close extras before a new run.

## Login result lines

`login-seesales.ps1` always prints one of:

- `LOGIN_STATUS=success host=use-idb0XX label=houston`
- `LOGIN_STATUS=fail host=use-idb0XX label=houston reason=…`

Stability runs also emit `LOGIN_RESULT status=success|fail lab=… pass=…` and
write `%TEMP%\seesales-login-summary.json`. Grep logs for `LOGIN_STATUS=` or
`LOGIN_RESULT` — do not infer from `LOGIN_OK` alone.

**LIMS stream (second login / IFORMS):** each snap logs
`LIMS_SNAP … LIMS_DIAG=… LIMS_OCR="…"` (OCR empty if pytesseract not installed),
plus `LIMS_PHASE=` (`linux-user`, `linux-password`, `iforms-user`,
`iforms-password`, `acculims-menu-invoice`, `seesales-month-list`) and
`LIMS_CONN state=connected|disconnected`. ORA-01017 on IFORMS means Oracle
rejected `loganb`/password for that lab’s acculims DB — fix
`ANITA_IFORMS_PASSWORD` in `.env`, not Linux `ANITA_PASSWORD`.

**Audit screenshots:** every classifier snap is copied under
`%TEMP%\seesales-login-audit\<run-ts>\<lab>-passN\` as numbered PNGs
(`001-<snap>-canvas-inv.png` is the readable LIMS canvas; full window in
`*-inv.png` / `*.png`). Logs emit `LOGIN_AUDIT_DIR=` / `LOGIN_AUDIT_RUN=` and
`LIMS_AUDIT seq=… view=<full path>` so you can open the same frame the
classifier saw. `manifest.jsonl` in each attempt folder lists seq, time, and paths.
Compare `view=` to the screen when logs disagree — classifier reads **canvas**
pixels, not the title bar. **Do not trust `LOGIN_STATUS=success` from runs before
2026-09-21 PM fix:** `-match 'CLASS=form'` falsely matched `CLASS=text`, so IFORMS
was skipped and success was declared on ORA-01017 screens (see
`*-seesales-canvas-inv.png` vs log).

Capture a full run (one log file per run — do not tee two shells to the same path):

```powershell
$log = Join-Path $env:TEMP ("seesales-login-stability-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
powershell -NoProfile -File .cursor/skills/extract-seesales/scripts/test-seesales-login.ps1 -Passes 2 -Lab all *>&1 | Tee-Object -FilePath $log
Select-String -Path $log -Pattern 'LIMS_|LOGIN_RESULT|LOGIN_STATUS|ORA|invaliduser'
```

## When it breaks (look, then pick up)

Run hands-off. Do **not** watch every key. The script now **stops**
instead of walking a dead session:

### VPN / network (cannot reach lab telnet)

**Not** the same as idle **Disconnected** after you were on `login:`.
VPN-off or no route to `10.149.0.x`:

- AniTa title stuck on **`Connecting ... (label)`** for 60–90s, then often
  **`Disconnected (label)`** before Linux `login:` ever paints.
- Log: repeated `LIMS_WAIT try=1 title=  use-idb0XX : Connecting ...`,
  then `LIMS_WARN connect try N failed title=...Disconnected`,
  then throw **`AniTa did not connect (use-idb0XX) after 2 launches. VPN ok
  if manual AniTa works; check host use-idb0XX.`**
- Quick check (4s): telnet to `10.149.0.5` port **23** blocked or times out;
  `check-anita-health.ps1` shows **`telnet23=False`** for that lab IP.
- With VPN on, title becomes **`use-idb057 (wheatridge)`** (no Connecting /
  Disconnected) and log shows **`LIMS_CONN state=connected`** before Linux user.

### Linux stale session (`REMOVE?`)

After Linux password, the host may show **`SESSIONS CURRENTLY EXIST UNDER
USER: loganb`** and **`REMOVE?`** (leftover telnet from an earlier AniTa or
automation run). This is **normal**, not VPN and not IFORMS.

- **Action:** type **`y`** + Enter (automation: `login-seesales.ps1` when
  classifier `KEYS=remove` or OCR mentions `REMOVE?` / `SESSIONS CURRENTLY`).
- **Then** wait for blue IFORMS or ACCULIMS — do not send Enter again on the
  REMOVE line (blank IFORMS password bug).
- If IFORMS shows **logon denied** immediately after a bad run: close AniTa,
  wait 30s, one clean retry (Oracle may need the stale session cleared with
  `y` first).

### Session / login mistakes

- login / invalid password painted
- **COMPANY WIDE** (F11)
- title **Disconnected** (after you were connected — idle timeout, F11, etc.)
- form stays on the same month after Down-arrow (date did not change)
- Export wait with no `SEE GROUP PROD DONE` and no new
  `seesales-seegroupprod-loganb.xls` mail

Never type Invoice, `g`, or Export on **Please Log On**. User ID is
`loganb` only; password only on the password line. Two failed IFORMS
logons hang up. The runner **revives** a failed lab: close that host,
log in again. **Retry tiers:** (1) **fail** → **close that host's AniTa**,
relogin, rerun export (heuristics only); (2) **fail again** →
**`ANITA_LLM_ESCALATE=1`**, Azure vision (max **3** calls), then Logan if still
stuck. **`-Retries`** (default **3**) is a failure **budget**; **success
resets** it. **`-MaxReviveRounds`** (default 48) caps loops. A `1 of 1` form
is only the starting view — **Down-arrow** loads older months
(count grows `2 of 2`, `3 of 3`, …). Then **you** look at
the last snap in `%LOCALAPPDATA%\Temp\anita-capture\<label>\` only if
retries are exhausted. Relogin, **no F11**. Do not keep Down-arrowing
on a dead session. Logan's manual Wheat Ridge Export (2026-09-18
13:58 GMT+8) landed a real product file (`SEEGROUPPROD`, SEP-2026,
7.8 KB) in Inbox and SharePoint. F11 dumped the session.

## How the agent decides (rules vs LLM vs ask Logan)

Automation is **mostly a fixed state machine** (`login-seesales.ps1`,
`export-seesales-groups.ps1`). Pixels are classified by
`read-anita-screen.py` (heuristics + optional OCR). Do **not** replace that
with an LLM for every keystroke — too slow, too flaky, and it might suggest
forbidden keys (F11, Backspace on `login:`).

**Tier 1 — Script + classifier (default):** Known phases with allowed actions
only (Linux user/password, `y` on REMOVE?, IFORMS password-only, Invoice,
See Sales, F7 / Page Down / Export cell 2,20). If `LOGIN_STATUS=success` or
export ledger says DONE, stop. No interview.

**Tier 2 — Agent reads logs + audit PNG:** On `LOGIN_STATUS=fail` or export
stall, open `LIMS_AUDIT view=` / `%TEMP%\seesales-login-audit\` and compare
to the tables in this skill (VPN vs REMOVE? vs ORA-01017 vs Disconnected).
Fix env or relaunch; use the runner retry budget. Heuristics first.

**Tier 3 — Azure OpenAI (second failure only):** Runner sets
**`ANITA_LLM_ESCALATE=1`** on **`RETRY_TIER=2_azure-openai`** (after tier 1
**shutdown AniTa + relogin**). **`ANITA_LLM_ASSIST=0`** disables all vision.
Cap **3** vision calls per escalation episode (v1: cost-aware). Allowlists in
**`anita-llm-assist.py`**. Logs **`LIMS_LLM`**. **`escalate_human`** or cap
hit → tier 4.

**Tier 4 — Ask Logan (short):** VPN off after telnet check, wrong lab/month
scope, repeated IFORMS deny after clean retry + confirmed `.env`, or LLM
**`escalate_human`** / budget exhausted. Never ask Logan to paste passwords
in chat.

Interviewing Logan on every `REMOVE?` is wrong — that prompt is documented;
automation sends **`y`**.

## Hands-off (lab + months, no agent watching)

One script logs in, opens SEE SALES, walks groups, emails, and stamps
SharePoint. Run on this PC with VPN + AniTa. It does not steal focus.
**Multi-window (four labs):** `-KeepAllWindowsOpen` on
`run-seesales-extract.ps1` — **launch and finish login on one host before
opening the next**. Idle `Connecting…` sessions drop quickly; after Linux +
IFORMS + SEE SALES they stay up for hours. WM_CHAR stays serial (one canvas at
a time). Exports run per host by window title without killing siblings. Do not
rely on `-ParallelLaunch` (ignored; it used to open every host first). Before each
new host login, close that host's stale tabs (especially **Disconnected** from
an earlier run); duplicate **066** windows make automation attach to the wrong
PID. On export errors, do **not** re-login a host that is still
connected — that looked like AniTa "randomly closing" mid-run.

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

Each lab is a **separate AniTa host** (different telnet target — not a
local TCP port you pick). Every launch is its own **`Anita.exe` PID** and
window title `use-idb0XX`. Drive that window with
`anita-bg.exe … use-idb0XX` so WM_CHAR does not hit another canvas.

**Multi-window isolation:** per-lab capture dirs avoid snap collisions:

- `%LOCALAPPDATA%\Temp\anita-capture\<label>\` — PNG snaps (`wheatridge`, …).
  Set when running `login-seesales.ps1 -Label <slug>`.
- **`ANITA_CAPTURE_LABEL=<slug>`** — `anita-bg`, `read-anita-screen.py`,
  `invert-snap.py` use that subfolder.
- Root holds **`anita-bg.exe`**, `seesales-login.wcf`, **`<label>.wcf`**.
- **`anita-sessions.jsonl`** logs `{pid, host, label, wcf, at}` per launch;
  `scripts/list-anita-sessions.ps1` lists live PIDs + manifest.
  **`scripts/check-anita-health.ps1`** — telnet reachability, title
  (`Disconnected` vs connected), LIMS classifier per lab; add
  `-ReconnectDisconnected` to kill stale windows and relaunch 057/059 only.
- **Why it looked like one window:** (1) **Only one `Anita.exe` was alive**
  — parallel runs kill all at pass end; idle `login:` hosts often disconnect
  and exit. Check `list-anita-sessions.ps1` / Task Manager, not just the
  desktop. (2) **Win11 one taskbar icon** for all AniTa windows — hover the
  icon or **Alt+Tab** for each host. (3) Old tiling used full AniTa width
  (~765px × 3 &gt; 1920px) so extra windows were **off-screen**; use
  `retile-anita-windows.ps1` after launch. Parallel test uses **`-ShowWindow`**
  and **`KeepAliveSeconds=45`** in the generated wcf.

Do not change location on the Wheat Ridge form. Use
`launch-anita-hidden.ps1 -HostName … -Label …` for each extra window.

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
| `ANITA_PASSWORD` | Linux `login:` password |
| `ANITA_IFORMS_PASSWORD` | optional; acculims IFORMS `Enter password` (defaults to `ANITA_PASSWORD`) |
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
- Press **Backspace** on the AniTa canvas at Linux `login:` (or after a
  typo). AniTa injects telnet escape junk like `^[]s4,6` / `^[]s1,14`
  (Navigate **cell clicks** on IFORMS User ID — close all AniTa, one host
  only; never run export/parallel while login is in progress).
  into the prompt — it is not a normal erase. Close that AniTa window
  and start a clean login; `anita-bg` refuses `key 8` so automation
  never sends it.

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
   `key` **refuses Backspace** (vk 8). Other keys skip WM_CHAR for
   PgUp-PgDn / Home / arrows / Insert / Delete (those VKs used to type
   `$!$-.%`). End still sends CHAR. Dates: `chars`, not `type` (hyphen
   is Insert).
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
