variable "prefix" {
  description = "This prefix will be included in the name of some resources. Use your own name or any other short string here."
}

variable "gcp_project" {
  description = "GCP Project ID can be sourced from Env.  Prefix with TF_VAR_"
}

variable "gcp_region" {
  description = "GCP region, or zone if you want single master."
  default     = "us-east1"
}

variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 3
  description = "number of gke nodes"
}