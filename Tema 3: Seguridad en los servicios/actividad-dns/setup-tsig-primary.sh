#!/usr/bin/env bash
# Deja el servidor primario (dns1) permitiendo transferencias solo con TSIG.
# Requiere que setup-dns.sh haya generado /etc/bind/Kdns1-dns2_tsigkey.
set -euo pipefail

BIND=/etc/bind

if ! grep -q 'Kdns1-dns2_tsigkey' "$BIND/named.conf"; then
    echo "include \"$BIND/Kdns1-dns2_tsigkey\";" >> "$BIND/named.conf"
fi

cat > "$BIND/named.conf.local" <<'EOF'
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
rndc reload
