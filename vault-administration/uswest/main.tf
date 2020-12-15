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
    vault-dr-token = "vault-dr-token-policy.hcl"
    superuser = "superuser-policy.hcl"
    k8s = "k8s-policy.hcl"
    terraform = "terraform.hcl"
  }
}

module "policy" {
  source = "../modules/vault-policy"
  for_each = local.policies

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
  password       = "admin"
}

module "k8s" {
  source             = "../modules/vault-k8s"
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert
  token_reviewer_jwt = var.token_reviewer_jwt
  policy_name        = "k8s"
  k8s_path           = var.k8s_path
}

#module "gcp" {
#  source = "../modules/gcp"

#  gcp_credentials = var.gcp_credentials
#  gcp_role_name   = var.gcp_role_name
#  gcp_bound_zones     = var.gcp_bound_zones
#  gcp_bound_projects  = var.gcp_bound_projects
#  gcp_token_policies  = var.gcp_token_policies
#  gcp_token_ttl       = var.gcp_token_ttl
#  gcp_token_max_ttl   = var.gcp_token_max_ttl
#}