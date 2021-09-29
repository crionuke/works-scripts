#!/bin/bash
set -e

# Setup docker registry with docker-compose beneath nginx with ssl by letsencrypt and secured by htpasswd

REGISTRY_NAME=$1
BASE_DOMAIN=$2
SERVER_PORT=$3

if [ -z "$REGISTRY_NAME" -o -z "$BASE_DOMAIN" -o -z "$SERVER_PORT" ]; then
  echo "Usage: ./install_registry.sh <registry_name> <base_domain> <server_port>"
  exit 1
fi

if [ -d "$REGISTRY_NAME" ]; then
  rm -rf $REGISTRY_NAME
fi
mkdir $REGISTRY_NAME

pushd $REGISTRY_NAME

# Install htpasswd
sudo apt install -y apache2-utils

# Env
cat > .env << EOF
REGISTRY_NAME=$REGISTRY_NAME
SERVER_PORT=$SERVER_PORT
BASE_DOMAIN=$BASE_DOMAIN
PRIVATE_INET=$(ip route | grep eth1 | awk '{print $1}')
PRIVATE_IP=$(ip route | grep eth1 | awk '{print $9}')
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
EOF
chmod 700 .env
source .env

# Setup structure
mkdir -p htpasswd
mkdir -p data

# Generate credential
htpasswd -bBc htpasswd/passwords $REGISTRY_NAME $PASSWORD

#
cat > docker-compose.yaml << EOL
version: '3'

services:
  registry:
    image: registry:2
    ports:
      - "${PRIVATE_IP}:${SERVER_PORT}:5000"
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: $REGISTRY_NAME
      REGISTRY_AUTH_HTPASSWD_PATH: /htpasswd/passwords
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
    volumes:
      - ./htpasswd:/htpasswd
      - ./data:/data
    restart: unless-stopped
EOL

# Ctl
cat > restart.sh << EOL
#!/bin/bash

docker-compose kill
docker-compose rm -f
docker-compose up -d
EOL

# Run registry
chmod u+x restart.sh
./restart.sh

# Add server to nginx
sudo mkdir -p /var/www/$REGISTRY_NAME.$BASE_DOMAIN/html
sudo chmod -R 755 /var/www/$REGISTRY_NAME.$BASE_DOMAIN
sudo bash -c "cat > /etc/nginx/sites-available/$REGISTRY_NAME.$BASE_DOMAIN" << EOL
server {
    listen 80;
    listen [::]:80;
    index index.html index.htm index.nginx-debian.html;
    server_name $REGISTRY_NAME.$BASE_DOMAIN;
    location / {
        proxy_pass                          http://$PRIVATE_IP:${SERVER_PORT};
        proxy_set_header  Host              \$http_host;
        proxy_set_header  X-Real-IP         \$remote_addr;
        proxy_set_header  X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header  X-Forwarded-Proto \$scheme;
        proxy_read_timeout                  900;
    }
}
EOL
sudo ln -f -s /etc/nginx/sites-available/$REGISTRY_NAME.$BASE_DOMAIN /etc/nginx/sites-enabled/
sudo service nginx reload
# Certbot
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $REGISTRY_NAME.$BASE_DOMAIN

popd
