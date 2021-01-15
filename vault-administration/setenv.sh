#!/bin/bash

# Get Root Token
kubectl config use-context usw
token=$(cat /root/gcp-gke/us-west/tmp/root.token.primary.json)

# Get Vault Address.  Wait for External IP to be available
SERVICE=$(kubectl get svc -o json | jq -r '.items[].metadata | select(.name | contains("ui")) | .name')
external_ip=$(kubectl get svc $SERVICE --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")

export VAULT_ADDR="http://${external_ip}:8200"
export VAULT_TOKEN="${token}"
export VAULT_SKIP_VERIFY=true

# Kubernetes
  export TF_VAR_k8s_path="k8s"
  export TF_VAR_kubernetes_host=$(kubectl config view --minify=true -o jsonpath='{.clusters[].cluster.server}')
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
