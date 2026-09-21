"""One-pass fill for Access Request (Azure RBAC draft). Does not Submit."""
print("start", flush=True)

import re
import sys
from pathlib import Path

from fill_servicenow_access_request import (
    ACCESS_REQUEST_APPLICATION_FALLBACKS,
    CMDB_APPLICATION_NAME,
    pick_application_select2,
)
from fill_servicenow_entra import NEED_LOGIN, need_login, set_watch_list
from playwright.sync_api import sync_playwright

DRAFT = Path(
    r"c:\Users\Logan_Bishop\OneDrive - SGS\Documents\ehscloudreporting\ehs_dashboard\CONTEXT\drafts\servicenow-azure-rbac-team-access-2026-09-21.txt"
)
CATALOG = (
    "https://sgs.service-now.com/sp?id=sc_cat_item"
    "&sys_id=d9d3e9d81b608950b1fc740e1d4bcbce"
)
CDP = "http://127.0.0.1:9223"
text = DRAFT.read_text(encoding="utf-8")
roles_m = re.search(r"^Roles:\r?\n(.+?)(?=\r?\n\r?\nAffected)", text, re.MULTILINE | re.DOTALL)
roles = roles_m.group(1).strip() if roles_m else ""
env_m = re.search(r"- Please add here the environment needed: (.+?)\r?\n", text)
env_detail = env_m.group(1).strip() if env_m else ""
users = [
    ln.strip()
    for ln in re.search(
        r"^Affected users .+?:\r?\n(.+?)(?=\r?\n\r?\nWatch list)", text, re.MULTILINE | re.DOTALL
    ).group(1).splitlines()
    if ln.strip()
]
reason_m = re.search(
    r"Business Reason \(paste entire block below\):\r?\n---\r?\n(.+?)\r?\n---", text, re.DOTALL
)
reason = reason_m.group(1).strip()
short_m = re.search(r"^Short Description:\r?\n(.+?)(?=\r?\n\r?\n)", text, re.MULTILINE)
short = short_m.group(1).strip() if short_m else ""
if len(users) > 1:
    reason += "\n\nADDITIONAL AFFECTED USERS:\n" + "; ".join(users[1:])
full_reason = f"{short}\n\nREQUESTED ROLES:\n{roles}\n\nENVIRONMENT / SUBSCRIPTION:\n{env_detail}\n\n{reason}"


def pick_label(page, label: str, option: str) -> None:
    trig = page.locator(
        f"xpath=//label[contains(normalize-space(.), '{label}')]"
        "/ancestor::*[contains(@class,'sp-form-field') or contains(@class,'form-group')][1]"
        "//a[contains(@class,'select2-choice')]"
    ).first
    trig.scroll_into_view_if_needed()
    trig.click(force=True)
    page.wait_for_timeout(600)
    page.locator("#select2-drop .select2-result-label").filter(has_text=option).first.click()
    page.wait_for_timeout(800)


def set_val(page, fid: str, val: str) -> None:
    page.evaluate(
        """([id, v]) => {
          const el = document.getElementById(id);
          el.value = v;
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        }""",
        [fid, val],
    )


print("connect", flush=True)
pw = sync_playwright().start()
page = [p for p in pw.chromium.connect_over_cdp(CDP).contexts[0].pages if "service-now.com" in p.url][0]
if need_login(page):
    print("NEED_LOGIN", flush=True)
    sys.exit(20)

page.goto(CATALOG, wait_until="load", timeout=90_000)
page.wait_for_timeout(3000)
print("form", page.title(), flush=True)

page.keyboard.press("Escape")
pick_label(page, "Type of action", "Update user")
pick_label(page, "Environment", "Other environment")
set_val(page, "sp_formfield_please_complete_here_the_enviroment_needed", env_detail)
set_val(page, "sp_formfield_roles", roles)
set_val(page, "sp_formfield_affected_user_email", users[0])
set_val(page, "sp_formfield_business_reason", full_reason)

ok, picked = pick_application_select2(
    page, CMDB_APPLICATION_NAME, *ACCESS_REQUEST_APPLICATION_FALLBACKS
)
print(f"application ok={ok} picked={picked!r}", flush=True)

try:
    page.set_default_timeout(12_000)
    set_watch_list(page, "sp_formfield_watch_list", "Logan.Bishop@sgs.com")
except Exception as exc:
    print("watch_list:", exc, flush=True)

state = page.evaluate(
    """() => ({
      action: document.getElementById('sp_formfield_type_of_action')?.value,
      env: document.getElementById('sp_formfield_environment')?.value,
      email: document.getElementById('sp_formfield_affected_user_email')?.value,
      reasonLen: (document.getElementById('sp_formfield_business_reason')?.value||'').length,
    })"""
)
print("DONE", state, flush=True)
pw.stop()
