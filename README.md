# Home-Server - Infrastructure
A Centralized Configuration for Home-Server Infrastructure

## Principles
* Single Git repository as the source of truth
* No service is configured manually — everything is code
* Shared infrastructure (database, proxy, tunnel, observability) runs once
* Each application service is isolated but connects to shared resources
* Secrets are encrypted at rest and never committed in plaintext

## Current infrastructure

The Compose configuration includes the services listed in the version history above, plus:

- **MariaDB and Flyway** for the Pterodactyl database and its migrations.
- **Pterodactyl Panel, Redis and Wings** for managing hosted servers. Wings uses the host Docker socket to manage containers.
- **Prometheus, node exporter and cAdvisor** for host and container metrics.
- **Promtail and Loki** for collecting Docker container logs, with **Grafana** for viewing metrics and logs. Grafana also has remote Prometheus and Loki data sources configured.
- **nginx static sites and application proxies** for the configured websites and external application backends.

The base stack uses separate bridge networks for shared access, internal services and databases, plus an external `pterodactyl_nw` network. Pi-hole and node exporter use the host network. Production overrides mount Let's Encrypt certificates; staging overrides expose additional service ports.

## Service interactions

The diagram shows configured connections; external backends and the Cloudflare tunnel configuration are managed outside this Compose file. The pgAdmin proxy currently targets `database_pgadmin`, while the Compose service is named `postgresql_pgadmin`, so that route requires alignment to work.

```mermaid
flowchart LR
    subgraph Networking[General networking]
        Cloudflare[Cloudflare tunnel]
        Nginx[nginx]
        Pihole[Pi-hole DNS]
    end
    subgraph Databases[Databases]
        PgAdmin[pgAdmin]
        Postgres[PostgreSQL]
        PgFlyway[PostgreSQL Flyway]
        MariaDB
        MariaFlyway[MariaDB Flyway]
    end
    subgraph Hosting[Pterodactyl hosting]
        Panel[Pterodactyl Panel]
        Redis[Redis cache]
        Wings[Pterodactyl Wings]
        Docker[Docker hosted containers]
    end
    subgraph Images[Image registry]
        RegistryUI[Registry UI]
        Registry[Docker Registry]
    end
    subgraph Observability[Observability]
        Prometheus
        NodeExporter[Node exporter]
        cAdvisor
        Promtail
        Loki
        Grafana
        Remote[Remote Prometheus and Loki]
    end
    Users --> Cloudflare
    Cloudflare --> Nginx[nginx]
    Users --> Nginx
    LAN[Home network] --> Pihole[Pi-hole DNS]
    Nginx --> Pihole
    Nginx -. pgAdmin route .-> PgAdmin[pgAdmin]
    PgAdmin --> Postgres[PostgreSQL]
    PgFlyway[PostgreSQL Flyway] --> Postgres
    Nginx --> Panel[Pterodactyl Panel]
    Panel --> MariaDB
    Panel --> Redis[Redis cache]
    Panel --> Wings[Pterodactyl Wings]
    Wings --> Docker[Docker hosted containers]
    MariaFlyway[MariaDB Flyway] --> MariaDB
    Nginx --> RegistryUI[Registry UI]
    Nginx --> Registry[Docker Registry]
    RegistryUI --> Registry
    Nginx --> Sites[Static sites and external application backends]
    Nginx --> Grafana
    Nginx --> Prometheus
    Prometheus --> NodeExporter[Node exporter]
    Prometheus --> cAdvisor
    Docker --> Promtail
    Promtail --> Loki
    Grafana --> Prometheus
    Grafana --> Loki
    Grafana --> Remote[Remote Prometheus and Loki]
```
