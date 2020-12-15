path "kv/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "secret/data/apikey" {
  capabilities = ["read","list"]
}
path "db/creds/dev" {
  capabilities = ["read"]
}
path "pki_int/issue/*" {
  capabilities = ["create", "update"]
}
path "sys/leases/renew" {
  capabilities = ["create"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
path "sys/renew/*" {
  capabilities = ["update"]
}