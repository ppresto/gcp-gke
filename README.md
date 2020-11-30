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

### dcanadillas (resolver_discover_servers)
https://gist.github.com/dcanadillas/8448a3ba6652f8fe120c011f1825555e
### GKE + VM replication Architecture
https://github.com/dcanadillas/vault-gke#architecture-to-be-deployed
