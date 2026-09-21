"""List <select> options on the open ServiceNow catalog form."""

from __future__ import annotations

import json
import sys

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"


def main() -> int:
    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(CDP)
    page = next(p for p in browser.contexts[0].pages if "service-now.com" in p.url)
    data = page.evaluate(
        """() => {
          const selects = Array.from(document.querySelectorAll('select[name]'));
          return selects.map(s => ({
            name: s.name,
            id: s.id,
            value: s.value,
            options: Array.from(s.options).map(o => ({ value: o.value, text: o.text.trim() }))
          }));
        }"""
    )
    print(json.dumps(data, indent=2))
    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
