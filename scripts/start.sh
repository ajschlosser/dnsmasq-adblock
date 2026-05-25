#!/usr/bin/bash

set -e

source ./.env

if [ -f "./.env.local" ]; then
  echo "Loading environment variables from .env.local..."
  source ./.env.local
fi

echo "Using the following configuration:"
echo "  CONTAINER_MODE: ${CONTAINER_MODE}"
echo "  DNS_BIND_IP: ${DNS_BIND_IP}"
echo "  DNS_CACHE_SIZE: ${DNS_CACHE_SIZE}"
echo "  DNS_LISTEN_PORT: ${DNS_LISTEN_PORT}"

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

if [ ! -f "../config/local.conf" ]; then
  echo "No local.conf found. Creating a default one with bind-interfaces enabled."
  echo "# Local configuration" > ../config/local.conf
fi

cd ../

echo "Starting dnsmasq-adblock container..."

if [ "$(docker compose ps -q)" ]; then
  echo "Container is already running. Do you want to stop it and restart it? (y/n)"
  echo "  Note: If you do not have another DNS server running on the host,"
  echo "  you may lose DNS resolution when stopping the container."
  read -r response
  while [ "$response" != "y" ]; do
    if [ "$response" == "n" ]; then
      echo "Exiting without restarting the container."
      exit 0
    fi
    echo "Invalid response. Please enter 'y' or 'n'."
    read -r response
  done
    docker compose stop
fi

docker compose \
  --env-file ./.env \
  --env-file ./.env.local \
  up -d --build --force-recreate