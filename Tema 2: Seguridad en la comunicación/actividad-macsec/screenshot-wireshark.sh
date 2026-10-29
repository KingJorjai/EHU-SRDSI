#!/usr/bin/env bash
# Captura Wireshark en un display virtual dentro de la VM.
# Uso: screenshot-wireshark.sh <png_salida> <pcap>
set -u
OUT="$1"; PCAP="$2"
export DISPLAY=:99

pkill -x wireshark 2>/dev/null
pkill -x openbox 2>/dev/null
pkill -x Xvfb 2>/dev/null
sleep 1
rm -f /tmp/.X99-lock

cat > /tmp/openbox-macsec.xml <<'OBRC'
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*"><maximized>yes</maximized></application>
  </applications>
</openbox_config>
OBRC

Xvfb :99 -screen 0 1600x900x24 -nolisten tcp >/tmp/xvfb-macsec.log 2>&1 &
for i in $(seq 1 20); do
    xset -display :99 q >/dev/null 2>&1 && break
    sleep 0.3
done
openbox --config-file /tmp/openbox-macsec.xml >/tmp/openbox-macsec.log 2>&1 &
sleep 1

wireshark -r "$PCAP" -Y "macsec" >/tmp/wireshark-macsec.log 2>&1 &
sleep 15
scrot "$OUT"
rc=$?
sleep 1
pkill -x wireshark 2>/dev/null
pkill -x openbox 2>/dev/null
pkill -x Xvfb 2>/dev/null
exit $rc
