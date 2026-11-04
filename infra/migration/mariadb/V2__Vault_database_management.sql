-- Locked until enrolled locally; no bootstrap password in Flyway history.
CREATE USER 'vault_manager'@'%' REQUIRE SSL ACCOUNT LOCK;
GRANT CREATE USER ON *.* TO 'vault_manager'@'%';
GRANT ALL PRIVILEGES ON panel.* TO 'vault_manager'@'%' WITH GRANT OPTION;
-- Exporter privileges, including MariaDB 11's replica-status collector.
GRANT SELECT, PROCESS, REPLICATION CLIENT, SLAVE MONITOR ON *.*
    TO 'vault_manager'@'%' WITH GRANT OPTION;
