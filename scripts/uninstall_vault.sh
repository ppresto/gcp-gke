#!/bin/bash
release=$($(helm list -o json | jq -r '.[].name' | grep vault))
helm uninstall $release
kubectl delete pvc -l app.kubernetes.io/name=vault