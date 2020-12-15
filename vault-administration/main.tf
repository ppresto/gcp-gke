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

variable "policies" {
  type = map(object({
    name            = string
    file            = any
  }))
}

policies = {
  dr = {
    name = "vault-dr-token"
    file = file("${path.module}/policies/vault-dr-token-policy.hcl")
  },
  superuser = {
    name = "superuser"
    file = file("${path.module}/policies/superuser.hcl")
  }
}

module "policy" {
  source = "../modules/vault-policy"
  for_each = var.policies

   policy_name = each.value.name
   policy_code = each.value.file
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