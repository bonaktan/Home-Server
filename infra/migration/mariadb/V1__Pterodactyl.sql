CREATE USER 'pterodactyl'@'%' IDENTIFIED AS 'pterodactyl';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'%' WITH GRANT OPTION;