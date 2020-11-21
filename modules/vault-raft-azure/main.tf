provider "azurerm" {
  features {}
}

provider "helm" {
  kubernetes {
    load_config_file = var.k8sloadconfig != "" ? var.k8sloadconfig : "true"
    host     = var.aks_fqdn
    #username = var.aks_username
    #password = var.aks_password

    client_certificate     = base64decode(var.aks_client_cert)
    client_key             = base64decode(var.aks_client_key)
    cluster_ca_certificate = base64decode(var.aks_ca)
  }
}

data "azurerm_client_config" "current" {}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com" 
  chart      = "vault"
  namespace  = var.k8s_namespace
  wait       = true
  timeout    = "120"

  values = [
    templatefile("${path.module}/templates/values-${var.vault-config-type}.yaml", { 
      client_id = data.azurerm_client_config.current.client_id,
      client_secret = var.ARM_CLIENT_SECRET,
      tenant_id = data.azurerm_client_config.current.tenant_id,
      vault_name = var.vault_name,
      key_name =  var.key_name
    })
  ]
}

resource "kubernetes_secret" "azure-keyvault-config" {
  count             = var.vault-config-type == "https" ? 1 : 0
  metadata {
    name = "azure-keyvault-config"
  }
  data = {
    "azure-keyvault-config.yaml" = templatefile("${path.module}/templates/azure-keyvault-config.yaml", { 
      client_id = data.azurerm_client_config.current.client_id,
      client_secret = var.ARM_CLIENT_SECRET,
      tenant_id = data.azurerm_client_config.current.tenant_id,
      vault_name = var.vault_name,
      key_name =  var.key_name
    })
  }
  depends_on = [helm_release.vault]
}