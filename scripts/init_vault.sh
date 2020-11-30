#!/bin/bash

# Vars
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PWD=$(echo $PWD)
timeout=420
vRunning=""
config="$HOME/.kube/config"

# Set this to one of your pod names.
if [[ $(helm list -o json | jq -r '.[].name' | grep vault) ]]; then
    init_inst="$(helm list -o json | jq -r '.[].name' | grep vault)-0"
else
    init_inst="vault-0"
fi

# GITDIR should be the working directory with your terraform.tfstate file.
if [[ ! -z $1 ]]; then
    GITDIR="${1}"
else
    GITDIR=${PWD}
fi



# K8s namespace is needed to lookup vault information
if [[ $(terraform output -state=${GITDIR}/terraform.tfstate gke_namespace) ]]; then
  ns=$(terraform output -state=${GITDIR}/terraform.tfstate gke_namespace)
else
  ns="default"
fi

# Setup K8s Env
if [[ -f ${GITDIR}/setkubectl.sh ]]; then
    . ${GITDIR}/setkubectl.sh
else
    echo "Init your K8s Envionment (${GITDIR}/setkubectl.sh)"
fi
# Find Active Vault Node
if [[ $(kubectl --kubeconfig ${config} --namespace ${ns} get pod --selector="vault-active=true" --output=jsonpath={.items..metadata.name}) ]]; then
    init_inst=$(kubectl --kubeconfig ${config} --namespace ${ns} get pod --selector="vault-active=true" --output=jsonpath={.items..metadata.name})
fi

# Initialize Vault

if [[ ! $(helm status --kubeconfig ${config} --namespace ${ns} ${init_inst%-*}) ]]; then
    echo "helm release status "
    exit 1
fi

isVaultRunning () {
    vRunning=1
    while [ ${timeout} -ge 1 ]
    do
        if [[ $(kubectl get --kubeconfig ${config} --namespace ${ns} pods -o json  | jq -r '.items[] | select(.status.phase != "Running") | .metadata.namespace + "/" + .metadata.name' | wc -l) -gt 0 ]]; then
            timeout=$((${timeout}-5))
            sleep 5
            kubectl get pods --kubeconfig ${config} --namespace ${ns}
            vRunning=1
        else
            vRunning=0
            return $vRunning
        fi
    done
    return $vRunning
}

initializeVault () {
    vaultInitStatus=$(kubectl --kubeconfig ${config} --namespace ${ns} exec -it ${init_inst} -- vault status | grep Initialized)
    #isInitialized=$(kubectl get pods -o json  | jq -r '.items[] | select(.status.phase == "Running" and select(.metadata.labels."vault-initialized" == "true" )) | .metadata.name')
    #if [[ $(echo $isInitialized | grep "${init_inst}" | grep -v grep) ]]; then
    if [[ $(echo $vaultInitStatus | awk '{ print $NF }' | grep false) ]]; then
        echo "\nInitializing Vault...  (Inititialized Status: $vaultInitStatus)"
        echo
        kubectl exec --kubeconfig ${config} --namespace ${ns} ${init_inst} -- vault operator init -key-shares=1 -key-threshold=1 -format=json > ${GITDIR}/tmp/cluster-keys.json
        sleep 5
        export VAULT_ROOT_TOKEN=$(cat ${GITDIR}/tmp/cluster-keys.json | jq -r ".root_token")
    else
        echo "\nVault Initialized : Skipping..."
    fi
    kubectl exec --kubeconfig ${config} --namespace ${ns} -it ${init_inst} -- vault status
    echo
}

joinRaftPeers() {
    echo "\nChecking for Raft Peers ..."
    podList=$(kubectl --kubeconfig ${config} --namespace ${ns} get pods -o json  | jq -r '.items[] | select(.metadata.labels.component == "server")|.metadata.name')
    podsNotReady=$(kubectl --kubeconfig ${config} --namespace ${ns} get pods -o json  | jq -r '.items[] | select(.status.phase == "Running" and ([ .status.containerStatuses[] | select(.ready == false )] | length ) == 1 ) | .metadata.namespace + "/" + .metadata.name')
    peersNotInit=$(kubectl --kubeconfig ${config} --namespace ${ns} get pods -o json  | jq -r '.items[] | select(.status.phase == "Running" and select(.metadata.labels."vault-initialized" == "false" )) | .metadata.name')
    #echo "Pods Not Read: kubectl --kubeconfig ${config} --namespace ${ns} get pods -o json  | jq -r '.items[] | select(.status.phase == \"Running\" and ([ .status.containerStatuses[] | select(.ready == false )] | length ) == 1 ) | .metadata.namespace + \"/\" + .metadata.name'"
    #echo "Peers not Init: kubectl --kubeconfig ${config} --namespace ${ns} get pods -o json  | jq -r '.items[] | select(.status.phase == \"Running\" and select(.metadata.labels.\"vault-initialized\" == \"false\" )) | .metadata.name'"
    for peer in $podList
    do
        # If pod status is 1/1 Ready
        echo "Checking Peer: $peer"
        # If vault status shows instance Initialzed = "false"
        if [[ $(kubectl exec -it ${peer} -- vault status | grep "Initialized" | grep "false" | wc -l) -gt 0 ]]; then
            echo "\nJoining Peer: ${peer}"
            echo "kubectl exec --kubeconfig ${config} --namespace ${ns} -ti ${peer} -- vault operator raft join http://${init_inst}.vault-internal:8200"
            sleep 5
            kubectl exec --kubeconfig ${config} --namespace ${ns} -ti ${peer} -- vault operator raft join http://${init_inst}.vault-internal:8200
        else
            echo "Skipping $peer. Initialized already"
        fi
    done
}

getRaftListPeers() {
    echo "\nVault List Peers"
    VAULT_ROOT_TOKEN=$(cat ${GITDIR}/tmp/cluster-keys.json | jq -r ".root_token")
    echo $?
    if [[ -z $VAULT_ROOT_TOKEN ]]; then
        echo "Failed to get login token"
        exit
    fi
    VAULT_TOKEN=$(kubectl exec --kubeconfig ${config} --namespace ${ns} -ti ${init_inst} -- vault login ${VAULT_ROOT_TOKEN} -format="json" | jq -r ".auth.client_token")
    #echo "export VAULT_TOKEN=$(kubectl exec -ti ${init_inst} -- vault login ${VAULT_ROOT_TOKEN} -format='json' | jq -r '.auth.client_token')"
    kubectl exec --kubeconfig ${config} --namespace ${ns} -ti ${init_inst} -- vault operator raft list-peers
}

installLicense () {
    # Login and Get Token
    echo -e "\n Logging into Vault to get Token"
    VAULT_ROOT_TOKEN=$(cat ${GITDIR}/tmp/cluster-keys.json | jq -r ".root_token")
    echo $?
    if [[ -z $VAULT_ROOT_TOKEN ]]; then
        echo "Failed to get login token"
        exit
    fi
    VAULT_TOKEN=$(kubectl exec --kubeconfig ${config} --namespace ${ns} -ti ${init_inst} -- vault login ${VAULT_ROOT_TOKEN} -format="json" | jq -r ".auth.client_token")
    
    
    echo -e "\nSetting up port-forward to ${init_inst}"
    kubectl port-forward --kubeconfig ${config} --namespace ${ns} ${init_inst} 8200:8200 &
    sleep 5
    #VAULT_ADDR=$(kubectl --kubeconfig ${config} --namespace ${ns} describe pod ${init_inst} | grep VAULT_ADDR | awk '{ print $NF }')
    VAULT_ADDR="http://127.0.0.1:8200"
    echo $VAULT_ADDR
    echo -e "\nChecking Enterprise License: ${VAULT_ADDR}/v1/sys/license \n"
    cur_lic=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/sys/license)
    if [[ $(echo $cur_lic | jq -r '.data.license_id' | grep temporary | grep -v grep) ]]; then
        echo "Found License: $cur_lic | jq -r '.data.license_id'"
        echo -e "\nInstalling Enterprise License"
        output=$(curl -k -s \
            --header "X-Vault-Token: ${VAULT_TOKEN}" \
            --request PUT \
            --data @${GITDIR}/../tmp/vault-ent.hclic \
            ${VAULT_ADDR}/v1/sys/license)
        cur_lic=$(curl -k -s --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/sys/license)
        echo $cur_lic | jq -r
    else
        license_id=$(echo $cur_lic | jq -r '.data.license_id')
        echo "\nLicense Already Installed: ${license_id}"
        echo $cur_lic | jq -r
    fi
    kill $(ps -ef | grep "port-forward" | grep -v grep | awk '{ print $2 }')
}

#
###  Main
#
isVaultRunning
if [[ $? -eq 0 ]]; then
    echo -e "\nVault is Running"
    kubectl get --kubeconfig ${config} --namespace ${ns} pods
else
    echo "Vault Cluster is not all running.  Exit"
    exit
fi
sleep 10

initializeVault
joinRaftPeers
#getRaftListPeers
installLicense