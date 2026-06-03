#!/usr/bin/env bash
set -e

source ./.env
source ./.env.local

bash ./scripts/start.sh -dr

# Wait a moment for the container to initialize.
sleep 5

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