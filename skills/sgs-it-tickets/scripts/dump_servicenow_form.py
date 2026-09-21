"""Dump ServiceNow catalog form fields from the open Edge tab (CDP 9223)."""

from __future__ import annotations

import json
import sys

from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"
DEFAULT_CATALOG = (
    "https://sgs.service-now.com/sp?id=sc_cat_item"
    "&sys_id=01714e3edb523f404ee710284b961975"
)


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Dump ServiceNow catalog form fields from Edge CDP.")
    parser.add_argument(
        "--url",
        default=DEFAULT_CATALOG,
        help="sc_cat_item URL to open if the active tab is not already on a catalog form",
    )
    args = parser.parse_args()
    catalog = args.url
    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(CDP)
    page = None
    for p in browser.contexts[0].pages:
        if "service-now.com" in p.url:
            page = p
            break
    if page is None:
        print("No service-now.com tab", file=sys.stderr)
        return 1
    if "sc_cat_item" not in page.url:
        page.goto(catalog, wait_until="networkidle", timeout=120_000)
    page.wait_for_timeout(3000)
    data = page.evaluate(
        """() => {
          const out = [];
          const fields = document.querySelectorAll(
            'input, textarea, select, [contenteditable="true"]'
          );
          for (const el of fields) {
            if (el.type === 'hidden') continue;
            const style = window.getComputedStyle(el);
            if (style.display === 'none' || style.visibility === 'hidden') continue;
            const root = el.closest('.sp-form-field, .form-group, .question, li, .row, fieldset') || el.parentElement;
            let label = '';
            if (root) {
              const lab = root.querySelector('label, .label, .sp-field-label, .question-label, span.label');
              if (lab) label = (lab.innerText || '').trim().replace(/\\s+/g, ' ');
            }
            const aria = el.getAttribute('aria-label') || '';
            const name = el.getAttribute('name') || '';
            const id = el.id || '';
            const ng = el.getAttribute('ng-model') || el.getAttribute('data-ng-model') || '';
            const auto = el.getAttribute('data-automation-id') || '';
            out.push({
              tag: el.tagName.toLowerCase(),
              type: el.type || '',
              label,
              ariaLabel: aria,
              name,
              id,
              ngModel: ng,
              automationId: auto,
              placeholder: el.placeholder || '',
              valueLen: (el.value || el.innerText || '').length,
            });
          }
          return { url: location.href, title: document.title, fields: out };
        }"""
    )
    print(json.dumps(data, indent=2))
    pw.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
