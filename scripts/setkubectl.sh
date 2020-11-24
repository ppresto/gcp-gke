#!/bin/bash
#GITDIR=/root/gcp-gke
echo \${GOOGLE_CREDENTIALS} > ${GITDIR}/tmp/credential_key.json
gcp_region=\$(terraform output -state=${GITDIR}/terraform.tfstate region)
gcp_cluster_name=\$(terraform output -state=${GITDIR}/terraform.tfstate kubernetes_cluster_name)

gcloud auth activate-service-account --key-file=${GITDIR}/tmp/credential_key.json
gcloud config set project \${INSTRUQT_GCP_PROJECT_GCP_PROJECT_PROJECT_ID}
gcloud config set compute/region \${gcp_region}
gcloud container clusters get-credentials \${gcp_cluster_name} --region \${gcp_region}