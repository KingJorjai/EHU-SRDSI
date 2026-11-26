#!/usr/bin/env bash
# Configura el servidor (VM1) del laboratorio Port Knocking + SPA.
# Servicio protegido: HTTP en 8080. Firewall: cadena PROTECTED con DROP.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
IFACE=enp0s8
PORT=8080

# --- fwknopd: captura por pcap en enp0s8 --------------------------------
sed -i 's/^ENABLE_NFQ_CAPTURE.*/ENABLE_NFQ_CAPTURE          N;/' /etc/fwknop/fwknopd.conf
sed -i 's/^#*VERBOSE.*/VERBOSE                     2;/' /etc/fwknop/fwknopd.conf
grep -q '^PCAP_INTF' /etc/fwknop/fwknopd.conf || \
    echo 'PCAP_INTF                   enp0s8;' >> /etc/fwknop/fwknopd.conf
install -m 600 "$LAB_DIR/access.conf" /etc/fwknop/access.conf

# --- knockd --------------------------------------------------------------
install -m 644 "$LAB_DIR/knockd.conf" /etc/knockd.conf
sed -i 's/^START_KNOCKD=.*/START_KNOCKD=1/' /etc/default/knockd
sed -i 's|^#*KNOCKD_OPTS=.*|KNOCKD_OPTS="-i enp0s8"|' /etc/default/knockd

# --- Firewall: DROP por defecto para el servicio protegido --------------
iptables -N PROTECTED 2>/dev/null || true
iptables -F PROTECTED
iptables -A PROTECTED -j DROP
iptables -C INPUT -p tcp --dport "$PORT" -j PROTECTED 2>/dev/null || \
    iptables -I INPUT 1 -p tcp --dport "$PORT" -j PROTECTED

# --- Servicio HTTP de prueba -------------------------------------------
pkill -f "http.server ${PORT}" 2>/dev/null || true
nohup python3 -m http.server "$PORT" --bind 0.0.0.0 >/tmp/http8080.log 2>&1 &

# --- Servicios -----------------------------------------------------------
systemctl enable --now knockd fwknop-server
systemctl restart knockd fwknop-server
sleep 1

echo "=== knockd ==="
systemctl --no-pager --lines=0 status knockd || true
echo "=== fwknop-server ==="
systemctl --no-pager --lines=0 status fwknop-server || true
echo "=== iptables INPUT ==="
iptables -S INPUT
echo "=== iptables PROTECTED ==="
iptables -S PROTECTED
echo "=== iptables FWKNOP_INPUT ==="
iptables -S FWKNOP_INPUT 2>/dev/null || true
echo "=== http ==="
ss -ltnp | grep ":${PORT} " || true
