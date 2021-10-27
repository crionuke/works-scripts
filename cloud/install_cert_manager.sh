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
  --set installCRDs=true \
  --set ingressShim.defaultIssuerName=letsencrypt-prod \
  --set ingressShim.defaultIssuerKind=ClusterIssuer \
  --set ingressShim.defaultIssuerGroup=cert-manager.io


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
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF