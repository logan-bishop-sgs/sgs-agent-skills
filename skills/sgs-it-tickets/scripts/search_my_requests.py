"""List ServiceNow requests from My Tickets (open + closed) via Edge CDP 9223."""

from __future__ import annotations

import json
import re
import sys

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"


def scrape_ticket_cards(page) -> list[dict]:
    return page.evaluate(
        """() => {
          const cards = [...document.querySelectorAll('[class*="ticket"], .sc-card, .request-card, li, .panel')];
          const out = [];
          const body = document.body.innerText || '';
          const ritmBlocks = body.split(/(?=RITM\\d+)/i);
          for (const block of ritmBlocks.slice(0, 80)) {
            const m = block.match(/^(RITM\\d+)/i);
            if (!m) continue;
            const lines = block.split('\\n').map(l => l.trim()).filter(Boolean);
            out.push({ ritm: m[1], lines: lines.slice(0, 8) });
          }
          return out;
        }"""
    )


def main() -> int:
    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(CDP)
    page = browser.contexts[0].pages[0] if browser.contexts[0].pages else browser.contexts[0].new_page()
    if "login.microsoftonline.com" in page.url:
        print("NEED_LOGIN", file=sys.stderr)
        pw.stop()
        return 20

    results: list[dict] = []
    for view in ("Open", "Closed"):
        page.goto("https://sgs.service-now.com/sp?id=requests", wait_until="load", timeout=90_000)
        page.wait_for_timeout(4000)
        # Click Closed tab if present
        closed_tab = page.locator("text=Closed").first
        if view == "Closed" and closed_tab.count():
            closed_tab.click()
            page.wait_for_timeout(5000)
        body = page.inner_text("body")
        azure_hits = []
        for block in re.split(r"(?=RITM\d+)", body, flags=re.I):
            if not re.search(r"RITM\d+", block, re.I):
                continue
            if re.search(r"Azure|genailab|TV.REPORT|US-EHS|Postgres|Key Vault|Access Request|Contributor|App Service", block, re.I):
                ritm = re.search(r"RITM\d+", block, re.I)
                azure_hits.append(
                    {
                        "view": view,
                        "ritm": ritm.group(0) if ritm else "",
                        "text": " | ".join(ln.strip() for ln in block.splitlines() if ln.strip())[:400],
                    }
                )
        results.extend(azure_hits[:25])

    print(json.dumps(results, indent=2))
    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
