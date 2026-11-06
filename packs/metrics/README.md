# InfraChecks Metrics

Sends Checkmk Community's service metrics to a time-series
database as they arrive, in InfluxDB line protocol. The paid
editions can do this from the GUI; on Community, this pack runs
as a one-minute job instead. Tested with VictoriaMetrics and
InfluxDB 2.

Each point looks like this:

    checkmk,host=web01,service=Memory,metric=mem_used_percent value=41.2 1793953186

with one point per metric per new check result. The timestamp
is the time of the check.

## Install

As the site user:

    mkp add infrachecks-metrics-1.0.0.mkp
    mkp enable infrachecks-metrics 1.0.0
    mkdir -p ~/etc/infrachecks
    cp ~/local/share/doc/check_mk/infrachecks-metrics/metrics.ini.example \
       ~/etc/infrachecks/metrics.ini
    chmod 600 ~/etc/infrachecks/metrics.ini

Set `url` (and `token` for InfluxDB 2), then look at what it
would send:

    infrachecks-metrics --dry-run | head

Run it every minute through mk-job. Create
`~/etc/cron.d/infrachecks-metrics`:

    * * * * * mk-job infrachecks-metrics $OMD_ROOT/local/bin/infrachecks-metrics

and run `omd reload crontab`. mk-job needs
`/var/lib/check_mk_agent/job/SITENAME`, created once by root and
owned by the site user.

## Limits

- Service metrics only, not host check metrics such as ping
  round-trip times.
- If the database is down, the run fails (mk-job shows it) and
  the next run sends the latest values. Results from the minutes
  in between aren't sent. The site's own graphs still have them.
- Metric values only: units, thresholds and min/max from the
  performance data aren't sent.
- Reads one site's Livestatus. On a distributed setup, run it on
  each site.

## Test

`python3 test_unit.py` runs the unit tests.
`tools/build.sh metrics` builds the MKP in a fresh Community
container, installs it from the file and runs `test.sh` against
a small HTTP server that stands in for the database.
