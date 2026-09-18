"""Collect every US_ Expense Item from the open prompt (virtualized list).

Uses the list DOM + mouse wheel so React Virtualized actually renders rows.
Never presses Escape.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

SKILL_DIR = Path(__file__).resolve().parents[1]
OUT = SKILL_DIR / "expense-items.json"


def harvest_visible(page) -> list[str]:
    return page.evaluate(
        """() => Array.from(document.querySelectorAll('[data-automation-id="promptOption"]'))
            .map(e => e.innerText.replace(/\\s+/g, ' ').trim())
            .filter(t => t.startsWith('US_'))"""
    )


def main() -> int:
    pw = sync_playwright().start()
    try:
        browser = pw.chromium.connect_over_cdp("http://127.0.0.1:9222")
        page = next(p for p in browser.contexts[0].pages if "myworkday" in p.url)
        li = page.locator("li").filter(
            has=page.locator('[data-automation-id="formLabel"]:text-is("Expense Item")')
        )
        li.locator('[data-automation-id="promptIcon"]').first.click()
        page.wait_for_timeout(700)
        alpha = page.get_by_text("By Alphabetical Order", exact=True)
        if alpha.count():
            alpha.first.click()
            page.wait_for_timeout(700)
        box = page.locator('[data-automation-id="activeListContainer"]')
        box.hover()
        seen: list[str] = []
        last_top = -1
        for _ in range(120):
            for name in harvest_visible(page):
                if name not in seen:
                    seen.append(name)
            page.mouse.wheel(0, 500)
            page.wait_for_timeout(70)
            st = page.evaluate(
                """() => {
                  const l = document.querySelector('[data-automation-id="activeListContainer"]');
                  return l ? [l.scrollTop, l.scrollHeight, l.clientHeight] : [0,0,0];
                }"""
            )
            if st[0] == last_top:
                break
            last_top = st[0]
            if st[0] + st[2] >= st[1] - 5:
                for name in harvest_visible(page):
                    if name not in seen:
                        seen.append(name)
                break
        pick = page.locator('[data-automation-id="promptOption"]').filter(
            has_text="US_IT SUPPLIES"
        )
        if pick.count():
            pick.first.click()
        payload = {
            "dumped_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "timezone": "UTC",
            "count": len(seen),
            "items": seen,
        }
        OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"wrote {OUT} ({len(seen)} items)")
        return 0
    finally:
        pw.stop()


if __name__ == "__main__":
    sys.exit(main())
