import json
import tempfile
import unittest
from pathlib import Path

from expense_draft import load_job, merge_selectors, need_login


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


if __name__ == "__main__":
    unittest.main()
