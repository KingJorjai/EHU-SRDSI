#!/usr/bin/env bash
#
# run-lab.sh — Automatiza el laboratorio SSL (lab-ssl) sobre la VM de VirtualBox.
#
# Por SSH hacia la VM "SRDSI" (carpeta compartida /media/sf_SRDSI == repo del host):
#   1. Comprueba que libssl-dev esta instalado (si falta: sudo apt-get install -y libssl-dev).
#   2. Compila cli-infouser.c / serv-infouser.c (ya migrados a OpenSSL).
#   3. Reproduce 3 escenarios capturando el trafico de loopback con dumpcap:
#        01_ok               handshake correcto
#        02_cert_inexistente servidor sin certificado
#        03_ca_desconocida   el cliente no reconoce la CA que firma al servidor
#   4. Analiza las capturas en el host con tshark (evidencia textual).
#
# Con --gui genera ADEMAS screenshots reales de Wireshark en un display virtual
# (Xvfb) dentro de la VM, de modo que NO se abre ninguna ventana en el host.
# Si la captura fallara, se avisa y se continua con la evidencia textual de tshark.
#
# Uso:  ./run-lab.sh [--gui]
#
set -uo pipefail

VM="${VM:-SRDSI}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CAP_HOST="$REPO/lab-ssl/capturas"

RREPO="/media/sf_SRDSI/Tema 2: Seguridad en la comunicación"
SRC="$RREPO/lab-ssl/source_files"
CAP="$RREPO/lab-ssl/capturas"
WORK=/tmp/labssl-run
LIBS="-lssl -lcrypto"

GUI=0
[ "${1:-}" = "--gui" ] && GUI=1

mkdir -p "$CAP_HOST"

echo "==> Comprobando conectividad con la VM '$VM'..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$VM" true 2>/dev/null; then
    echo "ERROR: no se puede conectar por SSH a '$VM' (revisa ~/.ssh/config y que la VM este encendida)." >&2
    exit 1
fi

# Cierra cualquier Wireshark residual (sus paquetes X11 por loopback contaminarian la captura)
for p in $(pgrep -x ssh); do
    grep -qa "ireshark" /proc/$p/cmdline 2>/dev/null && kill "$p" 2>/dev/null
done
ssh -o BatchMode=yes "$VM" 'pkill -x wireshark' 2>/dev/null
sleep 1

echo "==> Ejecutando el laboratorio dentro de la VM..."
ssh -o BatchMode=yes "$VM" 'bash -s' <<REMOTE
set -u
SRC="$SRC"
CAP="$CAP"
WORK="$WORK"
LIBS="$LIBS"

free_port(){ for i in \$(seq 1 30); do ss -ltn | grep -q ':1064 ' || return 0; \
    fuser -k 1064/tcp 2>/dev/null; pkill -9 -x serv 2>/dev/null; sleep 0.3; done; return 1; }

# --- 0. Comprueba libssl-dev (si falta, instalarlo con sudo) -----------------
if [ ! -f /usr/include/openssl/ssl.h ]; then
    echo "[!] Falta libssl-dev. Instalalo con: sudo apt-get install -y libssl-dev" >&2
    exit 1
fi
echo "[*] Cabeceras OpenSSL del sistema: /usr/include/openssl/ssl.h"

preparar(){
    rm -rf "\$WORK"; mkdir -p "\$WORK"
    cp "\$SRC"/*.c "\$WORK"/
    cp -r "\$SRC/certificados" "\$WORK"/
}

compilar(){
    cd "\$WORK"
    gcc -Wall -O2 -o serv serv-infouser.c \$LIBS || return 1
    gcc -Wall -O2 -o cli  cli-infouser.c  \$LIBS || return 1
}

# escenario <nombre> <mutacion>
#   mutacion se ejecuta en \$WORK tras copiar las fuentes y ANTES de compilar
escenario(){
    local nombre="\$1"; shift
    echo
    echo "=================== ESCENARIO \$nombre ==================="
    free_port || echo "AVISO: puerto 1064 ocupado"
    preparar
    ( cd "\$WORK" && eval "\$*" )
    compilar || { echo "ERROR compilando"; return 1; }
    rm -f "\$WORK/keylog-ssl.log" "\$CAP/\$nombre.pcapng"
    dumpcap -i lo -w "\$CAP/\$nombre.pcapng" -q >/tmp/dumpcap_\$nombre.log 2>&1 &
    local DPID=\$!
    sleep 1.5
    ( cd "\$WORK" && ./serv >/tmp/serv_\$nombre.log 2>&1 ) &
    local SPID=\$!
    sleep 0.6
    ss -ltn | grep -q ':1064 ' && echo "[*] servidor escuchando" || echo "[!] servidor NO escucha"
    ( cd "\$WORK" && ./cli 127.0.0.1 /tmp/out_\$nombre.txt ); echo "[*] cliente exit=\$?"
    sleep 0.6
    fuser -k 1064/tcp 2>/dev/null; pkill -9 -x serv 2>/dev/null
    kill -INT \$DPID 2>/dev/null; sleep 1.2; kill -9 \$DPID 2>/dev/null
    cp -f "\$WORK/keylog-ssl.log" "\$CAP/\$nombre.keylog" 2>/dev/null || true
    echo "--- servidor (\$nombre) ---"; cat /tmp/serv_\$nombre.log
    grep -i "Packets" /tmp/dumpcap_\$nombre.log | tail -1
}

mkdir -p "\$CAP"
escenario 01_ok               'true'
cp -f /tmp/file_users /tmp/ref_01 2>/dev/null || true
escenario 02_cert_inexistente 'rm -f certificados/s_cert.pem'
escenario 03_ca_desconocida   'sed -i "s#certificados/s-ca_cert.pem#certificados/c-ca_cert.pem#" cli-infouser.c'

# Verifica que el fichero recibido coincide con lo que genero el servidor
if cmp -s /tmp/out_01_ok.txt /tmp/ref_01; then
    echo "[*] 01_ok: contenido recibido == w del servidor (\$(wc -c </tmp/out_01_ok.txt) bytes)"
else
    echo "[!] 01_ok: el contenido recibido difiere de /tmp/ref_01"
fi
echo
echo "[*] Capturas en la carpeta compartida:"
ls -la "\$CAP"
free_port || true
REMOTE

echo
echo "==> Analizando capturas en el host con tshark..."
cd "$CAP_HOST"
for name in 01_ok 02_cert_inexistente 03_ca_desconocida; do
    key=()
    [ -f "$name.keylog" ] && key=(-o "tls.keylog_file:$name.keylog")
    {
        echo "# $name.pcapng"
        echo "# sink: tshark -r $name.pcapng ${key[*]}"
        echo
        tshark -r "$name.pcapng" "${key[@]}" -T fields \
               -e frame.number -e _ws.col.Protocol -e _ws.col.Info 2>/dev/null
        echo
        echo "# Datos de aplicacion descifrados:"
        tshark -r "$name.pcapng" "${key[@]}" -Y "data" -T fields -e frame.number -e data.len 2>/dev/null \
            | sed 's/^/  frame /'
    } > "$name.tshark.txt"
    echo "  -> $name.tshark.txt"
done

if [ "$GUI" = 1 ]; then
    echo
    echo "==> Capturas GUI de Wireshark (display virtual Xvfb en la VM, no abre ventanas en el host)..."
    # 01_ok: selecciona el frame de Application Data del servidor (el de mayor
    # tamano) y clica la fila "Data (N bytes)" para que el panel de bytes muestre
    # el contenido descifrado via keylog.
    appframe=$(tshark -r "$CAP_HOST/01_ok.pcapng" -o "tls.keylog_file:$CAP_HOST/01_ok.keylog" \
               -Y "tls.record.content_type==23" -T fields -e frame.number -e tcp.len 2>/dev/null \
               | sort -k2 -nr | head -1 | cut -f1)
    "$REPO/lab-ssl/ws_shot.sh" \
        "$CAP/01_ok.pcapng" "$CAP/01_ok.keylog" "tls" "$CAP_HOST/01_ok.png" "${appframe:-10}" "60,740" \
        || echo "  AVISO: fallo la captura GUI de 01_ok (queda la evidencia .tshark.txt)"
    for name in 02_cert_inexistente 03_ca_desconocida; do
        "$REPO/lab-ssl/ws_shot.sh" \
            "$CAP/$name.pcapng" "$CAP/$name.keylog" "tls" "$CAP_HOST/$name.png" \
            || echo "  AVISO: fallo la captura GUI de $name (queda la evidencia .tshark.txt)"
    done
fi

echo
echo "==> Hecho. Evidencia en: $CAP_HOST"
