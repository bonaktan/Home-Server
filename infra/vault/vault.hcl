ui = true
api_addr = "https://vault.internal.bonnybonnybonaktan.xyz"

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_cert_file   = "/vault/tls/fullchain.pem"
  tls_key_file    = "/vault/tls/privkey.pem"
  tls_min_version = "tls12"

  telemetry {
    unauthenticated_metrics_access = true
  }
}

telemetry {
  disable_hostname = true
}
