#-------------------------------------------------------------------------------------------
# Required:
#    * prefix - set it to your name or something unique   
#-------------------------------------------------------------------------------------------
prefix = "usc"
# Use a zone instead of region to limit the K8s cluster to single zone and master.
gcp_region = "us-central1"
gcp_zone = "us-central1-c"
gke_num_nodes = 5
ip_cidr_range = "10.100.0.0/24"
k8sloadconfig = false

# Create KMS Ring/Key for auto-unseal
key_ring  = "vaul-unseal-ring-usc"
crypto_key = "vault-unseal-key-usc"
