# Lab

A throwaway Checkmk Community lab for plugin testing and book screenshots. It runs anywhere with Docker, including cloud sessions without virtualization.

```sh
lab/up.sh                         # central site "wexford" on :8080, remote site "remote1" on :8081
node lab/shots.js screenshots/    # every screenshot listed in lab/shots.json, 1440x900 at 2x
docker compose -f lab/compose.yaml down
```

- Pin the Checkmk version with `CMK_VERSION` (default `2.5.0p17`) so a book's screenshots match one release.
- `up.sh` adds the books' IT staff as users, `bob` (admin) and `larry` (user), with the same password as `cmkadmin`. Screenshots log in as `bob`; set `CMK_USER` to shoot as someone else.
- `up.sh` adds one monitored host, `lab-linux-01`, which is the wexford container itself.
- To add a screenshot, add a `{ name, path }` entry to `shots.json`. `path` is relative to `/wexford/check_mk/`.
- `lab/load.sh 1000` adds 1 000 load hosts (`lh00001` ...) to wexford for performance tests, such as the Kickdown pack; `lab/load.sh 0` removes them. They replay `lab-linux-01`'s agent output from a file and ping their own 127.x address. Discovery and HW/SW inventory checks are off on them, because their first run after activation is a burst no real site sees. At 1 000 hosts a stock site needs many cores; a 4-core cloud session is enough with Kickdown enabled.
- Not covered here: Windows agents, network device images and hypervisors need real VMs.
