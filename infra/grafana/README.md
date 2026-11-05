# Home Server monitoring

Grafana provisions three dashboards in the **Home Server** folder: Containers,
Infrastructure, and Nginx. They use the local Prometheus and Loki data sources.
Container resource metrics come from cAdvisor; logs come from Promtail's Docker
discovery. The Nginx dashboard uses the internal stub-status exporter for
connections and requests and Docker logs for response codes and latency.
Registry access logging is disabled, so its requests are not included in the
log-derived Nginx panels or 5xx alert.

Critical alert rules evaluate every 5 minutes; warnings evaluate every 10 minutes.
Critical rules cover scrape failures, database connectivity, Vault sealing,
Nginx availability, and battery charge below 10%. Warnings cover battery charge
below 20% and resource pressure. Battery rules fire on the first low reading;
other rules retain their sustained-breach periods, so notification can take an
additional evaluation cycle after the pending period. Evaluation intervals do
not change notification repeat intervals in the existing notification policy.
The rules cover scrape failures,
host CPU, memory and disk, container memory limits, database connectivity,
Vault sealing, Nginx availability, and Nginx 5xx responses. Resource alerts
need sustained breaches to fire. A stopped container does not necessarily leave
a cAdvisor series, so its absence cannot be detected by the container memory
alert; scrape alerts only cover configured Prometheus targets. Scrape alerts
include the job and instance. All rules preserve metric labels so affected
containers and filesystems can be identified in the alert details.

The Infrastructure dashboard includes battery percentage from node-exporter's
power-supply collector, reading the host's `/sys` through `/host/sys`. The host
must expose a supported battery in `/sys/class/power_supply`; a machine without
one displays No data and does not fire battery alerts. External UPS units that
are not exposed through this interface require their own exporter.

Dashboards use readable status labels, percentage gauges, legends with latest
values, and descriptions explaining the measurements. Use the links at the top
to switch between server overview, containers, and web traffic. Battery low and
critical alerts can both fire below 10%, using the existing notification policy.

The provisioned rules directly select the existing contact point **Bonny's
Devsite / Aki's Server - Grafana Webhook**. Create or maintain that contact
point in Grafana and test it under **Alerting → Contact points**; its webhook
URLs are not stored here. Direct routing bypasses notification policy routes;
timing settings not specified by the rules inherit the default policy. No-data results are treated as
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
