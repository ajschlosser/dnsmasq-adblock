#!/usr/bin/bash

set -e

source ./.env

function get_yn_response() {
  read -p "(y/n) " response
  while [ "$response" != "y" ]; do
    if [ "$response" == "n" ]; then
      echo "Exiting without restarting the container."
      exit 0
    fi
    echo "Invalid response. Please enter 'y' or 'n'."
    read -p "(y/n) " response
  done
  echo $response
}

function source_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    echo "Loading environment variables from $env_file..."
    source "$env_file"
  else
    echo "Warning: $env_file not found. Skipping."
  fi
}

function print_env_vars() {
  local vars=("$@")
  echo "Using the following configuration:"
  for var in "${vars[@]}"; do
    echo "  $var: ${!var}"
  done
}

function check_local_files() {
  local files=("$@")
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      echo "Warning: $file not found. You may want to create it to customize your configuration."
    fi
  done
}

function start_container() {
  docker compose \
    --env-file ./.env \
    --env-file ./.env.local \
    up -d --build --force-recreate
}

env_vars=(
  "CONTAINER_MODE"
  "DNS_BIND_IP"
  "DNS_CACHE_SIZE"
  "DNS_LISTEN_PORT"
)

print_env_vars "${env_vars[@]}"

source_env_file "./.env.local"

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

check_local_files "../config/local.conf" "../data/blocklist-urls.local.txt"

cd ../

echo "Starting dnsmasq-adblock container..."

if [ "$(docker compose ps -q)" ]; then
  echo "Container is already running. Do you want to stop it and restart it? (y/n)"
  echo "  Note: If you do not have another DNS server running on the host,"
  echo "  you may lose DNS resolution when stopping the container."
  get_yn_response
  docker compose stop
fi

start_container