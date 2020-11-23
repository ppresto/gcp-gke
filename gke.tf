# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.prefix}-gke"
  location = var.gcp_region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  master_auth {
    username = var.gke_username
    password = var.gke_password

    client_certificate_config {
      issue_client_certificate = true
    }
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.gcp_region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.prefix
    }

    # preemptible  = true
    machine_type = "n1-standard-1"
    tags         = ["gke-node", "${var.prefix}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

module "gcp-gke-kms" {
  source         = "./modules/gcp-kms-unseal"
  gcloud-project = var.gcp_project
  gcloud-region  = var.gcp_region
  keyring_location = "global"
  key_ring    = "${var.gcp_region}-${var.key_ring}"
  crypto_key  = "${var.gcp_region}-${var.crypto_key}"
}

data "template_file" "init" {
  template = "${file("${path.module}/templates/override-values-http.yaml")}"
  vars = {
    project     = "${var.gcp_project}"
    region      = "global"
    key_ring    = "${var.gcp_region}-${var.key_ring}"
    crypto_key  = "${var.gcp_region}-${var.crypto_key}"
  }
}
resource "null_resource" "local" {
  triggers = {
    template = "${data.template_file.init.rendered}"
  }

  provisioner "local-exec" {
    command = "echo \"${data.template_file.init.rendered}\" > vault.yaml"
  }
}