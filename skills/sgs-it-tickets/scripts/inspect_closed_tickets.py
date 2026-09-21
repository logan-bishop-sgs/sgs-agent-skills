"""My Tickets → Closed: click ticket cards and read Application fields."""

from __future__ import annotations

import json
import re
import sys

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"


def goto_closed(page) -> None:
    page.goto("https://sgs.service-now.com/sp?id=requests", wait_until="load", timeout=90_000)
    page.wait_for_timeout(4000)
    page.locator("select").filter(has_text="Open").first.select_option(value="close")
    page.wait_for_timeout(6000)


def click_ticket_containing(page, ritm: str) -> bool:
    # Cards are often clickable rows/divs; RITM text may not be its own <a>.
    clicked = page.evaluate(
        """(ritm) => {
          const all = [...document.querySelectorAll('*')];
          for (const el of all) {
            const t = el.innerText || '';
            if (!t.includes(ritm) || t.length > 800) continue;
            const clickable = el.closest('a, [role="button"], .card, .ticket, li, tr') || el;
            if (clickable && clickable.innerText && clickable.innerText.includes(ritm)) {
              clickable.click();
              return true;
            }
          }
          return false;
        }""",
        ritm,
    )
    if clicked:
        page.wait_for_timeout(8000)
    return bool(clicked)


def grep_context(text: str) -> list[str]:
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    out: list[str] = []
    for i, ln in enumerate(lines):
        if re.search(
            r"^(Application|Business Service|Service Offering|Environment|Roles|Type of action|Catalog item|Short description)\b",
            ln,
            re.I,
        ):
            out.append(ln)
            for j in range(1, 4):
                if i + j < len(lines):
                    nxt = lines[i + j]
                    if nxt and len(nxt) < 220:
                        out.append("  " + nxt)
    return out[:24]


def main() -> int:
    pw = sync_playwright().start()
    page = [p for p in pw.chromium.connect_over_cdp(CDP).contexts[0].pages if "service-now.com" in p.url][0]
    if "login.microsoftonline.com" in page.url:
        print("NEED_LOGIN", file=sys.stderr)
        pw.stop()
        return 20

    goto_closed(page)
    targets = ["RITM0981150", "RITM0943812", "RITM0929379"]
    for ritm in targets:
        goto_closed(page)
        ok = click_ticket_containing(page, ritm)
        print(f"\n=== {ritm} clicked={ok} url={page.url[:90]} ===")
        text = page.inner_text("body")
        ctx = grep_context(text)
        if ctx:
            print("\n".join(ctx))
        else:
            for ln in text.splitlines():
                if re.search(r"Application|Business Service|Environment|Roles|Azure Web|Function", ln, re.I):
                    s = ln.strip()
                    if s and "Skip to" not in s:
                        print(s[:220])

    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
