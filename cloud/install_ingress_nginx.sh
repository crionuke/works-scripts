#!/bin/bash
set -e

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --atomic \
  --install \
  --create-namespace \
  --namespace ingress-nginx
