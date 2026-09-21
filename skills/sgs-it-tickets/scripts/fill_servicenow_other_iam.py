"""Fill Other IAM request catalog form on open ServiceNow Edge tab. Does not Submit."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from fill_servicenow_entra import (
    NEED_LOGIN,
    need_login,
    page_from_cdp,
    set_input,
    set_watch_list,
)

CATALOG_URL = (
    "https://sgs.service-now.com/sp?id=sc_cat_item"
    "&sys_id=7dec6166477f8594a1a7efb2e36d43de"
)
SHORT_ID = "sp_formfield_var_short_description"
DESC_ID = "sp_formfield_u_description_of_the_request"
WATCH_ID = "sp_formfield_watch_list"


def parse_draft(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    fields: dict[str, str] = {}

    m = re.search(r"^Short Description:\r?\n(.+?)(?=\r?\n\r?\n)", text, re.MULTILINE)
    if m:
        fields["short_description"] = m.group(1).strip()

    desc_m = re.search(
        r"Description \(paste entire block below\):\r?\n---\r?\n(.+?)\r?\n---",
        text,
        re.DOTALL,
    )
    if desc_m:
        fields["description"] = desc_m.group(1).strip()

    wl_m = re.search(r"^Watch list:\r?\n(.+?)(?:\r?\n\r?\n|\Z)", text, re.MULTILINE | re.DOTALL)
    if wl_m:
        fields["watch_list"] = wl_m.group(1).strip()

    return fields


def ensure_other_iam(page) -> None:
    if "7dec6166477f8594a1a7efb2e36d43de" not in page.url:
        try:
            page.goto(CATALOG_URL, wait_until="load", timeout=90_000)
        except Exception:
            page.goto(CATALOG_URL, wait_until="domcontentloaded", timeout=90_000)
        page.wait_for_timeout(2500)
    if "Other IAM request" not in page.title():
        raise SystemExit(f"Wrong catalog page: {page.title()}. Expected Other IAM request.")


def set_textarea(page, field_id: str, value: str) -> None:
    loc = page.locator(f"#{field_id}")
    loc.wait_for(state="visible", timeout=30_000)
    loc.click()
    loc.fill("")
    loc.fill(value)
    page.evaluate(
        """(id) => {
          const el = document.getElementById(id);
          if (!el) return;
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }""",
        field_id,
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--draft", type=Path, required=True)
    ap.add_argument("--cdp", default="http://127.0.0.1:9223")
    args = ap.parse_args()

    draft = parse_draft(args.draft)
    if not draft.get("short_description") or not draft.get("description"):
        print("draft missing Short Description or Description block", file=sys.stderr)
        return 1

    pw, page = page_from_cdp(args.cdp)
    try:
        ensure_other_iam(page)
        if need_login(page):
            print("NEED_LOGIN")
            return NEED_LOGIN

        page.keyboard.press("Escape")
        page.wait_for_timeout(300)

        set_input(page, SHORT_ID, draft["short_description"])
        set_textarea(page, DESC_ID, draft["description"])

        if draft.get("watch_list"):
            set_watch_list(page, WATCH_ID, draft["watch_list"])

        print("Filled Other IAM: short description, description, watch list (if any). Review and Submit in Edge.")
        return 0
    finally:
        pw.stop()


if __name__ == "__main__":
    raise SystemExit(main())
