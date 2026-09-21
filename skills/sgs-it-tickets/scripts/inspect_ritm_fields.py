"""Open RITM via portal search and print Application / Business Service context."""

from __future__ import annotations

import re
import sys

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"
RITMS = [
    "RITM0981150",  # contributor / app server
    "RITM0943812",  # new Azure Web App
    "RITM0929379",  # EHS Cloud reporting function app
    "RITM0963963",  # App Insights
]


def open_ritm(page, number: str) -> str:
    page.goto(
        f"https://sgs.service-now.com/sp?id=search&spa=1&t=requests&q={number}",
        wait_until="load",
        timeout=90_000,
    )
    page.wait_for_timeout(5000)
    link = page.get_by_role("link", name=re.compile(number, re.I)).first
    if link.count():
        link.click()
        page.wait_for_timeout(8000)
    return page.inner_text("body")


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
                    if nxt and not re.match(r"^(RITM|REQ|SCTASK|Stage|State)\b", nxt, re.I):
                        out.append("  " + nxt[:180])
    # Fallback: any line containing "Application" with neighbor
    if not any("Application" in x for x in out):
        for i, ln in enumerate(lines):
            if re.search(r"\bApplication\b", ln, re.I) and "Application URL" not in ln:
                out.append(ln[:180])
                if i + 1 < len(lines):
                    out.append("  " + lines[i + 1][:180])
    return out[:24]


def main() -> int:
    pw = sync_playwright().start()
    page = [p for p in pw.chromium.connect_over_cdp(CDP).contexts[0].pages if "service-now.com" in p.url][0]
    if "login.microsoftonline.com" in page.url:
        print("NEED_LOGIN", file=sys.stderr)
        pw.stop()
        return 20

    for ritm in RITMS:
        text = open_ritm(page, ritm)
        print(f"\n=== {ritm} ===")
        ctx = grep_context(text)
        if ctx:
            print("\n".join(ctx))
        else:
            # show catalog title snippet
            for ln in text.splitlines():
                if re.search(r"Azure|Access Request|Web App|Function|Insights", ln, re.I):
                    print(ln.strip()[:200])
        print("---")

    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
