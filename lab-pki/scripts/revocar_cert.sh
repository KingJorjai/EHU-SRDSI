#!/usr/bin/env bash
# revocar_cert.sh
# Revoca un certificado emitido por la CA subordinada (openssl ca -revoke).
# La decisión de revocar es manual: el script solo ejecuta la revocación.
#
# Uso: ./revocar_cert.sh <certificado.crt> [motivo]
#
# Motivos válidos (por defecto: unspecified):
#   unspecified, keyCompromise, CACompromise, affiliationChanged,
#   superseded, cessationOfOperation, certificateHold
#
# Variables de entorno opcionales:
#   CONF_CA   Ruta al openssl.cnf de la CA (por defecto, la de PKI_sub).
#   CA_PASS   Contraseña de la clave privada de la CA. Si no se define,
#             openssl la pedirá por terminal.
#
# IMPORTANTE: esto solo marca el certificado como revocado en la base de datos
# de la CA (index.txt). Para que los clientes se enteren hay que regenerar y
# publicar la CRL:  openssl ca -config <cnf> -gencrl -out <crl>

set -euo pipefail

CONF_CA="${CONF_CA:-/home/user1/PKI_root/PKI_sub/ca-sub_openssl.cnf}"
MOTIVOS=("unspecified" "keyCompromise" "CACompromise" "affiliationChanged" \
         "superseded" "cessationOfOperation" "certificateHold")

die() {
    local rc=$1; shift
    echo "Error: $*" >&2
    exit "$rc"
}

usage() {
    echo "Uso: $0 <certificado.crt> [$(IFS='|'; echo "${MOTIVOS[*]}")]" >&2
}

# ---------------------------------------------------------------- argumentos
if (( $# < 1 || $# > 2 )); then
    usage
    exit 1
fi

CRT=$1
MOTIVO=${2:-unspecified}

[[ -f "$CRT" ]] || die 1 "no existe el certificado '$CRT'."
[[ -f "$CONF_CA" ]] || die 3 "no existe el fichero de configuración de la CA '$CONF_CA'."
command -v openssl >/dev/null 2>&1 || die 3 "openssl no está instalado."

valido=0
for m in "${MOTIVOS[@]}"; do
    if [[ "$MOTIVO" == "$m" ]]; then
        valido=1
        break
    fi
done
(( valido )) || die 2 "motivo '$MOTIVO' no válido (válidos: ${MOTIVOS[*]})."

# Debe ser un certificado X.509 legible (PEM)
if ! info=$(openssl x509 -in "$CRT" -noout -serial -subject 2>/dev/null); then
    die 1 "'$CRT' no es un certificado X.509 válido en formato PEM."
fi

# ---------------------------------------------------------------- comprobación previa
# 'openssl ca -revoke' AÑADE una entrada (ya revocada) a index.txt si el serial no
# existe en la base de datos, lo que ensucia la CA. Por eso se consulta antes el
# estado con '-status' (solo lectura, no necesita la contraseña de la CA).
serial=$(openssl x509 -in "$CRT" -noout -serial | cut -d= -f2)
estado=$(openssl ca -config "$CONF_CA" -status "$serial" 2>&1 </dev/null || true)

case "$estado" in
    *"=Valid (V)"*)   ;;
    *"=Expired (E)"*) echo "Aviso: el certificado ya está caducado." >&2 ;;
    *"=Revoked (R)"*) die 3 "el certificado (serial $serial) ya está revocado." ;;
    *"not present in db"*)
        die 3 "el serial $serial no figura en la base de datos de esta CA; no se revoca." ;;
    *) die 3 "no se pudo consultar el estado del serial $serial: $estado" ;;
esac

# ---------------------------------------------------------------- revocación
OPENSSL_OPTS=(ca -config "$CONF_CA" -revoke "$CRT" -crl_reason "$MOTIVO")

if [[ -n "${CA_PASS:-}" ]]; then
    OPENSSL_OPTS+=(-passin env:CA_PASS)
fi

echo "Revocando certificado (motivo: $MOTIVO):"
echo "$info" | sed 's/^/   /'

openssl "${OPENSSL_OPTS[@]}"

echo "Certificado revocado: $CRT"
echo "Recuerda regenerar y publicar la CRL (openssl ca -gencrl)."
