#!/usr/bin/env bash
# Ejecuta las pruebas del laboratorio desde el host y guarda la salida.
set -euo pipefail
cd "$(dirname "$0")"

VM1=SRDSI
VM2=user1@192.168.56.111
KEY='azmRu/iYFPGFFU0zaJJWx+rPsV1qcH6sXblVwrHLgT8='
HMAC='mnousYvDpEjPYKGbwgVOTUsW/cogxGf+021r9+0cbh2dP6KgG0AKpJ8FqeAEM8ddaQdfx/WwCUyUztIiaRQhxA=='

http() {
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" \
        'python3 -c "import urllib.request; print(urllib.request.urlopen(\"http://192.168.56.110:8080/\", timeout=4).status)" 2>/dev/null || echo FAIL'
}

rules() {
    ssh -o BatchMode=yes "$VM1" 'echo user1 | sudo -S iptables -S PROTECTED; echo "--- FWKNOP ---"; echo user1 | sudo -S iptables -S FWKNOP_INPUT 2>/dev/null || true'
}

{
    echo "### Entorno"
    date
    ssh -o BatchMode=yes "$VM1" 'hostname; ip -brief addr show enp0s8'
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" 'hostname; ip -brief addr show enp0s8'

    echo
    echo "### Reset de reglas"
    ssh -o BatchMode=yes "$VM1" 'echo user1 | sudo -S iptables -F PROTECTED; echo user1 | sudo -S iptables -A PROTECTED -j DROP; echo user1 | sudo -S iptables -F FWKNOP_INPUT 2>/dev/null || true'
    rules

    echo
    echo "### 1. Sin knock: HTTP debe fallar"
    http

    echo
    echo "### 2. Secuencia knockd 7000,8000,9000"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" 'knock 192.168.56.110 7000 8000 9000'
    sleep 1
    echo -n "HTTP: "; http
    rules

    echo
    echo "### 3. Timeout de knockd (10 s)"
    sleep 12
    echo -n "HTTP: "; http
    rules

    echo
    echo "### 4. SPA fwknop correcta"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" \
        "fwknop -A tcp/8080 -a 192.168.56.111 -D 192.168.56.110 --use-hmac --key-base64-rijndael '$KEY' --key-base64-hmac '$HMAC'"
    sleep 1
    echo -n "HTTP: "; http
    rules
    ssh -o BatchMode=yes "$VM1" 'echo user1 | sudo -S journalctl -u fwknop-server -n 3 --no-pager | tail -3'

    echo
    echo "### 5. Timeout de fwknop (10 s)"
    sleep 12
    echo -n "HTTP: "; http
    rules

    echo
    echo "### 6. SPA con HMAC incorrecta"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" \
        "fwknop -A tcp/8080 -a 192.168.56.111 -D 192.168.56.110 --use-hmac --key-base64-rijndael '$KEY' --key-base64-hmac 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=='"
    sleep 1
    echo -n "HTTP: "; http
    ssh -o BatchMode=yes "$VM1" 'echo user1 | sudo -S journalctl -u fwknop-server -n 4 --no-pager | tail -4'

    echo
    echo "### 7. Replay: SPA nueva y reenvío inmediato"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" \
        "fwknop -A tcp/8080 -a 192.168.56.111 -D 192.168.56.110 --use-hmac --key-base64-rijndael '$KEY' --key-base64-hmac '$HMAC' -B /tmp/spa_test.pkt"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$VM2" \
        'python3 -c "import socket; d=open(\"/tmp/spa_test.pkt\",\"rb\").read().strip(); s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.sendto(d,(\"192.168.56.110\",62201))"'
    sleep 1
    ssh -o BatchMode=yes "$VM1" 'echo user1 | sudo -S journalctl -u fwknop-server -n 8 --no-pager | grep -i replay | tail -2'
    echo -n "HTTP (solo con la primera SPA): "; http
} > resultados/pruebas.txt 2>&1

echo "Resultados en resultados/pruebas.txt"
