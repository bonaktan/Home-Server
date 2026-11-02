# Debian host and Pi-hole baseline

Date: 2026-11-01. Target: `home-server-alt`, identifying as `home-server`, the Atom machine. This records a bounded read-only SSH inspection for the EGM refactor. It is not a complete reconstruction of the original Debian installation or a deployed fix.

## What was compared

The investigation distinguishes repository scripts, current configuration files, effective runtime observations, and registered package conffile checksums. These sources can disagree. A modified package conffile is evidence of a difference from that installed package's registered content; it does not identify who changed it or compare the entire machine with a clean Debian 13 installation.

A read-only check considered 824 registered, non-obsolete package conffiles. Four were unreadable with the available account. Three readable files differed from their package-registered checksums:

| Package | Installed version | Changed registered conffile |
| --- | --- | --- |
| `cron-daemon-common` | `3.0pl1-197` | `/etc/crontab` |
| `openssh-server` | `1:10.0p1-7+deb13u4` | `/etc/pam.d/sshd` |
| `systemd-resolved` | `257.13-1~deb13u1` | `/etc/systemd/resolved.conf` |

This is not a list of every host customization. Dynamically generated configuration, local additions, installer decisions, package selection, and files outside this registered set require separate evidence. For example, boot arguments and driver settings below still belong in the baseline even though they do not appear in this checksum deviation list. `/etc/crontab` content and the four unreadable files were not established by this check.

## Host state and configuration

| Area | Observed state | Design implication |
| --- | --- | --- |
| OS/kernel | Debian 13; running `6.12.113+deb13-amd64`. | Record exact installed package versions and the installation baseline before constructing a repeatable host setup. |
| Hardware | Atom x5-Z8300; approximately 4 GiB RAM, consistent with the owner's hardware reference. | Central infrastructure has a small resource budget. |
| Memory snapshot | About 3,839 MiB total, 1,619 MiB available, with about 561 MiB of a 3 GiB swap partition used. | This is one point in time, not peak demand or proof that a build VM fits. Hosted builds avoid adding build contention. |
| Root/storage snapshot | About 53 GiB filesystem size, 20 GiB used and 31 GiB available; `/srv` and Docker storage resolve to that filesystem. | Account for telemetry, databases, image/cache growth, and backup staging together. |
| Boot command line | `/etc/default/grub` sets `GRUB_CMDLINE_LINUX="pcie_aspm=off"`; the running kernel command line also contains `pcie_aspm=off`. | This is an active host deviation to explain and preserve or change deliberately. The inspection did not establish why it was added; do not remove it as generic cleanup. |
| Wi-Fi driver configuration | `/etc/modprobe.d/iwlwifi.conf` contains `options iwlwifi power_save=0` and `options iwlmvm power_scheme=1`. | Record the settings and investigate their hardware/stability rationale before deciding their target state. Reading the file does not establish the effective loaded module parameter values. |
| Microcode configuration files | Intel/AMD microcode blacklist files contain `blacklist microcode`. | File contents alone do not establish whether early-boot microcode updates are applied. Check package ownership, initramfs, and runtime evidence before calling these local bugs or changing them. |
| Runtime network | `wlp1s0` is active at `192.168.1.3/24`; the default route uses Wi-Fi. The interface listing does not show the wired adapter configured by the older setup script. | The current access path differs from the static wired setup assumptions. A network refactor must preserve the real SSH route and identify the intended stable address. |
| Persisted wired configuration | `/etc/network/interfaces` declares `enx00e04c360bc4` static at `192.168.1.4/24`. | Persisted intent and active networking differ. Do not assume the `.4` address is usable. |
| Network service ownership | `networking` is active/enabled. NetworkManager is not found; systemd-networkd is inactive/disabled. | Plan against the observed network manager rather than applying a generic replacement blindly. |
| Host DNS | systemd-resolved is active/enabled. Its main configuration specifies public DNS/fallback servers, `DNSSEC=yes`, `DNSOverTLS=opportunistic`, and `DNSStubListener=no`. `/etc/resolv.conf` lists public resolvers and a Tailscale search domain. | Capture resolver ownership and the no-stub setting alongside Pi-hole's port 53 use. These values differ from a generic untouched host configuration. |
| Firewall services | `netfilter-persistent` is active/enabled; `nftables` service is inactive/disabled. The readable `/etc/nftables.conf` is a minimal ruleset containing `flush ruleset` and empty filter chains. | Service state alone does not establish the active kernel rules or which backend Docker/iptables uses. Do not load the readable file as a diagnostic or assume the firewall is absent. |
| Firewall access limits | Noninteractive reads of the live nftables/iptables rules did not succeed. Persisted `/etc/iptables/rules.v4` and `.v6` were unreadable. | Effective filtering remains a material evidence gap for the Pi-hole path and IPv6 review. No rules were flushed or changed. |
| SSH main configuration | Port 5022, public-key authentication enabled, password/keyboard-interactive authentication disabled, `PermitRootLogin prohibit-password`, PAM enabled, `PrintMotd no`. No files were listed under `/etc/ssh/sshd_config.d`. | Preserve the working access path and validate/reload deliberately in the future setup. These are file observations, not a complete `sshd -T` or authentication-policy audit. |
| APT upgrades | `20auto-upgrades` enables daily package-list updates and unattended upgrades; unattended-upgrades and its APT timers are active. | Define supported unattended package scope and reporting while keeping it separate from container image maintenance. |
| APT package hook | `/etc/apt/apt.conf.d/20listchanges` uses `DPkg::Pre-Install-Pkgs` and requests protocol version 2 on information FD 20. | The installed package already provides the integration expected by apt-listchanges. Preserve this mechanism when fixing reporting. |
| APT custom hook | `/etc/apt/apt.conf.d/05listchanges-redirect` additionally invokes `apt-listchanges --apt` from `DPkg::Pre-Invoke`, redirects output to a shared log, and suppresses failure. | The script-level hook problem is present on the running host. A replacement must address input protocol and logging without installing a competing consumer. |
| apt-listchanges settings | Text frontend, both news/changelogs, no confirmation, root email, custom seen database path. | Decide interactive display and durable reporting separately. Whether root mail is delivered was not tested. |
| Live PAM/MOTD | `/etc/pam.d/sshd` currently has `pam_motd.so motd=/run/motd.dynamic`, rather than the script's `motd_dir=/etc/update-motd.d` entry. | Do not blindly apply the repository diagnosis as though the live PAM configuration still matched it. The dynamic-output path is already configured on this host. |
| MOTD script | `/etc/update-motd.d/95-apt-changes` reads then truncates the shared apt changes log. | This still discards shared history at login; it is unsuitable as the sole durable record or a per-user acknowledgement mechanism. |
| Journald main configuration | Only the `[Journal]` section is active in the inspected main file; no journald drop-in files were listed. | Effective defaults, persistence, retention, and forwarded audit sources still need verification. This observation alone does not establish whether host logs survive reboot. |
| Additional APT repositories | Repository files exist for Docker, Tailscale, Azlux, MariaDB, Sury PHP, and Redis. | Package-source inventory extends beyond `new_setup.sh`. Actual repository contents, installed consumers, and signing configuration remain to be reviewed. |

No `/etc/docker/daemon.json` or `/etc/sysctl.conf` was found by the bounded check. The listed `/etc/sysctl.d` file was its README. These observations do not exclude settings supplied by vendor directories, kernel command line, Docker options, units, or runtime services.

## Pi-hole: narrowed failure path

Selected values were parsed from `/etc/pihole/pihole.toml` inside the existing container. Passwords, authentication material, query history, and client data were not printed.

| Check | Result |
| --- | --- |
| DNS | Port 53, listening mode `ALL`; TCP and UDP listeners are present on the host. |
| DHCP | Disabled in persisted Pi-hole configuration. |
| NTP | IPv4/IPv6 serving and synchronization enabled in persisted configuration; host UDP 123 listeners are present. |
| Webserver | Persisted port string `8080o,[::]:8080o`; the host has TCP 8080 listeners. |
| HTTP from host loopback | `http://127.0.0.1:8080/admin/` returns HTTP 200. |
| HTTP from host to its Wi-Fi address | `http://192.168.1.3:8080/admin/` returns HTTP 200. This is a host-origin request, not a test from an independent LAN client. |
| Host access to `.4` | The request to `192.168.1.4:8080` fails. The runtime interface observation does not assign that address. |
| nginx host alias | The nginx container resolves `host.docker.internal` to `172.17.0.1`. |
| nginx networks | Attached to the infrastructure ingress network and Pterodactyl network. The default `docker0` bridge is down, while its host address remains configured. |
| HTTP from nginx to configured upstream | Request to `http://host.docker.internal:8080/admin/` times out. |

The earlier hypothesis that Pi-hole was using default HTTP ports instead of 8080 is ruled out for this observed deployment. The UI itself works from the host, while the configured nginx-to-host path fails. Filtering/routing/bridge-path behavior needs investigation with effective-rule access; the inspection does not establish the exact root cause. A down default bridge alone is not proof of the cause, nor is a missing allow rule in a repository script proof of the active firewall state.

The checked-in virtual host also restricts clients to the LAN subnet. Browser access through LAN, Tailscale, or Cloudflare must be tested separately against intended policy; a direct upstream check does not validate the complete browser/TLS/access-control path.

## Certificates and scheduled operations

The existing nginx configuration passes its read-only configuration test. Public certificate metadata read through its existing mounts shows:

| Mounted certificate | Names | Observed expiry |
| --- | --- | --- |
| Public domain certificate | `bonnybonnybonaktan.xyz` and `*.bonnybonnybonaktan.xyz` | 2026-12-24 |
| Internal certificate | `*.internal.bonnybonnybonaktan.xyz` | 2026-12-24 |

Both certificates were issued by Let's Encrypt. No private key contents were read. The bounded timer listing contains no `certbot.timer`, and that unit is reported not found. The inspected renewal-hooks directory lists no files. This does not establish that renewal is missing: cron, a manually installed virtual environment, other units, and other automation were not exhaustively inspected. In particular, `/etc/crontab` is modified and its contents were not part of this check. Renewal credentials, issuance method, nginx/Wings reload behavior, and a successful renewal record remain open evidence items.

The timer listing shows APT, logrotate, dpkg metadata backup, fstrim, filesystem checks, and other system maintenance. A `dpkg-db-backup` timer protects package metadata, not application databases or Pterodactyl workloads. No conclusion about complete application-backup coverage is drawn from this bounded timer list.

## Scope and verification limits

No host settings, firewall rules, service state, package state, or container configuration were changed. No updates, renewal, recovery, or migration were run. HTTP probes only requested the Pi-hole admin page and discarded its body. Certificate inspection used public certificate files, never private keys.

The original Debian installation's package/task selections and complete history remain unknown. Effective privileged firewall rules, root cron, the four unreadable registered conffiles, loaded driver parameters, all installed firmware/microcode state, certificate automation, and complete data/backup sizing remain unverified. Convert these gaps into explicit preflight evidence items in the formal plan rather than inventing defaults.

These remote configuration/runtime paths are outside the local codebase-memory index. Findings come from direct reads and bounded runtime probes, not a remote code graph or a claim of exhaustive host coverage.
