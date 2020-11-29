#-------------------------------------------------------------------------------------------
# Required:
#    * prefix - set it to your name or something unique   
#-------------------------------------------------------------------------------------------
prefix = "dr"
# Use a zone instead of region to limit the K8s cluster to single zone and master.
gcp_region = "us-east1"
gcp_zone = "us-east1-c"
gke_num_nodes = 3
ip_cidr_range = "10.40.0.0/24"

# Create KMS Ring/Key for auto-unseal
key_ring  = "us-east1-vaul-unseal-ring"
crypto_key = "us-east1-vault-unseal-key"
