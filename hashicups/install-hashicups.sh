#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo $DIR

###########
# Install Postgres client for testing
###########
#sudo apt-get update
#sudo apt-get install -y postgresql-client
#apt install -y postgresql-client-common

###########
# Install Vault Client
###########
#vault_version=1.5.3
#wget "https://releases.hashicorp.com/vault/${vault_version}/vault_${vault_version}_linux_amd64.zip"
#unzip "vault_${vault_version}_linux_amd64.zip"
#mv vault /usr/local/bin/vault
#chmod +x /usr/local/bin/vault
#rm -f "vault_${vault_version}_linux_amd64.zip"

###########
# Configure Consul Helm Chart values
###########
cat <<-EOF > ${DIR}/us-central-values.yaml
global:
  datacenter: uscentral
  #image: "consul:1.8.2"
  #imageK8S: "hashicorp/consul-k8s:0.18.1"

ui:
  enabled: true
  service:
    type: 'LoadBalancer'

server:
  replicas: 1
  bootstrapExpect: 1

client:
  enabled: true
  grpc: true

connectInject:
  enabled: true

syncCatalog:
  enabled: true
  #toConsul: true
  #toK8S: false
  #default: true
EOF


###########
# Install Consul with the Helm Chart
###########
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install -f ${DIR}/us-central-values.yaml us-central hashicorp/consul

# Wait for consul server pod to be ready
status=""
while [ -z "${status}" ]; do
  sleep 3
  status=$(kubectl get pods | grep "us-central-consul-server.*1/1")
done

kubectl apply -f ${DIR}/products-db.yml
kubectl apply -f ${DIR}/frontend.yml
kubectl apply -f ${DIR}/public-api.yml
kubectl apply -f ${DIR}/products-api.yml
exit 0