#!/usr/bin/env bash
# Captura una screenshot real de Wireshark (GUI) en un display VIRTUAL dentro de la VM.
# No abre ninguna ventana en el host (no usa ssh -X).
# Uso: ws_shot.sh <pcap_en_la_vm> <keylog_en_la_vm> <display_filter> <png_salida_host> [frame] [click_x,y]
set -u
pcap="$1"; keylog="$2"; filt="${3:-}"; out="$4"; frame="${5:-}"; click="${6:-}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
case "$out" in
    "$REPO"/*) vm_out="/media/sf_SRDSI${out#"$REPO"}" ;;   # host=$REPO/... == VM=/media/sf_SRDSI/...
    *)         vm_out="$out" ;;
esac
VM="${VM:-SRDSI}"

ssh -o BatchMode=yes "$VM" 'bash -s' <<EOF
set -u
export DISPLAY=:99
click="$click"
pkill -x wireshark 2>/dev/null; pkill -x openbox 2>/dev/null; pkill -x Xvfb 2>/dev/null
sleep 1
rm -f /tmp/.X99-lock

# Display virtual 1920x1200 (invisible en el host)
Xvfb :99 -screen 0 1920x1200x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
for i in \$(seq 1 20); do xset -display :99 q >/dev/null 2>&1 && break; sleep 0.3; done

# WM minimo que maximiza cualquier ventana -> Wireshark ocupa toda la pantalla
cat > /tmp/openbox-rc.xml <<'OBRC'
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*"><maximized>yes</maximized></application>
  </applications>
</openbox_config>
OBRC
openbox --config-file /tmp/openbox-rc.xml >/tmp/openbox.log 2>&1 &
sleep 1

# Wireshark sobre el display virtual
wireshark ${filt:+-Y "$filt"} ${frame:+-g "$frame"} -o "tls.keylog_file:$keylog" "$pcap" >/tmp/ws.log 2>&1 &
sleep 15

# Clic opcional (p.ej. seleccionar la pestana/prueba "Decrypted TLS")
if [ -n "\$click" ]; then
    cx="\${click%,*}"; cy="\${click#*,}"
    xdotool mousemove --sync "\$cx" "\$cy" click 1
    sleep 2
fi

scrot -o "$vm_out"; rc=\$?
echo "scrot rc=\$rc"
[ -s "$vm_out" ] && echo "OK: \$(ls -la "$vm_out")" || { echo "ERROR: sin captura"; cat /tmp/ws.log; }

pkill -x wireshark 2>/dev/null; sleep 1
pkill -x openbox 2>/dev/null; pkill -x Xvfb 2>/dev/null
EOF
