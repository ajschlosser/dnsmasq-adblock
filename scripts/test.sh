#!/usr/bin/env bash
set -e

export CI="${CI:-false}"
sudo CI=$CI bash ./scripts/start.sh -dr

# Wait a moment for the container to initialize.
sleep 5

if [[ "$CI" = "true" ]]; then

    echo "Running in CI environment, checking to see if dnsmasq is running in container."
    RESULT=$(docker compose exec dnsmasq-adblock pgrep dnsmasq)

    if [[ "$RESULT" == "1" ]]; then
        echo "Test passed: dnsmasq is running in the container."
    else
        echo "Test failed: dnsmasq is not running in the container."
        exit 1
    fi
    exit 0
fi

set -a
source ./.env
source ./.env.local
set +a

echo "Running in local environment, testing DNS resolution for blocked domains."

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
    exit 0
fi

# If we reach this point, the test has failed.
exit -1