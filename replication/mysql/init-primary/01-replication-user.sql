-- Usuario de replicación para escenario Warm (MySQL 8.x, red Docker interna)
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'repl_blume_local';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
