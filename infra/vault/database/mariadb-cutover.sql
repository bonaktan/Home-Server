-- Apply only AFTER the panel has been verified with dynamic credentials.
ALTER USER 'pterodactyl'@'%' ACCOUNT LOCK;
REVOKE GRANT OPTION ON panel.* FROM 'pterodactyl'@'%';
