# Machine setup (Python, .env, installs)

> Last verified: 2026-09-18

Library-owned. Two tracks: **full** (Logan / IT, can install software)
and **light** (data tech laptop, locked down).

## Recommend

- **Python 3.13** (`winget install Python.Python.3.13`, user scope when
  possible). 3.11+ is acceptable if 3.13 cannot install.
- Git (already on most SGS images).
- GitHub CLI (`gh`) for GitHub comments/PRs.
- A repo-root `.env` that is **gitignored**. Start from `.env.example`.

## Full track (IT)

`setup-agent` runs `bootstrap/install-machine.ps1` from this library:

1. Install Python 3.13 if missing (user-scope winget; no admin if it works).
2. Install GitHub CLI if missing.
3. `python -m pip install -r bootstrap/requirements.txt` (skill scripts).
4. If the **target repo** has `requirements.txt` or `pyproject.toml`,
   install those too (venv preferred when the repo already uses one).
5. Ensure `.gitignore` ignores `.env`, venv, `__pycache__`, `*.trc`,
   `anita.wcf`.
6. Ensure `.env.example` exists; create `.env` from it if missing.
   Pre-fill `SGS_EMAIL` and `SGS_NAME`. **Never write a real password.**
   Leave `ANITA_PASSWORD` empty. Microsoft / Entra password is SSO — not
   `.env`. Future keys stay commented in `.env.example` until a skill
   needs them.

If winget / MSI hits UAC and the user is not at the keyboard, stop the
install, keep the file setup, and list what IT still needs.

## Light track (tech)

Do the files (rules, CONTEXT, gitignore, `.env.example`, skills copy).
Do **not** fight Group Policy. Write a short leftover list:

- Python 3.13
- `gh`
- pip packages
- fill `.env`

## Logan PC — Agilent ChemStation

This Windows box has **MSD ChemStation E.02.02** at `C:\msdchem`
(offline Environmental Data Analysis / EnviroQuant). Map:
`skills/environmental-data-analysis/`. Do not treat it as a CLI.

## Future requirements

When a new skill needs a package, add it to
`bootstrap/requirements.txt` in **this** library and mention it in the
skill. Full setup installs that file every time, so future techs get it
on the next "help me get set up" / "refresh skills".
