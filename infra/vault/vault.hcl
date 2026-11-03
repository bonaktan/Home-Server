ui = true
api_addr = "http://127.0.0.1:8200"

storage "file" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
  unauthenticated_metrics_access = true
}

telemetry {
  disable_hostname = true
}
