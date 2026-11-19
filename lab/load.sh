#!/usr/bin/env bash
# Puts N load hosts (default 1000) on the wexford site, to test performance packs such as Kickdown.
# Every load host replays lab-linux-01's agent output from a file, so no agents run, and pings its own
# 127.x address. Discovery and HW/SW inventory checks are switched off on them: Nagios would run all of
# them within minutes of activation, each a full Python process, which is a burst no real site sees.
#
#   lab/up.sh && lab/load.sh 1000    # 1 000 load hosts (lh00001 ...)
#   lab/load.sh 0                    # remove them again
set -euo pipefail
cd "$(dirname "$0")"
N=${1:-1000}
site() { docker compose exec -T -u wexford wexford bash -lc "$1"; }

if [ "$N" = 0 ]; then
  site 'rm -f ~/etc/check_mk/conf.d/lab-load.mk && cmk -R >/dev/null'
  echo "load hosts removed"; exit 0
fi

site 'cmk -d lab-linux-01 > ~/var/lab-load-agent.txt'  # var/, because omd stop empties tmp/
site "cat > ~/etc/check_mk/conf.d/lab-load.mk" <<MK
# written by lab/load.sh: $N load hosts replaying lab-linux-01's agent output
_load = ["lh%05d" % i for i in range(1, $N + 1)]
all_hosts += [h + "|tcp|cmk-agent" for h in _load]
# one loopback address per host (Linux answers on all of 127/8), so a batch pinger sees distinct targets
ipaddresses.update({h: "127.0.%d.%d" % (i // 250 + 1, i % 250 + 1) for i, h in enumerate(_load)})
datasource_programs = [{"id": "lab-load", "condition": {"host_name": _load}, "value": "cat \$OMD_ROOT/var/lab-load-agent.txt"}] + datasource_programs
extra_service_conf.setdefault("active_checks_enabled", [])
extra_service_conf["active_checks_enabled"] = [{"id": "lab-load-no-discovery", "value": "0",
    "condition": {"host_name": _load, "service_description": [{"\$regex": "Check_MK (Discovery|HW/SW Inventory)\$"}]}}] + extra_service_conf["active_checks_enabled"]
MK
echo "discovering $N hosts (about a minute per 1 000)..."
site 'cmk -II >/dev/null && cmk -R >/dev/null'
site "lq 'GET hosts\nFilter: name ~ ^lh\nStats: state >= 0'" | xargs echo "load hosts in the core:"
site "lq 'GET services\nFilter: host_name ~ ^lh\nStats: state >= 0'" | xargs echo "load services:"
