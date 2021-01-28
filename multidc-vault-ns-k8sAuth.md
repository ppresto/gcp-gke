# Configure Vault Namespaces to support Multi-DC
Sometimes its a good idea to create Vault namespaces by team to put administrative boundaries in place and allow other teams to manage their own auth methods, policies, engines, etc... for a self service model.  However, in this excersise we will create namespaces based on Geo to isolate configurations, have flexible RBAC and change workflows, and reduce the blast radius from a bad change.  We will cover the following:
- Use Vault Terraform provider
- Create Vault Namespaces by Geo
  - Configure us-central - the secondary performance replica
  - Configure approle, userpass, policies, K8s auth
- Deploy Hashicups Service to us-central GKE cluster
- Use Vault K8s Auth to inject secrets into Hashicups products-api Pod


## PreReq
This excersize assumes you have performance replication setup b/w a primary and secondary.  The first track here can set that up for you. [Vault DR Multi-Region GKE Clusters](https://play.instruqt.com/hashicorp/tracks/vault-gke-pr-multi-region-presto)

## Create Namespace
Each namespace will have its own AppRole so we can manage then with different credentials that can be dynamically generated at the time of the change.  Each namespace is configured using its own <namespace>.tf file.  Rename the namespace files you want terraform to find and build.

```
cd ./vault-administration
mv uscentral.tf.disable uscentral.tf
source setenv.sh
terraform init
terraform apply -auto-approve
```

###  Configure Namespace (uscentral)
Now that we have a namespace built with an approle that can manage it, we need to use those to configure it. The `uscentral` directory contains all the elements we need to manage this namespace.

`set-project-env.sh` will setup the necessary environment variables terraform needs.  This is grabbing the namespace and approle information from what we just provisioned in ./vault-administration/terraform.tfstate.  It is also using kubectl to get the GKE cluster information needed to setup Kubernetes Auth.  This data is being put into TF_VAR_ variables so terraform can pick them up from the current shell environment during runtime.
```
cd uscentral
source set-project-env.sh
terraform init
terraform apply -auto-approve
```

The K8s service account running vault needs special permissions to use the K8s JWT token to facilitate authentication.  Lets apply that permission now to the secondary vault cluster (vault-dr).
```
cd ../..
kubectl apply -f ./vault-administration/uscentral/sa-vault-dr.yaml
```

### Login to Vault UI (secondary)
With performance replication setup we should be able to log into the primary or secondary cluster to see what we just built using terraform.  If we didn't rebuild a new root key then we wont be able to use a root token to login to the secondary since its been overwritten after setting up performance replication.  This is why we setup a root user if you review the terraform code above closely.

Get the secondary URL
```
cd us-central
./setkubectl.sh
echo "http://$(kubectl get svc vault-usc-ui --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}"):8200"
```
Login using userpass (root / root).  Check out the auth methods, policies, and kv-v2 secrets we will need to run hashicups

### Deploy Hashicups
```
cd ../hashicups
./install-hashicups.sh
```
Give it a few minutes and then check on the pods. `kubectl get pods`

### Verify K8s Auth

Walk through the Verification steps for [Vault Kubernetes Auth](https://learn.hashicorp.com/tutorials/vault/agent-kubernetes#optional-verify-the-kubernetes-auth-method-configuration)

