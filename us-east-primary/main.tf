module "gcp-vpc-gke" {
  source         = "../modules/gcp-vpc-gke"
  prefix        = var.prefix
  gcp_project = var.gcp_project
  gcp_region  = var.gcp_region
  gcp_zone    = var.gcp_zone
  ip_cidr_range = var.ip_cidr_range
  gke_num_nodes = var.gke_num_nodes
  #gke_namespace  = var.gke_namespace
}

module "gcp-gke-kms" {
  source         = "../modules/gcp-kms-unseal"
  gcloud-project = var.gcp_project
  gcloud-region  = var.gcp_region
  keyring_location = "global"
  key_ring    = "${var.gcp_region}-${var.key_ring}"
  crypto_key  = "${var.gcp_region}-${var.crypto_key}"
}

provider "helm" {
  kubernetes {
    load_config_file = var.k8sloadconfig != "" ? var.k8sloadconfig : "true"
    host     = module.gcp-vpc-gke.k8s_endpoint
    username = var.gke_username
    password = var.gke_password

    client_certificate     = base64decode(module.gcp-vpc-gke.k8s_master_auth_client_certificate)
    client_key             = base64decode(module.gcp-vpc-gke.k8s_master_auth_client_key)
    cluster_ca_certificate = base64decode(module.gcp-vpc-gke.k8s_master_auth_cluster_ca_certificate)
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com" 
  chart      = "vault"
  namespace  = var.gke_namespace
  wait       = true
  timeout    = "120"

  values = [
    templatefile("../${path.module}/templates/override-values-autounseal.yaml", { 
      project     = var.gcp_project
      region      = "global"
      key_ring    = "${var.gcp_region}-${var.key_ring}"
      crypto_key  = "${var.gcp_region}-${var.crypto_key}"
      replicas    = var.gke_num_nodes
    })
  ]
}

data "template_file" "init" {
  template = file("../${path.module}/templates/override-values-autounseal.yaml")
  vars = {
    project     = var.gcp_project
    region      = "global"
    key_ring    = "${var.gcp_region}-${var.key_ring}"
    crypto_key  = "${var.gcp_region}-${var.crypto_key}"
    replicas    = var.gke_num_nodes
  }
}

resource "local_file" "foo" {
  content     = data.template_file.init.rendered
  filename = "../vault.yaml"
}
