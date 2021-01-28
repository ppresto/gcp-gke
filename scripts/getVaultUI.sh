#!/bin/bash

# Param 1 is helm release name (ex: vault-usw)
[ -z "${1}" ] && echo "Usage: getVaultUI.sh <vault_helm_release>" && exit 1

# Get Root Token
context=$(kubectl config current-context)
if [[ $context == "usw" ]]; then
    token=$(cat /root/gcp-gke/us-west/tmp/${1}-cluster-keys.json | jq -r ".root_token")
else
    token=$(cat /root/gcp-gke/us-central/tmp/${1}-cluster-keys.json | jq -r ".root_token")
fi

# Wait for External IP to be available
external_ip=""
while [ -z $external_ip ]; do
  echo "Waiting for Vault External URL ..."
  external_ip=$(kubectl get svc ${1}-ui --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  [ -z "$external_ip" ] && sleep 10
done

export VAULT_ADDR="http://${external_ip}:8200"
export VAULT_TOKEN="${token}"
export VAULT_SKIP_VERIFY=true

echo
echo "http://${external_ip}:8200/ui"
echo
echo "Login Token:"
echo "${token}"