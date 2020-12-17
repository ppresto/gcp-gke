#!/bin/bash
VAULT_NAMESPACE="uswest"
SERVICE=$(kubectl --context=primary get svc -o json | jq -r '.items[].metadata | select(.name | contains("ui")) | .name')
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Get Root Token
context=$(kubectl config current-context)
token=$(cat /root/gcp-gke/us-west/tmp/root.token.primary.json)

# Wait for External IP to be available
external_ip=""
while [ -z $external_ip ]; do
  echo "Waiting for Vault External URL ..."
  external_ip=$(kubectl --context=primary get svc $SERVICE --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$external_ip" ] && sleep 10
done

export VAULT_ADDR="http://${external_ip}:8200"
export VAULT_TOKEN="${token}"
export VAULT_SKIP_VERIFY=true

# AppRole for Terraform Vault provider authentication
if [[ $(terraform output -state=../terraform.tfstate role_id_${VAULT_NAMESPACE}) ]]; then
  export TF_VAR_role_id=$(terraform output -state=../terraform.tfstate role_id_${VAULT_NAMESPACE})
  export TF_VAR_app_role_mount_point=$(terraform output -state=../terraform.tfstate approle_path_${VAULT_NAMESPACE})
  export TF_VAR_approle_path=$(terraform output -state=../terraform.tfstate approle_path_${VAULT_NAMESPACE})
  export TF_VAR_role_name=$(terraform output -state=../terraform.tfstate role_name_${VAULT_NAMESPACE})
  export TF_VAR_secret_id=$(terraform output -state=../terraform.tfstate secret_id_${VAULT_NAMESPACE})

  # Namespace
  export TF_VAR_namespace=$(terraform output -state=../terraform.tfstate namespace_${VAULT_NAMESPACE})

  # Kubernetes
  export TF_VAR_k8s_path=$(terraform output -state=../terraform.tfstate k8s_path_${VAULT_NAMESPACE})
  export TF_VAR_kubernetes_host=$(kubectl config view -o yaml | grep server | awk '{ print $NF }')
  export VAULT_DEPLOYMENT=$(helm list -o json | jq -r '.[].name')
  export VAULT_SA_NAME=$(kubectl get sa ${VAULT_DEPLOYMENT} -o jsonpath="{.secrets[*]['name']}")
  export TF_VAR_token_reviewer_jwt=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
  export TF_VAR_kubernetes_ca_cert=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

  # GCP Auth backend
  export TF_VAR_gcp_credentials=$(cat <<EOF
<GOOGLE CLOUD CREDENTIALS HERE>
EOF
)
  export TF_VAR_gcp_role_name="gce" 
  export TF_VAR_gcp_bound_zones='["<YOUR_GCP_ZONE>"]'
  export TF_VAR_gcp_bound_projects='["<YOUR_GCP_PROJECT>"]'
  export TF_VAR_gcp_token_policies='["terraform"]'
  export TF_VAR_gcp_token_ttl=1800
  export TF_VAR_gcp_token_max_ttl=86400
  
else
  echo "Error: No role_id_${VAULT_NAMESPACE} Found"
  echo "Please run terraform in the parent directory 'cd ../' to properly generate the namespace and approle"
  echo "Note: remember to 'source env.sh' to set your privilated token for TF"
fi