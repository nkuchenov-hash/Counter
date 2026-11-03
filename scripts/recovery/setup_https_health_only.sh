#!/usr/bin/env bash
set -euo pipefail

# Public HTTPS PROBE ONLY. It does not publish PocketBase authentication,
# user data, collection API, realtime endpoints or its admin dashboard.
# LIFE OS production traffic must not be switched to this staging service.
[ "$(id -u)" -eq 0 ] || { echo 'ERROR: run as root' >&2; exit 1; }
systemctl is-active --quiet lifeos-recovery-stage.service || {
  echo 'ERROR: staging PocketBase is not active' >&2; exit 1;
}
domain=137-22-146-109.sslip.io
expected_ip=137.22.146.109
actual_ips="$(getent ahostsv4 "$domain" | awk '{print $1}' | sort -u)"
if [ "$actual_ips" != "$expected_ip" ]; then
  echo "ERROR: DNS for $domain did not resolve exclusively to $expected_ip (got: $actual_ips)" >&2
  exit 1
fi
if ! ss -ltn | grep -qE '127[.]0[.]0[.]1:8099[[:space:]]'; then
  echo 'ERROR: staging PocketBase is not listening on 127.0.0.1:8099' >&2
  exit 1
fi

# Ubuntu 24.04 package supports Caddy v2: route handles, reverse_proxy and
# automatic TLS. A newer version can later be adopted through official repo.
export DEBIAN_FRONTEND=noninteractive
apt-get install -y caddy
install -d -m 0755 /etc/caddy
if [ -f /etc/caddy/Caddyfile ]; then
  cp -a /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.pre-lifeos-$(date -u +%Y%m%dT%H%M%SZ)"
fi
cat >/etc/caddy/Caddyfile <<'CADDY'
137-22-146-109.sslip.io {
    @health {
        method GET
        path /api/health
    }
    handle @health {
        reverse_proxy 127.0.0.1:8099
    }
    handle {
        respond "LIFE OS recovery staging: user data API is not public" 503
    }
}
CADDY

caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
# Preserve SSH when the host uses UFW. Never auto-enable a previously disabled firewall.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q 'Status: active'; then
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
fi
systemctl enable --now caddy
systemctl reload caddy

echo "Attempting TLS health check at https://$domain/api/health"
if curl --fail --silent --show-error --max-time 35 "https://$domain/api/health"; then
  echo
  echo "SUCCESS: public HTTPS health probe works."
else
  echo
  echo "WARNING: HTTPS probe not yet available. Confirm provider/network ports 80/443, DNS and certificate issuance." >&2
  echo "Check: journalctl -u caddy -n 60 --no-pager" >&2
  exit 1
fi
# This route MUST remain denied externally; reject accidental API exposure.
status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 10 "https://$domain/api/collections/profiles/records")"
[ "$status" = 503 ] || {
  echo "ERROR: external user-data API is not denied as expected (HTTP $status)" >&2
  exit 1
}
echo "SUCCESS: client API remains unavailable (HTTP 503)."
