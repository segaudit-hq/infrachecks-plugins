#!/usr/bin/env bash
# End-to-end test, run by tools/build.sh as the site user in a
# fresh site that has the pack installed from its MKP. A stub
# sendmail keeps the message instead of sending it.
set -euo pipefail
fail() { echo "FAIL: $*"; exit 1; }
etc=~/etc/infrachecks
out=~/var/infrachecks/reports
mon=$(date +%Y-%m)
mkdir -p $etc
printf '#!/bin/sh\ncat > /tmp/mail.eml\n' > /tmp/sendmail
chmod 755 /tmp/sendmail

infrachecks-reports >/dev/null 2>&1 && fail "ran without settings"
cat > $etc/systems.csv <<CSV
name,host,service,target,hours
Test host,ic-test-1,,99.9,24x7
Test memory,ic-test-1,Memory,99,24x7
Second host,ic-test-2,,99.9,shifts
Missing,no-such-host,,99.9,24x7
CSV
infrachecks-reports $mon --no-mail | tee /tmp/run1
grep -q '^Missing  *no data' /tmp/run1 || fail "missing host"
grep -Eq '^Test memory  *[0-9.]+%  target 99%$' /tmp/run1 \
    || fail "service figure"
python3 - "$out/avail-$mon.json" <<'PY' || fail "stored JSON"
import json, sys
m = json.load(open(sys.argv[1]))
s = {x["name"]: x for x in m["systems"]}
assert s["Test memory"]["availability"] is not None
assert s["Test memory"]["minutes"]["up"] >= 0
assert s["Missing"]["availability"] is None
assert s["Missing"]["met"] is None
PY
head -c 5 "$out/availability-$mon.pdf" | grep -q '^%PDF-' || fail "PDF"

infrachecks-reports $mon >/dev/null 2>&1 && fail "sent without mail_to"
cat > $etc/reports.ini <<INI
[report]
title = Wexford IT availability
mail_to = it@example.com
mail_from = monitoring@example.com
sendmail = /tmp/sendmail
INI
infrachecks-reports $mon | tail -1 | grep -q "^sent " || fail "send"
grep -q "^Subject: Wexford IT availability $mon: " /tmp/mail.eml \
    || fail "subject"
grep -q '^To: it@example.com' /tmp/mail.eml || fail "To"
grep -q "filename=\"availability-$mon.pdf\"" /tmp/mail.eml \
    || fail "attachment"

echo 'Bad,ic-test-1,,high,24x7' >> $etc/systems.csv
msg=$(infrachecks-reports $mon --no-mail 2>&1) && fail "bad CSV"
echo "$msg" | grep -q "line 6" || fail "CSV message: $msg"
infrachecks-reports 2026-13 --no-mail >/dev/null 2>&1 \
    && fail "accepted month 13"
echo "reports: all checks passed"
