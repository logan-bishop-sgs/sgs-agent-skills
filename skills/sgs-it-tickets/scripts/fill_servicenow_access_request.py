"""Fill Access Request catalog form on open ServiceNow Edge tab. Does not Submit."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from fill_servicenow_entra import (
    NEED_LOGIN,
    need_login,
    page_from_cdp,
    set_watch_list,
)

CATALOG_URL = (
    "https://sgs.service-now.com/sp?id=sc_cat_item"
    "&sys_id=d9d3e9d81b608950b1fc740e1d4bcbce"
)
TYPE_OF_ACTION_ID = "sp_formfield_type_of_action"
ENVIRONMENT_ID = "sp_formfield_environment"
ROLES_ID = "sp_formfield_roles"
BUSINESS_REASON_ID = "sp_formfield_business_reason"
AFFECTED_EMAIL_ID = "sp_formfield_affected_user_email"
ENV_DETAIL_ID = "sp_formfield_please_complete_here_the_enviroment_needed"
WATCH_ID = "sp_formfield_watch_list"
# CMDB name from Azure Web App tickets (RITM0953558) — NOT in Access Request picker (2026-09-21).
CMDB_APPLICATION_NAME = "Generative AI Lab Reports - GLOBAL"
# Closest Azure-related row in Access Request Application select2 when CMDB name missing.
ACCESS_REQUEST_APPLICATION_FALLBACKS = ("Azure DevOps",)


def parse_draft(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    fields: dict[str, str] = {}

    m = re.search(r"^Short Description:\r?\n(.+?)(?=\r?\n\r?\n)", text, re.MULTILINE)
    if m:
        fields["short_description"] = m.group(1).strip()

    roles_m = re.search(
        r"^Roles:\r?\n(.+?)(?=\r?\n\r?\nAffected users|\r?\n\r?\nWatch list|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if roles_m:
        fields["roles"] = roles_m.group(1).strip()

    users_m = re.search(
        r"^Affected users .+?:\r?\n(.+?)(?=\r?\n\r?\nWatch list|\r?\n\r?\nBusiness Reason|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if users_m:
        lines = [ln.strip() for ln in users_m.group(1).splitlines() if ln.strip()]
        if lines:
            fields["affected_user_email"] = lines[0]
            if len(lines) > 1:
                fields["affected_user_email_note"] = "; ".join(lines)

    env_m = re.search(
        r"^Manual fields .+?:\r?\n(?:.*\r?\n)*?- Please add here the environment needed: (.+?)\r?\n",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if env_m:
        fields["environment_detail"] = env_m.group(1).strip()

    desc_m = re.search(
        r"Business Reason \(paste entire block below\):\r?\n---\r?\n(.+?)\r?\n---",
        text,
        re.DOTALL,
    )
    if desc_m:
        fields["business_reason"] = desc_m.group(1).strip()

    wl_m = re.search(r"^Watch list:\r?\n(.+?)(?:\r?\n\r?\n|\Z)", text, re.MULTILINE | re.DOTALL)
    if wl_m:
        fields["watch_list"] = wl_m.group(1).strip()

    return fields


def ensure_access_request(page, reload: bool) -> None:
    if reload or "d9d3e9d81b608950b1fc740e1d4bcbce" not in page.url:
        try:
            page.goto(CATALOG_URL, wait_until="load", timeout=90_000)
        except Exception:
            page.goto(CATALOG_URL, wait_until="domcontentloaded", timeout=90_000)
        page.wait_for_timeout(3000)
    title = page.title()
    if "Access Request" not in title:
        raise SystemExit(f"Wrong catalog page: {title}. Expected Access Request.")


def pick_application_select2(page, *queries: str) -> tuple[bool, str]:
    """Pick Application on Access Request. Never clicks an unrelated first result."""
    trig = page.locator(
        "#sp_formfield_application >> xpath=ancestor::*"
        "[contains(@class,'sp-form-field') or contains(@class,'form-group')][1]"
        "//a[contains(@class,'select2-choice')]"
    ).first
    if not trig.count():
        return False, ""

    for query in queries:
        if not query:
            continue
        page.keyboard.press("Escape")
        page.wait_for_timeout(250)
        trig.scroll_into_view_if_needed()
        trig.click(force=True)
        page.wait_for_timeout(600)
        inp = page.locator("#select2-drop input.select2-input").first
        inp.fill("")
        inp.type(query, delay=25)
        page.wait_for_timeout(2500)
        drop_text = page.locator("#select2-drop").inner_text()
        if "No matches found" in drop_text:
            page.keyboard.press("Escape")
            page.wait_for_timeout(200)
            continue
        opt = page.locator("#select2-drop .select2-result-label").filter(has_text=query).first
        if not opt.count():
            page.keyboard.press("Escape")
            page.wait_for_timeout(200)
            continue
        opt.click()
        page.wait_for_timeout(700)
        return True, query

    page.keyboard.press("Escape")
    return False, ""


def pick_select2_by_label(page, label_text: str, option_text: str) -> None:
    trig = page.locator(
        f"xpath=//label[contains(normalize-space(.), '{label_text}')]"
        "/ancestor::*[contains(@class,'sp-form-field') or contains(@class,'form-group')][1]"
        "//a[contains(@class,'select2-choice')]"
    ).first
    trig.scroll_into_view_if_needed()
    trig.click(force=True)
    page.wait_for_timeout(600)
    page.locator("#select2-drop .select2-result-label").filter(has_text=option_text).first.click()
    page.wait_for_timeout(800)


def set_field_value(page, field_id: str, value: str) -> None:
    page.evaluate(
        """([id, val]) => {
          const el = document.getElementById(id);
          if (!el) throw new Error('missing ' + id);
          el.value = val;
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }""",
        [field_id, value],
    )


def build_business_reason(fields: dict[str, str]) -> str:
    reason = fields.get("business_reason", "")
    note = fields.get("affected_user_email_note")
    if note:
        reason = (
            reason
            + "\n\nADDITIONAL AFFECTED USERS (same grant; split tickets if IAM requires):\n"
            + note
        )
    parts: list[str] = []
    if fields.get("short_description"):
        parts.append(fields["short_description"])
    if fields.get("roles"):
        parts.append("REQUESTED ROLES:\n" + fields["roles"])
    if fields.get("environment_detail"):
        parts.append("ENVIRONMENT / SUBSCRIPTION:\n" + fields["environment_detail"])
    if reason:
        parts.append(reason)
    return "\n\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--draft", type=Path, required=True)
    ap.add_argument("--cdp", default="http://127.0.0.1:9223")
    ap.add_argument(
        "--no-reload",
        action="store_true",
        help="Do not reload the catalog page (default reloads for a clean form)",
    )
    args = ap.parse_args()

    fields = parse_draft(args.draft)
    pw, page = page_from_cdp(args.cdp)
    try:
        ensure_access_request(page, reload=not args.no_reload)
        if need_login(page):
            print("NEED_LOGIN: finish sign-in in ServiceNow Edge, then re-run.", file=sys.stderr)
            return NEED_LOGIN

        page.keyboard.press("Escape")
        page.wait_for_timeout(300)

        pick_select2_by_label(page, "Type of action", "Update user")
        pick_select2_by_label(page, "Environment", "Other environment")
        print("type_of_action=update, environment=other_environment")

        if fields.get("environment_detail"):
            set_field_value(page, ENV_DETAIL_ID, fields["environment_detail"])
            print("environment_detail")
        if fields.get("roles"):
            set_field_value(page, ROLES_ID, fields["roles"])
            print("roles")
        if fields.get("affected_user_email"):
            set_field_value(page, AFFECTED_EMAIL_ID, fields["affected_user_email"])
            print("affected_user_email")

        full_reason = build_business_reason(fields)
        if full_reason:
            set_field_value(page, BUSINESS_REASON_ID, full_reason)
            print("business_reason")

        app_queries = (CMDB_APPLICATION_NAME, *ACCESS_REQUEST_APPLICATION_FALLBACKS)
        ok, picked = pick_application_select2(page, *app_queries)
        if ok:
            print(f"application={picked}")
            if picked != CMDB_APPLICATION_NAME:
                print(
                    f"application note: CMDB row is {CMDB_APPLICATION_NAME!r} "
                    f"(Web App catalog only) — see Business Reason / filer-defaults.md",
                    file=sys.stderr,
                )
        else:
            print(
                f"application: leave blank or pick manually — CMDB {CMDB_APPLICATION_NAME!r} "
                f"is not in this picker; try {ACCESS_REQUEST_APPLICATION_FALLBACKS!r}",
                file=sys.stderr,
            )

        if fields.get("watch_list"):
            try:
                page.set_default_timeout(20_000)
                if not set_watch_list(page, WATCH_ID, fields["watch_list"]):
                    print(
                        "watch_list: add manually in Edge: " + fields["watch_list"],
                        file=sys.stderr,
                    )
                else:
                    print("watch_list")
            except Exception as exc:
                print(
                    f"watch_list: skipped ({exc}) — add manually: {fields['watch_list']}",
                    file=sys.stderr,
                )
            finally:
                page.set_default_timeout(30_000)

        print(
            "Done. Review Business Service / Application in Edge, then click Submit "
            "(agent does not Submit)."
        )
        return 0
    finally:
        pw.stop()


if __name__ == "__main__":
    raise SystemExit(main())
