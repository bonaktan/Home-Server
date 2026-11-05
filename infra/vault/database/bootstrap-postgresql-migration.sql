-- Run as an administrator in POSTGRES_DB, after V1/V2. Not a Flyway migration:
-- it establishes the identity that will run later Flyway migrations.
DO $bootstrap$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vault_postgresql_migration') THEN
        CREATE ROLE vault_postgresql_migration NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
    EXECUTE format('GRANT CONNECT, CREATE ON DATABASE %I TO vault_postgresql_migration', current_database());
END;
$bootstrap$;
GRANT USAGE, CREATE ON SCHEMA public TO vault_postgresql_migration;
ALTER TABLE IF EXISTS public.flyway_schema_history OWNER TO vault_postgresql_migration;
GRANT vault_postgresql_migration TO vault_manager WITH ADMIN TRUE, INHERIT FALSE, SET FALSE;
