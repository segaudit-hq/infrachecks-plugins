# InfraChecks Downtimes

Recurring scheduled downtimes for Checkmk Community. The
Community edition's REST API accepts a recurrence setting and
then ignores it, so this pack does the recurring part: an hourly
job reads a schedule file and creates the downtimes due in the
next 36 hours.

- Weekly (`sunday`), monthly by weekday (`2nd tuesday`,
  `last friday`), `daily`, or a list of dates.
- Hosts by name or by host group (`group:linux-patch-sunday`).
- Skip dates to cancel one occurrence.
- Never creates the same window twice, however often it runs.
- Talks to Livestatus on the site, so it needs no automation
  user and no secret. Downtimes show `infrachecks-downtimes` as
  the author.

## Install

As the site user:

    mkp add infrachecks-downtimes-1.0.0.mkp
    mkp enable infrachecks-downtimes 1.0.0
    mkdir -p ~/etc/infrachecks
    cp ~/local/share/doc/check_mk/infrachecks-downtimes/downtimes.ini.example \
       ~/etc/infrachecks/downtimes.ini

Edit the schedule, then check it without changing anything:

    infrachecks-downtimes --dry-run

Run it every hour through mk-job, so a failure shows up as a
service in Checkmk. Create `~/etc/cron.d/infrachecks-downtimes`:

    5 * * * * mk-job infrachecks-downtimes $OMD_ROOT/local/bin/infrachecks-downtimes

and run `omd reload crontab`. mk-job needs
`/var/lib/check_mk_agent/job/SITENAME`, created once by root and
owned by the site user.

## Limits

- Host downtimes only. Services on a host in downtime don't
  notify, but a single service can't be scheduled on its own.
- A host added to a group after its downtime was created isn't
  covered until the next occurrence.
- Deleting a scheduled downtime in the GUI doesn't cancel it:
  the next run creates it again. Use `skip =`.
- Runs on one site and sees only that site's hosts. On a
  distributed setup, run it on each site with its own schedule.
  A host or group that isn't on the site (or a group with no
  hosts) is skipped with a message, and the run exits with an
  error, so mk-job shows that the schedule needs fixing.
- Times are the server's local time unless `timezone =` is set.

## Test

`python3 test_unit.py` runs the unit tests.
`tools/build.sh downtimes` builds the MKP in a fresh Community
container, installs it from the file and runs `test.sh`.
