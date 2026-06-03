#!/usr/bin/env bash
set -e

source ./scripts/utils.sh

check_local_files "./.env" "./.env.local" "./.env.ci"

export CI="${CI:-false}"
sudo CI=$CI bash ./scripts/start.sh -dr

# Wait a moment for the container to initialize.
WAIT_TIME=5
if [[ "$CI" = "true" ]]; then
    echo "Running in CI environment, increasing wait time for container initialization."
    WAIT_TIME=8
fi
echo "Waiting $WAIT_TIME seconds for the container to initialize..."
sleep $WAIT_TIME

docker compose logs --tail=20

RESULT=$(docker compose exec dnsmasq-adblock pgrep dnsmasq)

if [[ "$RESULT" == "1" ]]; then
    echo "Test passed: dnsmasq is running in the container. OK."
else
    echo "Test failed: dnsmasq is not running in the container. OK."
    exit 1
fi

set -a
    source_env_file "./.env"
    source_env_file "./.env.local"
set +a

if [[ "$CI" = "true" ]]; then
    set -a
    source_env_file "./.env.ci"
    set +a
fi

# Test that the blocklist is working by querying for a known blocked domain.
RESULT=$(dig @${DNS_BIND_IP} doubleclick.net +short | grep 0.0.0.0)

# Check if the result is non-empty and matches the expected blocked IP address.
if [[ -n "$RESULT" ]]; then
    echo "Test passed: doubleclick.net resolved to $RESULT"
elif [[ "$RESULT" != "0.0.0.0" ]]; then
    echo "Test failed: doubleclick.net did not resolve to 0.0.0.0"
    exit 1
else
    echo "Test passed: doubleclick.net resolved to 0.0.0.0"
fi