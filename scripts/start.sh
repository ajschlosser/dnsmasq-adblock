#!/usr/bin/bash

set -e

source ./.env

# process command line options
function process_opts() {
  while getopts "hbdflr" opt; do
    case $opt in
      h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  -h        Show this help message and exit"
        echo "  -b        Rebuild the docker image before starting the container"
        echo "  -d        Start the container in detached mode (default)"
        echo "  -f        Force recreate the container even if it's already running"
        echo "  -l        Tail logs after starting the container (implies detached mode)"
        echo "  -r        Stop the container if it's running and start it"
        exit 0
        ;;
      b)
        BUILD_IMAGE=true
        ;;
      d)
        DETACHED_MODE=true
        ;;
      f)
        FORCE_RECREATE=true
        ;;
      l)
        TAIL_LOGS=true
        DETACHED_MODE=true
        ;;
      r)
        RESTART_CONTAINER=true
        ;;
      *)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
  done
}

# Get user confirmation for stopping the container if it's already running
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

# Source environment variables from a file if it exists
function source_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    echo "Loading environment variables from $env_file..."
    source "$env_file"
  else
    echo "Warning: $env_file not found. Skipping."
  fi
}

# Print the values of specified environment variables
function print_env_vars() {
  local vars=("$@")
  echo "Using the following configuration:"
  for var in "${vars[@]}"; do
    echo "  $var: ${!var}"
  done
}

# Check if specified local files exist and print a warning if they don't
function check_local_files() {
  local files=("$@")
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      echo "Warning: $file not found. You may want to create it to customize your configuration."
    fi
  done
}

# Start the container with the specified options
function start_container() {
  docker compose \
    --env-file ./.env \
    --env-file ./.env.local \
    up ${DETACHED_MODE:+-d} ${BUILD_IMAGE:+--build} ${FORCE_RECREATE:+--force-recreate}
  if [ "$TAIL_LOGS" = true ]; then
    echo "Tailing logs from the container..."
    docker compose logs dnsmasq-adblock -f
  fi
}

env_vars=(
  "DNS_BIND_IP"
  "DNS_CACHE_SIZE"
  "DNS_LISTEN_PORT"
)

process_opts "$@"

source_env_file "./.env.local"

print_env_vars "${env_vars[@]}"

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

check_local_files "../config/local.conf" "../data/blocklist-urls.local.txt"

cd ../

echo "Starting dnsmasq-adblock container..."

if [ "$(docker compose ps -q)" ]; then
  echo "Container is already running. Do you want to stop it and restart it? (y/n)"
  echo "  Note: If you do not have another DNS server running on the host,"
  echo "  you may lose DNS resolution when stopping the container."
  if [ ! $RESTART_CONTAINER = true ]; then
    get_yn_response
  fi
  docker compose stop
fi

start_container