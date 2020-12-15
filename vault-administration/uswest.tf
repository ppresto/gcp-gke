module "ns_uswest" {
  source    = "../modules/vault-namespace"
  namespace = "uswest"
}

module "approle_uswest" {
  source                    = "../modules/vault-approle"
  role_depends_on           = module.ns_uswest.id
  namespace                 = "uswest"
  approle_path              = var.approle_path
  role_name                 = var.role_name
  k8s_path                  = var.k8s_path
  kv_path                   = var.kv_path
  ssh_path                  = var.ssh_path
  default_lease_ttl_seconds = "3600s"
  max_lease_ttl_seconds     = "10800s"
  policies                  = ["default", "terraform"]
}

output "role_id_uswest" {
  value = module.approle_uswest.role_id
}

output "secret_id_uswest" {
  value = module.approle_uswest.secret_id
}

output "namespace_uswest" {
  value = local.namespace
}

output "k8s_path_uswest" {
  value = var.k8s_path
}
output "kv_path_uswest" {
  value = var.kv_path
}

output "approle_path_uswest" {
  value = module.approle_uswest.approle_path
}

output "ssh_path_uswest" {
  value = module.approle_uswest.ssh_path
}

output "role_name_uswest" {
  value = module.approle_uswest.role_name
}