#!/bin/bash
helm uninstall vault-primary
kubectl delete pvc -l app.kubernetes.io/name=vault