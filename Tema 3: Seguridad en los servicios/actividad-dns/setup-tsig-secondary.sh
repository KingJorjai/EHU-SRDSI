#!/usr/bin/env bash
# Configura el servidor secundario (dns2) para transferir srdsi.lab
# desde dns1 usando TSIG. Ejecutar con sudo en la VM2.
set -euo pipefail

BIND=/etc/bind
KEY_NAME=dns1-dns2_tsigkey
KEY_SECRET="Q8yCH4CPAxnw2cGiswJ60LWk3PlYAQsMZ9knGJg5HsQ="
PRIMARY=192.168.56.110

cat > "$BIND/K$KEY_NAME" <<EOF
key "$KEY_NAME" {
    algorithm hmac-sha256;
    secret "$KEY_SECRET";
};
EOF
chmod 640 "$BIND/K$KEY_NAME"

if ! grep -q "K$KEY_NAME" "$BIND/named.conf"; then
    cat >> "$BIND/named.conf" <<EOF
include "$BIND/K$KEY_NAME";
server $PRIMARY { keys { $KEY_NAME; }; };
EOF
fi

cat > "$BIND/named.conf.local" <<EOF
zone "srdsi.lab" {
    type secondary;
    file "/var/cache/bind/db.srdsi.lab";
    masterfile-format text;
    primaries { $PRIMARY key $KEY_NAME; };
    allow-transfer { none; };
};

zone "0.16.172.in-addr.arpa" {
    type secondary;
    file "/var/cache/bind/db.0.16.172";
    masterfile-format text;
    primaries { $PRIMARY key $KEY_NAME; };
    allow-transfer { none; };
};
EOF

named-checkconf "$BIND/named.conf"
systemctl restart bind9
sleep 3
dig @127.0.0.1 srdsi.lab SOA +short
