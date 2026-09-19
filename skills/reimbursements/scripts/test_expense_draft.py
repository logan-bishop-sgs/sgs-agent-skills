import json
import tempfile
import unittest
from pathlib import Path

from expense_draft import load_job, merge_selectors, need_login
from workday_dates import split_iso, widgets_equal


class MergeSelectorsTests(unittest.TestCase):
    def test_overlay_replaces_one_key(self):
        base = {"header_ok": {"text": ["OK"]}, "line_done": {"text": ["Done"]}}
        overlay = {"header_ok": {"css": ["[data-automation-id='newOk']"]}}
        merged = merge_selectors(base, overlay)
        self.assertEqual(merged["header_ok"]["css"], ["[data-automation-id='newOk']"])
        self.assertEqual(merged["line_done"]["text"], ["Done"])


class LoginTests(unittest.TestCase):
    def test_sso_is_login(self):
        self.assertTrue(need_login("https://sso.sgs.net/adfs/ls/wia"))

    def test_workday_is_not_login(self):
        self.assertFalse(need_login("https://wd3.myworkday.com/sgs/d/task/2997$728.htmld"))


class JobTests(unittest.TestCase):
    def test_rejects_missing_amount(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "job.json"
            path.write_text(
                json.dumps(
                    {
                        "lines": [
                            {
                                "kind": "oop",
                                "date": "2026-09-15",
                                "expense_item": "US_MEALS (SELF, SGS EMP.)TIPS",
                                "memo": "x",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaises(ValueError):
                load_job(path)

    def test_rejects_missing_date(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "job.json"
            path.write_text(
                json.dumps(
                    {
                        "lines": [
                            {
                                "kind": "oop",
                                "amount": 10,
                                "expense_item": "US_IT SUPPLIES",
                                "memo": "x",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaises(ValueError):
                load_job(path)

    def test_new_report_unless_they_named_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "job.json"
            line = {
                "kind": "oop",
                "date": "2026-09-16",
                "amount": 278.31,
                "expense_item": "US_IT SUPPLIES",
                "memo": "Software Expense",
            }
            path.write_text(json.dumps({"lines": [line]}), encoding="utf-8")
            job = load_job(path)
            self.assertTrue(job["new_report"])
            path.write_text(
                json.dumps({"existing_report": "WDERUS_10002505", "lines": [line]}),
                encoding="utf-8",
            )
            job = load_job(path)
            self.assertFalse(job["new_report"])
            self.assertEqual(job["existing_report"], "WDERUS_10002505")


class DateWidgetTests(unittest.TestCase):
    def test_split_and_match(self):
        self.assertEqual(split_iso("2026-09-16"), ("2026", "09", "16"))
        self.assertTrue(widgets_equal("09", "16", "2026", "2026-09-16"))
        self.assertFalse(widgets_equal("07", "02", "2026", "2026-09-16"))


if __name__ == "__main__":
    unittest.main()
