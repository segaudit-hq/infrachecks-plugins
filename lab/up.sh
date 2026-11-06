#!/usr/bin/env bash
# Bring up the lab and give the ridge site one monitored Linux host (the container itself).
set -euo pipefail
cd "$(dirname "$0")"
PASS=${CMK_PASSWORD:-labpass123}
API=http://localhost:8080/ridge/check_mk/api/1.0
AUTH="Authorization: Bearer cmkadmin $PASS"

if ! docker info >/dev/null 2>&1; then  # cloud sessions don't start dockerd
  (dockerd >/tmp/dockerd.log 2>&1 &)
  for _ in $(seq 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi
docker compose up -d

for site in ridge:8080 remote1:8081; do
  echo -n "waiting for ${site%%:*}"
  until curl -sf -o /dev/null "http://localhost:${site##*:}/${site%%:*}/check_mk/login.py"; do echo -n .; sleep 3; done
  echo " up"
done

# Agent: install the site's own package and query it directly instead of over TCP.
docker compose exec -T ridge bash -c 'dpkg -i /omd/sites/ridge/share/check_mk/agents/check-mk-agent_*_all.deb >/dev/null'
docker compose exec -T -u ridge ridge bash -c 'cat > ~/etc/check_mk/conf.d/lab-agent.mk' <<'MK'
datasource_programs = [{"id": "lab-agent", "condition": {}, "value": "/usr/bin/check_mk_agent"}] + datasource_programs
MK

curl -sf -o /dev/null -X POST "$API/domain-types/host_config/collections/all" -H "$AUTH" \
  -H "Content-Type: application/json" -d '{"folder":"/","host_name":"lab-linux-01","attributes":{"ipaddress":"127.0.0.1"}}' \
  || echo "lab-linux-01 already exists"
docker compose exec -T -u ridge ridge bash -lc 'cmk -II lab-linux-01 >/dev/null && cmk -O >/dev/null'

echo "ridge:   http://localhost:8080/ridge/  (cmkadmin / $PASS)"
echo "remote1: http://localhost:8081/remote1/"
