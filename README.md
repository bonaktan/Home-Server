# Home-Server - Infrastructure
A Centralized Configuration for Home-Server Infrastructure

## Principles
* Single Git repository as the source of truth
* No service is configured manually — everything is code
* Shared infrastructure (database, proxy, tunnel, observability) runs once
* Each application service is isolated but connects to shared resources
* Secrets are encrypted at rest and never committed in plaintext

## Version 0.1.0
### Client Services
- \+ Registry-UI         (registry.bonnybonnybonaktan.xyz)

### Infrastructure Services
- \+ nginx              (Client Networking)
- \+ Pi-hole            (Home Network Infrastucture)

## Version 0.0.1
### Client Services
N/A

### Infrastructure Services
- \+ Registry           (Docker Image Management)
- \+ Cloudflared        (Client Networking)

### Bare Metal Software
- \+ Docker (Required - Infrastructure)
