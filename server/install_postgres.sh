#!/bin/bash
set -e

# Install postgres with docker-compose

POSTGRES_NAME=$1
POSTGRES_IPADDR=${2:-0.0.0.0}
POSTGRES_PORT=${3:-5432}

if [ -z "$POSTGRES_NAME" ]; then
  echo "Usage: ./install_postgres.sh <postgres_name> <postgres_ipaddr:-0.0.0.0> <postgres_port:-5432>"
  exit 1
fi

if [ -d "$POSTGRES_NAME" ]; then
  sudo rm -rf $POSTGRES_NAME
fi
mkdir $POSTGRES_NAME

pushd $POSTGRES_NAME

# Env
cat > .env << EOF
POSTGRES_NAME=$POSTGRES_NAME
POSTGRES_PORT=$POSTGRES_PORT
POSTGRES_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
PRIVATE_INET=$(ip route | grep eth1 | awk '{print $1}')
PRIVATE_IP=$(ip route | grep eth1 | awk '{print $9}')
EOF
chmod 700 .env
source .env

# Structure
mkdir -p data
mkdir -p certs

# Certs
openssl req -new -x509 -days 365 -nodes -text \
  -out certs/server.crt -keyout certs/server.key \
  -subj "/CN=$POSTGRES_NAME"
chmod 600 certs/server.key
# 999:999 for debian, 70:70 for alpine
sudo chown 999:999 certs/server.key

cat > init.sql << EOL
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION $POSTGRES_NAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA $POSTGRES_NAME GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $POSTGRES_NAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA $POSTGRES_NAME GRANT USAGE, SELECT ON SEQUENCES TO $POSTGRES_NAME;
SET ROLE $POSTGRES_NAME;
EOL

cat > pg_hba.conf << EOL
local all all trust
hostssl all all all md5
EOL

cat > docker-compose.yaml << EOL
version: '3'

services:
  postgres:
    image: postgres
    command: -c ssl=on \
      -c ssl_cert_file=/var/lib/postgresql/server.crt \
      -c ssl_key_file=/var/lib/postgresql/server.key \
      -c hba_file=/var/lib/postgresql/pg_hba.conf
    ports:
      - "${POSTGRES_IPADDR}:${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_DB: $POSTGRES_NAME
      POSTGRES_USER: $POSTGRES_NAME
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
    volumes:
      - ./data:/var/lib/postgresql/data
      - ./pg_hba.conf:/var/lib/postgresql/pg_hba.conf
      - ./certs/server.crt:/var/lib/postgresql/server.crt:ro
      - ./certs/server.key:/var/lib/postgresql/server.key:ro
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped
EOL

# Ctl
cat > restart.sh << EOL
#!/bin/bash

docker-compose kill
docker-compose rm -f
docker-compose up -d
EOL

# Run
chmod u+x restart.sh
./restart.sh

popd