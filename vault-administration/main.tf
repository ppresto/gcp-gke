terraform {
  required_providers {
    # In the rare situation of using two providers that
    # have the same type name -- "http" in this example --
    # use a compound local name to distinguish them.
    vault = {
      source  = "hashicorp/vault"
      version = "= 2.16.0"
    }
    null = {
      source = "hashicorp/null"
      version = "= 3.0.0"
    }
  }
}

locals {
  resources = {
    # policy_name = "<filename>"
    vault-dr-token = "vault-dr-token-policy.hcl"
    superuser = "superuser-policy.hcl"
  }
}

module "policy" {
  source = "../modules/vault-policy"
  for_each = local.resources

   policy_name = each.key
   policy_code = file("${path.module}/policies/${each.value}")
}

#module "policy" {
##  source      = "../modules/vault-policy"
#  policy_name = "vault-dr-token"
#  policy_code = file("${path.module}/policies/vault-dr-token-policy.hcl")
#}

module "kv" {
  source         = "../modules/vault-kv"
  kv_path        = "kv"
  kv_secret_path = "kv/mysecrets"
  kv_secret_data = "{\"username\": \"admin\", \"password\": \"notsosecure\", \"ttl\": \"30m\"}"
}

module "userpass" {
  source         = "../modules/vault-userpass"
  username       = "admin"
  password       = "password"
}