#!/bin/bash

# Param 1 is K8s service
[ -z "${1}" ] && echo "Missing Param: getVaultUI.sh <k8s_svc_name>" && exit 1
#if [[ -z $1 ]]; then
#    exit 1
#fi

# Get Root Token
context=$(kubectl config current-context)
if [[ $context == "primary" ]]; then
    token=$(cat /root/gcp-gke/us-west-primary/tmp/cluster-keys.json | jq -r ".root_token")
else
    token=$(cat /root/gcp-gke/us-central-dr/tmp/cluster-keys.json | jq -r ".root_token")
fi

# Wait for External IP to be available
external_ip=""
while [ -z $external_ip ]; do
  echo "Waiting for Vault External URL ..."
  external_ip=$(kubectl get svc $1 --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
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