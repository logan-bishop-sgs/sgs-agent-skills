"""Fill Create Azure AD Application registration on open ServiceNow Edge tab.

Reads field ids from selectors.json + values from draft .txt. Does not Submit.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

SKILL_DIR = Path(__file__).resolve().parents[1]
SELECTORS = SKILL_DIR / "selectors.json"
NEED_LOGIN = 20


def parse_draft(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    fields: dict[str, str] = {}
    key_map = {
        "ApplicationName": "application_name",
        "Scope": "scope",
        "Short Description": "short_description",
        "Environment": "environment",
        "Application URL": "application_url",
        "Owner": "owner",
        "Watch list": "watch_list",
    }
    for line_key, internal in key_map.items():
        m = re.search(
            rf"^{re.escape(line_key)}:\r?\n(.+?)(?=\r?\n\r?\n[A-Za-z]|\Z)",
            text,
            re.MULTILINE | re.DOTALL,
        )
        if m:
            fields[internal] = m.group(1).strip()

    desc_m = re.search(
        r"Description \(paste entire block below\):\r?\n---\r?\n(.+?)\r?\n---",
        text,
        re.DOTALL,
    )
    if desc_m:
        fields["description"] = desc_m.group(1).strip()
    return fields


def env_to_select_value(label: str) -> str:
    low = label.strip().lower()
    if low.startswith("prod"):
        return "prod"
    if low.startswith("dev"):
        return "dev"
    if low.startswith("test"):
        return "test"
    if low.startswith("uat"):
        return "uat"
    if "non" in low:
        return "nonprod"
    return "prod"


def page_from_cdp(cdp: str):
    pw = sync_playwright().start()
    browser = pw.chromium.connect_over_cdp(cdp)
    ctx = browser.contexts[0]
    page = None
    for p in ctx.pages:
        if "service-now.com" in p.url:
            page = p
            break
    if page is None:
        page = ctx.new_page()
    return pw, page


def need_login(page) -> bool:
    if "login.microsoftonline.com" in page.url:
        return True
    if page.locator("text=Use external login").count() and page.locator(
        'input[type="password"]'
    ).count():
        return True
    return False


def set_input(page, field_id: str, value: str) -> None:
    loc = page.locator(f"#{field_id}")
    loc.wait_for(state="visible", timeout=30_000)
    loc.click()
    loc.fill("")
    loc.fill(value)
    page.evaluate(
        """(id) => {
          const el = document.getElementById(id);
          if (!el) return;
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
          el.dispatchEvent(new Event('blur', { bubbles: true }));
        }""",
        field_id,
    )


def set_select(page, field_id: str, option_value: str) -> None:
    page.locator(f"#{field_id}").select_option(value=option_value)


def _watch_queries(email: str) -> list[str]:
    """Reference lookup may match display name better than email."""
    e = email.strip()
    queries = [e]
    local = e.split("@")[0]
    if "." in local:
        parts = local.replace(".", " ").split()
        if len(parts) >= 2:
            queries.append(f"{parts[0]} {parts[-1]}")
        queries.append(parts[0])
    return queries


def _add_one_watch_user(page, root, queries: list[str]) -> bool:
    inp = root.locator("input.select2-input").first
    if not inp.count():
        return False
    for q in queries:
        page.keyboard.press("Escape")
        page.wait_for_timeout(200)
        inp.click()
        page.wait_for_timeout(200)
        inp.fill("")
        inp.type(q, delay=25)
        page.wait_for_timeout(1500)
        option = page.locator(
            "#select2-drop .select2-result-selectable .select2-result-label, "
            "#select2-drop .select2-results__option--highlighted, "
            "#select2-drop li.select2-results__option"
        ).first
        if option.count() and option.is_visible():
            option.click()
            page.wait_for_timeout(700)
            return True
    page.keyboard.press("Escape")
    return False


def set_watch_list(page, field_id: str, emails_csv: str) -> bool:
    """ServiceNow glide_list / select2 multi-user reference field."""
    emails = [e.strip() for e in emails_csv.split(",") if e.strip()]
    if not emails:
        return False
    root = page.locator(
        f"#{field_id} >> xpath=ancestor::*[contains(@class,'sp-form-field') or contains(@class,'form-group') or @sn-record-field][1]"
    )
    root.scroll_into_view_if_needed()
    page.keyboard.press("Escape")
    page.wait_for_timeout(300)
    def chip_texts() -> list[str]:
        return [
            t.strip().lower()
            for t in root.locator(
                ".select2-search-choice, .select2-selection__choice"
            ).all_inner_texts()
        ]

    added = 0
    for email in emails:
        queries = _watch_queries(email)
        if any(
            q.split("@")[0].replace(".", " ").lower() in " ".join(chip_texts())
            or any(part.lower() in " ".join(chip_texts()) for part in q.split() if len(part) > 2)
            for q in queries
        ):
            print(f"watch_list: skip (already on form) {email}")
            continue
        if _add_one_watch_user(page, root, queries):
            added += 1
        else:
            print(f"watch_list: could not pick user for {email}", file=sys.stderr)
    chips = root.locator(".select2-search-choice, .select2-selection__choice")
    count = chips.count()
    print(f"watch_list: {count} chip(s) on form ({added} new)")
    return count >= len(emails)


def ensure_entra_catalog(page, catalog_url: str) -> None:
    if "01714e3edb523f404ee710284b961975" in page.url:
        page.wait_for_timeout(1500)
        return
    page.goto(catalog_url, wait_until="networkidle", timeout=120_000)
    page.wait_for_timeout(2000)
    if "Create Azure AD Application registration" not in page.title():
        raise SystemExit(
            f"Wrong catalog page: {page.title()}. Expected Create Azure AD Application registration."
        )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--draft", type=Path, required=True)
    ap.add_argument("--cdp", default="http://127.0.0.1:9223")
    ap.add_argument("--selectors", type=Path, default=SELECTORS)
    args = ap.parse_args()

    sel = json.loads(args.selectors.read_text(encoding="utf-8"))
    catalog_url = sel["catalog_url"]
    draft = parse_draft(args.draft)
    if not draft.get("application_name"):
        print("draft missing ApplicationName", file=sys.stderr)
        return 1

    pw, page = page_from_cdp(args.cdp)
    try:
        ensure_entra_catalog(page, catalog_url)
        if need_login(page):
            print("NEED_LOGIN: finish sign-in in ServiceNow Edge, then re-run.")
            return NEED_LOGIN

        page.keyboard.press("Escape")
        page.wait_for_timeout(300)

        set_input(page, sel["app_name"]["id"], draft["application_name"])
        print("app_name")
        set_input(page, sel["scope"]["id"], draft["scope"])
        print("scope")
        set_input(page, sel["short_description"]["id"], draft["short_description"])
        print("short_description")
        env_val = sel["environment"].get("value") or env_to_select_value(
            draft.get("environment", "Production")
        )
        set_select(page, sel["environment"]["id"], env_val)
        print(f"environment={env_val}")
        set_input(page, sel["application_url"]["id"], draft["application_url"])
        print("application_url")
        set_input(page, sel["owner"]["id"], draft["owner"])
        print("owner")
        set_input(page, sel["description"]["id"], draft["description"])
        print("description")
        if draft.get("watch_list") and sel.get("watch_list"):
            if not set_watch_list(page, sel["watch_list"]["id"], draft["watch_list"]):
                print(
                    "watch_list: could not auto-fill select2 — add manually in Edge: "
                    + draft["watch_list"],
                    file=sys.stderr,
                )

        print("Done. Review in Edge and click Submit yourself (agent does not Submit).")
        return 0
    finally:
        pw.stop()


if __name__ == "__main__":
    raise SystemExit(main())
