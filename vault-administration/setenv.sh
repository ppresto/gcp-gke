#!/bin/bash

SERVICE=$(kubectl get svc -o json | jq -r '.items[].metadata | select(.name | contains("ui")) | .name')

# Get Root Token
context=$(kubectl config current-context)
if [[ $context == "primary" ]]; then
    token=$(cat /root/gcp-gke/us-west/tmp/cluster-keys.json | jq -r ".root_token")
else
    token=$(cat /root/gcp-gke/us-central/tmp/cluster-keys.json | jq -r ".root_token")
fi

# Wait for External IP to be available
external_ip=""
while [ -z $external_ip ]; do
  echo "Waiting for Vault External URL ..."
  external_ip=$(kubectl get svc $SERVICE --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$external_ip" ] && sleep 10
done

export VAULT_ADDR="http://${external_ip}:8200"
export VAULT_TOKEN="${token}"
export VAULT_SKIP_VERIFY=true

# Kubernetes
  export TF_VAR_k8s_path="k8s"
  export TF_VAR_kubernetes_host=$(kubectl config view -o yaml | grep server | awk '{ print $NF }')
  export VAULT_DEPLOYMENT=$(helm list -o json | jq -r '.[].name')
  export VAULT_SA_NAME=$(kubectl get sa ${VAULT_DEPLOYMENT} -o jsonpath="{.secrets[*]['name']}")
  export TF_VAR_token_reviewer_jwt=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
  export TF_VAR_kubernetes_ca_cert=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

  echo $TF_VAR_k8s_path
  echo $TF_VAR_kubernetes_host
  echo $VAULT_DEPLOYMENT
  echo $VAULT_SA_NAME
  echo $TF_VAR_token_reviewer_jwt
  echo $TF_VAR_kubernetes_ca_cert
