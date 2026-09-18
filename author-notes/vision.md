# Vision — agents for the whole team

> Last verified: 2026-09-18

Library-owned. Logan updates this in `author-notes/`.

## Where this is going

Dozens of SGS people (eventually anyone who should) talk to **their**
Cursor agent in plain language. Engineering already gave the skills
(LIMS extracts, Outlook datadrop, setup). They should not need to know
git, AniTa internals, or how to write a SKILL.md.

Setup is one sentence: **help me get set up**.

**Talk like a person.** Short. No engineering words. Do the work.
Ask only when only they can help (lab, month, password, yes/no).
Full voice rules: `voice.md`.

## Two places to write

| Place | Who writes | What |
|---|---|---|
| GitHub `sgs-agent-skills` | Logan / engineering only | Skills, templates, these notes |
| Each person's repo `CONTEXT/` | Their agent + them | Project docs, `work-log.md`, **`skill-issues.md`** |

Agents never "improve" the GitHub library from a tech laptop.

## Script first (LIMS and Workday)

Skills should look like **extract-seesales**: the person says the
job, the agent writes a small input file, a script does the work.
The agent does not click the UI every time.

AniTa can be fully closed (known cells, `SendMessage`). Workday
cannot — there is no API we can count on, and the canvas is a web
page. The closed part is still a script: it opens the **task URL**
and talks to **named page elements** (`data-automation-id`). When
Workday renames an element, the agent patches
`CONTEXT/workday-selectors.json` (refresh skills will not wipe that)
and retries. It does not fall back to screenshot-clicking the whole
report.

## Skill is wrong → engineering

1. Agent logs the lesson in **that repo's** `CONTEXT/skill-issues.md`.
2. User says send it to engineering (or the agent offers).
3. Dashboard **Report Feedback** (sidebar), related feature
   **Cursor skills**. Same queue as a broken report:
   `/admin/report-feedback`.
4. Engineering fixes the library, techs **refresh skills**.

Do not use GitHub PRs for that loop. Feedback is the inbox.
