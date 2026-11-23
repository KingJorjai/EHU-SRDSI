#!/usr/bin/env bash
# Capturas contra el servidor IMAP real de la UPV/EHU (ikasle.ehu.eus).
# No se envian credenciales reales: saludo, CAPABILITY, STARTTLS y un
# intento de LOGIN con credenciales ficticias.
set -euo pipefail
cd "$(dirname "$0")"
IFACE="${IFACE:-enp0s3}"
HOST=ikasle.ehu.eus
IP=$(getent hosts "$HOST" | awk '{print $1}' | head -1)
FILTER="host $IP and (tcp port 143 or tcp port 993)"
OUT=../capturas
mkdir -p "$OUT"

echo "Servidor $HOST ($IP), interfaz $IFACE"

echo "[1/4] 143: saludo + CAPABILITY en claro"
dumpcap -i "$IFACE" -f "$FILTER" -a duration:6 -w "$OUT/real-143-cleartext.pcapng" >/dev/null 2>&1 &
cap=$!; sleep 0.8
python3 probe143.py "$HOST" 143
wait "$cap" || true

echo "[2/4] 143: intento de LOGIN en claro (rechazado)"
dumpcap -i "$IFACE" -f "$FILTER" -a duration:6 -w "$OUT/real-143-login-blocked.pcapng" >/dev/null 2>&1 &
cap=$!; sleep 0.8
python3 probe_login_blocked.py "$HOST"
wait "$cap" || true

echo "[3/4] 143: STARTTLS"
dumpcap -i "$IFACE" -f "$FILTER" -a duration:8 -w "$OUT/real-143-starttls.pcapng" >/dev/null 2>&1 &
cap=$!; sleep 0.8
python3 probe_starttls.py "$HOST"
wait "$cap" || true

echo "[4/4] 993: IMAPS (TLS implicito)"
dumpcap -i "$IFACE" -f "$FILTER" -a duration:6 -w "$OUT/real-993-imaps.pcapng" >/dev/null 2>&1 &
cap=$!; sleep 0.8
timeout 12 openssl s_client -connect "$HOST":993 \
  -servername "$HOST" -brief </dev/null >/tmp/real-imaps.txt 2>&1 || true
wait "$cap" || true

echo "Hecho. Capturas en $OUT"
