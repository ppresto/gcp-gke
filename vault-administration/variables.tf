# Kubernetes
variable "kubernetes_host" {
  description = "Kubernetes API endpoint"
}
variable "kubernetes_ca_cert" {
  description = "Kubernetes CA"
}
variable "token_reviewer_jwt" {
  description = "Kubernetes Auth"
}
variable "kubernetes_namespace" {
  description = "Kubernetes namespace"
  default     = "default"
}
variable "kubernetes_sa" {
  description = "Kubernetes service account"
  default     = "default"
}
variable "k8s_path" {
  description = "Kubernetes Auth method path"
  default = "k8s"
}

# AppRole
variable "approle_path" {
  description = "AppRole mount point"
  default = "approle"
}
variable "role_name" {
  description = "AppRole role name"
  default = "terraform"
}
variable "policies" {
  type    = list(string)
  default = ["default", "terraform"]
}
variable "namespace" {
  description = "namespace where project will be onboarded"
  default = ""
}
variable "namespace_id" {
  description = "placeholder"
  default = ""
}

variable "kv_path" {
  description = "where k/v secret engine is mounted"
  default = ""
}
variable "default_lease_ttl_seconds" {
  description = "Default duration of lease validity"
  default = "3600s"
}
variable "max_lease_ttl_seconds" {
  description = "Maximum duration of lease validity"
  default = "10800s"
}
variable "ssh_path" {
  description = "where ssh secret engine will be mounted"
  default     = "ssh"
}
