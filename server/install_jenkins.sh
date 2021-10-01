#!/bin/bash
set -e

# Setup jenkins with docker-compose beneath nginx with ssl by letsencrypt and secured by htpasswd

JENKINS_NAME=$1
BASE_DOMAIN=$2
SERVER_PORT=$3

if [ -z "$JENKINS_NAME" -o -z "$BASE_DOMAIN" -o -z "$SERVER_PORT" ]; then
  echo "Usage: ./install_jenkins.sh <JENKINS_NAME> <base_domain> <server_port>"
  exit 1
fi

if [ -d "$JENKINS_NAME" ]; then
  rm -rf $JENKINS_NAME
fi
mkdir $JENKINS_NAME

pushd $JENKINS_NAME

# Install htpasswd
sudo apt install -y apache2-utils

# Env
cat > .env << EOF
JENKINS_NAME=$JENKINS_NAME
SERVER_PORT=$SERVER_PORT
BASE_DOMAIN=$BASE_DOMAIN
PRIVATE_INET=$(ip route | grep eth1 | awk '{print $1}')
PRIVATE_IP=$(ip route | grep eth1 | awk '{print $9}')
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
EOF
chmod 700 .env
source .env

mkdir -p data

cat > docker-compose.yaml << EOL
version: '3'

services:
  jenkins:
    image: jenkins/jenkins:lts
    privileged: true
    user: root
    ports:
      - "${PRIVATE_IP}:${SERVER_PORT}:8080"
    volumes:
      - ./data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
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
sudo mkdir -p /var/www/$JENKINS_NAME.$BASE_DOMAIN/html
sudo chmod -R 755 /var/www/$JENKINS_NAME.$BASE_DOMAIN
# Generate credential
sudo mkdir -p /etc/nginx/htpasswd
sudo htpasswd -bBc /etc/nginx/htpasswd/.$JENKINS_NAME.$BASE_DOMAIN $JENKINS_NAME $PASSWORD
# Create virtualhost
sudo bash -c "cat > /etc/nginx/sites-available/$JENKINS_NAME.$BASE_DOMAIN" << EOL
server {
    listen 80;
    listen [::]:80;
    index index.html index.htm index.nginx-debian.html;
    server_name $JENKINS_NAME.$BASE_DOMAIN;
    location / {
        auth_basic                          "$JENKINS_NAME.$BASE_DOMAIN";
        auth_basic_user_file                /etc/nginx/htpasswd/.$JENKINS_NAME.$BASE_DOMAIN;
        # Don't forward auth to Tomcat
        proxy_set_header                    Authorization "";
        proxy_pass                          http://$PRIVATE_IP:${SERVER_PORT};
    }
}
EOL
sudo ln -f -s /etc/nginx/sites-available/$JENKINS_NAME.$BASE_DOMAIN /etc/nginx/sites-enabled/
sudo service nginx reload
# Certbot
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $JENKINS_NAME.$BASE_DOMAIN

popd