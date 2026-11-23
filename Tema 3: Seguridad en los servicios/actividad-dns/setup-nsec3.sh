#!/usr/bin/env bash
# Firma la zona inversa 0.16.172.in-addr.arpa con NSEC3.
# Ejecutar con sudo en el servidor primario (dns1).
set -euo pipefail

BIND=/etc/bind
ZONE=0.16.172.in-addr.arpa
SALT=AABBCCDD

cd "$BIND"
rm -f K$ZONE.* dsset-$ZONE. db.0.16.172.signed* 2>/dev/null || true

dnssec-keygen -a RSASHA256 -b 1024 -f KSK -n ZONE "$ZONE." >/dev/null
dnssec-keygen -a RSASHA256 -b 1024 -n ZONE "$ZONE." >/dev/null

for k in K$ZONE.*.key; do
    grep -q "\$INCLUDE $k" db.0.16.172 || echo "\$INCLUDE $k" >> db.0.16.172
done

dnssec-signzone -3 "$SALT" -t -o "$ZONE." db.0.16.172 >/dev/null

cat > named.conf.local <<'EOF'
zone "srdsi.lab" {
    type primary;
    file "/etc/bind/db.srdsi.lab.signed";
    allow-transfer { key dns1-dns2_tsigkey; };
    also-notify { 192.168.56.111; };
};

zone "0.16.172.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.0.16.172.signed";
    allow-transfer { key dns1-dns2_tsigkey; };
    also-notify { 192.168.56.111; };
};
EOF

named-checkconf "$BIND/named.conf"
systemctl restart bind9
sleep 2
