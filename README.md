# SGS Agent Skills

Shared Cursor helpers for SGS NAM EHS. Built for **people who are not engineers**: they say what they need in normal words; the agent does the rest.

Repo: https://github.com/logan-bishop-sgs/sgs-agent-skills

Public so any SGS colleague with the link can open it. **Do not commit secrets.**

## Help me get set up

Clone/open this repo in Cursor and say:

> help me get set up

Give the path to **your working repo** (dashboard, V3, a new project).

- **Full track** (Logan / IT): Python **3.13**, GitHub CLI, pip, `.env`, `.gitignore`, skills, personalized Cursor rules, CONTEXT, SGS/team notes.
- **Light track** (data tech laptop): files only. Installs become a list for IT if the machine is locked down.

Then start a **new chat** in the working repo.

Later: **refresh skills** recopies skills + `.cursor/library-notes/` only. It does not overwrite their `CONTEXT/` or `work-log.md`.

Techs write in **their working repo**. They do not update this GitHub library. Skill problems go to dashboard **Report Feedback** (related feature **Cursor skills**) via the `report-skill-issue` skill.

## Author notes (Logan)

Edit [`author-notes/`](author-notes/README.md) **in this repo**. Setup copies them to each project as `.cursor/library-notes/` (read-only). Each person also gets their own `CONTEXT/` (`work-log.md`, `skill-issues.md`) and `.env.example` / `.env` with `SGS_EMAIL` + LIMS keys.

## Skills

| Skill | When |
|---|---|
| `setup-agent` | "help me get set up", refresh skills, Python / `.env` |
| `report-skill-issue` | skill failed; send to engineering via dashboard Feedback |
| `github-collab` | comment on a PR (not this library) |
| `extract-seesales` | Accutest SEE SALES → SharePoint |
| `extract-tat-by-group` | Accutest TAT by service group |
| `outlook-datadrop-rule` | Outlook → `us.ehs.datadrop@sgs.com` |
| `reimbursements` | Workday expense **draft** via Edge URL + page elements (not Cursor’s window) |
| `sgs-it-tickets` | ServiceNow / IAM ticket drafts (Entra, Graph); dedicated Edge + fill script |

LIMS skills need AniTa, VPN, and `ANITA_PASSWORD` in `.env` or User env (never git). Workday expenses need Edge on this PC; username is `EXPENSE_USERNAME` or `SGS_EMAIL` (never git a password).

## Layout

```
author-notes/     # Logan only
bootstrap/
skills/
templates/        # gitignore, env.example, rules, CONTEXT starters
```
