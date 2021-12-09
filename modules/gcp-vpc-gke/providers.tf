terraform {
  required_version = ">= 0.12"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.3.0"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.1.0"
    }
    template = {
      source = "hashicorp/template"
      version = "~> 2.2.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}
