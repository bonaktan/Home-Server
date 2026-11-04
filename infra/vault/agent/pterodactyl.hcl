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
env_template "DB_USERNAME" {
  contents = "{{ with secret \"database/creds/pterodactyl\" }}{{ .Data.username }}{{ end }}"
  error_on_missing_key = true
}
env_template "DB_PASSWORD" {
  contents = "{{ with secret \"database/creds/pterodactyl\" }}{{ .Data.password }}{{ end }}"
  error_on_missing_key = true
}
exec {
  command = ["/bin/ash", "/etc/vault-agent/panel-start.sh"]
  restart_on_secret_changes = "always"
  restart_stop_signal = "SIGTERM"
}
