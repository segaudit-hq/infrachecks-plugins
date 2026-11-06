# Lab

A throwaway Checkmk Community lab for plugin testing and book screenshots. It runs anywhere with Docker, including cloud sessions without virtualization.

```sh
lab/up.sh                         # central site "ridge" on :8080, remote site "remote1" on :8081
node lab/shots.js screenshots/    # every screenshot listed in lab/shots.json, 1440x900 at 2x
docker compose -f lab/compose.yaml down
```

- Pin the Checkmk version with `CMK_VERSION` (default `2.5.0p17`) so a book's screenshots match one release.
- `up.sh` adds one monitored host, `lab-linux-01`, which is the ridge container itself.
- To add a screenshot, add a `{ name, path }` entry to `shots.json`. `path` is relative to `/ridge/check_mk/`.
- Not covered here: Windows agents, network device images and hypervisors need real VMs.
