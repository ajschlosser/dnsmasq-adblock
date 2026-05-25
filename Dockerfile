# Use Alpine because this image only needs a small Linux userspace,
# dnsmasq, curl, bash, CA certificates, and a minimal init process.
FROM alpine:3.20

ARG DNS_BIND_IP
ARG DNS_CACHE_SIZE
ARG DNS_LISTEN_PORT

ENV DNS_BIND_IP $DNS_BIND_IP
ENV DNS_CACHE_SIZE $DNS_CACHE_SIZE
ENV DNS_LISTEN_PORT $DNS_LISTEN_PORT

# Install:
# - dnsmasq: the DNS forwarder/cache used for adblocking
# - bash: used by scripts/entrypoint.sh
# - curl: downloads blocklist files
# - ca-certificates: validates HTTPS blocklist downloads
# - tini: handles PID 1 / signal forwarding cleanly in Docker
RUN apk add --no-cache dnsmasq curl ca-certificates python3

RUN mkdir -p \
    /etc/dnsmasq.d \
    /etc/dnsmasq-adblock \
    /usr/local/bin/dnsmasq \
    /usr/local/share/dnsmasq

# DNS uses both UDP and TCP on port 53.
# UDP is used for most DNS queries; TCP is used for large responses,
# retries, zone transfers, and standards-compliant fallback behavior.
EXPOSE ${DNS_LISTEN_PORT}/udp
EXPOSE ${DNS_LISTEN_PORT}/tcp

# COPY config/dnsmasq.conf /etc/dnsmasq.conf
# COPY config/upstream.conf /etc/dnsmasq.d/upstream.conf
COPY config/*.conf /etc/dnsmasq.d/
COPY data/*.txt /usr/local/share/dnsmasq/
# COPY config/blocklist-urls.local.txt /usr/local/share/dnsmasq/blocklist-urls.local.txt
# COPY config/blocklist-urls.txt /usr/local/share/dnsmasq/blocklist-urls.txt
COPY scripts/*.py /usr/local/bin/dnsmasq/

# Run the host-mounted entrypoint through tini.
#
# The script generates the blocklist and then execs dnsmasq in the foreground.
ENTRYPOINT ["python3", "-u", "/usr/local/bin/dnsmasq/entrypoint.py"]