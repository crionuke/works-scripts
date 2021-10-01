#!/bin/bash

ECHO_APPS_HOSTNAME=$1

if [ -z "$ECHO_APPS_HOSTNAME" ]; then
  echo "Usage: ./install_echo_apps.sh <echo_apps_hostname>"
  exit 1
fi

helm upgrade echo-apps ./echo-apps \
  --install \
  --create-namespace \
  --namespace echo-apps \
  --set hostname=$ECHO_APPS_HOSTNAME