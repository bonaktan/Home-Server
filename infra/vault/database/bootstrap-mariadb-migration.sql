-- Run as an administrator with MARIADB_DB selected, after V1/V2.
-- The manager needs grant authority on this catalog to issue scoped migrators.
SET @migration_grant = CONCAT(
    'GRANT ALL PRIVILEGES ON `', REPLACE(DATABASE(), '`', '``'),
    '`.* TO ''vault_manager''@''%'' WITH GRANT OPTION'
);
PREPARE migration_grant FROM @migration_grant;
EXECUTE migration_grant;
DEALLOCATE PREPARE migration_grant;
