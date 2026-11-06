"""Unit tests for infrachecks-metrics: python3 test_unit.py"""
import importlib.machinery, importlib.util, os, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
loader = importlib.machinery.SourceFileLoader(
    "metrics_pack", f"{HERE}/files/bin/infrachecks-metrics")
spec = importlib.util.spec_from_loader("metrics_pack", loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


class Lines(unittest.TestCase):
    rows = [["web 1", "Filesystem /var", 100,
             "'fs used'=12.5;80;90 fs_size=200MB"],
            ["web1", "CPU load", 100, "load1=0.5 load5=bogus"]]

    def test_escaping_and_values(self):
        out, seen = m.lines(self.rows, {})
        self.assertEqual(out[0], "checkmk,host=web\\ 1,service="
                         "Filesystem\\ /var,metric=fs\\ used "
                         "value=12.5 100")
        self.assertIn("metric=fs_size value=200.0 100", out[1])
        self.assertEqual(len(out), 3)  # "bogus" isn't a number
        self.assertEqual(seen["web1;CPU load"], 100)

    def test_only_new_results(self):
        out, _ = m.lines(self.rows, {"web 1;Filesystem /var": 100})
        self.assertEqual(len(out), 1)


if __name__ == "__main__":
    unittest.main()
