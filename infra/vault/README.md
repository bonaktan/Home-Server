# Vault: home server and remote Transit seal

This is an opt-in, single-node deployment on each machine, with no HA. The remote Vault's Raft data and Transit key are required to open the primary; primary recovery shares cannot replace them. Do not put existing infrastructure secrets into Vault as part of this setup. Select MPC and zero-knowledge libraries separately and verify the exact algorithms and key operations before creating production keys.

## Prerequisites

- A remote Linux Docker host with a stable VPN interface and name. The home host's containers must be able to resolve and reach that name on TCP 8200 through the VPN. Firewall the remote VPN interface and Docker's forwarding path so only the home host and authorized operators can reach port 8200; binding a Docker port to an interface alone is not a complete firewall. Do not forward it through nginx or Cloudflare.
- A trusted CA and separate server certificates. The primary certificate must contain DNS SAN `vault`; the remote certificate must contain the VPN name used in both configuration files. Distribute CA certificates to clients. Do not disable TLS verification. Renew certificates before expiry and restart the relevant server after replacement.
- Protected off-host backup storage, an encryption recipient whose private key is stored independently, and operators who can hold separate key shares. Provision and test these before storing production secrets.
- The Vault CLI matching the pinned server version, or a trusted client container. The examples below use `vault` from a secure operator environment with `VAULT_ADDR`, `VAULT_CACERT` and an appropriate `VAULT_TOKEN` set. Never copy secrets or initialization output into this repository, shell history, tickets, or logs. Use interactive prompts or protected files; restrict administrator access to Docker and the hosts, as host administrators can read all container credentials.

## Configure the hosts

Copy `remote/compose.yaml` to the remote machine in its own directory. On each host create the private configuration and audit directories with restrictive permissions. Copy the respective `vault.hcl.example` to `/etc/vault-unseal/vault.hcl` or `/etc/vault-home/vault.hcl`, replace `REMOTE_VPN_NAME` with the resolvable VPN DNS name, and install `server.crt` and `server.key` in the same directory. On the home host also install the remote server's CA as `/etc/vault-home/remote-ca.crt`. The primary server certificate and key are under `/etc/vault-home`; its client CA must be distributed separately. Ensure the Vault process can read the files and write its data volume and `/vault/audit` directory. Vault's Docker image normally uses UID/GID 100:100; verify this for the pinned image and set ownership accordingly. Keep private keys and the token readable only by the Vault service and host administrators.

If the remote logs `A storage backend must be specified`, check that `/etc/vault-unseal/vault.hcl` is a nonempty, readable **file** containing the `storage "raft"` block from `remote/vault.hcl.example`. Older Compose configurations could create a directory at that path when the file was missing. If it is an empty directory, remove that empty directory, install the template as the file, configure the VPN name and certificates, then recreate the container with `docker compose up -d --force-recreate vault`. Do not initialize Vault again if its data volume already contains initialized data.

Raft with `disable_mlock = true` requires encrypted swap or swap disabled: Vault cannot lock its entire memory in this mode. Each Compose project uses its own named `vault-data` Docker volume. Startup sets the volume root to UID/GID 100:100 and mode 0700 before dropping privileges. Never remove these volumes or run `docker compose down -v` during ordinary shutdown or upgrade.

If either Vault was previously initialized using `/var/lib/vault-home` or `/var/lib/vault-unseal`, switching to a new volume does not move the existing Raft data. Before changing mounts, take and verify an encrypted snapshot, stop the affected Vault, and migrate its data to the corresponding new volume or restore the snapshot using the recovery procedure below. Verify the recovered Vault before retiring the original data. Never initialize an empty replacement volume as if it contained the old Vault.

On the remote host, set `VAULT_VPN_IP` to its actual VPN interface IP and start the service:

```sh
export VAULT_VPN_IP=REMOTE_VPN_IP
docker compose up -d
```

From a VPN-connected operator environment set `VAULT_ADDR=https://REMOTE_VPN_NAME:8200` and `VAULT_CACERT` to the remote CA. Check certificate verification and `vault status`. Initialize once using `vault operator init` in a secure session. The default five Shamir shares require three to unseal; distribute shares to independent custodians and retain the initial root token in a separate offline secure location. Each custodian runs `vault operator unseal` and enters a share at the prompt. Verify `vault status` reports unsealed.

Enable audit before using the server, then create the seal key and token:

```sh
vault audit enable file file_path=/vault/audit/audit.log
vault secrets enable transit
vault write -f transit/keys/home-unseal
vault policy write home-unseal /secure/path/home-unseal.hcl
vault token create -orphan -policy=home-unseal -period=24h
```

Copy `policies/home-unseal.hcl` to the secure operator environment for the policy command. The default token policy supplies self-renewal; the custom policy allows only encryption and decryption with this key. Store the resulting token in `/etc/vault-home/transit-token` on the home host, mode 0400, owned by the Vault UID. Transfer it through a secure channel. It must contain only the token. Record its accessor securely for monitoring/revocation, not in Git. This orphan periodic token is renewed by the primary while it is running; monitor its remaining TTL and renewal errors. If the primary is stopped longer than its period, or the token is revoked, issue a replacement before starting it. Tune the period and monitoring for the expected outage window. Never delete the Transit key or disable old key versions; old ciphertext may need them.

Start the primary from the repository root with `docker compose --profile vault up -d vault`. Its network is named `home_vault_clients` and it has no host-published port. An operator CLI can run in a separate container attached to that network, with the primary CA mounted read-only and `VAULT_ADDR=https://vault:8200`; keep tokens out of command arguments and container images. Verify TLS and `vault status`, then initialize the primary once. Its initialization returns **recovery shares**, not manual unseal shares; distribute them to independent custodians and keep the initial root token separately offline. Enable its audit device immediately:

```sh
vault audit enable file file_path=/vault/audit/audit.log
vault secrets enable -path=secret kv-v2
vault secrets enable transit
vault auth enable approle
```

## Internal web UI

The primary template enables the UI. If `/etc/vault-home/vault.hcl` was copied before this change, set `ui = true` in that file and restart the primary after confirming the remote Transit seal is available. Install the CA that issued the primary's `vault` certificate as `/etc/vault-home/primary-ca.crt`, readable by nginx, and set `VAULT_NGINX_CA_FILE=/etc/vault-home/primary-ca.crt` in the Compose environment or `.env`. The certificate must verify for DNS name `vault`; nginx verifies it on every upstream connection. Until the CA is configured, nginx uses the temporary internal web certificate as a fallback trust file so other sites can start; the Vault upstream will fail verification unless its certificate is trusted by that file.

Point `vault.internal.bonnybonnybonaktan.xyz` in internal DNS at the home server and ensure nginx's internal certificate covers that name. The base Compose stack uses the temporary self-signed certificate in `infra/certs/internal`; browsers will warn unless they trust it. Production uses the certificate mounted by `compose.production.yaml`. The route permits `192.168.1.0/24`, matching the existing pgAdmin route; adjust the allowlist in `infra/nginx/conf.d/vault.conf` if the authorized LAN differs. Do not add a public Cloudflare route. After the primary CA and nginx certificates are in place, recreate nginx and start Vault:

```sh
docker compose --profile vault up -d nginx vault
```

Include `-f compose.yaml -f compose.production.yaml` when using the production certificate mounts. Recreate nginx after changing `VAULT_NGINX_CA_FILE` so Docker remounts the selected file. Visit `https://vault.internal.bonnybonnybonaktan.xyz/ui/` from the authorized LAN. Vault authentication still applies; nginx can reach the full Vault API as well as the UI, so protect the LAN and nginx host accordingly.

Both audit directories must already exist and be writable. Protect, monitor, rotate and ship audit logs to a separate protected destination. File audit logs can contain sensitive metadata. Vault refuses requests when every enabled audit device is unavailable, so alert on write errors and full disks. Rotate by moving the file and signaling Vault to reopen it according to the Vault audit documentation; do not truncate an active file. Revoke initial root tokens after establishing and testing separately held administrative access and recovery procedures.

## Application access

For each application, replace `APP` in `policies/application.hcl.example` with its unique lowercase name, save the policy outside Git, and run on the primary:

```sh
vault policy write APP /secure/path/APP.hcl
vault write -f transit/keys/APP
vault write auth/approle/role/APP token_policies=APP token_no_default_policy=true token_ttl=1h token_max_ttl=4h secret_id_ttl=24h secret_id_num_uses=1
vault read auth/approle/role/APP/role-id
vault write -f auth/approle/role/APP/secret-id
```

Deliver each RoleID and short-lived SecretID separately through a secure channel or response wrapping; never commit them, include them in images or put them in Compose files. Provision a new SecretID when needed. Restrict the application to its own KV subtree and dedicated Transit key. The example grants KV write/delete and Transit encrypt/decrypt; reduce it if the application needs less. Transit keys default to non-exportable; do not enable export. Provision policies and roles for actual applications rather than sharing one role. Applications join the network with:

```yaml
networks:
  vault_clients:
    external: true
    name: home_vault_clients
```

Attach only authorized services to `vault_clients`; use `https://vault:8200` and verify the primary CA. Network membership is not authentication. AppRole login uses `auth/approle/login`; renew or reacquire application tokens before expiry.

## Restart, rotation and outage

1. After both hosts restart, restore VPN connectivity, start the remote Vault and have custodians unseal it. Confirm its TLS endpoint and Transit token are available, then start or restart the primary and verify it becomes unsealed. Starting the primary first may leave it sealed; after the remote is available check logs and restart the primary if necessary.
2. Restarting the primary alone should automatically unseal it while the remote and token remain available. An outage during startup prevents unseal; recovery shares cannot bypass the Transit seal. Restore connectivity and the remote Vault, then retry/restart. Do not initialize either Vault again to fix an outage.
3. To replace the seal token, create a new orphan periodic token with the same policy on the unsealed remote, securely replace the primary token file, restart the primary and verify auto-unseal and renewal. Only then revoke the old token by accessor. If the old token has already expired, issue a new one before restarting. Avoid atomic file replacement problems by mounting the directory, as configured here.
4. If the remote Transit key is rotated, retain every old key version and take a fresh remote snapshot before relying on new ciphertext. Never rotate away the ability to decrypt older snapshots.

## Backups and recovery drills

Vault Community does not schedule Raft snapshots. On **each** host, configure an external scheduler and alerting to run `vault operator raft snapshot save` with a dedicated token allowed to read `sys/storage/raft/snapshot`. Encrypt each snapshot with an independently held backup key before transferring it off host, use authenticated transport, retain multiple dated versions, and monitor failures and restore points. Do not use the Vault being backed up to hold the only decryption key for its own backup. Protect and back up the configuration, CA and TLS material separately; secure token material separately and recreate it when appropriate. Schedule and destination must be configured for the actual environment; no backup is automatic just by deploying this stack.

After initial setup and periodically thereafter, perform an isolated restore drill using separate hosts/volumes and no production routes. Follow HashiCorp's [Raft restore procedure](https://developer.hashicorp.com/vault/docs/sysadmin/snapshots/restore): initialize a temporary remote Vault, restore its snapshot with `vault operator raft snapshot restore -force`, wait for restoration to complete, and unseal it with the **original remote** Shamir shares. Confirm the restored Transit key includes the needed historical versions. A snapshot also restores the old token state: use a valid restored seal token, or create a new token against the restored remote Vault and point the isolated primary at it.

Initialize a temporary primary with the **same Transit seal/key and a valid token from the restored remote**, then restore the primary snapshot with `vault operator raft snapshot restore -force`. Wait for post-unseal setup to complete and restart if required. Confirm the restored primary unseals via the restored remote key, then authenticate and read a known non-production test secret. Never force-restore into production as a drill. Record the snapshot dates, success, and time taken; repeat after key rotations and configuration changes. Snapshots must be compatible: the restored remote snapshot must contain all key versions required by the primary snapshot.

## Acceptance checks

Before production use, validate both Compose files, check VPN reachability and certificate verification, initialize and unseal as above, and exercise primary-only restart, both-host restart, and VPN failure/recovery. From a separate application Compose project, verify AppRole login, allowed KV access, denial of another application's subtree, and encrypt/decrypt using its non-exportable Transit key. Complete and record the isolated restore drill for both snapshots. These tests require the actual hosts, VPN, certificates, credentials and backup destination; configuration alone does not demonstrate recovery.
