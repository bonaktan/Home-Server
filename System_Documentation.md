# Infrastructure Documentation

> **Domain:** `bonnybonnybonaktan.xyz`  
> **Stack:** Docker Compose · Nginx · Cloudflare Tunnel · PostgreSQL · Pi-hole

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Network Topology](#network-topology)
3. [Services](#services)
   - [Cloudflare Tunnel](#cloudflare-tunnel)
   - [Nginx Reverse Proxy](#nginx-reverse-proxy)
   - [PostgreSQL Database](#postgresql-database)
   - [pgAdmin](#pgadmin)
   - [Flyway Migrations](#flyway-migrations)
   - [Pi-hole](#pi-hole)
   - [Docker Registry](#docker-registry)
   - [Registry UI](#registry-ui)
4. [DNS & Routing](#dns--routing)
5. [TLS / SSL](#tls--ssl)
6. [Security](#security)
7. [Observability & Logging](#observability--logging)
8. [Resource Limits](#resource-limits)
9. [Volumes & Persistence](#volumes--persistence)
10. [Environment Variables](#environment-variables)

---

## Architecture Overview

```
Internet
   │
   ▼
Cloudflare (CDN / DDoS protection)
   │  Cloudflare Tunnel (cloudflared)
   ▼
Nginx (reverse proxy, TLS termination)
   ├── registry.bonnybonnybonaktan.xyz      → Docker Registry + UI
   ├── pgadmin.internal.bonnybonnybonaktan.xyz → pgAdmin 4
   └── pihole.internal.bonnybonnybonaktan.xyz  → Pi-hole Web UI

PostgreSQL (shared DB, isolated network)
   └── Flyway (schema migrations, runs on startup)

Pi-hole (host network, DNS resolver for the LAN)
```

All inbound traffic is routed through Cloudflare before reaching the server. The cloudflared tunnel eliminates the need to expose ports 80/443 directly to the internet for external services.

---

## Network Topology

Three isolated Docker bridge networks are defined to enforce service separation:

| Network | Purpose | Connected Services |
|---|---|---|
| `shared_infra_net` | Public-facing traffic plane | nginx, cloudflared, pgadmin, registry, registry-ui |
| `infra_services` | Internal registry communication | registry, registry-ui |
| `shared_infra_database` | Isolated database plane | database, pgadmin, flyway |

Pi-hole runs in **host network mode** so it can bind to the host's port 53 (DNS) and act as a LAN resolver.

---

## Services

### Cloudflare Tunnel

| Property | Value |
|---|---|
| Image | `cloudflare/cloudflared:latest` |
| Container | `infra-cloudflared` |
| Network | `shared_infra_net` |

Establishes an outbound-only encrypted tunnel from the host to Cloudflare's network. No inbound firewall ports need to be opened for external-facing services. Configured via `CLOUDFLARED_TOKEN`.

---

### Nginx Reverse Proxy

| Property | Value |
|---|---|
| Image | `nginx:alpine` |
| Container | `infra-nginx` |
| Ports | `80`, `443` |
| Network | `shared_infra_net` |

Acts as the central reverse proxy and TLS termination point for all services. Key configuration highlights:

- **4 worker processes**, up to 512 connections each (`epoll`)
- **Gzip compression** enabled for text, JSON, JS, CSS, SVG (level 4, min 1 KB)
- **Rate limiting** via two zones:
  - `api_limit` — 10 req/s (used for `/v2/` registry API)
  - `general_limit` — 30 req/s (used for all web UIs)
- **Real IP passthrough** — reads `CF-Connecting-IP` header so logs show the actual client IP behind Cloudflare
- **Scan blocker** (`scanblock.conf`) — blocks dotfiles (`.env`, `.git`, `.htaccess`, etc.) and sensitive filenames (`docker-compose.yml`, `*.pem`, `id_rsa`, etc.) with a 444 (silent drop) response

Virtual host configs live in `infra/nginx/conf.d/`.

---

### PostgreSQL Database

| Property | Value |
|---|---|
| Image | `postgres:18-alpine` |
| Container | `infra-database` |
| Network | `shared_infra_database` (isolated) |
| Volume | `database-data` |

Shared relational database for all services that require persistence. Exposed **only** on the `shared_infra_database` network — not reachable from nginx or cloudflared.

Health check runs `pg_isready` every 10 seconds; dependent services wait for a healthy state before starting.

---

### pgAdmin

| Property | Value |
|---|---|
| Image | `dpage/pgadmin4` |
| Container | `infra-database_pgadmin` |
| Networks | `shared_infra_net`, `shared_infra_database` |
| URL | `https://pgadmin.internal.bonnybonnybonaktan.xyz` |

Web-based PostgreSQL administration UI. Sits on both networks so it can serve the web UI through nginx while reaching the database on the isolated network. Caching is disabled at the proxy layer (`proxy_no_cache`).

---

### Flyway Migrations

| Property | Value |
|---|---|
| Image | `flyway/flyway:10` |
| Container | `infra-database_migration` |
| Network | `shared_infra_database` |
| SQL Path | `./infra/migration/sql` |

Runs once on startup (`migrate` command) to apply versioned SQL migrations. Depends on the database health check. Connects via JDBC to `database:5432`.

---

### Pi-hole

| Property | Value |
|---|---|
| Image | `pihole/pihole:latest` |
| Container | `infra-pihole` |
| Network | `host` (host networking) |
| Timezone | `Asia/Manila` |
| URL | `https://pihole.internal.bonnybonnybonaktan.xyz` |

LAN-level DNS resolver and ad blocker. Uses host networking to bind directly to the host's port 53 (TCP/UDP). The web UI is proxied through nginx at port 8080 on `host.docker.internal`.

Requires `NET_ADMIN`, `SYS_TIME`, and `SYS_NICE` capabilities. DNS listening mode is set to `ALL` interfaces.

---

### Docker Registry

| Property | Value |
|---|---|
| Image | `registry:2` |
| Container | `infra-registry` |
| Networks | `shared_infra_net`, `infra_services` |
| Internal Port | `5000` |
| URL | `https://registry.bonnybonnybonaktan.xyz/v2/` |

Private Docker image registry with:
- **htpasswd authentication** (`./infra/registry/auth/htpasswd`)
- **Image deletion enabled**
- Health checks on the storage driver every 10 seconds
- JSON-formatted logs

Image data is persisted in the `registry-data` volume.

The nginx vhost splits traffic:
- `/v2/` → proxied to registry API (rate limited to 10 req/s, max body 1 GB for image pushes)
- `/` → proxied to Registry UI

---

### Registry UI

| Property | Value |
|---|---|
| Image | `joxit/docker-registry-ui:latest` |
| Container | `infra-registry_ui` |
| Networks | `shared_infra_net`, `infra_services` |
| URL | `https://registry.bonnybonnybonaktan.xyz` |

Web UI for browsing and managing images in the private registry. Communicates with the registry backend via the `infra_services` internal network. Image deletion is enabled.

---

## DNS & Routing

| Hostname | Visibility | Backend |
|---|---|---|
| `registry.bonnybonnybonaktan.xyz` | Public | registry-ui / registry API |
| `pgadmin.internal.bonnybonnybonaktan.xyz` | Internal | pgadmin container |
| `pihole.internal.bonnybonnybonaktan.xyz` | Internal | Pi-hole web UI (host:8080) |

The `*.internal.*` subdomain is intended for LAN-only access. TLS certificates are issued separately for the internal subdomain.

---

## TLS / SSL

| Setting | Value |
|---|---|
| Protocols | TLSv1.2, TLSv1.3 |
| Session cache | 10 MB shared, 1-day timeout |
| Session tickets | Disabled |
| HSTS | `max-age=31536000; includeSubDomains; preload` |
| Ciphers | ECDHE-ECDSA/RSA with AES-128/256-GCM |

Two certificate sets are mounted into nginx:
- `bonnybonnybonaktan.xyz` — used for public-facing services (registry)
- `internal.bonnybonnybonaktan.xyz` — used for internal services (pgadmin, pihole)

Certificates are stored in `./infra/certs/` and mounted read-only.

---

## Security

### Request Filtering

- Dotfiles and sensitive filenames are silently dropped (444) via `scanblock.conf`, included in every vhost
- `server_tokens off` hides nginx version
- `X-Powered-By` and `Server` upstream headers are stripped

### Security Headers (global)

| Header | Value |
|---|---|
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | geolocation, microphone, camera all denied |
| `Strict-Transport-Security` | 1-year, includeSubDomains, preload |

### Rate Limiting

| Zone | Rate | Burst | Used By |
|---|---|---|---|
| `api_limit` | 10 req/s | 10 | Registry `/v2/` |
| `general_limit` | 30 req/s | 20 | All web UIs |

HTTP 429 is returned on limit breach.

### Registry Auth

Registry access requires htpasswd credentials. The auth file is mounted read-only at `/auth/htpasswd` inside the container.

---

## Observability & Logging

All services use the `json-file` Docker log driver with a **10 MB / 3 file** rotation policy.

Nginx access logs are structured JSON with the following fields:

```
time, request_id, remote_addr, remote_user, request, status,
body_bytes_sent, request_time, upstream_response_time,
upstream_addr, http_referer, http_user_agent, http_x_forwarded_for
```

Logs are written to `/var/log/nginx/access.log` (access) and `/var/log/nginx/error.log` (warn level).

---

## Resource Limits

| Service | CPU Limit | Memory Limit | CPU Reserved | Memory Reserved |
|---|---|---|---|---|
| cloudflared | 1 | 256 MB | 1 | 64 MB |
| nginx | 1 | 256 MB | 1 | 64 MB |
| pihole | 1 | 512 MB | 1 | 256 MB |
| registry | 1 | 256 MB | 0.25 | 32 MB |
| registry-ui | 0.5 | 64 MB | 0.25 | 32 MB |

pgAdmin, Flyway, and the database have no explicit resource limits defined.

---

## Volumes & Persistence

| Volume | Mount | Service | Contents |
|---|---|---|---|
| `registry-data` | `/var/lib/registry` | registry | Docker image layers |
| `database-data` | `/var/lib/postgresql` | database | PostgreSQL data files |
| `./infra/pihole` | `/etc/pihole` | pihole | Pi-hole config & blocklists |
| `./infra/migration/sql` | `/flyway/sql` | flyway | SQL migration scripts |
| `./infra/registry/auth` | `/auth` | registry | htpasswd auth file |
| `./infra/registry/config.yml` | `/etc/docker/registry/config.yml` | registry | Registry config |
| `./infra/nginx/` | `/etc/nginx/` | nginx | Nginx config & vhosts |
| `./infra/certs` | `/etc/letsencrypt/...` | nginx | TLS certificates |

---

## Environment Variables

| Variable | Used By | Description |
|---|---|---|
| `CLOUDFLARED_TOKEN` | cloudflared | Cloudflare tunnel token |
| `POSTGRES_USER` | database, flyway | DB superuser username |
| `POSTGRES_PASSWORD` | database, flyway | DB superuser password |
| `POSTGRES_DB` | database, flyway | Default database name |
| `PGADMIN_EMAIL` | pgadmin | pgAdmin login email |
| `PGADMIN_PASSWORD` | pgadmin | pgAdmin login password |

All secrets are expected in a `.env` file at the project root (loaded automatically by Docker Compose).