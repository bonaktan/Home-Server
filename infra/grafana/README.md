# Home Server monitoring

Grafana provisions three dashboards in the **Home Server** folder: Containers,
Infrastructure, and Nginx. They use the local Prometheus and Loki data sources.
Container resource metrics come from cAdvisor; logs come from Promtail's Docker
discovery. The Nginx dashboard uses the internal stub-status exporter for
connections and requests and Docker logs for response codes and latency.
Registry access logging is disabled, so its requests are not included in the
log-derived Nginx panels or 5xx alert.

The provisioned alert rules evaluate every minute. They cover scrape failures,
host CPU, memory and disk, container memory limits, database connectivity,
Vault sealing, Nginx availability, and Nginx 5xx responses. Resource alerts
need sustained breaches to fire. A stopped container does not necessarily leave
a cAdvisor series, so its absence cannot be detected by the container memory
alert; scrape alerts only cover configured Prometheus targets. The classic alert
conditions group matching series into one alert per rule; inspect the dashboard
to identify the affected target, filesystem or container.

Grafana uses its existing notification policy and contact point for delivery.
Configure and test a reachable contact point in **Alerting → Contact points**
and route alerts to it under **Notification policies**. Provisioning the rules
alone does not configure an external recipient. No-data results are treated as
OK for these rules; scrape-target alerts cover missing metrics only while
Prometheus itself is reachable. Monitor Grafana and Prometheus externally if
notifications must survive a failure of the monitoring stack.

Apply the Compose configuration for the environment in use, including the
Nginx exporter, then restart Nginx, Prometheus and Grafana to load their new
configuration. Check **Connections → Data sources**, **Alerting → Alert rules**,
and the dashboards after a few scrape intervals. Provisioned dashboards and
rules are managed by files in this directory; edit the files to keep changes
across restarts. Existing Prometheus-Bonny and Loki-Bonny sources receive stable
UIDs used by these dashboards and rules; check any existing dashboards that
reference their previous UIDs after applying the change.
