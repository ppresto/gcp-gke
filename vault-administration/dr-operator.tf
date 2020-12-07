module "policy" {
  source      = "../modules/vault-policy"
  policy_name = "vault-dr-token"
  policy_code = file("${path.module}/policies/vault-dr-token-policy.hcl")
}

module "kv" {
  source         = "../modules/vault-kv"
  kv_path        = "kv"
  kv_secret_path = "kv/mysecrets"
  kv_secret_data = "{\"username\": \"admin\", \"password\": \"pa$$w0rd!\", \"ttl\": \"30m\"}"
}