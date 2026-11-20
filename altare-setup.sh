#!/usr/bin/env bash
# Altare sandbox one-shot: install Xray and run a VLESS+Reality inbound on a given port.
# Usage: bash setup.sh <PORT>
# Prints one RESULT line with the client parameters at the end.
set -u
PORT="${1:-}"
if [ -z "$PORT" ]; then echo "NEED_PORT"; exit 1; fi

if ! command -v curl >/dev/null 2>&1; then
  echo "INSTALLING_CURL"
  apt-get update -qq && apt-get install -y -qq curl >/dev/null 2>&1
fi

XRAY=/usr/local/bin/xray
if [ ! -x "$XRAY" ]; then
  echo "INSTALLING_XRAY"
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
fi
if [ ! -x "$XRAY" ]; then echo "INSTALL_FAILED"; exit 1; fi
"$XRAY" version | head -1

UUID=$("$XRAY" uuid)
KEYS=$("$XRAY" x25519)
PRIV=$(printf '%s\n' "$KEYS" | sed -n 's/.*[Pp]rivate[^:]*:[[:space:]]*//p' | head -1)
PUB=$(printf '%s\n' "$KEYS" | sed -n 's/.*[Pp]ublic[^:]*:[[:space:]]*//p' | head -1)
if [ -z "$PRIV" ]; then PRIV=$(printf '%s\n' "$KEYS" | grep -i 'private' | awk '{print $NF}'); fi
if [ -z "$PUB" ]; then PUB=$(printf '%s\n' "$KEYS" | grep -iE 'public|password' | awk '{print $NF}' | head -1); fi
if [ -z "$PRIV" ] || [ -z "$PUB" ]; then echo "KEYGEN_FAILED"; printf '%s\n' "$KEYS"; exit 1; fi
SID=$(openssl rand -hex 8 2>/dev/null || head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')

mkdir -p /usr/local/etc/xray
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "www.microsoft.com:443",
          "serverNames": ["www.microsoft.com"],
          "privateKey": "$PRIV",
          "shortIds": ["$SID"]
        }
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
    }
  ],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF

"$XRAY" run -test -c /usr/local/etc/xray/config.json || { echo "CONFIG_BAD"; exit 1; }
pkill -f 'xray run' 2>/dev/null
sleep 1
nohup "$XRAY" run -c /usr/local/etc/xray/config.json > /root/xray.log 2>&1 &
sleep 2
if pgrep -f 'xray run' >/dev/null; then echo "XRAY_RUNNING"; else echo "XRAY_NOT_RUNNING"; cat /root/xray.log; exit 1; fi
ss -tlnp 2>/dev/null | grep ":$PORT" || echo "PORT_CHECK_SKIP"
echo "RESULT uuid=$UUID pbk=$PUB sid=$SID port=$PORT"
