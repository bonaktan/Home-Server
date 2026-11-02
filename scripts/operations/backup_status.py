#!/usr/bin/env python3
"""Classify one advisory storage observation; no storage mutation is performed.

The caller must durably retain last_known and collect destination observations.
An absent or stale observation cannot clear an earlier warning.
"""
import json
import sys

LIMIT = 4096
STATES = {"ok", "warning", "exceeded", "unknown"}
FIELDS = {"budget_bytes", "used_bytes", "observed_at", "now", "max_age_seconds", "last_known"}


def integer(value, minimum):
    return type(value) is int and value >= minimum


def classify(record):
    if not isinstance(record, dict) or set(record) != FIELDS:
        raise ValueError("invalid observation fields")
    previous = record["last_known"]
    if previous not in STATES:
        raise ValueError("invalid previous state")
    now, max_age = record["now"], record["max_age_seconds"]
    if not integer(now, 0) or not integer(max_age, 1):
        raise ValueError("invalid observation clock")
    budget, used, observed = (record[k] for k in ("budget_bytes", "used_bytes", "observed_at"))
    if ((budget is not None and not integer(budget, 1)) or
            (used is not None and not integer(used, 0)) or
            (observed is not None and not integer(observed, 0))):
        raise ValueError("invalid storage observation")
    if budget is None or used is None or observed is None:
        return {"state": "unknown", "last_known": previous}
    if observed > now:
        return {"state": "unknown", "last_known": previous}
    if now - observed > max_age:
        return {"state": "stale", "last_known": previous}
    if used * 100 >= budget * 100:
        state = "exceeded"
    elif used * 100 >= budget * 80 or (previous in {"warning", "exceeded"} and used * 100 >= budget * 75):
        state = "warning"
    else:
        state = "ok"
    return {"state": state, "last_known": state}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate field")
        result[key] = value
    return result


def main():
    try:
        data = sys.stdin.buffer.read(LIMIT + 1)
        if len(data) > LIMIT:
            raise ValueError("observation too large")
        result = classify(json.loads(data, object_pairs_hook=unique_object))
    except (ValueError, TypeError, UnicodeError):
        print("invalid backup status input", file=sys.stderr)
        return 2
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
