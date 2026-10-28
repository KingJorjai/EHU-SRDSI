#!/usr/bin/env bash
# Copia a docs/assets los PDFs, imágenes, capturas, scripts, configuraciones,
# código y certificados de laboratorio que usa la documentación.
#
# docs/assets/ está ignorado por git: el material original sigue siendo la única
# fuente de verdad y el sitio se construye a partir de estas copias.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/docs/assets"
T1="$ROOT/Tema 1: Introducción a la seguridad informática"
T2="$ROOT/Tema 2: Seguridad en la comunicación"
G="$ROOT/General"

rm -rf "$DEST"
mkdir -p "$DEST"/{pdf,img/lab-pki,img/lab-openssh,capturas/lab-ssl,scripts,config,codigo/lab-ssl,certs/lab-ssl,certs/lab-certs,benchmarks}

copy() {
    local src=$1 dst=$2
    if [ -e "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
    else
        echo "AVISO: no existe $src" >&2
    fi
}

copy_dir() {
    local src=$1 dst=$2
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -a "$src/." "$dst/"
    else
        echo "AVISO: no existe $src" >&2
    fi
}

# ------------------------------------------------------------------ PDFs
copy "$G/programaSRDSI_26-27.pdf"                 "$DEST/pdf/programa.pdf"
copy "$G/Anexo_laboratorios_26-27.pdf"            "$DEST/pdf/anexo-laboratorios.pdf"
copy "$G/Personalizar_Entorno.pdf"                "$DEST/pdf/personalizar-entorno.pdf"
copy "$G/6.- b) Protocolo plagio cas -.pdf"       "$DEST/pdf/protocolo-plagio.pdf"

for f in "$T1"/SRDSI_T1-*.pdf; do
    [ -e "$f" ] && cp -a "$f" "$DEST/pdf/"
done
for f in "$T2"/SRDSI_T2-*.pdf; do
    [ -e "$f" ] && cp -a "$f" "$DEST/pdf/"
done

copy "$T1/lab-pki/docs/Enunciado-lab-PKI-1.pdf"              "$DEST/pdf/lab-pki-enunciado.pdf"
copy "$T1/lab-pki/informe/informe.pdf"                       "$DEST/pdf/informe-pki.pdf"
copy "$T1/actividad-criptografia/Actividad-criptografia.pdf" "$DEST/pdf/actividad-criptografia.pdf"
copy "$T1/actividad-criptografia/[SRDSI] ASCON.pdf"          "$DEST/pdf/actividad-ascon.pdf"
copy "$T1/actividad-estudio-CAs/Autoridad de certificación - GlobalSign.pdf" "$DEST/pdf/actividad-estudio-ca.pdf"
copy "$T1/Material extra/cysec5/cripto.pdf"                  "$DEST/pdf/cripto-lucena.pdf"

copy "$T2/lab-ssl/Lab-ssl-actividad.pdf"     "$DEST/pdf/lab-ssl-actividad.pdf"
copy "$T2/lab-ssl/Lab-ssl-teoria.pdf"        "$DEST/pdf/lab-ssl-teoria.pdf"
copy "$T2/lab-ssl/GDB.pdf"                   "$DEST/pdf/gdb.pdf"
copy "$T2/lab-ssl/informe/informe.pdf"       "$DEST/pdf/informe-ssl.pdf"
copy "$T2/lab-openssh/Lab_SSH.pdf"           "$DEST/pdf/lab-openssh.pdf"
copy "$T2/lab-openssh/SSH_PORT-FORWARDING.pdf" "$DEST/pdf/lab-openssh-port-forwarding.pdf"
copy "$T2/lab-openssh/informe_open_ssh.pdf"  "$DEST/pdf/informe-openssh.pdf"
copy "$T2/ejercicio-tls-dtls/Lab-TLS_y_DTLS.pdf" "$DEST/pdf/lab-tls-dtls.pdf"

# ------------------------------------------------------------------ imágenes
copy_dir "$T1/lab-pki/informe/img"   "$DEST/img/lab-pki"
for f in "$T2/lab-openssh"/*.png; do
    [ -e "$f" ] && cp -a "$f" "$DEST/img/lab-openssh/"
done
copy_dir "$T2/lab-ssl/capturas"      "$DEST/capturas/lab-ssl"

# ------------------------------------------------------------------ scripts y configs
for f in "$T1/lab-pki/scripts"/*.sh; do
    [ -e "$f" ] && cp -a "$f" "$DEST/scripts/"
done
for f in "$T1/lab-pki/pki-config-files"/*.cnf; do
    [ -e "$f" ] && cp -a "$f" "$DEST/config/"
done

# ------------------------------------------------------------------ código C
for f in "$T2/lab-ssl/source_files"/*.c; do
    [ -e "$f" ] && cp -a "$f" "$DEST/codigo/lab-ssl/"
done

# ------------------------------------------------------------------ certificados y claves (sintéticos)
copy_dir "$T2/lab-ssl/source_files/certificados" "$DEST/certs/lab-ssl"
copy_dir "$T2/ejercicio-tls-dtls/lab-certs"      "$DEST/certs/lab-certs"

# ------------------------------------------------------------------ benchmarks
copy "$T1/actividad-criptografia/benchmark_ascon.txt" "$DEST/benchmarks/benchmark_ascon.txt"
copy "$T1/actividad-criptografia/benchmark_all.txt"   "$DEST/benchmarks/benchmark_all.txt"

echo "Assets preparados en $DEST ($(find "$DEST" -type f | wc -l) ficheros)."
