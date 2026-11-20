#!/bin/sh
set -e
UUID="${UUID:?UUID env required}"
WS_PATH="${WS_PATH:-/dv-ws}"
PORT="${PORT:-8080}"
mkdir -p /etc/xray
cat > /etc/xray/config.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "listen": "0.0.0.0",
    "port": ${PORT},
    "protocol": "vless",
    "settings": {"clients": [{"id": "${UUID}"}], "decryption": "none"},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "${WS_PATH}"}}
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
exec /usr/bin/xray run -config /etc/xray/config.json
