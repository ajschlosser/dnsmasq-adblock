# Use Alpine because this image only needs a small Linux userspace,
# dnsmasq, curl, bash, CA certificates, and a minimal init process.
FROM alpine:3.20

# Run as root to install packages and set up configuration. The entrypoint script
# will drop privileges to run dnsmasq as a non-root user.
USER root

# Build arguments for DNS configuration. These can be overridden at build time
# or runtime to customize the behavior of dnsmasq.
ARG DNS_BIND_IP
ARG DNS_CACHE_SIZE
ARG DNS_LISTEN_PORT

ENV DNS_BIND_IP $DNS_BIND_IP
ENV DNS_CACHE_SIZE $DNS_CACHE_SIZE
ENV DNS_LISTEN_PORT $DNS_LISTEN_PORT

# Install:
# - dnsmasq: the DNS forwarder/cache used for adblocking
# - curl: downloads blocklist files
# - ca-certificates: validates HTTPS blocklist downloads
# - python3: runs the entrypoint script that generates the blocklist and starts dnsmasq
RUN apk add --no-cache dnsmasq curl ca-certificates python3

# Create directories for dnsmasq configuration, blocklists, and scripts.
RUN mkdir -p \
    /etc/dnsmasq.d \
    /usr/local/bin/dnsmasq \
    /usr/local/share/dnsmasq

# Copy configuration files, blocklists, and scripts into the container.
COPY config/[^dnsmasq]*.conf /etc/dnsmasq.d/
COPY config/dnsmasq.conf /etc/dnsmasq.conf
COPY data/*.txt /usr/local/share/dnsmasq/
COPY scripts/*.py /usr/local/bin/dnsmasq/

# DNS uses both UDP and TCP on port 53.
# UDP is used for most DNS queries; TCP is used for large responses,
# retries, zone transfers, and standards-compliant fallback behavior.
EXPOSE ${DNS_LISTEN_PORT}/udp
EXPOSE ${DNS_LISTEN_PORT}/tcp

# Run the host-mounted entrypoint through python3.
#
# The script generates the blocklist and then execs dnsmasq in the foreground.
ENTRYPOINT ["python3", "-u", "/usr/local/bin/dnsmasq/entrypoint.py"]