#!/usr/bin/env bash
set -euo pipefail

# Path where the generated dnsmasq-compatible block rules will be written.
# This file is mounted from ./config/blocklist.conf on the host.
BLOCKLIST="/generated/blocklist.conf"

# Path to the host-editable list of blocklist URLs.
# This file is mounted from ./config/blocklist-urls.txt on the host.
URL_FILE="/etc/dnsmasq-adblock/blocklist-urls.txt"

# Temporary file used to concatenate all downloaded blocklists before parsing.
TMP="$(mktemp)"

# Ensure the mounted URL file exists before continuing.
if [[ ! -f "$URL_FILE" ]]; then
  echo "ERROR: blocklist URL file not found: $URL_FILE" >&2
  exit 1
fi

# Read blocklist URLs from the URL file.
#
# Processing rules:
# - Remove anything after a # comment marker.
# - Trim leading/trailing whitespace.
# - Ignore blank lines.
URLS=()

while IFS= read -r line || [[ -n "$line" ]]; do
  # Remove Windows carriage returns.
  line="${line//$'\r'/}"

  # Remove comments.
  line="${line%%#*}"

  # Trim leading whitespace.
  line="${line#"${line%%[![:space:]]*}"}"

  # Trim trailing whitespace.
  line="${line%"${line##*[![:space:]]}"}"

  # Skip blank lines.
  [[ -z "$line" ]] && continue

  URLS+=("$line")
done < "$URL_FILE"

# Refuse to start if no usable URLs were found.
if [[ "${#URLS[@]}" -eq 0 ]]; then
  echo "ERROR: no blocklist URLs configured in $URL_FILE" >&2
  exit 1
fi

# Print the exact blocklist sources being used.
echo "Blocklist URLs configured:"
for url in "${URLS[@]}"; do
  echo "  - $url"
done

# Download all configured blocklists into one temporary file.
#
# A failed download is treated as a warning rather than a fatal error so one
# unavailable source does not prevent dnsmasq from starting with the remaining
# lists.
echo "Downloading blocklists..."

DOWNLOAD_OK=0

for url in "${URLS[@]}"; do
  [[ -z "$url" ]] && continue

  echo "Fetching $url"
  if curl -fsSL "$url" >> "$TMP"; then
    DOWNLOAD_OK=1
  else
    echo "Warning: failed to fetch $url" >&2
  fi
  echo >> "$TMP"
done

if [[ "$DOWNLOAD_OK" -eq 0 ]]; then
  if [[ -s "$BLOCKLIST" ]]; then
    echo "Warning: all blocklist downloads failed; reusing existing $BLOCKLIST"
    echo "Starting dnsmasq..."
    exec dnsmasq --conf-file=/etc/dnsmasq.conf
  else
    echo "ERROR: all blocklist downloads failed and no existing blocklist is available." >&2
    exit 1
  fi
fi

# Convert common hosts-file formats into dnsmasq address rules.
#
# Supported input examples:
#   0.0.0.0 doubleclick.net
#   127.0.0.1 doubleclick.net
#   doubleclick.net
#
# Generated dnsmasq output:
#   address=/doubleclick.net/0.0.0.0
#   address=/doubleclick.net/::
#
# The IPv6 :: rule matters because browsers may prefer IPv6 when available.
awk '
  BEGIN { IGNORECASE=1 }

  # Skip comments and empty lines.
  /^[[:space:]]*#/ { next }
  /^[[:space:]]*$/ { next }

  {
    host=""

    # Standard hosts-file format: IP hostname.
    if ($1 == "0.0.0.0" || $1 == "127.0.0.1" || $1 == "::1") {
      host=$2

    # Some lists may provide bare domains.
    } else if ($1 ~ /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/) {
      host=$1
    }

    # Clean up Windows line endings and normalize common www-prefixed entries.
    gsub(/\r/, "", host)
    gsub(/^www\./, "", host)

    # Drop invalid or unsafe values.
    if (host == "") next
    if (host == "localhost") next
    if (host ~ /localhost.localdomain/) next
    if (host ~ /[^A-Za-z0-9.-]/) next
    if (host !~ /\./) next
    if (host ~ /^\./) next
    if (host ~ /\.$/) next

    # Block IPv4 and IPv6 lookups for the domain.
    print "address=/" host "/0.0.0.0"
    print "address=/" host "/::"
  }
' "$TMP" | sort -u > "$BLOCKLIST"

# Remove the temporary concatenated source file.
rm -f "$TMP"

# Print a rule count. There are two rules per blocked hostname: IPv4 and IPv6.
echo "Generated $(grep -c '^address=/' "$BLOCKLIST") dnsmasq block rules."

# Add local.conf if one does not already exist
if [[ ! -f /etc/dnsmasq.d/local.conf ]]; then
  echo "Creating empty local.conf..."
  touch /etc/dnsmasq.d/local.conf
else
  echo "Using existing local.conf..."
fi

# Start dnsmasq in the foreground.
echo "Starting dnsmasq..."
exec dnsmasq --conf-file=/etc/dnsmasq.conf