#!/bin/bash
#release=$(helm list -o json | jq -r '.[].name' | grep vault)
if [[ -z $1 ]]; then
    echo "Required Param missing"
    echo "Usage:"
    echo "  uninstall_vault.sh <context>"
    echo ""
    echo "Example:"
    echo "  uninstall_vault.sh primary"
    exit
else
    context="${1}"
    release="vault-${1}"
    helm uninstall ${release}
    kubectl --context=${context} delete pvc -l app.kubernetes.io/name=vault
fi