-- Password enrollment happens over the local socket, then Vault rotates it.
CREATE ROLE vault_manager NOLOGIN CREATEROLE NOSUPERUSER NOCREATEDB NOREPLICATION;
CREATE ROLE vault_postgresql_exporter NOLOGIN;
GRANT pg_monitor TO vault_postgresql_exporter;
GRANT CONNECT ON DATABASE itskolar_system TO "ITskolar-System_Admin", "ITskolar-System_Worker";
GRANT CONNECT ON DATABASE skybridge_airways TO "Skybridge-Airways_Admin", "Skybridge-Airways_Worker";

-- PostgreSQL 16+ requires ADMIN OPTION to grant existing roles to new logins.
-- The manager must not automatically inherit application privileges.
GRANT "ITskolar-System_Admin", "ITskolar-System_Worker",
      "Skybridge-Airways_Admin", "Skybridge-Airways_Worker",
      vault_postgresql_exporter TO vault_manager
      WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
