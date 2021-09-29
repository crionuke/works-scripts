#!/bin/bash
set -e

# Install nginx, setup firewall

apt update -y
# nginx
apt install -y nginx
service nginx restart
# Setup firewall
ufw allow 80
ufw allow 443
ufw status verbose
