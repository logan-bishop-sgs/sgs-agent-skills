"""Create a Workday expense-report *draft* through already-open Edge (CDP 9222).

The agent writes a job JSON and runs this. It does not click Submit.
On a missed locator it dumps automation ids so the agent can patch
CONTEXT/workday-selectors.json and retry.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

from workday_dates import type_date_widgets

EXIT_OK = 0
EXIT_USAGE = 10
EXIT_LOGIN = 20
EXIT_HEAL = 30
EXIT_WORKDAY = 40
EXIT_ENV = 50

LOGIN_HINTS = (
    "sso.sgs.net",
    "login.microsoftonline.com",
    "sts.windows.net",
    "adfs/ls",
)
DUMP_DIR = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "sgs-workday-expense"

SKILL_DIR = Path(__file__).resolve().parents[1]


def _load_dotenv() -> None:
    here = Path.cwd()
    for folder in [here, *here.parents]:
        env_file = folder / ".env"
        if env_file.is_file():
            for raw in env_file.read_text(encoding="utf-8").splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                name, value = line.split("=", 1)
                name, value = name.strip(), value.strip().strip('"').strip("'")
                if name and name not in os.environ:
                    os.environ[name] = value
            return


def merge_selectors(base: dict, overlay: dict) -> dict:
    out = deepcopy(base)
    for key, value in overlay.items():
        if key.startswith("_"):
            continue
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            merged = dict(out[key])
            merged.update(value)
            out[key] = merged
        else:
            out[key] = value
    return out


def find_overlay(explicit: Path | None) -> Path | None:
    if explicit and explicit.is_file():
        return explicit
    here = Path.cwd()
    for folder in [here, *here.parents]:
        for rel in (
            Path("CONTEXT") / "workday-selectors.json",
            Path("context") / "workday-selectors.json",
        ):
            candidate = folder / rel
            if candidate.is_file():
                return candidate
        apps = [p for p in folder.iterdir() if p.is_dir()] if folder.exists() else []
        for app in apps:
            candidate = app / "CONTEXT" / "workday-selectors.json"
            if candidate.is_file():
                return candidate
    return None


def load_selectors(overlay_path: Path | None) -> tuple[dict, Path | None]:
    base = json.loads((SKILL_DIR / "selectors.json").read_text(encoding="utf-8"))
    found = find_overlay(overlay_path)
    if found:
        overlay = json.loads(found.read_text(encoding="utf-8"))
        return merge_selectors(base, overlay), found
    return base, None


def load_job(path: Path) -> dict:
    job = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(job.get("lines"), list) or not job["lines"]:
        raise ValueError("job.lines must be a non-empty list")
    for i, line in enumerate(job["lines"]):
        kind = (line.get("kind") or "").lower()
        if kind not in {"card", "oop"}:
            raise ValueError(f"lines[{i}].kind must be card or oop")
        if line.get("amount") in (None, ""):
            raise ValueError(f"lines[{i}].amount is required")
        if not line.get("expense_item"):
            raise ValueError(f"lines[{i}].expense_item is required")
        if not line.get("memo"):
            raise ValueError(f"lines[{i}].memo is required")
        if not line.get("date"):
            raise ValueError(
                f"lines[{i}].date is required (receipt date, else card date, else today)"
            )
        receipt = line.get("receipt")
        if receipt:
            receipt_path = Path(receipt)
            if not receipt_path.is_absolute():
                receipt_path = (path.parent / receipt_path).resolve()
            if not receipt_path.is_file():
                receipt_path = (Path.cwd() / Path(receipt)).resolve()
            if not receipt_path.is_file():
                raise ValueError(f"receipt not found: {receipt}")
            line["receipt"] = str(receipt_path)
    job.setdefault("header_memo", "")
    existing = str(job.get("existing_report") or "").strip()
    if existing:
        job["existing_report"] = existing
        job["new_report"] = False
    else:
        job["new_report"] = True
        job.pop("existing_report", None)
    return job


def need_login(url: str, title: str = "") -> bool:
    blob = f"{url} {title}".lower()
    return any(hint in blob for hint in LOGIN_HINTS)


def dump_fail(page, step: str, detail: str) -> Path:
    DUMP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    shot = DUMP_DIR / f"fail-{stamp}.png"
    payload = {
        "step": step,
        "detail": detail,
        "url": getattr(page, "url", ""),
        "title": "",
        "dumped_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "timezone": "UTC",
        "automation": [],
    }
    try:
        payload["title"] = page.title()
        page.screenshot(path=str(shot), full_page=False)
        payload["screenshot"] = str(shot)
        payload["automation"] = page.evaluate(
            """() => Array.from(document.querySelectorAll('[data-automation-id]'))
                .slice(0, 120)
                .map(el => ({
                    id: el.getAttribute('data-automation-id'),
                    tag: el.tagName,
                    text: (el.innerText || '').replace(/\\s+/g, ' ').trim().slice(0, 80)
                }))"""
        )
    except Exception as exc:  # noqa: BLE001 — dump must not hide the original miss
        payload["dump_error"] = str(exc)
    out = DUMP_DIR / "last-fail.json"
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"HEAL dump: {out}", file=sys.stderr)
    return out


def locate(page, spec: dict, timeout_ms: int = 4000):
    from playwright.sync_api import TimeoutError as PlaywrightTimeout

    if not spec:
        return None
    last_err = None
    for css in spec.get("css") or []:
        loc = page.locator(css)
        try:
            loc.first.wait_for(state="visible", timeout=timeout_ms)
            return loc.first
        except PlaywrightTimeout as exc:
            last_err = exc
    for text in spec.get("text") or []:
        loc = page.get_by_text(text, exact=False)
        try:
            loc.first.wait_for(state="visible", timeout=timeout_ms)
            return loc.first
        except PlaywrightTimeout as exc:
            last_err = exc
    label = spec.get("label")
    if label:
        loc = page.get_by_label(label, exact=False)
        try:
            loc.first.wait_for(state="visible", timeout=1500)
            return loc.first
        except PlaywrightTimeout as exc:
            last_err = exc
    if last_err:
        return None
    return None


def click_named(page, selectors: dict, key: str, timeout_ms: int = 4000):
    loc = locate(page, selectors.get(key) or {}, timeout_ms=timeout_ms)
    if loc is None:
        raise LookupError(key)
    loc.click()
    return loc


def fill_named(page, selectors: dict, key: str, value: str, timeout_ms: int = 4000):
    loc = locate(page, selectors.get(key) or {}, timeout_ms=timeout_ms)
    if loc is None:
        raise LookupError(key)
    loc.click()
    loc.fill(str(value))
    return loc


def workday_page(context):
    ranked = []
    for page in context.pages:
        url = page.url or ""
        score = 0
        if "myworkday.com" in url:
            score += 3
        if any(h in url for h in LOGIN_HINTS):
            score += 2
        if "microsoftonline" in url:
            score += 1
        ranked.append((score, page))
    ranked.sort(key=lambda item: item[0], reverse=True)
    return ranked[0][1] if ranked else context.pages[0]


def checkbox_checked(locator) -> bool | None:
    handle = locator.element_handle()
    if handle is None:
        return None
    flag = handle.get_attribute("data-automationcheckboxchecked")
    if flag is not None:
        return flag.lower() in {"true", "1", "checked"}
    aria = handle.get_attribute("aria-checked")
    if aria is not None:
        return aria.lower() == "true"
    try:
        return handle.evaluate(
            "el => !!(el.checked || el.getAttribute('aria-checked') === 'true')"
        )
    except Exception:  # noqa: BLE001
        return None


def pick_expense_item(page, selectors: dict, label: str) -> None:
    click_named(page, selectors, "expense_item_prompt", timeout_ms=6000)
    time.sleep(0.4)
    alpha = locate(page, selectors.get("expense_item_alpha") or {}, timeout_ms=2000)
    if alpha:
        alpha.click()
        time.sleep(0.3)
    option = page.get_by_text(label, exact=True)
    try:
        option.first.wait_for(state="visible", timeout=2500)
        option.first.click()
        return
    except Exception:
        pass
    listed = page.locator((selectors.get("expense_item_list") or {}).get("css", [""])[0] or "[data-automation-id='promptOption']")
    count = listed.count()
    for i in range(min(count, 400)):
        row = listed.nth(i)
        text = (row.inner_text() or "").strip()
        if text == label or label.lower() in text.lower():
            row.scroll_into_view_if_needed()
            row.click()
            return
    raise LookupError(f"expense_item:{label}")


def attach_receipt(page, selectors: dict, receipt: str) -> None:
    loc = locate(page, selectors.get("attach_receipt") or {}, timeout_ms=3000)
    if loc is None:
        raise LookupError("attach_receipt")
    loc.set_input_files(receipt)


def select_card_row(page, selectors: dict, line: dict) -> None:
    grid = locate(page, selectors.get("card_grid") or {}, timeout_ms=5000)
    if grid is None:
        raise LookupError("card_grid")
    rows = page.locator((selectors.get("card_row") or {}).get("css", [""])[0] or "[role='row']")
    merchant = str(line.get("merchant") or "").strip().lower()
    amount = str(line.get("amount"))
    date = str(line.get("date") or "")
    hits = []
    for i in range(min(rows.count(), 80)):
        row = rows.nth(i)
        text = (row.inner_text() or "").replace("\n", " ").lower()
        score = 0
        if merchant and merchant in text:
            score += 2
        if amount and amount in text.replace(",", ""):
            score += 2
        if date and date in text:
            score += 1
        if score >= 2:
            hits.append((score, row))
    if not hits:
        raise LookupError("card_row")
    hits.sort(key=lambda item: item[0], reverse=True)
    hits[0][1].click()


def close_page_error(page, selectors: dict) -> None:
    loc = locate(page, selectors.get("page_error_close") or {}, timeout_ms=800)
    if loc is None:
        return
    title = ""
    try:
        title = page.inner_text("body")[:400]
    except Exception:  # noqa: BLE001
        title = ""
    if "page error" in title.lower() or "errors" in title.lower():
        loc.click()


def run_job(page, selectors: dict, job: dict) -> None:
    expense_url = os.environ.get("EXPENSE_URL") or "https://wd3.myworkday.com/sgs/d/task/2997$728.htmld"
    existing = (job.get("existing_report") or "").strip()
    if existing:
        if "myworkday.com" not in (page.url or "") and not need_login(page.url or ""):
            page.goto(expense_url, wait_until="domcontentloaded")
    else:
        # Always Create Expense Report. Do not keep adding to whatever
        # send-back or last-month report happens to be open.
        page.goto(expense_url, wait_until="domcontentloaded")

    if need_login(page.url or "", page.title()):
        raise SystemExit(EXIT_LOGIN)

    remember = locate(page, selectors.get("remember_device_checkbox") or {}, timeout_ms=1500)
    if remember:
        remember.click()
        click_named(page, selectors, "remember_device_submit", timeout_ms=3000)
        time.sleep(1.0)
        if need_login(page.url or "", page.title()):
            raise SystemExit(EXIT_LOGIN)

    if job.get("header_memo"):
        try:
            fill_named(page, selectors, "header_memo", job["header_memo"])
        except LookupError:
            # Already past the header on a retry — keep going.
            pass
    ok = locate(page, selectors.get("header_ok") or {}, timeout_ms=2500)
    if ok:
        ok.click()
        time.sleep(0.8)
    if existing:
        edit = locate(page, selectors.get("edit_expense_report") or {}, timeout_ms=2000)
        if edit:
            edit.click()
            time.sleep(0.8)

    for index, line in enumerate(job["lines"]):
        if line["kind"] == "card":
            add = locate(page, selectors.get("add_expense") or {}, timeout_ms=2500)
            if add:
                add.click()
                time.sleep(0.3)
            card_link = locate(page, selectors.get("credit_card_transactions") or {}, timeout_ms=2500)
            if card_link:
                card_link.click()
                time.sleep(0.5)
            select_card_row(page, selectors, line)
            ok2 = locate(page, selectors.get("header_ok") or {}, timeout_ms=2500)
            if ok2:
                ok2.click()
                time.sleep(0.6)
        else:
            add = locate(page, selectors.get("add_expense") or {}, timeout_ms=4000)
            if add:
                add.click()
            new_exp = locate(page, selectors.get("new_expense") or {}, timeout_ms=2500)
            if new_exp:
                new_exp.click()
            time.sleep(0.5)
            paid = locate(page, selectors.get("paid_with_card") or {}, timeout_ms=3000)
            if paid is None:
                raise LookupError("paid_with_card")
            if checkbox_checked(paid) is not False:
                paid.click()
                time.sleep(0.2)
                if checkbox_checked(paid) is not False:
                    raise LookupError("paid_with_card_still_checked")
            if line.get("date"):
                type_date_widgets(page, str(line["date"]))
            qty = str(line.get("qty") or "1")
            page.locator("li").filter(
                has=page.locator('[data-automation-id="formLabel"]:text-is("Quantity")')
            ).locator('[data-automation-id="numericInput"]').first.fill(qty)
            page.locator("li").filter(
                has=page.locator('[data-automation-id="formLabel"]:text-is("Per Unit Amount")')
            ).locator('[data-automation-id="numericInput"]').first.fill(str(line["amount"]))

        pick_expense_item(page, selectors, line["expense_item"])
        fill_named(page, selectors, "line_memo", line["memo"])
        page.keyboard.press("Tab")
        if line.get("receipt"):
            attach_receipt(page, selectors, line["receipt"])
        close_page_error(page, selectors)
        try:
            click_named(page, selectors, "line_done", timeout_ms=4000)
        except LookupError:
            # Existing-draft edit screen often has Save for Later, not Done.
            click_named(page, selectors, "save_for_later", timeout_ms=5000)
        time.sleep(0.6)
        print(f"line {index + 1}/{len(job['lines'])} done ({line['kind']})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Workday expense draft via Edge CDP")
    parser.add_argument("--job", required=False, help="Path to job JSON")
    parser.add_argument("--overlay", default="", help="CONTEXT/workday-selectors.json")
    parser.add_argument("--cdp", default="http://127.0.0.1:9222")
    parser.add_argument("--dry-check", action="store_true", help="Validate job + selectors only")
    args = parser.parse_args(argv)

    _load_dotenv()
    overlay = Path(args.overlay) if args.overlay else None
    try:
        selectors, overlay_used = load_selectors(overlay)
    except OSError as exc:
        print(f"selectors: {exc}", file=sys.stderr)
        return EXIT_USAGE

    if args.dry_check:
        if args.job:
            load_job(Path(args.job))
        print(f"selectors_ok overlay={overlay_used or 'none'}")
        return EXIT_OK

    if not args.job:
        print("--job is required unless --dry-check", file=sys.stderr)
        return EXIT_USAGE

    try:
        job = load_job(Path(args.job))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"job: {exc}", file=sys.stderr)
        return EXIT_USAGE

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("pip install playwright  (connectOverCDP uses the Edge window already open)", file=sys.stderr)
        return EXIT_ENV

    with sync_playwright() as pw:
        try:
            browser = pw.chromium.connect_over_cdp(args.cdp)
        except Exception as exc:  # noqa: BLE001
            print(f"Edge CDP {args.cdp} is not up. Run Open-Workday-Edge.ps1 first. ({exc})", file=sys.stderr)
            return EXIT_ENV
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = workday_page(context)
        if need_login(page.url or "", page.title()):
            print("NEED_LOGIN: finish SGS sign-in in Edge, then re-run.", file=sys.stderr)
            return EXIT_LOGIN
        try:
            run_job(page, selectors, job)
        except SystemExit as exc:
            code = int(exc.code or EXIT_WORKDAY)
            if code == EXIT_LOGIN:
                print("NEED_LOGIN: finish SGS sign-in in Edge, then re-run.", file=sys.stderr)
            return code
        except LookupError as exc:
            dump_fail(page, str(exc), "locator missed")
            print(f"HEAL: locator missed ({exc}). Patch CONTEXT/workday-selectors.json and retry.", file=sys.stderr)
            return EXIT_HEAL
        except Exception as exc:  # noqa: BLE001
            dump_fail(page, "unhandled", str(exc))
            print(f"WORKDAY: {exc}", file=sys.stderr)
            return EXIT_WORKDAY
    print("Draft lines filled. Do not submit — they review.")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
