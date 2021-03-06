#-------------------------------------------------------------------------------------------
# Required:
#    * prefix - set it to your name or something unique   
#-------------------------------------------------------------------------------------------
prefix = "usw"
# Use a zone instead of region to limit the K8s cluster to single zone and master.
gcp_region = "us-west1"
gcp_zone = "us-west1-c"
gke_num_nodes = 3
ip_cidr_range = "10.10.0.0/24"
k8sloadconfig = true

# Create KMS Ring/Key for auto-unseal
key_ring  = "vaul-unseal-ring-usw"
crypto_key = "vault-unseal-key-usw"
