module "policy" {
  source      = "../modules/vault-policy"
  policy_name = "vault-dr-token"
  policy_code = file("${path.module}/policies/vault-dr-token-policy.hcl")
}