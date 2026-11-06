#!/usr/bin/env bash
# End-to-end test, run by tools/build.sh as the site user in a
# fresh site that has the pack installed from its MKP. A small
# HTTP server stands in for InfluxDB and keeps what it receives.
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
mkdir -p ~/etc/infrachecks
got=/tmp/received.txt
: > $got
python3 - <<'PY' &
import http.server
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        with open("/tmp/received.txt", "a") as f:
            f.write(f"# {self.path} {self.headers.get('Authorization')}\n")
            f.write(body.decode() + "\n")
        self.send_response(204)
        self.end_headers()
http.server.HTTPServer(("127.0.0.1", 18086), H).serve_forever()
PY
trap 'kill %1' EXIT
sleep 1

infrachecks-metrics >/dev/null 2>&1 && fail "ran without settings"
printf '[target]\nurl = http://127.0.0.1:18086/api/v2/write?bucket=cmk\ntoken = t0ken\n' \
    > ~/etc/infrachecks/metrics.ini

infrachecks-metrics --dry-run > /tmp/dry
grep -q 'points (dry run' /tmp/dry || fail "dry run"
[ -s $got ] && fail "dry run sent data"

infrachecks-metrics | tee /tmp/run1
n=$(grep -o '^[0-9]*' /tmp/run1)
[ "$n" -gt 10 ] || fail "only $n points"
head -1 $got | grep -q '^# /api/v2/write?bucket=cmk&precision=s Token t0ken$' \
    || fail "URL or token: $(head -1 $got)"
grep -q '^checkmk,host=ic-test-1,service=Memory,metric=mem_used_percent value=[0-9.]* [0-9]*$' $got \
    || fail "no Memory line"
[ "$(grep -vc '^#' $got)" = "$n" ] || fail "line count"

infrachecks-metrics | grep -q '^0 points written' \
    || fail "resent old results"

# A new check result is sent again; an unreachable target fails
# without saving state, so the next run sends the points again.
lq "COMMAND [$(date +%s)] SCHEDULE_FORCED_SVC_CHECK;ic-test-1;Memory;$(date +%s)"
for _ in $(seq 30); do
    infrachecks-metrics --dry-run | tail -1 | grep -q '^0 ' || break
    sleep 1
done
sed -i 's/18086/18087/' ~/etc/infrachecks/metrics.ini
infrachecks-metrics >/tmp/err 2>&1 && fail "dead target succeeded"
grep -q "failed" /tmp/err || fail "error message: $(cat /tmp/err)"
sed -i 's/18087/18086/' ~/etc/infrachecks/metrics.ini
infrachecks-metrics | grep -qv '^0 points' || fail "lost points"
echo "metrics: all checks passed"
