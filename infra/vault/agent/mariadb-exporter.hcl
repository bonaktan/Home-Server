exit_after_auth = false
vault {
  address = "https://vault.internal.bonnybonnybonaktan.xyz:8200"
  ca_cert = "/etc/vault-agent/vault-ca.pem"
}
auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "/run/vault-auth/role-id"
      secret_id_file_path = "/run/vault-auth/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }
}
template_config {
  exit_on_retry_failure = true
}
env_template "MYSQLD_USERNAME" {
  contents = "{{ with secret \"database/creds/mariadb-exporter\" }}{{ .Data.username }}{{ end }}"
  error_on_missing_key = true
}
env_template "MYSQLD_EXPORTER_PASSWORD" {
  contents = "{{ with secret \"database/creds/mariadb-exporter\" }}{{ .Data.password }}{{ end }}"
  error_on_missing_key = true
}
exec {
  command = ["/bin/sh", "-ec", "exec /bin/mysqld_exporter --mysqld.address=mariadb:3306 --mysqld.username=\"$MYSQLD_USERNAME\" --config.my-cnf=/etc/vault-agent/mysql.cnf"]
  restart_on_secret_changes = "always"
  restart_stop_signal = "SIGTERM"
}
