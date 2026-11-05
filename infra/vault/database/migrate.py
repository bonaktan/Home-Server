#!/usr/bin/env python3
"""Run an official Flyway image with a dedicated, renewed Vault database lease."""
import argparse
import os
from pathlib import Path
import secrets
import subprocess
import sys
import threading

from configure import ROOT, Vault


def renew(vault, lease_id, duration, stop, errors):
    while not stop.wait(max(1, duration / 2)):
        try:
            lease = vault.request("sys/leases/renew", {"lease_id": lease_id})
            token = vault.request("auth/token/renew-self", {})
            duration = min(lease["lease_duration"], token["auth"]["lease_duration"])
            if duration <= 0:
                raise RuntimeError("Vault returned an expired migration credential")
        except Exception:
            errors.append("Migration credential renewal failed; stopping the job without retrying SQL")
            return


def run(vault, database, command):
    files = os.environ.get("COMPOSE_FILE", "").split(os.pathsep)
    if not all(files):
        raise ValueError("Set COMPOSE_FILE explicitly, e.g. compose.yaml:compose.production.yaml")
    compose = ["docker", "compose"]
    for file in files:
        compose += ["-f", str(Path(file).resolve())]

    role = database + "-migration"
    identity = ROOT / "infra/vault/private/approle" / role
    stop, errors = threading.Event(), []
    process = worker = None
    authenticated = False
    job_name = "infra-" + role + "-" + secrets.token_hex(8)
    code = 1
    try:
        login = vault.request("auth/approle/login", {
            "role_id": (identity / "role-id").read_text().strip(),
            "secret_id": (identity / "secret-id").read_text().strip(),
        })
        vault.token = login["auth"]["client_token"]
        authenticated = True
        credentials = vault.request("database/creds/" + role)
        username, password = credentials["data"]["username"], credentials["data"]["password"]
        duration = min(credentials["lease_duration"], login["auth"]["lease_duration"])
        if not username or not password or duration <= 0:
            raise RuntimeError("Vault returned unusable migration credentials")

        # Values enter the container environment, never command arguments or a file.
        environment = {**os.environ, "FLYWAY_USER": username, "FLYWAY_PASSWORD": password}
        environment.pop("VAULT_TOKEN", None)
        process = subprocess.Popen(
            compose + ["run", "--rm", "--no-deps", "--name", job_name,
                       "-e", "FLYWAY_USER", "-e", "FLYWAY_PASSWORD", database + "_migration", command],
            cwd=ROOT, env=environment,
        )
        worker = threading.Thread(target=renew, args=(vault, credentials["lease_id"], duration, stop, errors), daemon=True)
        worker.start()
        while process.poll() is None:
            if errors:
                raise RuntimeError(errors[0])
            stop.wait(0.2)
        code = process.returncode
        if errors:
            raise RuntimeError(errors[0])
    finally:
        stop.set()
        if process:
            # The named container is ours; never stop another migration job.
            # Also catches a Docker client interruption that left its job running.
            try:
                removed = subprocess.run(["docker", "rm", "-f", job_name], capture_output=True, timeout=30)
                if removed.returncode and process.poll() is None:
                    print(f"Could not confirm migration container stopped: {job_name}", file=sys.stderr)
            except (OSError, subprocess.SubprocessError):
                print(f"Could not clean up migration container: {job_name}", file=sys.stderr)
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        if worker:
            worker.join()
        if authenticated:
            try:
                # Revoking the parent token revokes the database lease as well.
                vault.request("auth/token/revoke-self", {})
            except Exception:
                print("Could not revoke the migration token; its existing TTL still applies", file=sys.stderr)
                if code == 0:
                    code = 1
    return code


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", choices=("postgresql", "mariadb"))
    parser.add_argument("command", nargs="?", choices=("migrate", "validate", "info"), default="migrate")
    args = parser.parse_args()
    try:
        # Never inherit an operator's privileged VAULT_TOKEN for migration work.
        raise SystemExit(run(Vault(token=""), args.database, args.command))
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error)) from None
