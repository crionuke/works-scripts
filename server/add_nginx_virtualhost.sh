#!/bin/bash
set -e

# Add virtual host to nginx with letsencrypt

DOMAIN_NAME=$1

if [ -z "$DOMAIN_NAME" ]; then
  echo "Usage: ./add_nginx_virtualhost.sh <domain_name>"
  exit 1
fi

sudo mkdir -p /var/www/$DOMAIN_NAME/html
sudo chmod -R 755 /var/www/$DOMAIN_NAME
# Create virtualhost
sudo bash -c "cat > /etc/nginx/sites-available/$DOMAIN_NAME" << EOL
server {
    listen 80;
    listen [::]:80;
    index index.html index.htm index.nginx-debian.html;
    server_name $DOMAIN_NAME;

    location / {
        root /var/www/$DOMAIN_NAME/html;
    }
}
EOL
sudo ln -f -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
sudo service nginx reload
# Certbot
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME

