#!/usr/bin/env bash
# Configura BIND9 en la VM con la zona srdsi.lab (directa e inversa),
# la firma con DNSSEC y genera una clave TSIG. Ejecutar con sudo.
set -euo pipefail

BIND=/etc/bind
ZONE=srdsi.lab
REV=0.16.172.in-addr.arpa
SERVER_IP=172.16.0.136
HOST1_IP=172.16.0.138

cd "$BIND"

# --- Zonas ---------------------------------------------------------------
cat > "$BIND/named.conf.local" <<'EOF'
// zona de resolución directa "srdsi.lab"
zone "srdsi.lab" {
    type primary;
    file "/etc/bind/db.srdsi.lab";
};

// zona de resolución inversa "0.16.172.in-addr.arpa"
zone "0.16.172.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.0.16.172";
};
EOF

cat > "$BIND/db.srdsi.lab" <<EOF
\$ORIGIN $ZONE.
\$TTL 2h
@       IN  SOA dns1.$ZONE. admin.$ZONE. (
            2026112301 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
$ZONE.  IN NS    dns1.$ZONE.
dns1    IN A     $SERVER_IP
host1   IN A     $HOST1_IP
www     IN CNAME host1
EOF

cat > "$BIND/db.0.16.172" <<EOF
\$TTL 604800
@       IN  SOA dns1.$ZONE. admin.$ZONE. (
            2026112301 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@       IN NS  dns1.$ZONE.
136     IN PTR dns1.$ZONE.
138     IN PTR host1.$ZONE.
EOF

named-checkconf "$BIND/named.conf"
named-checkzone "$ZONE" "$BIND/db.srdsi.lab"
named-checkzone "$REV" "$BIND/db.0.16.172"
systemctl restart bind9
sleep 1
rndc status

# --- DNSSEC --------------------------------------------------------------
cd "$BIND"
rm -f Ksrdsi.lab.* dsset-srdsi.lab. db.srdsi.lab.signed* 2>/dev/null || true

dnssec-keygen -a RSASHA256 -b 1024 -f KSK -n ZONE "$ZONE." >/dev/null
dnssec-keygen -a RSASHA256 -b 1024 -n ZONE "$ZONE." >/dev/null

for k in Ksrdsi.lab.*.key; do
    grep -q "\$INCLUDE $k" db.srdsi.lab || echo "\$INCLUDE $k" >> db.srdsi.lab
done

dnssec-signzone -t -o "$ZONE." db.srdsi.lab >/dev/null

cat > "$BIND/named.conf.local" <<'EOF'
// zona de resolución directa "srdsi.lab" (firmada con DNSSEC)
zone "srdsi.lab" {
    type primary;
    file "/etc/bind/db.srdsi.lab.signed";
};

// zona de resolución inversa "0.16.172.in-addr.arpa"
zone "0.16.172.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.0.16.172";
};
EOF

named-checkconf "$BIND/named.conf"
systemctl restart bind9
sleep 1
rndc status

# --- TSIG ----------------------------------------------------------------
tsig-keygen dns1-dns2_tsigkey > "$BIND/Kdns1-dns2_tsigkey"
chmod 640 "$BIND/Kdns1-dns2_tsigkey"
grep -q 'Kdns1-dns2_tsigkey' "$BIND/named.conf" || \
    echo "include \"$BIND/Kdns1-dns2_tsigkey\";" >> "$BIND/named.conf"

echo "OK: zona $ZONE firmada y TSIG generada"
