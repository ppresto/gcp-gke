#-------------------------------------------------------------------------------------------
# Required:
#    * prefix - set it to your name or something unique   
#-------------------------------------------------------------------------------------------
prefix = "presto"
# Use a zone instead of region to limit the K8s cluster to single zone and master.
gcp_region = "us-central1-c"
gke_num_nodes = 3

# Create KMS Ring/Key for auto-unseal
key_ring  = "vaul-unseal-ring"
crypto_key = "vault-unseal-key"
