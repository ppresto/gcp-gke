#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# SERVICE is the name of the Vault service in Kubernetes.
# It does not have to match the actual running service, though it may help for consistency.
SERVICE=vault-internal

# NAMESPACE where the Vault service is running.
if [[ $(terraform output -state=${DIR}/../terraform.tfstate gke_namespace) ]]; then
  NAMESPACE=$(terraform output -state=${DIR}/../terraform.tfstate gke_namespace)
elif [[ ! -z "${1}" ]]; then
  NAMESPACE="${1}"
else
  NAMESPACE="default"
fi
echo "namespace: $NAMESPACE"

# SECRET_NAME to create in the Kubernetes secrets store.
SECRET_NAME=vault-server-tls
# CSR to create/approve in K8s
export CSR_NAME=vault-server-csr

# TMPDIR is a temporary working directory.
TMPDIR="../tmp/tls"
if [[ ! -d ${DIR}/${TMPDIR} ]]; then
    mkdir -p ${DIR}/${TMPDIR}
fi

# Cleanup Existing Certs
kubectl --namespace $NAMESPACE delete secrets ${SECRET_NAME}
kubectl --namespace $NAMESPACE delete csr ${CSR_NAME}

# Create Key
openssl genrsa -out ${DIR}/${TMPDIR}/vault-server.key 2048
echo "Created vault-server.key"

# Create CSR
cat <<EOF >${DIR}/${TMPDIR}/vault-server-csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.${SERVICE}
DNS.2 = *.${SERVICE}.${NAMESPACE}
DNS.3 = *.${SERVICE}.${NAMESPACE}.svc
DNS.4 = vault-0
DNS.5 = *.vault-active.${NAMESPACE}.svc
DNS.6 = *.vault-standby.${NAMESPACE}.svc
DNS.7 = *.vault-agent-injector-svc.${NAMESPACE}.svc
DNS.8 = vault.${NAMESPACE}.svc
IP.1 = 127.0.0.1
EOF

openssl req -new -key ${DIR}/${TMPDIR}/vault-server.key \
  -subj "/CN=${SERVICE}.${NAMESPACE}.svc.cluster.local" \
  -out ${DIR}/${TMPDIR}/vault-server.csr \
  -config ${DIR}/${TMPDIR}/vault-server-csr.conf

echo "Created vault-server.csr"

# Create Certificate
cat <<EOF >${DIR}/${TMPDIR}/vault-server-csr.yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  request: $(cat ${DIR}/${TMPDIR}/vault-server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl create -f ${DIR}/${TMPDIR}/vault-server-csr.yaml
sleep 2
kubectl get csr ${CSR_NAME}

# approve csr
kubectl certificate approve ${CSR_NAME}
timeout=60
while [ ${timeout} -ge 1 ]
    do
        status=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.conditions[].type}')
        if [[ $(echo $status | grep Approved) ]]; then
            break
        fi
        timeout=$((${timeout}-2))
        sleep 2
    done
echo "CSR Approved"

# Get server cert
sleep 2
serverCert=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')
echo "${serverCert}" | openssl base64 -d -A -out ${DIR}/${TMPDIR}/vault-server.crt
echo "Created: $(ls -al ${DIR}/${TMPDIR}/vault-server.crt)"
# Get K8s CA
echo "Getting Kubernetes CA"
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode > ${DIR}/${TMPDIR}/vault-server.ca
echo "$(ls -al ${DIR}/${TMPDIR}/vault-server.ca)"

# Create K8s Secret with Certs
kubectl create secret generic ${SECRET_NAME} \
        --namespace ${NAMESPACE} \
        --from-file=vault.key=${DIR}/${TMPDIR}/vault-server.key \
        --from-file=vault.crt=${DIR}/${TMPDIR}/vault-server.crt \
        --from-file=vault.ca=${DIR}/${TMPDIR}/vault-server.ca

kubectl get secret ${SECRET_NAME}