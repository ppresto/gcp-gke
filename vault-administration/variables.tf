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