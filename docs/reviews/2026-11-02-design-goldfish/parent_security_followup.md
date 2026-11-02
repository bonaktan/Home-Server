# Parent verification of interrupted security-review leads

**Status:** Limited source/documentation follow-up by the parent, not a completed independent Goldfish security review. The dedicated security reviewer failed initially at the usage limit and again on its single retry at model capacity. Its interim messages are not counted as a final report or clean review.

These two leads were checked against repository configuration and official documentation. No attack, service shutdown, log injection or live-server probe was performed. Runtime exploitability is not asserted. References to the design use the frozen 484-line snapshot in this directory.

## PSEC-01 — Major — Proxy-header trust can defeat the intended LAN-only ACL

**Scope:** frozen design lines 288–290 and 296; repository `infra/nginx/nginx.conf:68`, `infra/nginx/conf.d/pihole.conf:17`, `infra/nginx/conf.d/pgadmin.conf:17`, and the nginx/cloudflared/pterodactyl network memberships in `compose.yaml`.

The checked-in nginx configuration trusts `172.16.0.0/12` to supply `CF-Connecting-IP`. The internal virtual hosts allow the LAN source range and deny other sources. nginx shares an infrastructure network with the panel and also joins the Pterodactyl network. A reachable untrusted peer whose actual source falls in the trusted range can supply a false LAN client address. The real-IP module replaces the address used for subsequent request processing; the [official directive documentation](https://nginx.org/en/docs/http/ngx_http_realip_module.html) establishes that trust behavior.

This is a concrete unsafe trust configuration in the repository, conditional on the effective peer addressing/reachability. It is not a verified live compromise. Repairing only the Pi-hole upstream does not address the header-trust boundary.

**Correction/proof:** distinguish trusted ingress peers from application peers, constrain accepted replacement-address headers accordingly, and validate LAN restrictions against the correct connection identity. In an isolated fixture, have an untrusted peer send a forged LAN header and confirm denial. Include IPv6 and the actual container address ranges. Select the exact networking/configuration mechanism explicitly; do not silently broaden internal access or assume every bridge peer is a trusted proxy.

## PSEC-02 — Major — A Loki port grant does not establish query-only authority

**Scope:** frozen design lines 274–276 and 296; second-host datasource/query-path contract. The second-host deployment does not exist yet, so this finding concerns the proposed boundary rather than a proven live exposure.

Restricting a backend port to the main host controls who connects, not which Loki API operations it may invoke. For a monolithic `all` deployment, the documented HTTP surface includes ingestion and shutdown as well as queries. `/ingester/shutdown` accepts GET and POST and can terminate the process; [the API reference](https://grafana.com/docs/loki/latest/reference/loki-http-api/) documents these operations. The current repository uses `auth_enabled: false`; setting that flag true would not by itself add authenticated read-only roles. [Loki's authentication documentation](https://grafana.com/docs/loki/latest/operations/authentication/) distinguishes tenant headers from an authentication layer.

If the intended trust is query-only, a compromised main-host process allowed to that port could otherwise inject logs or interrupt the second host's local collection backend. Local collection during an ordinary link outage does not establish protection against such an authorized client.

**Decision/proof:** either explicitly accept the main host's broader backend authority, or define a restricted query interface that separates it from local ingestion/administration. Enforce the actual allowed methods and paths; a blanket GET allowance is insufficient for the documented shutdown endpoint. Test query success and denial of writes/control operations from the exact permitted principal. This may require an architecture decision before file-level planning.

## Evidence and limits

Safe selected reads confirmed real-IP/ACL directives, nginx/cloudflared/panel network names, and Loki's boolean auth/listen settings without printing their environment values. The parent had checked exact-path graph coverage for Compose/Loki/nginx; nginx parsing was unusable, so source directives were read directly. The frozen-input manifest still matched at resume. Primary documentation was checked on 2026-11-02. No private runtime address allocation, firewall rules, loaded nginx module/version or second-host endpoint behavior was newly verified.

No architectural fixes or credential rotations were applied. These parent findings must remain separate from native reviewer counts and from any claim of a full independent security audit.
