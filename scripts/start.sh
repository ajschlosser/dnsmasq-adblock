#!/usr/bin/bash

set -e

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

if [ ! -f "../config/local.conf" ]; then
  echo "No local.conf found. Creating a default one with bind-interfaces enabled."
  echo "# Local configuration" > ../config/local.conf
fi

echo "Starting dnsmasq-adblock container..."

cd ../
docker compose up -d --build --force-recreate