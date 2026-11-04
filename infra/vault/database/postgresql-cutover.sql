-- Apply only AFTER all application deployments use database/creds/*.
-- Preserve these roles and their ownership/grants for dynamic memberships.
ALTER ROLE "ITskolar-System_Admin" NOLOGIN PASSWORD NULL;
ALTER ROLE "ITskolar-System_Worker" NOLOGIN PASSWORD NULL;
ALTER ROLE "Skybridge-Airways_Admin" NOLOGIN PASSWORD NULL;
ALTER ROLE "Skybridge-Airways_Worker" NOLOGIN PASSWORD NULL;
