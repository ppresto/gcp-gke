# Learn Terraform - Provision a GKE Cluster

This repo is a companion repo to the [Provision a GKE Cluster learn guide](https://learn.hashicorp.com/terraform/kubernetes/provision-gke-cluster), containing
Terraform configuration files to provision an GKE cluster on
GCP.

This sample repo also creates a VPC and subnet for the GKE cluster. This is not
required but highly recommended to keep your GKE cluster isolated.

## Install and configure GCloud

First, install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/quickstarts) 
and initialize it.

```shell
$ gcloud init
```

Once you've initialized gcloud (signed in, selected project), add your account 
to the Application Default Credentials (ADC). This will allow Terraform to access
these credentials to provision resources on GCloud.

```shell
$ gcloud auth application-default login
```

## Initialize Terraform workspace and provision GKE Cluster

# Notes

```
kubectl config use-context
kubectl config get-contexts
kubectl config rename-context 
```

## DR Replication

Get Status on primary or DR
```
vault read sys/replication/performance/status
```

### DR Replication with Wrapped Token
```
vault write sys/replication/dr/primary/secondary-token id=EU-2 | tee /root/config-files/vault/wrapping_token.txt

vault read sys/replication/dr/status

scp -o StrictHostKeyChecking=no vault-eu-1:/root/config-files/vault/wrapping_token.txt /root/config-files/vault/wrapping_token.txt
wrapping_token=$(cat /root/config-files/vault/wrapping_token.txt | grep wrapping_token: | cut -d' ' -f19)
```
### DR Replication with public key
```
# na1
vault write -f sys/replication/dr/primary/enable

# na2
vault write -f sys/replication/dr/secondary/generate-public-key

# na1
vault write sys/replication/dr/primary/secondary-token id=NA-2 secondary_public_key=<your_spk> | tee /root/config-files/vault/sec_token.txt
vault read sys/replication/dr/status

# na2
scp -o StrictHostKeyChecking=no vault-na-1:/root/config-files/vault/sec_token.txt /root/config-files/vault/sec_token.txt
sec_token=$(cat /root/config-files/vault/sec_token.txt | grep token | cut -d' ' -f5)

vault write sys/replication/dr/secondary/enable ca_file=/etc/consul.d/tls/consul-agent-ca.pem token=$sec_token

# na1 - revoke to restart if needed
vault write sys/replication/dr/primary/revoke-secondary id=NA-2
```


Secondary Perf Rep - Get new root token after replication working.
FYI:  License can be reset after performance secondary setup.  Reapply. 
```
vault operator generate-root -generate-otp
vault operator generate-root -init -otp=<your_otp>

# Run 2x, use recover keys from Primary, get encoded token
vault operator generate-root   
vault operator generate-root -decode=<token> -otp=<otp>
export VAULT_TOKEN=<dr-root-key>
```
### Kubernetes
https://learn.hashicorp.com/tutorials/vault/kubernetes-raft-deployment-guide#load-balancers-and-replication
https://www.vaultproject.io/docs/platform/k8s/helm/examples/enterprise-dr-with-raft

### Hashicorp Vault Replication Links
https://www.vaultproject.io/docs/enterprise/replication
https://learn.hashicorp.com/tutorials/vault/disaster-recovery#enable-dr-secondary-replication
https://www.vaultproject.io/docs/concepts/ha#behind-load-balancers
https://www.vaultproject.io/api-docs/system/health
https://www.vaultproject.io/api-docs/system/replication/replication-dr#primary_api_addr
https://www.vaultproject.io/api/system/replication.html
https://learn.hashicorp.com/tutorials/vault/monitor-replication#port-traffic-consideration-with-load-balancer

### dcanadillas (resolver_discover_servers)
https://gist.github.com/dcanadillas/8448a3ba6652f8fe120c011f1825555e
### GKE + VM replication Architecture
https://github.com/dcanadillas/vault-gke#architecture-to-be-deployed
