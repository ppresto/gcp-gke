# Vault Project Template

Project onboarding automation with HashiCorp Vault Enterprise using Terraform Vault provider.  Create a new vault namespace and approle in the root ns of your existing vault cluster and then automate everything within your new ns using the terraform vault provider and modules found here.

* Authenticate application running in Kubernetes Pods
* Authenticate instances running on Google Cloud Platform
* OpenSSH access to instances using Vault SSH secret engine
* Automate Instance onboarding to Vault SSH Secret Engine
 
Modified from platentrobbie.  Thank you for sharing! 
https://github.com/planetrobbie/terraform-vault-onboard


## Requirements:

* [Terraform 0.12](https://www.terraform.io/)
* [Terraform Vault provider](https://www.terraform.io/docs/providers/vault/index.html)
* [Vault Enterprise](https://www.hashicorp.com/products/vault/enterprise)
* [Kubernetes cluster](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s)
 
## Setup

First of all you need to export the following environment variables in your shell environment. But if you're using Terraform Cloud or Enterprise you can easily do so from the UI, just remove `TF_VAR_`. When setting them up in Terraform Cloud or Enterprise, just keep the variable name itself.

So if you're using Terraform Open Source, just export values for the following environment variables, we've kept some default values, feel free to change any of them.

### 1. Configure Root Namespace

We want to restrict Projects to a namespace to limit the blast radius. So First things first, we create 
* 1 new namespace for our project
* 1 new approle id we will use to manage it.

You need to have administrative privileges on your Vault cluster to create namespace and AppRoles in the root namespace. Export the following main environment variables.

    export VAULT_ADDR="https://VAULT_API_ENDPOINT"
    export VAULT_TOKEN="<VAULT_TOKEN>"

the `env.sh` script can set these environment variables for you.  It assumes you have followed the rest of this repo and will pull secrets from `../../install-vault-raft/tmp/`.  
This script will attempt to find the vault root token, k8s config, and setup a `kubectl port-forward` to your vault service to make it look like its http://localhost:8200.  You will want to run `pkill kubectl` after you've successfully applied all your configurations.
```
source env.sh
terraform init
terraform apply -auto-approve

pkill kubectl
```

If that doesn't work, it might be because you haven't exported `VAULT_ADDR` and `VAULT_TOKEN` environment variable to allow our Terraform Vault provider to authenticate.

If it fails at the init step, you may not have internet access, in such a case you have to install the [Terraform Vault provider](https://www.terraform.io/docs/providers/vault/index.html) manually in `~/.terraform.d/plugins`, it's available for all supported platforms below

    https://releases.hashicorp.com/terraform-provider-vault/2.9.0/


### Configure New Project Namespace
Now that we have a namespace created and an approle we will use these to configure our vault project namespace.  
```
cd namespace
```
You'll find all the remaining environment variables gathered into `set-project-env.sh`, edit this file and customize it to your wishes.  This file has been setup to dynamically get most values assuming you follow this guide.

Modify the `main.tf` to setup your auth methods, engines, and policies as needed.  Once you have your vault configuration all in terraform go ahead and apply it to your new namespace.

```
cd ../
terraform init
terraform apply -auto-approve
```
You should have a namespace setup with k/v,  some policies, and /auth/k8s.

In my example project I had to setup KMIP too.  The vault provider doesn't support KMIP as of this project so Im using local-exec and bash.  This script should be able to run from terrafrom and independently if needed.

### Variable Reference:

Namespace where your project onboarding will take place
    
    export TF_VAR_namespace

Where to mount AppRole auth backend

    export TF_VAR_app_role_mount_point

AppRole role name

    export TF_VAR_role_name

Path where to mount a Key/Value Vault Secret Engine

    export TF_VAR_kv_path

Path where to mound a Kubernetes Auth Backend

    export TF_VAR_k8s_path 

###  Kubernetes Overview

    TF_VAR_kubernetes_host: Kubernetes API endpoint for example https://api.k8s.foobar.com
    VAULT_SA_NAME: $(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")

Replace in the line above `vault-auth` by the service account name you're using for your Kubernetes Vault integration. See our [article](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s) for details.

The next two variables allows Vault to verify the token that Kubernetes Pods sends.

    TF_VAR_token_reviewer_jwt=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
    TF_VAR_kubernetes_ca_cert=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

Now we can define a policy which will be associated with each authenticated Pods.

    TF_VAR_policy_name: Kubernetes Vault Policy name to be creation
    TF_VAR_policy_code: Kubernetes Vault Policy JSON definition

As a example you could have in the above variable something like

    $(cat <<EOF
    path "kv/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/data/apikey" {
      capabilities = ["read","list"]
    }
    path "db/creds/dev" {
      capabilities = ["read"]
    }
    path "pki_int/issue/*" {
      capabilities = ["create", "update"]
    }
    path "sys/leases/renew" {
      capabilities = ["create"]
    }
    path "sys/leases/revoke" {
      capabilities = ["update"]
    }
    path "sys/renew/*" {
      capabilities = ["update"]
    }
    EOF
    )

### Kubernetes - Test Authentication

To verify that everything went according to plan, launch a vault pod in the corresponding Kubernetes namespace, and login to vault

```
kubectl apply -f scripts/vault-test-pod.yaml
kubectl exec -it vault-test-pod -- bash

JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
VAULT_TOKEN=$(curl -k --request POST \
    --header "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
    --data '{"jwt": "'"$JWT"'", "role": "'"$VAULT_ROLE"'"}' \
    $VAULT_ADDR/v1/auth/k8s/login | jq -r '.auth.client_token')
echo $VAULT_TOKEN

curl \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --header "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
  http://vault.default.svc:8200/v1/kv/data/database/config
```

You can also use the vault CLI
```
JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

kubectl run --rm -i --tty vault-test \
--env="VAULT_ADDR=http://vault.default.svc:8200" \
--image=vault:latest --restart=Never -- /bin/sh

vault write auth/k8s/login role=<ROLE> jwt=$JWT
```

Once login is successful vault will give you a token: $VAULT_TOKEN.  Use this to test your permissions by getting a known k/v secret.
```
curl \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --header "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
  http://vault.default.svc:8200/v1/kv/data/database/config
```


### Additional K8s Troubleshooting

When trying to authenticate if you get a message like

    * service account name not authorized

It is mostly probably due to a wrong role setup, make sure the role allows the service account under which the pod is running. If you don't have a line in your manifest saying

    serviceAccountName: <SERVICE_ACCOUNT>

Your pod will run under `default`, so your role needs to be configured with

    bound_service_account_names=default

or to allow all

    bound_service_account_names=*

If you want to check under which service account your pod is running you can use

    kubectl get po/<POD_NAME> -o yaml | grep serviceAccount

If that's not the service account which is causing issues it could also be the namespace, check that with

    kubectl get po/<POD_NAME> -o yaml | grep namespace

The Vault k8s role definition should match both service account and namespace, verify that with

     vault read -namespace=<VAULT_NAMESPACE>  auth/<k8s_auth_mount_point>/role/<ROLE>

### Commands

Troubleshooting vault secrets injection
```
kubectl exec -it mongodb-standalone-kmip-0 --container vault-agent-init -- sh
kubectl get mutatingwebhookconfigurations
kubectl get pod mongodb-standalone-kmip-0 -o yaml | grep serviceAccount
kubectl get pod mongodb-standalone-kmip-0 -o yaml | grep namespace
```

Testing new annotations with yaml
```
kubectl edit statefulset mongodb-standalone-kmip  # update replicas to 0
vi ../mongo-ent/tf-PVC-withKMIP/patch.yaml
kubectl patch statefulset mongodb-standalone-kmip --patch "$(cat ../mongo-ent/tf-PVC-withKMIP/patch.yaml)"

```

Useful containers
```
kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=mongodb --image alpine:3.7 --restart=Never -- sh
apk update && apk add curl jq

kubectl run --generator=run-pod/v1 -i --tty tmp2 --image=praqma/network-multitool --serviceaccount=app-auth --restart=Never -- sh

kubectl run test --rm -i --tty \
    --env="VAULT_ADDR=https://vault:8200" \
    --image alpine:latest -- /bin/sh
```

You can set the ENV var AGENT_INJECT_LOG_LEVEL to debug in the vault-agent-injector deployment to get more details in the log. Then you can view the agent-injector logs kubectl logs -n vault vault-agent-injector-XXXXXX

## Links

* HashiCorp Vault [documentation](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s)
* Kubernetes Tips: [Using a ServiceAccount](https://medium.com/better-programming/k8s-tips-using-a-serviceaccount-801c433d0023)