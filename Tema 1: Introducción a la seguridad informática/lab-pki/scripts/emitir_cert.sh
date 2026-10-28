#!/usr/bin/env bash
# emitir_cert.sh
# Emite un certificado a partir de una solicitud (CSR) ya revisada manualmente.
# El script NO revisa la solicitud: firma directamente con la CA subordinada.
#
# Uso: ./emitir_cert.sh <solicitud.csr> {server_ext|user_ext|ocsp_ext}
#
# Según la extensión:
#   server_ext, ocsp_ext  Solo firma la CSR y deja el certificado en $CERTS_DIR. La clave
#                         privada nunca llega a la CA (la conserva el solicitante), así
#                         que no se necesita ni se empaqueta nada más.
#   user_ext              Además del certificado, crea un PKCS#12 con certificado + clave
#                         privada para enviárselo al usuario. La clave privada debe estar
#                         junto a la solicitud, con el nombre que genera gen_solicitud.sh:
#                         solicitud-<nombre>.csr  <->  clave-privada-<nombre>.key
#
# Variables de entorno:
#   KEY_PASS  Contraseña de la clave privada de la solicitud.
#             OBLIGATORIA solo con user_ext (con las demás extensiones se ignora).
#   P12_PASS  Contraseña del PKCS#12 (por defecto, la misma que KEY_PASS). Solo user_ext.
#   PKI_DIR   Directorio de la CA subordinada (por defecto, /home/user1/PKI_root/PKI_sub).
#   CONF_CA   Ruta al openssl.cnf de la CA (por defecto, $PKI_DIR/ca-sub_openssl.cnf).
#   CERTS_DIR Directorio de salida de los certificados (por defecto, $PKI_DIR/certs).
#   P12_DIR   Directorio de salida de los PKCS#12 (por defecto, $PKI_DIR/certs.p12).
#             Solo se usa (y se exige que exista) con user_ext.
#   CA_PASS   Contraseña de la clave privada de la CA. Si no se define,
#             openssl la pedirá por terminal.
#
# Se escriben:
#   $CERTS_DIR/certificado-<nombre>.crt   certificado emitido
#   $P12_DIR/certificado-<nombre>.p12     (solo user_ext) PKCS#12, permisos 600
# <nombre> es el nombre de la solicitud sin el prefijo "solicitud-" ni ".csr".

set -euo pipefail

PKI_DIR="${PKI_DIR:-/home/user1/PKI_root/PKI_sub}"
CONF_CA="${CONF_CA:-$PKI_DIR/ca-sub_openssl.cnf}"
CERTS_DIR="${CERTS_DIR:-$PKI_DIR/certs}"
P12_DIR="${P12_DIR:-$PKI_DIR/certs.p12}"
EXTENSIONES=("server_ext" "user_ext" "ocsp_ext")

CRT=""
P12=""
EMITIDO=0       # pasa a 1 cuando openssl ca ha firmado el certificado
EMPAQUETAR=0    # pasa a 1 si hay que crear el PKCS#12 (solo user_ext)

die() {
    local rc=$1; shift
    echo "Error: $*" >&2
    exit "$rc"
}

usage() {
    echo "Uso: $0 <solicitud.csr> {$(IFS='|'; echo "${EXTENSIONES[*]}")}" >&2
}

# Si algo falla, no dejamos ficheros a medias. Una vez emitido, el certificado queda
# registrado en la base de datos de la CA, así que el .crt se conserva aunque falle
# después el empaquetado; solo se borra el .p12 incompleto.
cleanup() {
    local rc=$?
    if (( rc != 0 )); then
        if (( ! EMITIDO )) && [[ -n "$CRT" ]]; then
            rm -f -- "$CRT"
        fi
        if [[ -n "$P12" ]]; then
            rm -f -- "$P12"
        fi
    fi
    return 0
}
trap cleanup EXIT

# ---------------------------------------------------------------- argumentos
if (( $# != 2 )); then
    usage
    exit 1
fi

CSR=$1
EXT=$2

[[ -f "$CSR" ]] || die 1 "no existe la solicitud '$CSR'."
[[ -f "$CONF_CA" ]] || die 3 "no existe el fichero de configuración de la CA '$CONF_CA'."
[[ -d "$CERTS_DIR" ]] || die 3 "no existe el directorio de certificados '$CERTS_DIR'."
[[ -w "$CERTS_DIR" ]] || die 3 "no hay permiso de escritura en '$CERTS_DIR'."
command -v openssl >/dev/null 2>&1 || die 3 "openssl no está instalado."

valida=0
for e in "${EXTENSIONES[@]}"; do
    if [[ "$EXT" == "$e" ]]; then
        valida=1
        break
    fi
done
(( valida )) || die 2 "no existe la extensión '$EXT' (válidas: ${EXTENSIONES[*]})."

# La sección de extensiones debe existir en la configuración de la CA
if ! grep -Eq "^[[:space:]]*\[[[:space:]]*${EXT}[[:space:]]*\]" "$CONF_CA"; then
    die 2 "la sección [$EXT] no está definida en $CONF_CA."
fi

# Solo los certificados de usuario se empaquetan en un PKCS#12: la CA genera su clave
# y se la envía. En servicios (y OCSP) la clave privada la guarda el solicitante.
if [[ "$EXT" == "user_ext" ]]; then
    EMPAQUETAR=1
fi

if (( EMPAQUETAR )); then
    [[ -d "$P12_DIR" ]] || die 3 "no existe el directorio de PKCS#12 '$P12_DIR'."
    [[ -w "$P12_DIR" ]] || die 3 "no hay permiso de escritura en '$P12_DIR'."
fi

# ---------------------------------------------------------------- nombre de salida
# solicitud-www.ejemplo.com.csr -> www.ejemplo.com
nombre=$(basename -- "$CSR")
nombre=${nombre%.csr}
nombre=${nombre#solicitud-}
[[ -n "$nombre" ]] || die 1 "no se pudo obtener un nombre a partir de '$CSR'."

CRT="${CERTS_DIR%/}/certificado-${nombre}.crt"
if [[ -e "$CRT" ]]; then
    existente=$CRT
    CRT=""   # no es nuestro: que cleanup no lo borre
    die 3 "ya existe $existente; no se sobrescribe."
fi

# ---------------------------------------------------------------- PKCS#12 (solo user_ext)
if (( EMPAQUETAR )); then
    P12="${P12_DIR%/}/certificado-${nombre}.p12"
    if [[ -e "$P12" ]]; then
        existente=$P12
        P12=""   # no es nuestro: que cleanup no lo borre
        die 3 "ya existe $existente; no se sobrescribe."
    fi

    # Se valida TODO antes de firmar: si el empaquetado fallara después, el certificado
    # ya estaría emitido y registrado en la CA.
    KEY="$(dirname -- "$CSR")/clave-privada-${nombre}.key"
    [[ -f "$KEY" ]] || die 1 "no existe la clave privada '$KEY' (debe estar junto a la solicitud)."
    [[ -n "${KEY_PASS:-}" ]] || die 1 "falta la contraseña de la clave privada: defina KEY_PASS."
    export P12_PASS="${P12_PASS:-$KEY_PASS}"

    if ! pub_key=$(openssl pkey -in "$KEY" -passin env:KEY_PASS -pubout 2>/dev/null); then
        die 1 "no se pudo leer la clave privada '$KEY' (¿KEY_PASS incorrecta?)."
    fi
    pub_csr=$(openssl req -in "$CSR" -noout -pubkey 2>/dev/null) \
        || die 1 "no se pudo leer la clave pública de la solicitud '$CSR'."
    [[ "$pub_key" == "$pub_csr" ]] || die 1 "la clave privada '$KEY' no corresponde a la solicitud '$CSR'."
fi

# ---------------------------------------------------------------- emisión
# -batch   : no pregunta "Sign the certificate?" ni "commit?" (revisión ya hecha)
# -notext  : el .crt solo contiene el PEM, sin el volcado de texto
OPENSSL_OPTS=(ca -batch -notext -in "$CSR" -out "$CRT" -config "$CONF_CA" -extensions "$EXT")

if [[ -n "${CA_PASS:-}" ]]; then
    OPENSSL_OPTS+=(-passin env:CA_PASS)
fi

openssl "${OPENSSL_OPTS[@]}"
EMITIDO=1
echo "Certificado emitido: $CRT"

# ---------------------------------------------------------------- empaquetado PKCS#12
if (( EMPAQUETAR )); then
    # umask 077: el .p12 contiene la clave privada y no debe ser legible por otros
    if ! ( umask 077
           openssl pkcs12 -export -out "$P12" -in "$CRT" -inkey "$KEY" \
               -passin env:KEY_PASS -passout env:P12_PASS ); then
        die 4 "el certificado se emitió ($CRT) pero falló la creación del PKCS#12."
    fi
    echo "PKCS#12 generado:    $P12"
else
    echo "Entregar al solicitante solo el certificado (no se genera PKCS#12 para $EXT)."
fi
