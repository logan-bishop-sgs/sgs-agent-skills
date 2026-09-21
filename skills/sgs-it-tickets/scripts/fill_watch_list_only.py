"""Add Watch List users only (CDP 9223). Usage: python fill_watch_list_only.py --draft path.txt"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# reuse helpers from sibling module
from fill_servicenow_entra import (  # noqa: E402
    NEED_LOGIN,
    ensure_entra_catalog,
    need_login,
    page_from_cdp,
    parse_draft,
    set_watch_list,
)
from playwright.sync_api import sync_playwright

import json

SELECTORS = Path(__file__).resolve().parents[1] / "selectors.json"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--draft", type=Path, required=True)
    ap.add_argument("--cdp", default="http://127.0.0.1:9223")
    args = ap.parse_args()
    draft = parse_draft(args.draft)
    if not draft.get("watch_list"):
        print("no Watch list in draft", file=sys.stderr)
        return 1
    sel = json.loads(SELECTORS.read_text(encoding="utf-8"))
    pw, page = page_from_cdp(args.cdp)
    try:
        ensure_entra_catalog(page, sel["catalog_url"])
        if need_login(page):
            print("NEED_LOGIN")
            return NEED_LOGIN
        ok = set_watch_list(page, sel["watch_list"]["id"], draft["watch_list"])
        return 0 if ok else 2
    finally:
        pw.stop()


if __name__ == "__main__":
    raise SystemExit(main())
