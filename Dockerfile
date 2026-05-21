# Use Alpine because this image only needs a small Linux userspace,
# dnsmasq, curl, bash, CA certificates, and a minimal init process.
FROM alpine:3.20



# Install:
# - dnsmasq: the DNS forwarder/cache used for adblocking
# - bash: used by scripts/entrypoint.sh
# - curl: downloads blocklist files
# - ca-certificates: validates HTTPS blocklist downloads
# - tini: handles PID 1 / signal forwarding cleanly in Docker
RUN apk add --no-cache dnsmasq curl ca-certificates python3

# Create directories used by mounted config and scripts.
#
# /etc/dnsmasq.d:
#   dnsmasq include files live here.
#
# /etc/dnsmasq-adblock:
#   app-specific files, such as the blocklist URL list, live here.
#
# /scripts:
#   mounted host scripts live here.
RUN mkdir -p /etc/dnsmasq.d /etc/dnsmasq-adblock /scripts

# DNS uses both UDP and TCP on port 53.
# UDP is used for most DNS queries; TCP is used for large responses,
# retries, zone transfers, and standards-compliant fallback behavior.
EXPOSE 53/udp
EXPOSE 53/tcp

# Run the host-mounted entrypoint through tini.
#
# The script generates the blocklist and then execs dnsmasq in the foreground.
ENTRYPOINT ["python3", "-u", "/scripts/entrypoint.py"]