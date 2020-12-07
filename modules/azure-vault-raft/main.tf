provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

provider "helm" {
  kubernetes {
    load_config_file = var.k8sloadconfig != "" ? var.k8sloadconfig : "true"
    host     = var.k8s_endpoint
    username = var.gke_username
    password = var.gke_password

    client_certificate     = base64decode(var.k8s_master_auth_client_certificate)
    client_key             = base64decode(var.k8s_master_auth_client_key)
    cluster_ca_certificate = base64decode(var.k8s_master_auth_cluster_ca_certificate)
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com" 
  chart      = "vault"
  namespace  = var.k8s_namespace
  wait       = true
  timeout    = "120"

  values = [
    templatefile("${path.module}/templates/values-${var.vault-config-type}.yaml", { 
      project     = var.gcp_project
      region      = "global"
      key_ring    = "vaul-autounseal-ring"
      crypto_key  = "vault-autounseal-key"
    })
  ]
}

resource "kubernetes_secret" "keyvault-config" {
  count             = var.vault-config-type == "https" ? 1 : 0
  metadata {
    name = "azure-keyvault-config"
  }
  data = {
    "azure-keyvault-config.yaml" = templatefile("${path.module}/templates/values-${var.vault-config-type}.yaml", { 
      project     = var.gcp_project
      region      = "global"
      key_ring    = "vaul-autounseal-ring"
      crypto_key  = "vault-autounseal-key"
    })
  }
  depends_on = [helm_release.vault]
}