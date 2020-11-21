variable "gcp_project" {
  description = "GCP Project ID can be sourced from Env.  Prefix with TF_VAR_"
}
variable "gcp_region" {
  description = "GCP region, or zone if you want single master."
}
variable k8s_endpoint {}
variable gke_username {}
variable gke_password {}
variable k8s_master_auth_cluster_ca_certificate {default=""}
variable k8s_master_auth_client_certificate {default=""}
variable k8s_master_auth_client_key {default=""}
variable k8s_namespace {default="default"}

variable vault-config-type {
    description = "http, https"
    default = "http"
}
variable k8sloadconfig {
    default = ""
}
variable key_ring {
    description = "Get GCP key_ring name"
}
variable keyring_location {
    default = "global"
}
variable crypto_key {
    description = "Get GCP key_name"
}