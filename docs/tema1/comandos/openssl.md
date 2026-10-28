# OpenSSL y PKI

OpenSSL permite montar una PKI completa desde la línea de comandos: crear la clave y el certificado de una CA, firmar solicitudes, emitir certificados con extensiones, revocar, publicar CRL y responder consultas OCSP. Esta página sigue el flujo del [laboratorio PKI](../lab-pki/index.md) y usa los ficheros de configuración del repositorio.

[:material-file-pdf-box: Transparencias — Gestión de claves y PKI (PDF)](../../assets/pdf/SRDSI_T1-4.pdf){ .md-button }

!!! note "Versiones"
    Comandos comprobados con **OpenSSL 4.0.3** en el host y con la VM Debian del laboratorio. La sintaxis es válida para OpenSSL 1.1.1 o superior; `-addext` exige al menos 1.1.1.

## Estructura de una PKI jerárquica

Una PKI mínima del laboratorio tiene dos niveles:

- **rootCA**: autoridad raíz. Su certificado es autofirmado y es el ancla de confianza.
- **subCA**: autoridad subordinada, firmada por la raíz. Emite los certificados finales de usuario y servicio.

```text
~/PKI_root/
├── ca-root_openssl.cnf
├── certificado-rootCA.crt
├── private/                  # 700; claves privadas
│   └── rootCA.key
├── DB/
│   ├── index.txt             # base de datos de certificados
│   ├── serie_emitidos.txt    # número de serie
│   ├── serie_revocados.txt   # número de CRL
│   └── crl-CA.pem
├── certs/                    # new_certs_dir de la raíz
└── PKI_sub/
    ├── ca-sub_openssl.cnf
    ├── certificado-subCA.crt
    ├── private/subCA.key
    ├── DB/{index.txt,serie_emitidos.txt,serie_revocados.txt,crl-sub.pem}
    ├── certs/                # certificados emitidos por la subCA
    ├── certs.p12/            # PKCS#12 para usuarios
    └── solicitudes/          # CSR pendientes de revisión
```

La raíz solo firma a la subCA; los certificados finales los emite la subCA. Así la clave raíz puede mantenerse *offline*.

## Ficheros de configuración

Los ficheros de ejemplo están en `Tema 1: Introducción a la seguridad informática/lab-pki/pki-config-files/`:

- `ca-root_openssl.cnf`
- `ca-sub_openssl.cnf`

Ambos se copian junto a la CA correspondiente y se ajusta la ruta `home`. El resto de rutas se deriva de ella.

| Campo | Función |
| --- | --- |
| `home` | Directorio base de la CA. El resto de rutas suele usar `$home`. |
| `database` | `index.txt`: estado de cada certificado (válido, revocado, caducado). |
| `serial` | Fichero con el siguiente número de serie de los certificados. |
| `crlnumber` | Fichero con el siguiente número de CRL. |
| `certificate` | Certificado PEM de la CA. |
| `private_key` | Clave privada de la CA. Debe estar en un directorio `700`. |
| `new_certs_dir` | Directorio donde `openssl ca` deja una copia `<serial>.pem` de cada certificado emitido. |
| `policy` | Sección que decide qué campos del *subject* son obligatorios (`supplied`), opcionales o deben coincidir (`match`). |
| `copy_extensions` | `copy` copia a la CSR extensiones como `subjectAltName`; `none` las ignora. La raíz usa `none`; la subCA, `copy`. |
| `unique_subject` | `no` permite reutilizar el mismo *subject* para varias claves. |

Fragmento real de la subCA:

```ini
[CA_default]
home            = /home/user1/PKI_root/PKI_sub
database        = $home/DB/index.txt
serial          = $home/DB/serie_emitidos.txt
crlnumber       = $home/DB/serie_revocados.txt
certificate     = $home/certificado-subCA.crt
private_key     = $home/private/subCA.key
new_certs_dir   = $home/certs
unique_subject  = no
copy_extensions = copy
default_md      = sha256
policy          = policy_c_o_match
```

La política del laboratorio exige que `C` y `O` coincidan con los de la CA y que el correo esté presente en la subCA:

```ini
[policy_c_o_match]
countryName         = match
organizationName    = match
commonName          = supplied
emailAddress        = supplied
```

!!! warning "La política se aplica al emitir"
    `gen_solicitud.sh` solo exige `-e` para un usuario, pero la subCA **sí** exige `C` y `O` coincidentes. Si se omite `-C`/`-O`, `openssl ca` aborta con `The mandatory countryName field was missing` (comprobado).

## Ciclo completo de la PKI

### 1. Preparar directorios, configuración, base de datos y números de serie

Desde la raíz del repositorio:

```bash
LAB='Tema 1: Introducción a la seguridad informática/lab-pki'
PKI="$HOME/PKI_root"
SUB="$PKI/PKI_sub"

mkdir -p "$PKI"/{private,DB,certs,solicitudes,certs.p12} \
         "$SUB"/{private,DB,certs,certs.p12,solicitudes}

cp "$LAB/pki-config-files/ca-root_openssl.cnf" "$PKI/"
cp "$LAB/pki-config-files/ca-sub_openssl.cnf" "$SUB/"
sed -i "s#^home = .*#home = $PKI#" "$PKI/ca-root_openssl.cnf"
sed -i "s#^home = .*#home = $SUB#" "$SUB/ca-sub_openssl.cnf"
chmod 700 "$PKI/private" "$SUB/private"
touch "$PKI/DB/index.txt" "$SUB/DB/index.txt"

openssl rand -hex 16 > "$PKI/DB/serie_emitidos.txt"
openssl rand -hex 16 > "$PKI/DB/serie_revocados.txt"
openssl rand -hex 16 > "$SUB/DB/serie_emitidos.txt"
openssl rand -hex 16 > "$SUB/DB/serie_revocados.txt"
```

### 2. Clave y certificado autofirmado de la raíz

El certificado de la raíz se firma con su propia clave (`-selfsign`) y la extensión `ca_ext` (`basicConstraints=critical,CA:true`, `keyUsage=keyCertSign,cRLSign`).

```bash
CONF="$PKI/ca-root_openssl.cnf"
export KEY_PASS='passphrase-de-la-clave-raiz'
export CA_PASS="$KEY_PASS"

openssl req -new -newkey rsa:3072 \
  -keyout "$PKI/private/rootCA.key" \
  -out "$PKI/solicitud-rootCA.csr" \
  -config "$CONF" -batch -passout env:KEY_PASS

openssl ca -selfsign -batch -notext -config "$CONF" \
  -extensions ca_ext \
  -in "$PKI/solicitud-rootCA.csr" \
  -out "$PKI/certs/certificado-rootCA.crt" \
  -passin env:CA_PASS

mv "$PKI/certs/certificado-rootCA.crt" "$PKI/certificado-rootCA.crt"
```

`openssl ca` deja además una copia en `new_certs_dir` (`$PKI/certs/<serial>.pem`) y actualiza `index.txt`. Por eso el `mv` mueve la salida a la ruta que espera la configuración (`certificate`).

Primera CRL de la raíz:

```bash
openssl ca -gencrl -batch -config "$CONF" \
  -out "$PKI/DB/crl-CA.pem" -passin env:CA_PASS
```

### 3. Clave y certificado de la subCA

La subCA genera su propia clave y CSR; la raíz la firma con `subca_ext` (`CA:true,pathlen:0`).

```bash
SUBCONF="$SUB/ca-sub_openssl.cnf"
export KEY_PASS='passphrase-de-la-clave-subca'

openssl req -new -newkey rsa:3072 \
  -keyout "$SUB/private/subCA.key" \
  -out "$SUB/solicitud-subCA.csr" \
  -config "$SUBCONF" -batch -passout env:KEY_PASS

openssl ca -batch -notext -config "$PKI/ca-root_openssl.cnf" \
  -extensions subca_ext \
  -in "$SUB/solicitud-subCA.csr" \
  -out "$SUB/certificado-subCA.crt" \
  -passin env:CA_PASS
```

La CSR de la subCA usa el mismo `C`/`O` que la raíz, como exige la política `match`.

### 4. Crear una CSR (PKCS#10)

Para un servicio con SAN y correo (la política de la subCA exige `emailAddress`):

```bash
export KEY_PASS='passphrase-de-la-clave-del-servicio'

openssl req -new -newkey rsa:3072 \
  -keyout www.ejemplo.lab.key \
  -out www.ejemplo.lab.csr \
  -subj '/C=ES/O=Bocata de Jamon/CN=www.ejemplo.lab/emailAddress=admin@ejemplo.lab' \
  -addext 'subjectAltName=DNS:www.ejemplo.lab,DNS:ejemplo.lab' \
  -batch -passout env:KEY_PASS

chmod 600 www.ejemplo.lab.key
```

Para un usuario, los SAN se piden con `email:`:

```bash
openssl req -new -newkey rsa:3072 \
  -keyout usuario.key -out usuario.csr \
  -subj '/C=ES/O=Bocata de Jamon/CN=Nombre Apellido/emailAddress=usuario@ejemplo.lab' \
  -addext 'subjectAltName=email:usuario@ejemplo.lab' \
  -addext 'keyUsage=critical,digitalSignature,keyEncipherment' \
  -addext 'extendedKeyUsage=clientAuth,emailProtection' \
  -batch -passout env:KEY_PASS
```

Revisar la solicitud antes de firmarla (el administrador actúa como RA):

```bash
openssl req -in www.ejemplo.lab.csr -noout -subject -verify
openssl req -in www.ejemplo.lab.csr -noout -text | less
```

### 5. Emitir el certificado

La subCA firma con una sección de extensiones concreta. `copy_extensions=copy` hace que el SAN de la CSR llegue al certificado.

```bash
export CA_PASS='passphrase-de-la-clave-subca'

openssl ca -batch -notext -config "$SUBCONF" \
  -in www.ejemplo.lab.csr \
  -out "$SUB/certs/certificado-www.ejemplo.lab.crt" \
  -extensions server_ext \
  -passin env:CA_PASS
```

| Sección | Uso | Extensiones principales |
| --- | --- | --- |
| `ca_ext` | Certificado autofirmado de la raíz | `basicConstraints=CA:true`, `keyUsage=keyCertSign,cRLSign` |
| `subca_ext` | Certificado de la subCA | `CA:true,pathlen:0`, `keyUsage=keyCertSign,cRLSign`, AIA, CRLDP |
| `server_ext` | Servicios | `CA:false`, `keyUsage=digitalSignature,keyEncipherment`, EKU cliente/servidor |
| `user_ext` | Usuarios | `CA:false`, `keyUsage=digitalSignature`, EKU `clientAuth` |
| `ocsp_ext` | Respondedor OCSP | `CA:false`, `keyUsage=digitalSignature`, EKU `OCSPSigning` |

### 6. Inspeccionar y verificar

```bash
CERT="$SUB/certs/certificado-www.ejemplo.lab.crt"

openssl x509 -in "$CERT" -noout -text | less
openssl x509 -in "$CERT" -noout -subject -issuer -serial
openssl x509 -in "$CERT" -noout -ext subjectAltName
openssl x509 -in "$CERT" -noout -dates
```

Cadena de confianza:

```bash
cat "$SUB/certificado-subCA.crt" "$PKI/certificado-rootCA.crt" > chain.crt

# Opción 1: raíz como ancla y subCA como no fiable
openssl verify -CAfile "$PKI/certificado-rootCA.crt" \
  -untrusted "$SUB/certificado-subCA.crt" "$CERT"

# Opción 2: cadena completa como almacén de confianza
openssl verify -CAfile chain.crt "$CERT"
```

Ambas variantes devuelven `...: OK` si la cadena es correcta (comprobado).

### 7. Revocar y publicar la CRL

```bash
CERT="$SUB/certs/certificado-www.ejemplo.lab.crt"
SERIAL=$(openssl x509 -in "$CERT" -noout -serial | cut -d= -f2)

# Estado antes de revocar (solo lectura)
openssl ca -config "$SUBCONF" -status "$SERIAL" </dev/null

# Revocar indicando el motivo
openssl ca -batch -config "$SUBCONF" -revoke "$CERT" \
  -crl_reason keyCompromise -passin env:CA_PASS

# Regenerar y publicar la CRL
openssl ca -gencrl -batch -config "$SUBCONF" \
  -out "$SUB/DB/crl-sub.pem" -passin env:CA_PASS

openssl crl -in "$SUB/DB/crl-sub.pem" -noout -text | less
```

Motivos válidos: `unspecified`, `keyCompromise`, `CACompromise`, `affiliationChanged`, `superseded`, `cessationOfOperation`, `certificateHold`.

!!! danger "Revocar no basta"
    `openssl ca -revoke` solo marca el certificado en `index.txt`. Los clientes no lo sabrán hasta que se regenere y publique la CRL (o hasta que el OCSP lo refleje).

### 8. Respondedor OCSP

El certificado del respondedor debe emitirse con `ocsp_ext`. En el laboratorio se genera con `gen_solicitud.sh` y se emite con `emitir_cert.sh ... ocsp_ext`.

Servidor (la clave del respondedor está cifrada, de ahí `-passin`):

```bash
export OCSP_PASS='passphrase-de-la-clave-ocsp'

openssl ocsp -port 4747 \
  -index "$SUB/DB/index.txt" \
  -CA "$SUB/certificado-subCA.crt" \
  -rsigner "$SUB/certs/certificado-ocsp.bocata-jamon.srdsi.lab.crt" \
  -rkey "$SUB/private/clave-privada-ocsp.bocata-jamon.srdsi.lab.key" \
  -passin env:OCSP_PASS \
  </dev/null >"$SUB/ocsp/responder.log" 2>&1 &
```

Cliente:

```bash
openssl ocsp \
  -issuer "$SUB/certificado-subCA.crt" \
  -cert "$CERT" \
  -url http://ocsp.bocata-jamon.srdsi.lab:4747 \
  -CAfile chain.crt -resp_text
```

Salida esperada (resumida):

```console
OCSP Response Status: successful (0x0)
Cert Status: revoked
Revocation Reason: cessationOfOperation (0x5)
.../certificado-www.ejemplo.lab.crt: revoked
```

Para un certificado válido, `Cert Status: good`. La consulta puede fallar si el nombre `ocsp...` no resuelve; en el laboratorio se añade a `/etc/hosts`.

### 9. PKCS#12 y conversión PEM/DER

Exportar un `.p12` con certificado + clave (y, opcionalmente, la cadena):

```bash
openssl pkcs12 -export \
  -out usuario.p12 \
  -inkey usuario.key \
  -in usuario.crt \
  -certfile chain.crt \
  -passin env:KEY_PASS -passout env:P12_PASS
```

Inspeccionar sin extraer y extraer partes:

```bash
openssl pkcs12 -in usuario.p12 -info -noout -passin env:P12_PASS
openssl pkcs12 -in usuario.p12 -nokeys -out usuario-cert.pem -passin env:P12_PASS
openssl pkcs12 -in usuario.p12 -nocerts -out usuario-key.pem -passin env:P12_PASS
```

`-nocerts` deja la clave cifrada con la contraseña de salida; `-nodes` la deja sin cifrar (solo para pruebas y con permisos `600`).

Conversión entre PEM y DER:

```bash
openssl x509 -in cert.pem -outform DER -out cert.der
openssl x509 -in cert.der -inform DER -noout -text
openssl x509 -in cert.der -inform DER -out cert.pem

openssl crl -in crl.pem -outform DER -out crl.der
openssl crl -in crl.der -inform DER -noout -text
```

## Scripts del repositorio

Rutas relativas a la raíz del repositorio:

```bash
LAB='Tema 1: Introducción a la seguridad informática/lab-pki'
SCRIPTS="$LAB/scripts"
```

### `gen_solicitud.sh`

Genera una clave RSA cifrada (modo `600`) y una CSR. No sobrescribe salvo con `-f`.

```bash
KEY_PASS='passphrase' bash "$SCRIPTS/gen_solicitud.sh" \
  -t usuario -n 'Paco Antonio Gutierrez' \
  -e paco@bocata-jamon.srdsi.lab \
  -C ES -O 'Bocata de Jamon' \
  -o "$HOME/PKI_root/PKI_sub/solicitudes"
```

Para un servicio son obligatorios `-d`, `-e`, `-C` y `-O`:

```bash
KEY_PASS='passphrase' bash "$SCRIPTS/gen_solicitud.sh" \
  -t servicio -n 'www.ejemplo.lab' \
  -d 'www.ejemplo.lab,ejemplo.lab' \
  -e admin@ejemplo.lab -C ES -O 'Bocata de Jamon' \
  -o ./solicitudes
```

| Opción | Uso |
| --- | --- |
| `-t usuario\|servicio` | Tipo de certificado (obligatorio). |
| `-n <CN>` | *Common Name* (obligatorio). |
| `-e <correo>` | Obligatorio para usuario y servicio. |
| `-d <DNS,...>` | SAN de servicio, separados por comas (obligatorio para servicio). |
| `-C`, `-S`, `-L`, `-O`, `-U` | País, provincia, localidad, organización y unidad. |
| `-b <bits>` | RSA, mínimo 2048 (por defecto 3072). |
| `-o <dir>` | Directorio de salida. |
| `-f` | Sobrescribe clave y CSR existentes. |
| `-p <pass>` | Contraseña; preferible `KEY_PASS` para no dejarla en `ps`/historial. |

### `emitir_cert.sh`

```bash
KEY_PASS='passphrase' CA_PASS='passphrase-subca' \
  bash "$SCRIPTS/emitir_cert.sh" \
  "$HOME/PKI_root/PKI_sub/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr" \
  user_ext
```

Con `user_ext` exige la clave hermana `clave-privada-<nombre>.key`, comprueba que la clave pública coincide con la CSR y genera además un PKCS#12 (modo `600`). Con `server_ext` y `ocsp_ext` solo entrega el `.crt`.

| Variable | Efecto |
| --- | --- |
| `KEY_PASS` | Contraseña de la clave de la CSR; obligatoria solo con `user_ext`. |
| `P12_PASS` | Contraseña del `.p12`; por defecto, igual que `KEY_PASS`. |
| `PKI_DIR` | Directorio de la subCA (por defecto `/home/user1/PKI_root/PKI_sub`). |
| `CONF_CA` | Configuración de la CA (por defecto `$PKI_DIR/ca-sub_openssl.cnf`). |
| `CERTS_DIR` / `P12_DIR` | Destinos de `.crt` / `.p12`. |
| `CA_PASS` | Contraseña de la CA; si falta, OpenSSL la pide por terminal. |

Códigos de salida: `1` solicitud/clave ilegible, `2` extensión no válida, `3` configuración o fichero existente, `4` certificado emitido pero fallo al crear el `.p12`.

### `revocar_cert.sh`

```bash
CONF_CA="$HOME/PKI_root/PKI_sub/ca-sub_openssl.cnf" \
CA_PASS='passphrase-subca' \
  bash "$SCRIPTS/revocar_cert.sh" \
  "$HOME/PKI_root/PKI_sub/certs/certificado-Paco_Antonio_Gutierrez.crt" \
  cessationOfOperation
```

El script consulta antes `openssl ca -status` y no toca `index.txt` si el serial no existe o ya está revocado. Después hay que regenerar la CRL.

## Errores y gotchas

!!! warning "Rutas y directorio de trabajo"
    `openssl ca` resuelve `database`, `serial`, `certificate`, etc. desde la configuración. Si se ejecuta desde otro directorio, usa siempre `-config` con una ruta absoluta. Los scripts resuelven la clave hermana respecto al directorio de la CSR.

- **`-batch`**: evita las preguntas interactivas de `openssl ca`. Úsalo cuando la revisión de la CSR ya se ha hecho a mano.
- **`-notext`**: el `.crt` contiene solo el PEM, sin el volcado de texto. Es lo que esperan los clientes.
- **Contraseñas por entorno**: `KEY_PASS`, `CA_PASS` y `P12_PASS` evitan que la contraseña aparezca en `ps` o en el historial. No uses `-p` en máquinas compartidas.
- **`emitir_cert.sh` no valida la CSR**: el administrador es la RA y debe revisar el *subject*, el SAN y la clave pública antes de firmar. El script solo comprueba la correspondencia clave/CSR con `user_ext`.
- **`copy_extensions`**: en la raíz es `none`; en la subCA es `copy`. Sin `copy`, el SAN pedido con `-addext` no llegaría al certificado final.
- **Política C/O**: `countryName=match` y `organizationName=match` obligan a que la CSR lleve los mismos valores que la CA. Para usuarios también, aunque el script no los exija.
- **CRL**: tras cada revocación hay que ejecutar `openssl ca -gencrl`; si no, la CRL publicada sigue diciendo que el certificado es válido.
- **`openssl ca -revoke` y seriales desconocidos**: añade una entrada a `index.txt` si el serial no existe. Por eso `revocar_cert.sh` consulta `-status` antes.
- **OCSP**: el certificado del respondedor necesita `extendedKeyUsage=OCSPSigning` (`ocsp_ext`). El cliente debe confiar en la cadena (`-CAfile`), no solo en el certificado del respondedor.
- **`unique_subject=no`**: permite emitir un certificado nuevo con el mismo *subject* (por ejemplo, tras renovar), pero no impide que convivan certificados antiguos.

## Enlaces

- [Laboratorio PKI](../lab-pki/index.md)
- [Guía del laboratorio PKI](../lab-pki/guia.md)
- [Scripts del laboratorio](../lab-pki/scripts.md)
- [Informe PKI](../lab-pki/informe.md)
- [Gestión de claves y PKI (teoría)](../teoria/gestion-claves.md)
- [Estudio de una CA: GlobalSign](../actividades/estudio-ca.md)
