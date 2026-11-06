"""Unit tests for infrachecks-reports: python3 test_unit.py"""
import datetime as dt
import importlib.machinery, importlib.util, os, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
loader = importlib.machinery.SourceFileLoader(
    "reports_pack", f"{HERE}/files/bin/infrachecks-reports")
spec = importlib.util.spec_from_loader("reports_pack", loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


class Tally(unittest.TestCase):
    # state, seconds, in_downtime, in_host_downtime, in_period
    rows = [[0, 3000, 0, 0, 1], [2, 600, 0, 0, 1],
            [2, 1200, 1, 0, 1], [1, 600, 0, 0, 0],
            [-1, 300, 0, 0, 1]]

    def test_service_24x7(self):
        pct, mins = m.tally(self.rows, False, False)
        self.assertAlmostEqual(pct, 100 * 3600 / 4200)  # WARN = up
        self.assertEqual(mins, {"up": 60, "down": 10,
                                "planned": 20, "unmonitored": 5})

    def test_host_and_shifts(self):
        pct, _ = m.tally(self.rows, True, False)
        self.assertAlmostEqual(pct, 100 * 3000 / 4200)  # 1 = down
        pct, _ = m.tally(self.rows, False, True)
        self.assertAlmostEqual(pct, 100 * 3000 / 3600)

    def test_no_data(self):
        self.assertIsNone(m.tally([[-1, 60, 0, 0, 1]], True,
                                  False)[0])


class Months(unittest.TestCase):
    def test_default_is_last_month(self):
        first, start, end = m.month(None, dt.date(2026, 1, 1))
        self.assertEqual(first, dt.date(2025, 12, 1))
        self.assertEqual(end - start, 31 * 86400)

    def test_twelve_month_average(self):
        mk = lambda mon, a: {"month": mon, "systems": [
            {"name": "ERP", "target": 99.9, "availability": a,
             "met": None}]}
        rows = m.table_rows([mk("2026-09", 99.0),
                             mk("2026-10", None),
                             mk("2026-11", 100.0)])
        self.assertEqual(rows[1], ["ERP", "100.00%", "99.9%",
                                   "99.50%"])


if __name__ == "__main__":
    unittest.main()
