#!/bin/bash
kubectl create namespace vault
kubectl create namespace vaultdr

helm install vault hashicorp/vault -f vault.yaml --namespace vault
helm install vault hashicorp/vault -f vault.yaml --namespace vaultdr