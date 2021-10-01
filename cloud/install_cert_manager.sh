#!/bin/bash
set -e

LETSENCRYPT_EMAIL=$1

if [ -z "$LETSENCRYPT_EMAIL" ]; then
  echo "Usage: ./install_cert_manager.sh <letsencrypt_email>"
  exit 1
fi

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade cert-manager jetstack/cert-manager \
  --install \
  --create-namespace \
  --namespace cert-manager \
  --version v1.5.3 \
  --set installCRDs=true

cat << EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $LETSENCRYPT_EMAIL
    privateKeySecretRef:
      name: letsencrypt-p
      rod-private-key
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: cert-manager
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $LETSENCRYPT_EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging-private-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF