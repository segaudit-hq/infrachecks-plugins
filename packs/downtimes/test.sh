#!/usr/bin/env bash
# End-to-end test, run by tools/build.sh as the site user in a
# fresh site that has the pack installed from its MKP.
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
count() { printf 'GET downtimes\nColumns: id\nFilter: author = infrachecks-downtimes\n' | lq | wc -l; }
mkdir -p ~/etc/infrachecks
ini=~/etc/infrachecks/downtimes.ini

infrachecks-downtimes >/dev/null 2>&1 && fail "ran without a schedule"

ago=$(date -d '-1 hour' +%H:%M)
soon=$(date -d '+2 hours' +%H:%M)
cat > $ini <<INI
[running]
hosts = ic-test-1
every = daily
start = $ago
minutes = 180

[group]
hosts = group:ic-patch
every = daily
start = $soon
minutes = 30
comment = Group window

[skipped]
hosts = ic-test-1
every = daily
start = $soon
minutes = 30
skip = $(date -d yesterday +%F) $(date +%F) $(date -d tomorrow +%F)

[far]
hosts = ic-test-1
dates = 2099-01-01
start = 01:00
minutes = 60
INI

# Daily windows within 36 hours: two each for running and group.
infrachecks-downtimes --dry-run | tee /tmp/dry
grep -q "^4 new downtime windows (dry run" /tmp/dry || fail "dry run"
[ "$(count)" = 0 ] || fail "dry run created downtimes"

infrachecks-downtimes | tee /tmp/run1
grep -q "^4 new downtime windows$" /tmp/run1 || fail "first run"
for _ in $(seq 20); do [ "$(count)" = 4 ] && break; sleep 1; done
[ "$(count)" = 4 ] || fail "expected 4 downtimes, got $(count)"

infrachecks-downtimes | grep -q "^0 new" || fail "second run duplicated"
[ "$(count)" = 4 ] || fail "second run created downtimes"

for _ in $(seq 30); do  # the core starts it on its next tick
    depth=$(printf 'GET hosts\nColumns: scheduled_downtime_depth\nFilter: name = ic-test-1\n' | lq)
    [ "$depth" = 1 ] && break; sleep 1
done
[ "$depth" = 1 ] || fail "ic-test-1 isn't in downtime now ($depth)"
printf 'GET downtimes\nColumns: host_name comment\nFilter: host_name = ic-test-2\n' \
    | lq | grep -q '^ic-test-2;\[sched:group:[0-9]*\] Group window$' \
    || fail "group downtime comment"

# Targets that aren't on this site are skipped, and the run
# fails so mk-job shows it.
printf '[elsewhere]\nhosts = p2-host group:no-group\nevery = daily\nstart = %s\nminutes = 30\n' \
    "$soon" >> $ini
infrachecks-downtimes >/tmp/run3 2>/tmp/err3 && fail "missing hosts passed"
grep -q "^skipped group:no-group:" /tmp/err3 || fail "group warning"
grep -q "^skipped p2-host:" /tmp/err3 || fail "host warning"
grep -q "^0 new" /tmp/run3 || fail "created for missing hosts"
sed -i '/^\[elsewhere\]/,$d' $ini

printf '[bad]\nhosts = h1\nevery = 2nd tusday\nstart = 01:00\nminutes = 5\n' >> $ini
out=$(infrachecks-downtimes 2>&1) && fail "accepted a bad rule"
echo "$out" | grep -q "tusday" || fail "bad rule message: $out"
echo "downtimes: all checks passed"
