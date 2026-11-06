# InfraChecks Reports

A monthly availability report for Checkmk Community: one PDF
with each system's availability for the month, its target, and
its average over the last 12 months, sent by email. Systems that
missed their target are red.

- Availability comes from Livestatus state history. Scheduled
  downtime counts as planned and is left out, and so is time the
  system wasn't monitored.
- For services, WARN counts as up. For hosts, only UP does.
- `hours = shifts` measures a system only during its
  notification period, for systems that only matter while the
  plant (or office) is open.
- Each month's figures are saved as JSON, so the 12-month column
  never re-reads a year of history.

## Install

As the site user:

    mkp add infrachecks-reports-1.0.0.mkp
    mkp enable infrachecks-reports 1.0.0
    mkdir -p ~/etc/infrachecks
    cd ~/local/share/doc/check_mk/infrachecks-reports
    cp reports.ini.example ~/etc/infrachecks/reports.ini
    cp systems.csv.example ~/etc/infrachecks/systems.csv

List your systems in `systems.csv` (leave `service` empty for a
host), set the addresses in `reports.ini`, and try this month so
far without sending anything:

    infrachecks-reports $(date +%Y-%m) --no-mail

The PDF is in `~/var/infrachecks/reports`. To send last month's
report on the 1st, create `~/etc/cron.d/infrachecks-reports`:

    30 6 1 * * mk-job infrachecks-reports $OMD_ROOT/local/bin/infrachecks-reports

and run `omd reload crontab`. Mail goes through the site's
`sendmail`, the same way Checkmk's own notification email does.

## Limits

- The state history only goes back as far as the site keeps its
  monitoring history. Run the first report for a recent month.
- Re-running a month measures it again and replaces its stored
  figures.
- One site's Livestatus. On a distributed setup, run it on each
  site, or list each site's systems in that site's own CSV.
- The PDF layout is fixed: a title, an optional logo and one
  table.

## Test

`python3 test_unit.py` runs the unit tests.
`tools/build.sh reports` builds the MKP in a fresh Community
container, installs it from the file and runs `test.sh`, with a
stub sendmail that keeps the message.
