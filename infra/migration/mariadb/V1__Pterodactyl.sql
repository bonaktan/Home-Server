CREATE USER 'pterodactyl'@'%' IDENTIFIED BY 'pterodactyl';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'%' WITH GRANT OPTION;
