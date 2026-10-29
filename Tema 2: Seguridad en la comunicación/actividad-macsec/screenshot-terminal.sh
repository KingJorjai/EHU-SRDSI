#!/usr/bin/env bash
# Captura una ventana de terminal en un display virtual dentro de la VM.
# Uso: screenshot-terminal.sh <png_salida> <script_a_ejecutar>
set -u
OUT="$1"; TERMSCRIPT="$2"
export DISPLAY=:99

pkill -x lxterminal 2>/dev/null
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

Xvfb :99 -screen 0 1280x800x24 -nolisten tcp >/tmp/xvfb-macsec.log 2>&1 &
for i in $(seq 1 20); do
    xset -display :99 q >/dev/null 2>&1 && break
    sleep 0.3
done
openbox --config-file /tmp/openbox-macsec.xml >/tmp/openbox-macsec.log 2>&1 &
sleep 1

cp "$TERMSCRIPT" /tmp/term-macsec.sh
chmod +x /tmp/term-macsec.sh
lxterminal --geometry=120x32 -e "bash /tmp/term-macsec.sh" >/tmp/lxterminal-macsec.log 2>&1 &
sleep 4
scrot "$OUT"
rc=$?
sleep 1
pkill -x lxterminal 2>/dev/null
pkill -x openbox 2>/dev/null
pkill -x Xvfb 2>/dev/null
exit $rc
