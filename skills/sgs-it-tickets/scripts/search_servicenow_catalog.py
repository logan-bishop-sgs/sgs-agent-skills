"""Search SGS ServiceNow catalog via open Edge tab (CDP 9223)."""

from __future__ import annotations

import json
import sys
import urllib.parse

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"
QUERIES = [
    "azure hybrid",
    "app service",
    "firewall rule",
    "network access",
    "azure connectivity",
    "hybrid connection",
    "cloud azure",
    "firewall request",
    "IAM firewall",
]


def main() -> int:
    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(CDP)
    ctx = browser.contexts[0]
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    print("START_URL", page.url, file=sys.stderr)

    results: list[dict] = []
    for q in QUERIES:
        enc = urllib.parse.quote(q)
        url = f"https://sgs.service-now.com/sp?id=search&spa=1&t=sc&q={enc}"
        # ServiceNow SPA search often never hits networkidle — use load + fixed wait.
        try:
            page.goto(url, wait_until="load", timeout=90_000)
        except Exception:
            page.goto(url, wait_until="domcontentloaded", timeout=90_000)
        page.wait_for_timeout(8000)
        login_required = (
            "login.microsoftonline.com" in page.url
            or page.locator("text=Use external login").count() > 0
        )
        if login_required:
            results.append({"q": q, "login_required": True, "url": page.url})
            print("LOGIN_REQUIRED", file=sys.stderr)
            break
        items = page.evaluate(
            """() => {
          const links = [...document.querySelectorAll('a')];
          const hits = [];
          const seen = new Set();
          for (const a of links) {
            const t = (a.innerText || '').trim().replace(/\\s+/g, ' ');
            const href = a.getAttribute('href') || '';
            if (!t || t.length < 4) continue;
            if (!href.includes('sc_cat_item') && !href.includes('sys_id=')) continue;
            const key = t + href;
            if (seen.has(key)) continue;
            seen.add(key);
            hits.push({ text: t.slice(0, 160), href });
          }
          return hits.slice(0, 30);
        }"""
        )
        results.append(
            {
                "q": q,
                "login_required": False,
                "url": page.url,
                "title": page.title(),
                "items": items,
            }
        )
        print(f"--- {q}: {len(items)} items", file=sys.stderr)

    print(json.dumps(results, indent=2))
    pw.stop()
    return 0 if not any(r.get("login_required") for r in results) else 20


if __name__ == "__main__":
    raise SystemExit(main())
