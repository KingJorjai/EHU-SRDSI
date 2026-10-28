# Guía rápida del laboratorio PKI

Esta página condensa el procedimiento completo del [informe](informe.md) en pasos verificables. Para el detalle de cada comando manual, consulta [OpenSSL y PKI](../comandos/openssl.md); para los scripts, [Scripts](scripts.md).

!!! info "Entorno"
    Los ejemplos usan la VM Debian del laboratorio (`user1`) y rutas absolutas bajo `/home/user1`. Si trabajas en otro usuario, ajusta `PKI` y la directiva `home` de los ficheros `.cnf` (o define `PKI_DIR`/`CONF_CA` al usar los scripts).

## 1. Estructura de directorios y permisos

La raíz y la subCA tienen una estructura paralela. La raíz conserva su clave separada de la subCA para poder mantenerla *offline*.

```bash
PKI="$HOME/PKI_root"
SUB="$PKI/PKI_sub"

mkdir -p "$PKI"/{private,DB,certs,solicitudes,certs.p12} \
         "$SUB"/{private,DB,certs,certs.p12,solicitudes}

chmod 700 "$PKI/private" "$SUB/private"
touch "$PKI/DB/index.txt" "$SUB/DB/index.txt"
```

| Directorio | Contenido |
| --- | --- |
| `private/` | Claves privadas de la CA (modo `700`). |
| `DB/` | `index.txt`, series, CRL y ficheros de estado. |
| `certs/` | Certificados emitidos y copia `<serial>.pem` de `openssl ca`. |
| `certs.p12/` | PKCS#12 de usuarios (clave + certificado). |
| `solicitudes/` | CSR pendientes de revisión por el administrador (RA). |

Los scripts trabajan con `umask 077`: las claves y los `.p12` quedan con modo `600`.

## 2. Números de serie e `index.txt`

`index.txt` debe existir vacío. Cada CA necesita un número de serie para certificados y otro para CRL; se generan aleatoriamente.

```bash
openssl rand -hex 16 > "$PKI/DB/serie_emitidos.txt"
openssl rand -hex 16 > "$PKI/DB/serie_revocados.txt"
openssl rand -hex 16 > "$SUB/DB/serie_emitidos.txt"
openssl rand -hex 16 > "$SUB/DB/serie_revocados.txt"

wc -c "$PKI/DB/index.txt" "$SUB/DB/index.txt"
```

Cada `serie_*.txt` contiene 32 caracteres hexadecimales (16 bytes) más el salto de línea. `openssl ca` incrementa el fichero en cada emisión o CRL.

## 3. Configuración de las CAs

Copia las plantillas del repositorio junto a cada CA:

```bash
LAB='Tema 1: Introducción a la seguridad informática/lab-pki'
cp "$LAB/pki-config-files/ca-root_openssl.cnf" "$PKI/"
cp "$LAB/pki-config-files/ca-sub_openssl.cnf" "$SUB/"
```

Ajusta `home` en cada fichero (`$PKI` para la raíz y `$SUB` para la subCA). Valores usados en el laboratorio:

| Parámetro | rootCA | subCA |
| --- | --- | --- |
| `name` | `rootCA` | `subCA` |
| `domain_suffix` | `bocata-jamon.srdsi.lab` | igual |
| `ocsp_url` | `http://ocsp.bocata-jamon.srdsi.lab:4747` | igual |
| `C` / `ST` / `L` | `ES` / `GP` / `Donostia` | igual |
| `O` / `OU` | `Bocata de Jamon` / `PKI` | igual |
| `CN` | `bocata_jamon_rootCA` | `bocata_jamon_subCA` |
| `home` | `/home/user1/PKI_root` | `/home/user1/PKI_root/PKI_sub` |
| `database` | `$home/DB/index.txt` | igual |
| `serial` / `crlnumber` | `DB/serie_emitidos.txt` / `DB/serie_revocados.txt` | igual |
| `certificate` | `$home/certificado-rootCA.crt` | `$home/certificado-subCA.crt` |
| `private_key` | `$home/private/rootCA.key` | `$home/private/subCA.key` |
| `new_certs_dir` | `$home/certs` | igual |
| `copy_extensions` | `none` | `copy` |
| `policy` | `policy_c_o_match` | `policy_c_o_match` |
| `emailAddress` en la política | `optional` | `supplied` |

La política exige que `C` y `O` del solicitante coincidan con los de la CA (`match`). La subCA además exige `emailAddress` (`supplied`). La raíz solo firma a la subCA y no copia extensiones de la CSR; la subCA sí las copia (`subjectAltName`, etc.).

Extensiones disponibles en la subCA:

| Sección | Uso | Campos principales |
| --- | --- | --- |
| `server_ext` | Servicios | `CA:false`, `keyUsage=digitalSignature,keyEncipherment`, EKU servidor/cliente, AIA y CRLDP. |
| `user_ext` | Usuarios | `CA:false`, `keyUsage=digitalSignature`, EKU `clientAuth`. |
| `ocsp_ext` | Respondedor OCSP | `CA:false`, `keyUsage=digitalSignature`, EKU `OCSPSigning`. |
| `subca_ext` (en la raíz) | Certificado de la subCA | `CA:true,pathlen:0`, `keyCertSign,cRLSign`, AIA y CRLDP. |

## 4. Clave y certificado autofirmado de la rootCA

```bash
CONF="$PKI/ca-root_openssl.cnf"
export ROOT_PASS='passphrase-de-la-raiz'

openssl req -new -newkey rsa:3072 \
  -keyout "$PKI/private/rootCA.key" \
  -out "$PKI/solicitud-rootCA.csr" \
  -config "$CONF" -batch -passout env:ROOT_PASS

openssl ca -selfsign -batch -notext -config "$CONF" \
  -extensions ca_ext \
  -in "$PKI/solicitud-rootCA.csr" \
  -out "$PKI/certs/certificado-rootCA.crt" \
  -passin env:ROOT_PASS

mv "$PKI/certs/certificado-rootCA.crt" "$PKI/certificado-rootCA.crt"
```

El `mv` es necesario porque la configuración espera el certificado en `$home/certificado-rootCA.crt`, mientras que `openssl ca` escribe la salida donde se le indique (y deja además una copia `<serial>.pem` en `certs/`). Genera la CRL inicial:

```bash
openssl ca -gencrl -batch -config "$CONF" \
  -out "$PKI/DB/crl-CA.pem" -passin env:ROOT_PASS
```

![Firma del certificado raíz autofirmado](../../assets/img/lab-pki/paso1-01.png)

Detalle en [§2.4 del informe](informe.md#24-clave-y-certificado-de-la-ca-raiz-autofirmado).

## 5. Clave y certificado de la subCA

La subCA genera su propia clave y CSR; la raíz la firma con `subca_ext`:

```bash
SUBCONF="$SUB/ca-sub_openssl.cnf"
export SUB_PASS='passphrase-de-la-subca'

openssl req -new -newkey rsa:3072 \
  -keyout "$SUB/private/subCA.key" \
  -out "$SUB/solicitud-subCA.csr" \
  -config "$SUBCONF" -batch -passout env:SUB_PASS

openssl ca -batch -notext -config "$CONF" \
  -extensions subca_ext \
  -in "$SUB/solicitud-subCA.csr" \
  -out "$SUB/certificado-subCA.crt" \
  -passin env:ROOT_PASS
```

La CSR de la subCA debe llevar el mismo `C` y `O` que la raíz. Comprueba el resultado:

```bash
openssl x509 -in "$SUB/certificado-subCA.crt" -noout -subject -issuer
openssl x509 -in "$SUB/certificado-subCA.crt" -noout -text | grep -A2 'Basic Constraints'
```

Debe aparecer `CA:TRUE, pathlen:0` y el emisor `CN=bocata_jamon_rootCA`.

![Emisión del certificado de la subCA](../../assets/img/lab-pki/paso1-02.png)

Detalle en [§2.5 del informe](informe.md#25-clave-y-certificado-de-la-ca-subordinada).

## 6. Certificados de usuario, servicio y OCSP

Los scripts automatizan la generación de la clave y la CSR, la emisión y la revocación. Consulta [Scripts](scripts.md) para opciones, variables y códigos de salida.

### 6.1 Usuario

```bash
export KEY_PASS='Contraseña segura1234_'
"$LAB/scripts/gen_solicitud.sh" -t usuario -n "Paco Antonio Gutierrez" \
  -e paco@bocata-jamon.srdsi.lab -C ES -O "Bocata de Jamon" \
  -o "$SUB/solicitudes" -f

export CA_PASS="$SUB_PASS"
"$LAB/scripts/emitir_cert.sh" \
  "$SUB/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr" user_ext
```

Resultado: `certs/certificado-Paco_Antonio_Gutierrez.crt` y `certs.p12/certificado-Paco_Antonio_Gutierrez.p12`. Con `user_ext` la clave privada debe estar junto a la CSR con el nombre `clave-privada-<nombre>.key`.

### 6.2 Servicio

Para un servicio son obligatorios `-d`, `-e`, `-C` y `-O`. La emisión con `server_ext` entrega solo el `.crt`: la clave privada se queda en el solicitante.

```bash
export KEY_PASS='passphrase-del-servicio'
"$LAB/scripts/gen_solicitud.sh" -t servicio -n "www.bocata-jamon.srdsi.lab" \
  -d "www.bocata-jamon.srdsi.lab,bocata-jamon.srdsi.lab" \
  -e admin@bocata-jamon.srdsi.lab -C ES -S GP -L Donostia \
  -O "Bocata de Jamon" -U PKI -o "$SUB/solicitudes"

export CA_PASS="$SUB_PASS"
"$LAB/scripts/emitir_cert.sh" \
  "$SUB/solicitudes/solicitud-www.bocata-jamon.srdsi.lab.csr" server_ext
```

El SAN de la CSR (`DNS:...`) se copia al certificado porque la subCA usa `copy_extensions=copy`.

### 6.3 Servicio OCSP

El certificado del respondedor usa `ocsp_ext` y el CN `ocsp`:

```bash
mkdir -p "$SUB/ocsp"
export KEY_PASS='user1Sub_CA_ocsp'
"$LAB/scripts/gen_solicitud.sh" -t servicio -n "ocsp" \
  -d ocsp.bocata-jamon.srdsi.lab \
  -e ocsp@bocata-jamon.srdsi.lab -C ES -S GP -L Donostia \
  -O "Bocata de Jamon" -U PKI -o "$SUB/ocsp"

export CA_PASS="$SUB_PASS"
"$LAB/scripts/emitir_cert.sh" \
  "$SUB/ocsp/solicitud-ocsp.bocata-jamon.srdsi.lab.csr" ocsp_ext

mv "$SUB/ocsp/clave-privada-ocsp.bocata-jamon.srdsi.lab.key" "$SUB/private/"
chmod 600 "$SUB/private/clave-privada-ocsp.bocata-jamon.srdsi.lab.key"
```

El certificado queda en `certs/certificado-ocsp.bocata-jamon.srdsi.lab.crt`; `ocsp_ext` no genera PKCS#12.

### 6.4 Revisión previa de la CSR

El administrador actúa como autoridad de registro y **debe revisar** la solicitud; `emitir_cert.sh` no lo hace:

```bash
openssl req -in "$SUB/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr" \
  -noout -subject -verify
openssl req -in "$SUB/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr" \
  -noout -text | less
```

Para emitir manualmente, sin scripts, sigue el [ciclo completo de OpenSSL](../comandos/openssl.md#5-emitir-el-certificado).

![Confirmación de emisión y PKCS#12](../../assets/img/lab-pki/paso2-03.png)

Detalle en [§3 del informe](informe.md#3-paso-2-certificados-de-usuario-scripts-y-ejemplo).

## 7. Revocar, regenerar la CRL y consultar el estado

```bash
"$LAB/scripts/revocar_cert.sh" \
  "$SUB/certs/certificado-Paco_Antonio_Gutierrez.crt" cessationOfOperation

openssl ca -gencrl -batch -config "$SUBCONF" \
  -passin env:CA_PASS -out "$SUB/DB/crl-sub.pem"
```

Comprobaciones:

```bash
SERIAL=$(openssl x509 -in "$SUB/certs/certificado-Paco_Antonio_Gutierrez.crt" \
  -noout -serial | cut -d= -f2)
openssl ca -config "$SUBCONF" -status "$SERIAL"
openssl crl -in "$SUB/DB/crl-sub.pem" -noout -text | less
```

`revocar_cert.sh` consulta el estado antes de revocar para no ensuciar `index.txt` con seriales inexistentes o ya revocados. La revocación no se propaga hasta que se regenera y publica la CRL.

Motivos admitidos: `unspecified`, `keyCompromise`, `CACompromise`, `affiliationChanged`, `superseded`, `cessationOfOperation`, `certificateHold`.

![Revocación por cese de operación](../../assets/img/lab-pki/paso2-04.png)

Detalle en [§5.3 del informe](informe.md#53-estado-por-crl-pem-y-der).

## 8. Respondedor OCSP

Resuelve el nombre del respondedor y arranca el servicio:

```bash
echo "127.10.0.1  ocsp ocsp.bocata-jamon.srdsi.lab" | sudo tee -a /etc/hosts

openssl ocsp -port 4747 \
  -index "$SUB/DB/index.txt" \
  -CA "$SUB/certificado-subCA.crt" \
  -rsigner "$SUB/certs/certificado-ocsp.bocata-jamon.srdsi.lab.crt" \
  -rkey "$SUB/private/clave-privada-ocsp.bocata-jamon.srdsi.lab.key" \
  </dev/null >"$SUB/ocsp/responder.log" 2>&1 &
```

Consulta de un certificado revocado y de uno bueno:

```bash
cat "$SUB/certificado-subCA.crt" "$PKI/certificado-rootCA.crt" > /tmp/chain.crt

openssl ocsp -issuer "$SUB/certificado-subCA.crt" \
  -cert "$SUB/certs/certificado-Paco_Antonio_Gutierrez.crt" \
  -url http://ocsp.bocata-jamon.srdsi.lab:4747 \
  -CAfile /tmp/chain.crt -resp_text
```

La respuesta debe indicar `Cert Status: revoked` para Paco (con el motivo) y `Cert Status: good` para el certificado OCSP. Si el puerto ya está ocupado, comprueba el proceso con `ss -ltnp | grep 4747` y detén el respondedor anterior.

![Consulta OCSP con resultado good](../../assets/img/lab-pki/paso3-04.png)

Detalle en [§4 del informe](informe.md#4-paso-3-servidor-ocsp).

## 9. Verificación, inspección y PKCS#12

### 9.1 Cadena de certificación

```bash
cat "$SUB/certificado-subCA.crt" "$PKI/certificado-rootCA.crt" > /tmp/chain.crt

openssl verify -CAfile "$PKI/certificado-rootCA.crt" \
  -untrusted "$SUB/certificado-subCA.crt" \
  "$SUB/certs/certificado-Paco_Antonio_Gutierrez.crt"

openssl verify -CAfile /tmp/chain.crt \
  "$SUB/certs/certificado-Paco_Antonio_Gutierrez.crt"
```

Ambas formas deben devolver `OK`. La raíz es el ancla de confianza y la subCA se pasa como certificado intermedio (`-untrusted`) o dentro de la cadena completa.

### 9.2 Inspección del certificado

```bash
CERT="$SUB/certs/certificado-Paco_Antonio_Gutierrez.crt"

openssl x509 -in "$CERT" -noout -subject -issuer -serial -dates
openssl x509 -in "$CERT" -noout -text | less
openssl x509 -in "$CERT" -noout -ext subjectAltName,keyUsage,extendedKeyUsage
```

Comprueba `subject`, `issuer` (subCA), validez, SAN, `keyUsage` y `extendedKeyUsage`.

### 9.3 PKCS#12

```bash
P12="$SUB/certs.p12/certificado-Paco_Antonio_Gutierrez.p12"

openssl pkcs12 -in "$P12" -info -noout
openssl pkcs12 -in "$P12" -nokeys -out /tmp/paco-cert.pem
openssl pkcs12 -in "$P12" -nocerts -out /tmp/paco-key.pem
```

El `.p12` contiene la clave privada y el certificado del usuario. Solo lo descarga el administrador y se entrega en persona; en la web, el usuario únicamente descarga el `.crt` público.

Detalle en [§5 del informe](informe.md#5-verificacion-de-certificados).

## 10. Cierre

Al terminar, detén el respondedor OCSP y revisa el [checklist de la práctica](index.md#checklist-de-la-practica). El informe con las capturas y las salidas completas está en [Informe completo](informe.md).
