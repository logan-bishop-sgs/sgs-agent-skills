"""Search Application select2 on Access Request; list result labels."""
from playwright.sync_api import sync_playwright

CDP = "http://127.0.0.1:9223"
CATALOG = (
    "https://sgs.service-now.com/sp?id=sc_cat_item"
    "&sys_id=d9d3e9d81b608950b1fc740e1d4bcbce"
)
RITM0953558 = (
    "https://sgs.service-now.com/sp?id=ticket&table=sc_req_item"
    "&sys_id=9ae8652e2b8c0f105d45f6716e91bffe"
)
QUERIES = [
    "",
    "Report",
    "Reports",
    "EHS",
    "Cloud",
    "Certis",
    "engineering",
    "Gen",
    "AI",
    "Application",
    "Support",
    "Azure",
]


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


def app_trigger(page):
    return page.locator(
        "#sp_formfield_application >> xpath=ancestor::*"
        "[contains(@class,'sp-form-field') or contains(@class,'form-group')][1]"
        "//a[contains(@class,'select2-choice')]"
    ).first


def search_results(page, query: str) -> list[str]:
    page.keyboard.press("Escape")
    page.wait_for_timeout(300)
    trig = app_trigger(page)
    trig.scroll_into_view_if_needed()
    trig.click(force=True)
    page.wait_for_timeout(500)
    inp = page.locator("#select2-drop input.select2-input").first
    inp.fill("")
    if query:
        inp.type(query, delay=12)
    page.wait_for_timeout(3000)
    labels = page.locator("#select2-drop .select2-result-label").all_inner_texts()
    no_match = page.locator("#select2-drop").inner_text()
    page.keyboard.press("Escape")
    page.wait_for_timeout(300)
    return [x.strip() for x in labels if x.strip()], no_match[:120]


def main() -> None:
    pw = sync_playwright().start()
    page = [
        p
        for p in pw.chromium.connect_over_cdp(CDP).contexts[0].pages
        if "service-now.com" in p.url
    ][0]

    page.goto(CATALOG, wait_until="load", timeout=90_000)
    page.wait_for_timeout(3000)
    page.keyboard.press("Escape")
    pick_label(page, "Type of action", "Update user")
    pick_label(page, "Environment", "Other environment")
    page.wait_for_timeout(1000)

    for q in QUERIES:
        rows, drop = search_results(page, q)
        print(f"\nQUERY {q!r} -> {len(rows)} result(s) drop={drop!r}")
        for r in rows[:15]:
            print(" ", r[:120])

    page.goto(RITM0953558, wait_until="load", timeout=90_000)
    page.wait_for_timeout(6000)
    text = page.inner_text("body")
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    for i, ln in enumerate(lines):
        if "Project or Application" in ln or "Generative" in ln:
            block = lines[i : i + 5]
            print("\nRITM0953558 lines:", " | ".join(block))

    pw.stop()


if __name__ == "__main__":
    main()
