#!/usr/bin/env python3
"""Persist advisory state for one trusted backup-usage observation.

This is a local state primitive, not a collector or an alerting service.  The
installed caller must supply measurements and policy from trusted sources.
"""
import fcntl
import json
import os
import secrets
import stat
import sys
import time

from backup_status import FIELDS, LIMIT, STATES, classify, unique_object

STATE_DIR = "/var/lib/home-server/backup-status"
DESTINATIONS = {"r2", "second_server"}
INPUT_FIELDS = FIELDS - {"last_known", "now"}


def checked_file(fd, owner):
    info = os.fstat(fd)
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != owner or
            info.st_mode & 0o077 or info.st_nlink != 1):
        raise ValueError("unsafe status file")


def read_previous(directory, destination, owner):
    try:
        fd = os.open(destination + ".json", os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
                     dir_fd=directory)
    except FileNotFoundError:
        return {"last_known": "unknown", "observed_at": None, "used_bytes": None,
                "state": "unknown", "source_observed_at": None, "evaluated_at": None,
                "reported_used_bytes": None, "budget_bytes": None}
    with os.fdopen(fd, "rb") as stream:
        checked_file(stream.fileno(), owner)
        raw = stream.read(LIMIT + 1)
    if len(raw) > LIMIT:
        raise ValueError("status file too large")
    state = json.loads(raw, object_pairs_hook=unique_object)
    if (not isinstance(state, dict) or set(state) != {"last_known", "observed_at", "used_bytes", "state", "source_observed_at", "evaluated_at", "reported_used_bytes", "budget_bytes"} or
            state["last_known"] not in STATES or state["state"] not in STATES | {"stale"} or
            any(value is not None and (type(value) is not int or value < 0)
                for value in (state["observed_at"], state["used_bytes"],
                              state["source_observed_at"], state["evaluated_at"], state["reported_used_bytes"])) or
            (state["budget_bytes"] is not None and
             (type(state["budget_bytes"]) is not int or state["budget_bytes"] < 1)) or
            ((state["observed_at"] is None) != (state["used_bytes"] is None))):
        raise ValueError("invalid status file")
    return state


def save(directory, destination, state):
    name = "." + destination + "." + secrets.token_hex(16) + ".tmp"
    fd = os.open(name, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
                 0o600, dir_fd=directory)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(json.dumps(state, separators=(",", ":")).encode() + b"\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, destination + ".json", src_dir_fd=directory, dst_dir_fd=directory)
        os.fsync(directory)
    finally:
        try:
            os.unlink(name, dir_fd=directory)
        except FileNotFoundError:
            pass


def observe(path, destination, observation, now, owner):
    if destination not in DESTINATIONS or not isinstance(observation, dict) or set(observation) != INPUT_FIELDS:
        raise ValueError("invalid status request")
    directory = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(directory)
        if info.st_uid != owner or info.st_mode & 0o022:
            raise ValueError("unsafe status directory")
        lock = os.open(destination + ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC,
                       0o600, dir_fd=directory)
        try:
            checked_file(lock, owner)
            fcntl.flock(lock, fcntl.LOCK_EX)
            previous = read_previous(directory, destination, owner)
            current = dict(observation, now=now, last_known=previous["last_known"])
            result = classify(current)
            observed_at = observation["observed_at"]
            if (observed_at is not None and previous["observed_at"] is not None and
                    observed_at < previous["observed_at"]):
                result = {"state": "stale", "last_known": previous["last_known"]}
            elif (observed_at is not None and observed_at == previous["observed_at"] and
                  observation["used_bytes"] != previous["used_bytes"]):
                result = {"state": "unknown", "last_known": previous["last_known"]}
            accepted = result["state"] in {"ok", "warning", "exceeded"}
            save(directory, destination, {
                "last_known": result["last_known"],
                "observed_at": observed_at if accepted else previous["observed_at"],
                "used_bytes": observation["used_bytes"] if accepted else previous["used_bytes"],
                "state": result["state"], "source_observed_at": observed_at, "evaluated_at": now,
                "reported_used_bytes": observation["used_bytes"], "budget_bytes": observation["budget_bytes"],
            })
            return {"destination": destination, "state": result["state"],
                    "last_known": result["last_known"], "observed_at": observed_at,
                    "used_bytes": observation["used_bytes"], "budget_bytes": observation["budget_bytes"],
                    "evaluated_at": now}
        finally:
            os.close(lock)
    finally:
        os.close(directory)


def verify_production_parents():
    directory = os.open("/", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        for component in ("var", "lib", "home-server", "backup-status"):
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                            dir_fd=directory)
            os.close(directory)
            directory = child
            info = os.fstat(directory)
            if info.st_uid != 0 or info.st_mode & 0o022:
                raise ValueError("unsafe status directory ancestor")
    finally:
        os.close(directory)


def main():
    try:
        if os.geteuid() != 0 or len(sys.argv) != 2:
            raise ValueError("root and a destination are required")
        verify_production_parents()
        raw = sys.stdin.buffer.read(LIMIT + 1)
        if len(raw) > LIMIT:
            raise ValueError("input too large")
        result = observe(STATE_DIR, sys.argv[1], json.loads(raw, object_pairs_hook=unique_object),
                         int(time.time()), 0)
    except (OSError, TypeError, ValueError, UnicodeError):
        print("backup status persistence failed", file=sys.stderr)
        return 2
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
