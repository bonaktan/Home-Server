ARG SERVICE_IMAGE=prometheuscommunity/postgres-exporter:latest
FROM hashicorp/vault:1.21 AS vault
FROM ${SERVICE_IMAGE} AS service
COPY --from=vault /bin/vault /bin/vault
ENTRYPOINT ["/bin/vault", "agent", "-config=/etc/vault-agent/agent.hcl"]
CMD []

FROM service AS panel
USER root
# Run cron under the same supervisor so it receives each new DB environment.
RUN sed -i '/^crond -L /d' /app/.github/docker/entrypoint.sh \
    && sed -i '/^php artisan migrate --seed --force/i php artisan config:clear' /app/.github/docker/entrypoint.sh \
    && printf '\n[program:vault-cron]\ncommand=/usr/sbin/crond -f -l 5\nautorestart=true\nstopasgroup=true\nkillasgroup=true\n' >> /etc/supervisord.conf
