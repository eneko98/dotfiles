#!/usr/bin/env python3
"""Per-app cgroup stats for the overview.

Prints one JSON line per second, one entry per app scope, and nothing else:

    {"app-Hyprland-kitty-6bb512da.scope": {"mem": 51200000, "cpu": 1.2,
                                           "frozen": false, "pids": [12169]}}

`mem` is bytes, `cpu` is percent of one core since the previous line, and `pids`
is what the overview needs to answer "which app is this window?" (a window's PID
belongs to exactly one scope). Everything comes from the cgroup filesystem: no
daemon, no `systemctl` per tick, no scanning /proc.

Only the app-graphical.slice is read, so a frozen Spotify cannot inflate this
while nothing else moves. Meant to run only while the overview is open.
"""

import json
import os
import sys
import time

CGROUP_ROOT = "/sys/fs/cgroup"


def app_slice():
    """The slice uwsm puts app scopes in, as a path.

    Not every process lives under it: this helper is usually started from a
    terminal whose shell sits in `session.slice` (kitty moves its children
    there), and Quickshell itself lives one level up, in `app.slice`. So the path
    is resolved, then narrowed to `app-graphical.slice` when it exists.
    """
    roots = []

    with open("/proc/self/cgroup") as handle:
        for line in handle:
            if not line.startswith("0::"):
                continue
            path = line[3:].strip()
            for name in ("app-graphical.slice", "app.slice"):
                marker = "/" + name
                if marker in path:
                    roots.append(CGROUP_ROOT + path[:path.index(marker) + len(marker)])

    uid = os.getuid()
    roots.append("%s/user.slice/user-%d.slice/user@%d.service/app.slice"
                 % (CGROUP_ROOT, uid, uid))

    for root in roots:
        graphical = os.path.join(root, "app-graphical.slice")
        if os.path.isdir(graphical):
            return graphical
        if os.path.isdir(root):
            return root

    return None


def read(path, name):
    with open(os.path.join(path, name)) as handle:
        return handle.read()


def stats(slice_path, previous):
    """One dict per scope, plus the CPU accounting for the next call."""
    now = time.monotonic()
    out = {}
    current = {}

    for entry in os.scandir(slice_path):
        # Only the scopes uwsm makes for apps. kitty puts its children (the
        # shell) in a sibling scope of its own; that one is not "an app" and no
        # window points at it.
        if not (entry.name.startswith("app-") and entry.name.endswith(".scope")):
            continue

        try:
            memory = int(read(entry.path, "memory.current"))
            usage = int(read(entry.path, "cpu.stat").split()[1])
            frozen = read(entry.path, "cgroup.freeze").strip() == "1"
            pids = [int(pid) for pid in read(entry.path, "cgroup.procs").split()]
        except (FileNotFoundError, ProcessLookupError, IndexError, ValueError):
            continue

        cpu = 0.0
        last = previous.get(entry.name)
        if last is not None:
            delta_seconds = now - last[1]
            if delta_seconds > 0:
                cpu = round(100 * (usage - last[0]) / (delta_seconds * 1e6), 1)

        current[entry.name] = (usage, now)
        out[entry.name] = {
            "mem": memory,
            "cpu": cpu,
            "frozen": frozen,
            "pids": pids,
        }

    return out, current


def main():
    slice_path = app_slice()
    if slice_path is None:
        print("cgstat: no app slice in /proc/self/cgroup", file=sys.stderr)
        return 1

    previous = {}
    try:
        while True:
            snapshot, previous = stats(slice_path, previous)
            try:
                print(json.dumps(snapshot), flush=True)
            except BrokenPipeError:
                return 0
            time.sleep(1)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main())
