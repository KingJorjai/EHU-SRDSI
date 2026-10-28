#!/usr/bin/env bash
# gen_solicitud.sh
# Genera clave privada (siempre cifrada) y CSR para usuarios y servicios.
# Los campos del Distinguished Name no especificados se omiten del subject.
#
# Uso: ./gen_solicitud.sh -t {usuario|servicio} -n <nombre> {-p <password> | KEY_PASS} [opciones]
# No interactivo: la contraseña se toma de -p o de la variable KEY_PASS (obligatoria).
# Para tipo servicio son obligatorios -d, -e, -C y -O: la política de la subCA exige
# emailAddress, y que C y O coincidan con los de la CA (si no, rechaza la solicitud).

set -euo pipefail

# Las claves privadas solo deben ser legibles por el propietario
umask 077

# ---------------------------------------------------------------- valores por defecto
TIPO=""
CN=""
EMAIL=""
DNS=""
OUTDIR="/home/user1/PKI_root/PKI_sub/solicitudes"
PASS=""
BITS=3072
FORCE=0
C=""
ST=""
L=""
O=""
OU=""

# ---------------------------------------------------------------- utilidades
die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    cat <<EOF
Uso: $0 -t {usuario|servicio} -n <nombre_comun> {-p <password> | KEY_PASS=<password>} [opciones]

Opciones:
  -t tipo       Tipo de certificado: usuario o servicio (obligatorio)
  -n nombre     Common Name (CN) (obligatorio)
  -p password   Contraseña de la clave privada. Si no se indica, se usa la variable
                de entorno KEY_PASS. Es obligatorio que una de las dos esté definida
                y no vacía. Preferible KEY_PASS: -p queda visible en 'ps' y en el
                historial del shell.
  -e email      Correo (obligatorio para usuario y para servicio)
  -d dns        Nombres DNS separados por comas (obligatorio para servicio)
  -b bits       Tamaño de la clave RSA, mínimo 2048 (por defecto: 3072)
  -C pais       Country (C), 2 letras ISO 3166 (obligatorio para servicio; opcional
                para usuario). Debe coincidir con el C de la CA.
  -S provincia  State or Province (ST) (opcional)
  -L localidad  Locality (L) (opcional)
  -O organiz.   Organization (O) (obligatorio para servicio; opcional para usuario).
                Debe coincidir con el O de la CA.
  -U unidad     Organizational Unit (OU) (opcional)
  -o dir        Directorio de salida (por defecto: ./solicitudes)
  -f            Forzar: sobrescribir clave y solicitud si ya existen (por defecto
                se aborta). ¡La clave privada anterior se pierde!
  -h            Mostrar esta ayuda

Ejemplos:
  KEY_PASS=mi_clave $0 -t usuario -n "Juan Perez" -e juan@ejemplo.com
  $0 -p mi_clave -t servicio -n www.ejemplo.com -d "www.ejemplo.com,ejemplo.com" \\
     -e admin@ejemplo.com -C ES -S GP -L Donostia -O "Bocata de Jamon" -U PKI
EOF
}

# Escapa caracteres con significado especial en el formato -subj de openssl
esc() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\//\\/}
    s=${s//+/\\+}
    printf '%s' "$s"
}

# Elimina espacios al principio y al final
trim() {
    local s=$1
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------- argumentos
while getopts "t:n:p:e:d:b:C:S:L:O:U:o:fh" opt; do
    case $opt in
        t) TIPO="$OPTARG" ;;
        n) CN="$OPTARG" ;;
        p) PASS="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        d) DNS="$OPTARG" ;;
        b) BITS="$OPTARG" ;;
        C) C="$OPTARG" ;;
        S) ST="$OPTARG" ;;
        L) L="$OPTARG" ;;
        O) O="$OPTARG" ;;
        U) OU="$OPTARG" ;;
        o) OUTDIR="$OPTARG" ;;
        f) FORCE=1 ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------- validaciones
command -v openssl >/dev/null 2>&1 || die "openssl no está instalado."

# -addext requiere OpenSSL >= 1.1.1 (LibreSSL no lo soporta igual)
ossl_ver=$(openssl version)
if [[ "$ossl_ver" =~ ^OpenSSL\ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
    major=${BASH_REMATCH[1]}; minor=${BASH_REMATCH[2]}; patch=${BASH_REMATCH[3]}
    if (( major < 1 || (major == 1 && minor < 1) || (major == 1 && minor == 1 && patch < 1) )); then
        die "se necesita OpenSSL >= 1.1.1 (detectado: $ossl_ver)."
    fi
else
    die "no se pudo verificar la versión de OpenSSL ('$ossl_ver'); se requiere OpenSSL >= 1.1.1."
fi

[[ -n "$TIPO" && -n "$CN" ]] || { echo "Error: -t y -n son obligatorios." >&2; usage >&2; exit 1; }
[[ "$TIPO" == "usuario" || "$TIPO" == "servicio" ]] || die "-t debe ser 'usuario' o 'servicio'."

if [[ "$TIPO" == "usuario" && -z "$EMAIL" ]]; then
    die "para tipo 'usuario' se requiere -e email."
fi
if [[ "$TIPO" == "servicio" ]]; then
    [[ -n "$DNS"   ]] || die "para tipo 'servicio' se requiere -d dns."
    [[ -n "$EMAIL" ]] || die "para tipo 'servicio' se requiere -e email."
    [[ -n "$C"     ]] || die "para tipo 'servicio' se requiere -C pais."
    [[ -n "$O"     ]] || die "para tipo 'servicio' se requiere -O organizacion."
fi

if [[ -n "$EMAIL" ]]; then
    [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] \
        || die "email no válido: '$EMAIL'."
fi

if [[ -n "$C" ]]; then
    [[ "$C" =~ ^[A-Za-z]{2}$ ]] || die "-C debe ser un código de país de 2 letras (p. ej. ES)."
    C=${C^^}
fi

[[ "$BITS" =~ ^[0-9]+$ ]] && (( BITS >= 2048 )) || die "-b debe ser un número entero >= 2048."

# Contraseña (script no interactivo): se toma de -p o, si no, de KEY_PASS.
# Si ninguna está definida y con valor, se aborta.
if [[ -z "$PASS" ]]; then
    PASS="${KEY_PASS:-}"
fi
[[ -n "$PASS" ]] || die "falta la contraseña: use -p <password> o defina la variable de entorno KEY_PASS (no vacía)."
(( ${#PASS} >= 4 )) || die "la contraseña debe tener al menos 4 caracteres."
export KEY_PASS="$PASS"
unset PASS

# ---------------------------------------------------------------- rutas de salida
mkdir -p "$OUTDIR"

SAFE_CN=$(printf '%s' "$CN" | tr ' ' '_' | tr -cd '[:alnum:]_.-')
[[ -n "$SAFE_CN" ]] || die "el nombre común no contiene caracteres válidos para un nombre de fichero."
KEY_FILE="$OUTDIR/clave-privada-${SAFE_CN}.key"
CSR_FILE="$OUTDIR/solicitud-${SAFE_CN}.csr"

if [[ -e "$KEY_FILE" || -e "$CSR_FILE" ]]; then
    if (( FORCE )); then
        echo "Aviso: se sobrescribirán los ficheros existentes (-f)." >&2
    else
        die "ya existen $KEY_FILE o $CSR_FILE; use -f para sobrescribirlos."
    fi
fi

# ---------------------------------------------------------------- subject (DN)
SUBJ=""
[[ -n "$C"  ]] && SUBJ+="/C=$(esc "$C")"
[[ -n "$ST" ]] && SUBJ+="/ST=$(esc "$ST")"
[[ -n "$L"  ]] && SUBJ+="/L=$(esc "$L")"
[[ -n "$O"  ]] && SUBJ+="/O=$(esc "$O")"
[[ -n "$OU" ]] && SUBJ+="/OU=$(esc "$OU")"
SUBJ+="/CN=$(esc "$CN")"
[[ -n "$EMAIL" ]] && SUBJ+="/emailAddress=$(esc "$EMAIL")"

# ---------------------------------------------------------------- extensiones
SAN=""
if [[ "$TIPO" == "servicio" ]]; then
    IFS=',' read -ra DNS_ARRAY <<< "$DNS"
    for d in "${DNS_ARRAY[@]}"; do
        d=$(trim "$d")
        [[ -n "$d" ]] || continue
        [[ "$d" =~ ^(\*\.)?[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*$ ]] \
            || die "nombre DNS no válido: '$d'."
        SAN+="${SAN:+,}DNS:${d}"
    done
    [[ -n "$SAN" ]] || die "la lista de DNS está vacía."
fi

# Extensiones que se piden en la solicitud (-addext):
#  - servicio: solo subjectAltName con los DNS indicados en -d
# El email, si se da, va únicamente en el subject; keyUsage y
#    extendedKeyUsage los fija la CA en su sección server_ext.
#  - usuario: subjectAltName con el email, keyUsage y extendedKeyUsage.
ADDEXT=()
if [[ "$TIPO" == "usuario" ]]; then
    ADDEXT+=(-addext "subjectAltName=email:${EMAIL}")
    ADDEXT+=(-addext "keyUsage=critical,digitalSignature,keyEncipherment")
    ADDEXT+=(-addext "extendedKeyUsage=clientAuth,emailProtection")
else
    ADDEXT+=(-addext "subjectAltName=${SAN}")
fi

# ---------------------------------------------------------------- openssl
# Se genera todo en un directorio temporal (dentro de OUTDIR, con permisos 700 por
# el umask) y solo se mueve al destino si openssl termina bien. Así, un fallo nunca
# deja ficheros a medias ni destruye los existentes cuando se usa -f.
TMP_DIR=""
cleanup() {
    [[ -n "$TMP_DIR" ]] && rm -rf -- "$TMP_DIR"
    return 0
}
trap cleanup EXIT
TMP_DIR=$(mktemp -d "$OUTDIR/.gen_solicitud.XXXXXX")

echo "Generando solicitud para $TIPO: $CN"
openssl req -new -newkey "rsa:${BITS}" \
    -keyout "$TMP_DIR/key" -out "$TMP_DIR/csr" \
    -subj "$SUBJ" -batch \
    -passout env:KEY_PASS \
    "${ADDEXT[@]}"

chmod 600 "$TMP_DIR/key"
unset KEY_PASS

mv -f -- "$TMP_DIR/key" "$KEY_FILE"
mv -f -- "$TMP_DIR/csr" "$CSR_FILE"

echo "Solicitud generada correctamente:"
echo "   Clave privada: $KEY_FILE (cifrada, RSA ${BITS})"
echo "   CSR:           $CSR_FILE"
echo "   Subject:       $SUBJ"
