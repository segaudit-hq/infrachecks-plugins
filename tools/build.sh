#!/usr/bin/env bash
# build.sh PACK [CHECKMK_VERSION]
# Builds one pack's MKP in a fresh Checkmk Community container,
# removes it, installs it again from the MKP file, then runs the
# pack's end-to-end test. The MKP lands in dist/.
# KEEP=1 leaves the container running for a look around.
set -euo pipefail
cd "$(dirname "$0")/.."
pack=${1:?usage: build.sh PACK [CHECKMK_VERSION]}
ver=${2:-2.5.0p18}
[ -d "packs/$pack" ] || { echo "no pack $pack"; exit 1; }
case $ver in  # the image was renamed in 2.5
2.4*) image=mirror.gcr.io/checkmk/check-mk-raw:$ver ;;
*) image=mirror.gcr.io/checkmk/check-mk-community:$ver ;;
esac
site=ictest
pass=ictest-password-2026
c=ic-build-$pack-$$
run() { docker exec -i -u "$site" "$c" bash -lc "$1"; }

docker run -d --name "$c" -e CMK_SITE_ID=$site \
    -e CMK_PASSWORD=$pass \
    --tmpfs "/opt/omd/sites/$site/tmp:uid=1000,gid=1000" \
    "$image" >/dev/null
[ "${KEEP:-}" = 1 ] || trap 'docker rm -f "$c" >/dev/null' EXIT
echo -n "waiting for the site"
until docker exec "$c" curl -sf -o /dev/null \
    "http://localhost:5000/$site/check_mk/login.py"; do
    echo -n .; sleep 3
done
echo " up ($ver)"

# Package the files the way a developer would.
docker cp "packs/$pack/files/." "$c:/omd/sites/$site/local/"
docker exec "$c" chown -R "$site:$site" "/omd/sites/$site/local"
python3 -c 'import json, sys; print(repr(json.load(open(sys.argv[1]))))' \
    "packs/$pack/manifest.json" | run 'cat > ~/tmp/manifest'
run 'mkp package ~/tmp/manifest'
name=$(python3 -c 'import json, sys; m = json.load(open(sys.argv[1])); print(m["name"] + "-" + m["version"])' "packs/$pack/manifest.json")
mkdir -p dist
docker cp "$c:/omd/sites/$site/var/check_mk/packages_local/$name.mkp" dist/

# Install it the way a user would.
run "mkp disable ${name%-*} ${name##*-} && mkp remove ${name%-*} ${name##*-}"
docker cp "dist/$name.mkp" "$c:/tmp/$name.mkp"
docker exec "$c" chmod 644 "/tmp/$name.mkp"
run "mkp add /tmp/$name.mkp && mkp enable ${name%-*} ${name##*-}"
run "mkp list | grep -q '^${name%-*} ' && cmk -R >/dev/null"
echo "installed $name"

# Test hosts: ic-test-1 (the container's own agent, so it has
# real services), and ic-test-2 in host group ic-patch.
docker exec "$c" bash -c "dpkg -i /omd/sites/$site/share/check_mk/agents/check-mk-agent_*_all.deb >/dev/null 2>&1"
docker cp tools/test-site.sh "$c:/tmp/test-site.sh"
docker cp "packs/$pack/test.sh" "$c:/tmp/test.sh"
docker exec "$c" chmod 755 /tmp/test-site.sh /tmp/test.sh
run "CMK_PASSWORD=$pass bash /tmp/test-site.sh"
run "bash /tmp/test.sh"
echo "PASS $pack on $ver"
