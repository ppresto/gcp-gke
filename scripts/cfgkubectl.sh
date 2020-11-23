#!/bin/bash
echo ${GOOGLE_CREDENTIALS} > /Users/patrickpresto/Projects/workshops/gcp-gke/credential_key.json
gcp_region=us-east1
gcp_cluster_name=presto-gke

gcloud auth activate-service-account --key-file=/Users/patrickpresto/Projects/workshops/gcp-gke/credential_key.json
gcloud config set project ${GOOGLE_PROJECT}
gcloud config set compute/region ${gcp_region}
gcloud container clusters get-credentials ${gcp_cluster_name} --region ${gcp_region}
