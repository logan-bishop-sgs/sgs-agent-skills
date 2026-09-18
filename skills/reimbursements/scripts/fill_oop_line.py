"""Fill one out-of-pocket Workday expense line on the already-open page.

Does not navigate away. Does not Submit. Never presses Escape.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright


def page_from_cdp(cdp: str):
    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(cdp)
    page = next(p for p in browser.contexts[0].pages if "myworkday" in p.url)
    return pw, page


def li_for_label(page, label: str):
    """Workday puts each field in an <li>; the label is a sibling of the widget."""
    return page.evaluate_handle(
        """(label) => {
          const lab = Array.from(document.querySelectorAll('[data-automation-id="formLabel"]'))
            .find(el => el.innerText.trim() === label);
          if (!lab) throw new Error('no label ' + label);
          return lab.closest('li');
        }""",
        label,
    )


def set_paid_with_card(page, want_checked: bool) -> None:
    li = page.locator("li").filter(
        has=page.locator('[data-automation-id="formLabel"]:text-is("Paid with Corporate Card")')
    )
    box = li.locator('[data-automation-id="checkbox"]')
    panel = li.locator('[data-automation-id="checkboxPanel"]')
    on = box.get_attribute("data-automationcheckboxchecked") == "true"
    if on != want_checked:
        panel.click()
        page.wait_for_timeout(400)
        on = box.get_attribute("data-automationcheckboxchecked") == "true"
    if on != want_checked:
        # native input as last resort
        li.locator('input[type="checkbox"]').click(force=True)
        page.wait_for_timeout(400)
        on = box.get_attribute("data-automationcheckboxchecked") == "true"
    if on != want_checked:
        raise SystemExit(f"paid_with_card still {on}")
    print(f"paid_with_card={on}")


def set_date(page, yyyy_mm_dd: str) -> None:
    y, m, d = yyyy_mm_dd.split("-")
    page.evaluate(
        """({y,m,d}) => {
          const lab = Array.from(document.querySelectorAll('[data-automation-id="formLabel"]'))
            .find(el => el.innerText.trim() === 'Expense Date');
          const li = lab.closest('li');
          const set = (id, val) => {
            const el = li.querySelector('[data-automation-id="' + id + '"]');
            el.focus();
            el.value = val;
            el.dispatchEvent(new Event('input', {bubbles: true}));
            el.dispatchEvent(new Event('change', {bubbles: true}));
          };
          set('dateSectionMonth-input', m);
          set('dateSectionDay-input', d);
          set('dateSectionYear-input', y);
        }""",
        {"y": y, "m": m, "d": d},
    )
    li = page.locator("li").filter(has=page.locator('[data-automation-id="formLabel"]', has_text="Expense Date"))
    # Playwright fill is more reliable for Workday widgets
    li.locator('[data-automation-id="dateSectionMonth-input"]').fill(m)
    li.locator('[data-automation-id="dateSectionDay-input"]').fill(d)
    li.locator('[data-automation-id="dateSectionYear-input"]').fill(y)
    print(f"date={yyyy_mm_dd}")


def wait_glass(page) -> None:
    page.wait_for_timeout(400)
    page.evaluate(
        """() => {
          const panels = Array.from(document.querySelectorAll('[data-automation-id="glassPanel"]'));
          return panels.every(p => p.getAttribute('data-automation-hidden') === 'true' || p.offsetParent === null);
        }"""
    )


def set_numeric(page, label: str, value: str) -> None:
    wait_glass(page)
    ok = page.evaluate(
        """({label, value}) => {
          const lab = Array.from(document.querySelectorAll('[data-automation-id="formLabel"]'))
            .find(el => el.innerText.trim() === label);
          if (!lab) return false;
          const input = lab.closest('li').querySelector('[data-automation-id="numericInput"]');
          if (!input) return false;
          input.focus();
          input.value = String(value);
          input.dispatchEvent(new Event('input', {bubbles: true}));
          input.dispatchEvent(new Event('change', {bubbles: true}));
          return true;
        }""",
        {"label": label, "value": str(value)},
    )
    if not ok:
        for _ in range(15):
            page.wait_for_timeout(300)
            ok = page.evaluate(
                """({label, value}) => {
                  const lab = Array.from(document.querySelectorAll('[data-automation-id="formLabel"]'))
                    .find(el => el.innerText.trim() === label);
                  if (!lab) return false;
                  const input = lab.closest('li').querySelector('[data-automation-id="numericInput"]');
                  if (!input) return false;
                  input.focus();
                  input.value = String(value);
                  input.dispatchEvent(new Event('input', {bubbles: true}));
                  input.dispatchEvent(new Event('change', {bubbles: true}));
                  return true;
                }""",
                {"label": label, "value": str(value)},
            )
            if ok:
                break
        if not ok:
            raise SystemExit(f"numeric missing: {label}")
    print(f"{label}={value}")


def set_memo(page, memo: str) -> None:
    # Line memo, not header memo — last Memo label
    labels = page.locator('[data-automation-id="formLabel"]:text-is("Memo")')
    n = labels.count()
    lab = labels.nth(n - 1)
    li = lab.locator("xpath=ancestor::li[1]")
    box = li.locator('[data-automation-id="textInputBox"]').first
    box.click()
    box.fill(memo)
    box.press("Tab")
    print(f"memo={memo}")


def set_expense_item(page, name: str) -> None:
    li = page.locator("li").filter(
        has=page.locator('[data-automation-id="formLabel"]:text-is("Expense Item")')
    )
    if name in (li.inner_text() or "") and "0 items selected" not in (li.inner_text() or ""):
        print(f"item already {name}")
        return
    already_open = page.locator('[data-automation-id="activeListContainer"]').count()
    if not already_open:
        li.locator('[data-automation-id="promptIcon"]').first.click(timeout=8000)
        page.wait_for_timeout(600)
    alpha = page.get_by_text("By Alphabetical Order", exact=True)
    if alpha.count():
        alpha.first.click()
        page.wait_for_timeout(500)
    box = page.locator('[data-automation-id="activeListContainer"]')
    if box.count():
        box.hover()
        for _ in range(80):
            opt = page.locator('[data-automation-id="promptOption"]').filter(has_text=name)
            if opt.count():
                opt.first.click()
                print(f"item={name}")
                return
            page.mouse.wheel(0, 500)
            page.wait_for_timeout(50)
    opt = page.locator('[data-automation-id="promptOption"]').filter(has_text=name)
    if opt.count() == 0:
        raise SystemExit(f"expense_item not in DOM: {name}")
    opt.first.click()
    print(f"item={name}")


def attach(page, receipt: str) -> None:
    if not receipt:
        return
    path = Path(receipt)
    if not path.is_file():
        raise SystemExit(f"receipt missing: {receipt}")
    page.locator('[data-automation-id="uploadElement"]').set_input_files(str(path))
    print(f"receipt={path.name}")


def collect_errors(page) -> list[str]:
    """Read Workday's error bar / field errors. Empty list = clean."""
    return page.evaluate(
        """() => {
          const out = [];
          const bar = document.querySelector('[data-automation-id="errorWidgetBarMessageCountCanvas"]');
          if (bar && bar.offsetParent && /[1-9]/.test(bar.innerText || '')) {
            out.push(bar.innerText.trim());
          }
          const texts = new Set();
          document.querySelectorAll('[aria-invalid="true"]').forEach(() => {});
          const walker = document.body.innerText.split('\\n');
          for (const line of walker) {
            const t = line.trim();
            if (t.startsWith('Error:') && t.length < 280) texts.add(t);
          }
          out.push(...texts);
          const items = Array.from(document.querySelectorAll('[data-automation-id="multiViewListDetailItem"]'))
            .map(el => el.innerText.replace(/\\s+/g, ' ').trim());
          items.filter(t => t.startsWith('0.00') && !t.includes('US_IT')).forEach(t => {
            out.push('incomplete line: ' + t);
          });
          return out;
        }"""
    )


def assert_no_errors(page) -> None:
    errs = collect_errors(page)
    if errs:
        print("WORKDAY_ERRORS:", file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        raise SystemExit(40)
    print("workday errors: none")


def click_new_expense(page) -> None:
    """Expense Lines Add opens a menu: Credit Card Transactions | New Expense.

    Credit Card Transactions = charges already on the SGS card.
    New Expense = out of pocket (these Cursor invoices).
    """
    page.locator('[data-automation-id="multiViewContainerAddButton"]').click()
    page.wait_for_timeout(500)
    page.locator('[data-automation-id="menuItem"]').filter(has_text="New Expense").click()
    page.wait_for_timeout(900)
    print("clicked New Expense")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--cdp", default="http://127.0.0.1:9222")
    p.add_argument("--add", action="store_true")
    p.add_argument("--date", required=False)
    p.add_argument("--amount", required=False)
    p.add_argument("--qty", default="1")
    p.add_argument("--memo", required=False)
    p.add_argument("--item", default="US_IT SUPPLIES")
    p.add_argument("--receipt", default="")
    p.add_argument("--fix-only", action="store_true")
    p.add_argument("--check-only", action="store_true", help="read Workday errors; do not fill")
    args = p.parse_args()

    pw, page = page_from_cdp(args.cdp)
    try:
        if args.check_only:
            assert_no_errors(page)
            return 0
        if not args.date or not args.amount or not args.memo:
            raise SystemExit("need --date --amount --memo (or --check-only)")
        if args.add and not args.fix_only:
            click_new_expense(page)
        set_paid_with_card(page, False)
        for _ in range(20):
            if page.evaluate(
                """() => !!Array.from(document.querySelectorAll('[data-automation-id="formLabel"]'))
                    .find(el => el.innerText.trim() === 'Quantity')"""
            ):
                break
            page.wait_for_timeout(400)
        set_date(page, args.date)
        set_expense_item(page, args.item)
        set_numeric(page, "Quantity", args.qty)
        set_numeric(page, "Per Unit Amount", args.amount)
        set_memo(page, args.memo)
        if args.receipt:
            attach(page, args.receipt)
        page.wait_for_timeout(500)
        assert_no_errors(page)
        print("oop line filled (draft; not submitted)")
        return 0
    finally:
        pw.stop()


if __name__ == "__main__":
    sys.exit(main())
