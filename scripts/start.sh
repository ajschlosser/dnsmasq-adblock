#!/usr/bin/bash

set -e

ENV_FILE="./.env"

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

if [ ! -f "../config/local.conf" ]; then
  echo "No local.conf found. Creating a default one with bind-interfaces enabled."
  echo "# Local configuration" > ../config/local.conf
fi

echo "Starting dnsmasq-adblock container..."

if [ -f "../.env.local" ]; then
  echo "Loading environment variables from .env.local..."
  ENV_FILE="./.env.local"
fi

if [ "$(docker compose ps -q)" ]; then
  echo "Container is already running. Restarting..."
  docker compose restart
  exit 0
fi

cd ../
docker compose --env-file "$ENV_FILE" up -d --build --force-recreate