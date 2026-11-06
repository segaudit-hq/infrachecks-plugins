# InfraChecks plugins

Free plugin packs for Checkmk Community, one MKP per pack,
licensed under the GPL, version 2. Each pack is built from public
interfaces of the Community edition (Livestatus, the REST API and
the site's own tools) and is tested end to end in a fresh
Community site before release.

| Pack | What it does | Status |
|---|---|---|
| [Downtimes](packs/downtimes/) | Recurring scheduled downtimes from a schedule file | 1.0.0 |
| [Metrics](packs/metrics/) | Service metrics to InfluxDB or VictoriaMetrics | 1.0.0 |
| [Reports](packs/reports/) | Monthly availability PDF by email | 1.0.0 |
| Notify | Ticket notifications | Planned |
| Agents | Linux agent rollout | Planned |
| Dashboards | Ready-made dashboards | Planned |

InfraChecks isn't affiliated with or endorsed by Checkmk GmbH.
"Checkmk" is used only to say which software these packs work
with.

## Layout

    packs/PACK/
      manifest.json   name, version, files, minimum Checkmk version
      files/          mirrors the site's ~/local tree
      README.md       what it does, install, limits
      test_unit.py    unit tests (plain Python, no site needed)
      test.sh         end-to-end test, run inside a test site
    tools/build.sh    build, install and test one pack
    lab/              a longer-lived lab for screenshots

## Build and test

    python3 packs/downtimes/test_unit.py
    tools/build.sh downtimes              # current 2.5 release
    tools/build.sh downtimes 2.4.0-latest

`build.sh` starts a fresh Community container, packages the
pack's files with `mkp package`, removes the package, installs
it again from the `.mkp` file the way a user would, adds two test
hosts, and runs the pack's `test.sh`. The MKP lands in `dist/`.
CI runs the same thing for every pack on 2.4 and 2.5.
