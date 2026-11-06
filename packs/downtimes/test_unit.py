"""Unit tests for infrachecks-downtimes: python3 test_unit.py"""
import datetime as dt
import importlib.machinery, importlib.util, os, sys, unittest

sys.dont_write_bytecode = True  # keep files/ clean for packaging

HERE = os.path.dirname(os.path.abspath(__file__))
loader = importlib.machinery.SourceFileLoader(
    "dt_pack", f"{HERE}/files/bin/infrachecks-downtimes")
spec = importlib.util.spec_from_loader("dt_pack", loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)
UTC = dt.timezone.utc


def entry(**kw):
    sec = {"hosts": "h1", "start": "02:00", "minutes": "60"}
    sec.update(kw)
    return m.entry("w", sec)


class Rules(unittest.TestCase):
    def test_nth(self):
        # November 2026: Tuesdays are the 3rd, 10th, 17th, 24th
        self.assertTrue(m.matches(dt.date(2026, 11, 10),
                                  "2nd tuesday"))
        self.assertFalse(m.matches(dt.date(2026, 11, 3),
                                   "2nd tuesday"))
        self.assertTrue(m.matches(dt.date(2026, 11, 27),
                                  "last friday"))
        self.assertFalse(m.matches(dt.date(2026, 11, 20),
                                   "last friday"))
        self.assertTrue(m.matches(dt.date(2026, 11, 8), "Sunday"))
        self.assertTrue(m.matches(dt.date(2026, 11, 8), "daily"))

    def test_bad_rules(self):
        for rule in ("2nd tusday", "every sunday", "6th monday",
                     ""):
            with self.assertRaises(m.Bad):
                m.parse_every(rule)

    def test_bad_entries(self):
        with self.assertRaises(m.Bad):
            entry()  # neither every nor dates
        with self.assertRaises(m.Bad):
            entry(every="daily", dates="2026-11-08")
        with self.assertRaises(m.Bad):
            entry(every="daily", comment="x\nCOMMAND [1] X")
        with self.assertRaises(m.Bad):
            entry(every="daily", hosts="h1;h2")
        with self.assertRaises(m.Bad):
            entry(every="daily", minutes="0")
        with self.assertRaises(m.Bad):
            entry(every="daily", start="25:00")
        with self.assertRaises(m.Bad):
            m.entry("two words", {"hosts": "h", "start": "1:00",
                                  "minutes": "5", "every": "daily"})


class Windows(unittest.TestCase):
    now = dt.datetime(2026, 11, 7, 12, 0, tzinfo=UTC)  # a Saturday
    ahead = dt.timedelta(hours=36)

    def win(self, **kw):
        return list(m.occurrences(entry(**kw), self.now,
                                  self.ahead, UTC))

    def test_next_sunday(self):
        self.assertEqual(self.win(every="sunday"), [(
            dt.datetime(2026, 11, 8, 2, 0, tzinfo=UTC),
            dt.datetime(2026, 11, 8, 3, 0, tzinfo=UTC))])

    def test_running_now_starts_now(self):
        w = self.win(every="daily", start="11:00", minutes="120")
        self.assertEqual(w[0][0], self.now)

    def test_long_window_started_days_ago(self):
        w = self.win(dates="2026-11-02", minutes="10080")
        self.assertEqual(w, [(self.now, dt.datetime(
            2026, 11, 9, 2, 0, tzinfo=UTC))])

    def test_skip_and_far_dates(self):
        self.assertEqual(self.win(every="sunday",
                                  skip="2026-11-08"), [])
        self.assertEqual(self.win(dates="2026-12-25"), [])

    def test_dst_local_time(self):
        # Without a time zone, each start gets its own date's offset
        e = entry(dates="2026-03-07 2026-03-08", start="12:00")
        os.environ["TZ"] = "America/New_York"
        import time
        time.tzset()
        now = dt.datetime(2026, 3, 6, 12, 0).astimezone()
        got = list(m.occurrences(e, now, dt.timedelta(days=5),
                                 None))
        self.assertEqual([s.utcoffset() for s, _ in got],
                         [dt.timedelta(hours=-5),
                          dt.timedelta(hours=-4)])


if __name__ == "__main__":
    unittest.main()
