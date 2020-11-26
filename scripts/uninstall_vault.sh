#!/bin/bash
helm uninstall vault
kubectl delete pvc -l app.kubernetes.io/name=vault