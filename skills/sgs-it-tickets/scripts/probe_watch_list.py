"""Inspect Watch List DOM on open ServiceNow form (CDP 9223)."""

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
          const hid = document.getElementById('sp_formfield_watch_list');
          const root = hid?.closest('.sp-form-field, .form-group, [sn-record-field]') || hid?.parentElement;
          const chips = root ? Array.from(root.querySelectorAll('.select2-search-choice, .select2-selection__choice')).map(e => e.innerText.trim()) : [];
          const inputs = root ? Array.from(root.querySelectorAll('input, textarea')).map(e => ({
            id: e.id, name: e.name, type: e.type, className: e.className, ariaHidden: e.getAttribute('aria-hidden'), visible: e.offsetParent !== null
          })) : [];
          return {
            url: location.href,
            hiddenValue: hid?.value || '',
            chips,
            inputs,
            htmlSnippet: root ? root.innerHTML.slice(0, 2500) : null
          };
        }"""
    )
    print(json.dumps(data, indent=2))
    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
