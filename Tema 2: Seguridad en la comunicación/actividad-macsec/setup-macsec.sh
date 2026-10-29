#!/usr/bin/env bash
# Configura MACsec en una de las dos VM del laboratorio.
# Uso (como root): setup-macsec.sh mv1|mv2 [--replay]
set -euo pipefail

ROLE="${1:-}"
REPLAY="${2:-}"
KEY1="11111111111111111111111111111111"
KEY2="22222222222222222222222222222222"

case "$ROLE" in
  mv1)
    DEV="macsec0"; IP="1.1.1.1/24"; NATIP="10.0.3.11/24"
    PEER_MAC="08:00:27:d1:03:ae"; TXID="01"; RXID="02"
    ;;
  mv2)
    DEV="macsec1"; IP="1.1.1.2/24"; NATIP="10.0.3.12/24"
    PEER_MAC="08:00:27:17:ce:47"; TXID="02"; RXID="01"
    ;;
  *)
    echo "Uso: $0 mv1|mv2 [--replay]" >&2
    exit 1
    ;;
esac

if [ "$ROLE" = "mv1" ]; then
  TXKEY="$KEY1"; RXKEY="$KEY2"
else
  TXKEY="$KEY2"; RXKEY="$KEY1"
fi

modprobe macsec
ip link set enp0s9 up
ip addr flush dev enp0s9
ip addr add "$NATIP" dev enp0s9
ip link del "$DEV" 2>/dev/null || true

opts=(encrypt on)
if [ "$REPLAY" = "--replay" ]; then
  opts+=(replay on window 0)
fi
ip link add link enp0s9 "$DEV" type macsec "${opts[@]}"
ip macsec add "$DEV" tx sa 0 pn 100 on key "$TXID" "$TXKEY"
ip macsec add "$DEV" rx address "$PEER_MAC" port 1
ip macsec add "$DEV" rx address "$PEER_MAC" port 1 sa 0 pn 100 on key "$RXID" "$RXKEY"
ip link set "$DEV" up
ip addr add "$IP" dev "$DEV"

echo "== $ROLE: $DEV sobre enp0s9 =="
ip -brief addr show enp0s9
ip -brief addr show "$DEV"
ip macsec show
