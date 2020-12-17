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
  policies = {
    # policy_name = "<filename>"
    k8s = "k8s-policy.hcl"
    products-api = "products-api-policy.hcl"
  }
}

module "policy" {
  source = "../../modules/vault-policy"
  for_each = local.policies

   policy_name = each.key
   policy_code = file("${path.module}/../policies/${each.value}")
}

#module "policy" {
##  source      = "../modules/vault-policy"
#  policy_name = "vault-dr-token"
#  policy_code = file("${path.module}/policies/vault-dr-token-policy.hcl")
#}

module "kv" {
  source         = "../../modules/vault-kv"
  kv_path        = "kv"
  kv_secret_path = "kv/db/postgres/product-db-creds"
  kv_secret_data = "{\"username\": \"postgres\", \"password\": \"password\"}"
}

module "userpass" {
  source         = "../../modules/vault-userpass"
  username       = "admin"
  password       = "admin"
}

module "k8s" {
  source             = "../../modules/vault-k8s"
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert
  token_reviewer_jwt = var.token_reviewer_jwt
  policy_name        = "k8s"
  k8s_path           = var.k8s_path
  kubernetes_sa      = "products-api"
}