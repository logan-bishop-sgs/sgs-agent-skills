---
name: setup-agent
description: >-
  Sets up a Cursor agent workspace from sgs-agent-skills: copies LIMS
  and GitHub skills, writes a personalized .cursor/rules/workspace.mdc,
  CONTEXT docs, .gitignore, .env.example / .env, and SGS/team author-notes.
  Full (IT) track can install Python 3.13, gh, and pip requirements.
  Use when the user says help me get set up, set up cursor, set up the
  agent, create cursor rules, CONTEXT folder, onboard this repo,
  refresh skills, or install Python / .env.
---

# Setup a Cursor agent workspace

Turn the user's **working repo** into a Logan-style Cursor workspace,
filled in with **their** name and **this** repo — not a dump of
`ehscloudreporting`.

Library layout: `skills/`, `templates/`, `author-notes/`, `bootstrap/`.

Also read [full-install.md](full-install.md) on the IT track.

## Do not

- Copy `ehs_dashboard/CONTEXT/` into a different repo.
- Create more than **one** `.mdc` — only `.cursor/rules/workspace.mdc`.
- Put `.cursor/rules/` inside an app package.
- Commit `.env`, passwords, tokens, `*.trc`, or `anita.wcf`.
- Paste passwords into chat. Leave `ANITA_PASSWORD` blank in `.env`.
- Run this against `sgs-agent-skills` itself unless **Logan** asked to
  change the library. Techs' working repo is never this GitHub repo.
- Fight Group Policy on a locked-down tech laptop. File-setup still
  runs; installs become a leftover list.
- Let a tech agent "improve" `author-notes/`, `skills/`, or `templates/`
  on GitHub. They write `CONTEXT/` + `work-log.md` in **their** repo.

## Resolve paths

1. **Library root** — folder with `skills/`, `templates/`,
   `author-notes/`. Walk up from this `SKILL.md`. If this skill was
   copied into `.cursor/skills/setup-agent/` and those folders are
   missing, clone
   `https://github.com/logan-bishop-sgs/sgs-agent-skills` to a temp
   dir and use that.
2. **Target root** — the working git repo.
   - If the current workspace **is** `sgs-agent-skills`, ask for the
     working-repo path.
   - Otherwise the current workspace is the target.
   - Confirm `Test-Path` before writing.

## Interview

These people are not engineers. **Ask for name and work email only.**
Infer everything else (role, folder layout, LIMS skills = yes for NAM
EHS). Do not ask about app folders, Python, git, or "full vs light."

- Default **light** (files only) unless they are Logan / IT or they
  said to install programs.
- Never ask them to paste a LIMS password into chat. If login is
  needed later, say: "You'll type your LIMS password in a small
  settings file I'll open — I won't look."

Refresh-only ("refresh skills"): recopy **skills** +
**`.cursor/library-notes/`**. Do **not** wipe their CONTEXT or work log.

When you speak to them during setup, follow `author-notes/voice.md`
(short, plain). Example finish:

> You're set. Open a new chat here and say what you need, like
> "pull this month's SEE SALES for Houston."

## Explore the target

Read it. Do not invent folders.

- `git rev-parse --show-toplevel`, remotes, top-level listing
- Existing `.cursor/`, `CONTEXT/`, `admin/`, `.gitignore`, `.env*`
- `requirements.txt` / `pyproject.toml`

If `workspace.mdc` or `CONTEXT/INDEX.md` already exists, show what you
would change and **ask before overwrite**. Merge Developer Context.

## 1. Install skills

Copy from `<library>/skills/` → `<target>/.cursor/skills/<name>/`:

- `setup-agent`
- `github-collab`
- `report-skill-issue`
- `reimbursements`
- `extract-seesales`, `extract-tat-by-group`, `outlook-datadrop-rule`
  (skip LIMS only if they said no)
- `environmental-data-analysis`
- `sgs-it-tickets`

Overwrite copies that came from this library. Keep extra skills already
in the target.

## 2. Library notes (read-only) vs their CONTEXT

Copy (overwrite; Logan-owned) from `<library>/author-notes/` →
`<target>/.cursor/library-notes/`:

- `sgs-and-team.md`
- `github.md`
- `machine-setup.md`
- `vision.md`
- `voice.md`

Do not copy `author-notes/README.md`. Do **not** put these files in
`CONTEXT/` — that folder is the user's.

**Their context dir:** `<target>/<app>/CONTEXT/` if there is a primary
app folder, else `<target>/CONTEXT/`. Create it even if empty of
library notes. This is where agents keep project docs, `work-log.md`, and `skill-issues.md`.

## 3. .gitignore

If the target has no `.gitignore`, copy `templates/gitignore`.

If it has one, **merge** — ensure these patterns exist, do not delete
theirs:

```
.env
.env.*
!.env.example
venv/
.venv/
__pycache__/
*.trc
anita.wcf
```

## 4. .env.example and .env

Contract file is `templates/env.example` (`SGS_EMAIL`, `SGS_NAME`,
`ANITA_*`, plus commented future keys).

- If the target **has no** `.env.example`, copy the template to
  `<target>/.env.example`.
- If it **has** one, append any missing keys (`SGS_EMAIL`, `SGS_NAME`,
  `SGS_EMAIL`, `SGS_NAME`, `ANITA_USER`, `ANITA_PASSWORD`, `ANITA_HOST`,
  `EHS_DASHBOARD_BASE_URL`) with comments. Do not
  strip dashboard keys.
- If `<target>/.env` is missing, copy `.env.example` → `.env`.
- Pre-fill **non-secret** identity from the interview / `git config`:
  `SGS_EMAIL`, `SGS_NAME`. Pre-fill `ANITA_USER` only if they gave it.
- Never fill `ANITA_PASSWORD` or any Microsoft password. Tell them to
  edit `.env` locally.
- Confirm `.env` is gitignored (`git check-ignore -v .env`).

## 5. Rules and CONTEXT templates

Read `<library>/templates/` and substitute placeholders. Today's date
is the user_info date (`YYYY-MM-DD`).

| Template | Write to |
|---|---|
| `workspace.mdc` | `<target>/.cursor/rules/workspace.mdc` |
| `CONTEXT-INDEX.md` | `<context-dir>/INDEX.md` |
| `CONTEXT-project-overview.md` | `<context-dir>/project-overview.md` |
| `CONTEXT-conventions.md` | `<context-dir>/conventions.md` |
| `CONTEXT-work-log.md` | `<context-dir>/work-log.md` (create if missing; **never overwrite** an existing log) |
| `CONTEXT-skill-issues.md` | `<context-dir>/skill-issues.md` (create if missing; **never overwrite**) |
| `admin-plans-README.md` | `<target>/admin/plans/README.md` |
| `admin-CONTEXT-subagents.md` | `<target>/admin/CONTEXT/subagents.md` |

Placeholders: `{{TODAY}}` `{{NAME}}` `{{ROLE}}` `{{TEAM}}`
`{{EXPERTISE}}` `{{BUSINESS}}` `{{WORKSPACE_TITLE}}` `{{REPO_ONE_LINER}}`
`{{PRIMARY_APP}}` `{{CONTEXT_DIR}}` `{{CONTEXT_INDEX_PATH}}`
`{{REPO_LAYOUT}}` (from **this** explore) `{{DIAGNOSIS_LINE}}`
`{{TASK_ROWS}}` `{{WHERE_NEW_WORK_GOES}}`.

Replace every `{{...}}`. INDEX already has SGS/GitHub rows; still add
LIMS rows when those skills are installed.

Create `admin/plans/active/` and `completed/` (`.gitkeep` if tracked).
If `admin/` is gitignored, write anyway and say local-only.

## 6. Machine install (full track only)

Read [full-install.md](full-install.md). Run:

```powershell
powershell -File "<library>/bootstrap/install-machine.ps1" -TargetRoot "<target>" -LibraryRoot "<library>"
```

Recommend Python **3.13**. 3.11+ is acceptable if 3.13 cannot install.
If winget hangs on UAC, stop, keep files, list leftovers.

Light track: skip this script. If something could not install, tell
them in one sentence to ping Logan/IT. Do not list package names.

## Finish

1. One rule file only: `.cursor/rules/workspace.mdc`.
2. No leftover `{{PLACEHOLDER}}`.
3. `.env` exists, is ignored, has email/name if known, no password you typed.
4. Say to them, and nothing more technical:

> You're set. Open a new chat in this folder and tell it what you
> need in normal words.

If LIMS will be used and password is empty:

> One extra step: I'll open a settings file. Type your LIMS password
> on the password line. Don't paste it in this chat.

Do not mention GitHub, CONTEXT, or leftover pip lists.

Do not commit unless they ask. Never commit the library from a tech's
setup session.
