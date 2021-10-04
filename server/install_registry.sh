#!/bin/bash
set -e

# Install docker registry with docker-compose beneath nginx with ssl by letsencrypt and secured by htpasswd

REGISTRY_NAME=$1
BASE_DOMAIN=$2
REGISTRY_UI_PORT=${3:-8080}

if [ -z "$REGISTRY_NAME" -o -z "$BASE_DOMAIN" ]; then
  echo "Usage: ./install_registry.sh <registry_name> <base_domain> <registry_ui_port:-8080>"
  exit 1
fi

if [ -d "$REGISTRY_NAME" ]; then
  sudo rm -rf $REGISTRY_NAME
fi
mkdir $REGISTRY_NAME

pushd $REGISTRY_NAME

# Install htpasswd
sudo apt install -y apache2-utils

# Env
cat > .env << EOF
REGISTRY_NAME=$REGISTRY_NAME
REGISTRY_URL=$REGISTRY_NAME.$BASE_DOMAIN
REGISTRY_USERNAME=$REGISTRY_NAME
REGISTRY_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
PRIVATE_INET=$(ip route | grep eth1 | awk '{print $1}')
PRIVATE_IP=$(ip route | grep eth1 | awk '{print $9}')
EOF
chmod 700 .env
source .env

mkdir -p data

cat > docker-compose.yaml << EOL
version: '3'
services:
  registry:
    image: registry:2
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
    volumes:
      - ./data:/data
    networks:
      - registry-net
    restart: unless-stopped
  ui:
    image: joxit/docker-registry-ui:latest
    ports:
      - "${PRIVATE_IP}:${REGISTRY_UI_PORT}:80"
    environment:
      - REGISTRY_TITLE=$REGISTRY_NAME
      - NGINX_PROXY_PASS_URL=http://registry:5000
      - SINGLE_REGISTRY=true
    depends_on:
      - registry
    networks:
      - registry-net
networks:
  registry-net:
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
# Generate credential
sudo mkdir -p /etc/nginx/htpasswd
sudo htpasswd -bBc /etc/nginx/htpasswd/.$REGISTRY_NAME.$BASE_DOMAIN $REGISTRY_NAME $REGISTRY_PASSWORD
# Create virtualhost
sudo bash -c "cat > /etc/nginx/sites-available/$REGISTRY_NAME.$BASE_DOMAIN" << EOL
server {
    listen 80;
    listen [::]:80;
    index index.html index.htm index.nginx-debian.html;
    server_name $REGISTRY_NAME.$BASE_DOMAIN;
    location / {
        auth_basic                          "$REGISTRY_NAME.$BASE_DOMAIN";
        auth_basic_user_file                /etc/nginx/htpasswd/.$REGISTRY_NAME.$BASE_DOMAIN;
        proxy_pass                          http://$PRIVATE_IP:${REGISTRY_UI_PORT};
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
