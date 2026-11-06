#!/usr/bin/env bash
# Bring up the lab and give the wexford site one monitored Linux host (the container itself).
set -euo pipefail
cd "$(dirname "$0")"
PASS=${CMK_PASSWORD:-wexford-lab-2026}
API=http://localhost:8080/wexford/check_mk/api/1.0
AUTH="Authorization: Bearer cmkadmin $PASS"

if ! docker info >/dev/null 2>&1; then  # cloud sessions don't start dockerd
  (dockerd >/tmp/dockerd.log 2>&1 &)
  for _ in $(seq 30); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi
docker compose up -d

for site in wexford:8080 remote1:8081; do
  echo -n "waiting for ${site%%:*}"
  until curl -sf -o /dev/null "http://localhost:${site##*:}/${site%%:*}/check_mk/login.py"; do echo -n .; sleep 3; done
  echo " up"
done

# Agent: install the site's own package and query it directly instead of over TCP.
docker compose exec -T wexford bash -c 'dpkg -i /omd/sites/wexford/share/check_mk/agents/check-mk-agent_*_all.deb >/dev/null'
docker compose exec -T -u wexford wexford bash -c 'cat > ~/etc/check_mk/conf.d/lab-agent.mk' <<'MK'
datasource_programs = [{"id": "lab-agent", "condition": {}, "value": "/usr/bin/check_mk_agent"}] + datasource_programs
MK

curl -sf -o /dev/null -X POST "$API/domain-types/host_config/collections/all" -H "$AUTH" \
  -H "Content-Type: application/json" -d '{"folder":"/","host_name":"lab-linux-01","attributes":{"ipaddress":"127.0.0.1"}}' \
  || echo "lab-linux-01 already exists"
docker compose exec -T -u wexford wexford bash -lc 'cmk -II lab-linux-01 >/dev/null && cmk -O >/dev/null && sleep 5 && lq "COMMAND [$(date +%s)] SCHEDULE_FORCED_HOST_SVC_CHECKS;lab-linux-01;$(date +%s)"'  # so screenshots show results, not PEND

# The books' IT staff: Bob owns monitoring (admin), Larry covers Windows and network (user).
for u in "bob Bob admin" "larry Larry user"; do
  set -- $u
  curl -sf -o /dev/null -X POST "$API/domain-types/user_config/collections/all" -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"username\":\"$1\",\"fullname\":\"$2\",\"roles\":[\"$3\"],\"auth_option\":{\"auth_type\":\"password\",\"password\":\"$PASS\"}}" \
    || echo "could not create user $1 (already exists?)"
done

echo "wexford:   http://localhost:8080/wexford/  (bob, larry or cmkadmin / $PASS)"
echo "remote1: http://localhost:8081/remote1/"
