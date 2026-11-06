#!/usr/bin/env bash
# Runs as the site user inside a build container: two test hosts
# and one host group, created through the REST API and activated.
set -euo pipefail
api=http://localhost:5000/$OMD_SITE/check_mk/api/1.0
auth="Authorization: Bearer cmkadmin $CMK_PASSWORD"
post() {
    curl -sS --fail-with-body -o /tmp/post.out -X POST \
        "$api/$1" -H "$auth" -H "If-Match: *" \
        -H "Content-Type: application/json" -d "$2" \
        || { echo "POST $1 failed: $(cat /tmp/post.out)"; exit 1; }
}
post domain-types/host_group_config/collections/all \
    '{"name": "ic-patch", "alias": "Test patch group"}'
for h in ic-test-1 ic-test-2; do
    post domain-types/host_config/collections/all \
        "{\"folder\": \"/\", \"host_name\": \"$h\",
          \"attributes\": {\"ipaddress\": \"127.0.0.1\"}}"
done
post domain-types/rule/collections/all '{"ruleset": "host_groups",
    "folder": "/", "value_raw": "\"ic-patch\"",
    "conditions": {"host_name": {"match_on": ["ic-test-2"],
                                 "operator": "one_of"}}}'
cat > ~/etc/check_mk/conf.d/ic-test-agent.mk <<'MK'
datasource_programs = [{"id": "ic-test-agent",
    "condition": {"host_name": ["ic-test-1"]},
    "value": "/usr/bin/check_mk_agent"}] + datasource_programs
MK
post domain-types/activation_run/actions/activate-changes/invoke \
    '{"force_foreign_changes": true}'
for _ in $(seq 60); do  # wait until the core knows both hosts
    # lq fails while the core restarts, so don't let it stop us
    n=$(printf 'GET hosts\nColumns: name\nFilter: groups >= ic-patch\n' \
        | lq 2>/dev/null | wc -l) || true
    [ "$n" = 1 ] && break
    sleep 2
done
[ "$n" = 1 ] || { echo "test hosts never appeared"; exit 1; }
cmk -I ic-test-1 >/dev/null || { echo "discovery failed"; exit 1; }
cmk -O >/dev/null || { echo "core reload failed"; exit 1; }
for _ in $(seq 60); do  # wait for services with metrics
    sleep 2
    lq "COMMAND [$(date +%s)] SCHEDULE_FORCED_HOST_SVC_CHECKS;ic-test-1;$(date +%s)" \
        2>/dev/null || true
    n=$(printf 'GET services\nColumns: description\nFilter: host_name = ic-test-1\nFilter: perf_data != \n' \
        | lq 2>/dev/null | wc -l) || true
    [ "$n" -gt 5 ] && exit 0
done
echo "ic-test-1 has no services with metrics"; exit 1
