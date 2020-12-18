module "ns_uscentral" {
  source    = "../modules/vault-namespace"
  namespace = "uscentral"
}

module "approle_uscentral" {
  source                    = "../modules/vault-approle"
  role_depends_on           = module.ns_uscentral.id
  namespace                 = "uscentral"
  approle_path              = var.approle_path
  role_name                 = var.role_name
  k8s_path                  = var.k8s_path
  kv_path                   = var.kv_path
  ssh_path                  = var.ssh_path
  default_lease_ttl_seconds = "3600s"
  max_lease_ttl_seconds     = "10800s"
  policies                  = ["default", "terraform"]
}

output "role_id_uscentral" {
  value = module.approle_uscentral.role_id
}

output "secret_id_uscentral" {
  value = module.approle_uscentral.secret_id
}

output "namespace_uscentral" {
  value = "uscentral"
}

output "k8s_path_uscentral" {
  value = var.k8s_path
}
output "kv_path_uscentral" {
  value = var.kv_path
}

output "approle_path_uscentral" {
  value = module.approle_uscentral.approle_path
}

output "ssh_path_uscentral" {
  value = module.approle_uscentral.ssh_path
}

output "role_name_uscentral" {
  value = module.approle_uscentral.role_name
}