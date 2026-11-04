# Attach only this policy to the corresponding workload identity.
path "database/creds/itskolar-admin" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
# Permit renewal only for this service's database leases.
path "sys/leases/renew" {
  capabilities = ["update"]
  allowed_parameters = {
    "lease_id" = ["database/creds/itskolar-admin/*"]
    "increment" = []
  }
}
