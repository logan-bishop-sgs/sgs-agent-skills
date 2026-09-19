"""Expense dates: receipt (or card) for lines; today for a new report header.

Workday date widgets often ignore .fill() and keep the leftover date from
the last report. Type the digits, then read them back.
"""

from __future__ import annotations

from datetime import date, datetime


def today_iso() -> str:
    return datetime.now().astimezone().date().isoformat()


def split_iso(yyyy_mm_dd: str) -> tuple[str, str, str]:
    raw = str(yyyy_mm_dd).strip()
    parsed = date.fromisoformat(raw)
    return f"{parsed.year:04d}", f"{parsed.month:02d}", f"{parsed.day:02d}"


def widgets_equal(month: str, day: str, year: str, iso: str) -> bool:
    y, m, d = split_iso(iso)
    return str(month).zfill(2) == m and str(day).zfill(2) == d and str(year) == y


def type_date_widgets(page, iso: str) -> None:
    """Click + select-all + type. fill() is not enough on Workday."""
    y, m, d = split_iso(iso)
    li = page.locator("li").filter(
        has=page.locator('[data-automation-id="formLabel"]:text-is("Expense Date")')
    )
    parts = (
        ("dateSectionMonth-input", m),
        ("dateSectionDay-input", d),
        ("dateSectionYear-input", y),
    )
    for automation_id, value in parts:
        box = li.locator(f'[data-automation-id="{automation_id}"]')
        box.click()
        box.press("Control+A")
        box.type(value, delay=40)
    li.locator('[data-automation-id="dateSectionYear-input"]').press("Tab")
    page.wait_for_timeout(300)
    got_m = li.locator('[data-automation-id="dateSectionMonth-input"]').input_value()
    got_d = li.locator('[data-automation-id="dateSectionDay-input"]').input_value()
    got_y = li.locator('[data-automation-id="dateSectionYear-input"]').input_value()
    if not widgets_equal(got_m, got_d, got_y, iso):
        raise LookupError(
            f"expense_date_stuck wanted={iso} widgets={got_m}/{got_d}/{got_y}"
        )
