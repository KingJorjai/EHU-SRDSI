#!/usr/bin/env bash
# Crea la subzona delegada sub.srdsi.lab, la firma con DNSSEC y publica
# el DS en la zona padre. Ejecutar con sudo en dns1.
set -euo pipefail

BIND=/etc/bind
PARENT=srdsi.lab
CHILD=sub.srdsi.lab
SERVER_IP=172.16.0.136

cd "$BIND"

# --- Zona hija -----------------------------------------------------------
cat > db.sub.srdsi.lab <<EOF
\$ORIGIN $CHILD.
\$TTL 2h
@       IN  SOA dns1.$PARENT. admin.$PARENT. (
            2026112301 ; Serial
            604800     ; Refresh
            86400      ; Retry
            2419200    ; Expire
            604800 )   ; Negative Cache TTL
;
@       IN NS    dns1.$PARENT.
host1   IN A     172.16.145.45
host2   IN A     172.16.145.46
EOF

rm -f K$CHILD.* dsset-$CHILD. db.sub.srdsi.lab.signed* 2>/dev/null || true
dnssec-keygen -a RSASHA256 -b 1024 -f KSK -n ZONE "$CHILD." >/dev/null
dnssec-keygen -a RSASHA256 -b 1024 -n ZONE "$CHILD." >/dev/null
for k in K$CHILD.*.key; do
    echo "\$INCLUDE $k" >> db.sub.srdsi.lab
done
dnssec-signzone -t -o "$CHILD." db.sub.srdsi.lab >/dev/null

# --- Zona padre: NS, glue y DS ------------------------------------------
sed -i '/^sub[[:space:]]/d' db.srdsi.lab
sed -i '/^sub\.srdsi\.lab\.[[:space:]].*DS/d' db.srdsi.lab
sed -i 's/2026112301/2026112302/' db.srdsi.lab

{
    echo "sub IN NS dns1.$PARENT."
    echo "sub IN A $SERVER_IP"
    cat dsset-$CHILD.
} >> db.srdsi.lab

dnssec-signzone -t -o "$PARENT." db.srdsi.lab >/dev/null

# --- named.conf.local ----------------------------------------------------
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

zone "sub.srdsi.lab" {
    type primary;
    file "/etc/bind/db.sub.srdsi.lab.signed";
    allow-transfer { none; };
};
EOF

named-checkconf "$BIND/named.conf"
named-checkzone "$PARENT" db.srdsi.lab
named-checkzone "$CHILD" db.sub.srdsi.lab
rndc reload
sleep 2

# --- Trust anchor del padre para delv ------------------------------------
KSK=$(dig @127.0.0.1 "$PARENT" DNSKEY +short | awk '$1==257 {for (i=4;i<=NF;i++) printf "%s", $i; exit}')
cat > trustanchor.key <<EOF
trust-anchors {
    $PARENT. static-key 257 3 8 "$KSK";
};
EOF

echo "OK: $CHILD delegada y firmada"
