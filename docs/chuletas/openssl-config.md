# Configuración OpenSSL de la PKI

Anotación de los dos ficheros del laboratorio. El original está en `Tema 1: Introducción a la seguridad informática/lab-pki/pki-config-files/` y la copia publicada en [`docs/assets/config/`](../assets/config/ca-root_openssl.cnf):

- [`ca-root_openssl.cnf`](../assets/config/ca-root_openssl.cnf) — autoridad raíz.
- [`ca-sub_openssl.cnf`](../assets/config/ca-sub_openssl.cnf) — autoridad subordinada que emite los certificados finales.

La raíz solo firma a la subCA; la subCA firma usuarios y servicios. Cada fichero se copia junto a su CA y se ajusta la ruta `home`. El resto de rutas se deriva de ella.

## `[default]`

Variables comunes y sección de CA por defecto. OpenSSL sustituye `$name`, `$domain_suffix`, etc. dentro del propio fichero.

```ini
[default]
name = rootCA
domain_suffix = bocata-jamon.srdsi.lab
aia_url = http://$name.$domain_suffix/$name.crt
crl_url = http://$name.$domain_suffix/$name.crl
ocsp_url = http://ocsp.$domain_suffix:4747

# Sección que usa "openssl ca" si no se pasa -name ni otra sección
default_ca = CA_default

# Formato al imprimir el subject
name_opt = utf8,esc_ctrl,multiline,lname,align
```

- `name` y `domain_suffix` construyen las URL de AIA, CRL y OCSP.
- `aia_url` es el **Authority Information Access**: dónde se descarga el certificado del emisor.
- `crl_url` es el **CRL Distribution Point**: dónde se publica la CRL.
- `ocsp_url` apunta al respondedor OCSP (puerto `4747`).
- `default_ca = CA_default` evita tener que pasar `-name CA_default` en cada `openssl ca`.
- `name_opt` solo afecta a la presentación del *subject*.

En la subCA, `name = subCA`; el resto de variables se resuelven con ese valor.

## `[ca_dn]`

*Distinguished Name* de la propia CA. Se usa al generar su CSR porque en `[req]` está `prompt = no`.

```ini
[ca_dn]
countryName = ES
stateOrProvinceName = GP
localityName = Donostia
organizationName = Bocata de Jamon
organizationalUnitName = PKI
commonName = bocata_jamon_rootCA
```

La subCA cambia el `commonName` por `bocata_jamon_subCA`. `C`, `O` y `OU` deben ser coherentes con la política de la CA que la firma.

## `[CA_default]`

El corazón de la configuración: rutas, base de datos, política y valores por defecto de emisión.

```ini
[CA_default]
home = /home/user1/PKI_root
db = DB
privado = private

# Base de datos y contadores
database = $home/$db/index.txt
serial = $home/$db/serie_emitidos.txt
crlnumber = $home/$db/serie_revocados.txt

# Certificado y clave de la CA
certificate = $home/certificado-rootCA.crt
private_key = $home/$privado/rootCA.key
crl = $home/$db/rootCA.crl

# Fichero de aleatoriedad y copia de certificados emitidos
RANDFILE = $home/$privado/.rand
new_certs_dir = $home/certs

# Comportamiento de emisión
unique_subject = no
copy_extensions = none
default_days = 3650
default_crl_days = 300
default_md = sha256
policy = policy_c_o_match
```

| Directiva | Función |
| --- | --- |
| `home` | Directorio base. Si cambias de máquina, es la primera ruta que hay que ajustar. |
| `database` | `index.txt`: estado de cada certificado (válido, revocado, caducado). |
| `serial` | Siguiente número de serie de los certificados. |
| `crlnumber` | Siguiente número de CRL. |
| `certificate` | Certificado PEM de la CA. |
| `private_key` | Clave privada de la CA; debe estar en un directorio `700`. |
| `crl` | CRL por defecto que genera `openssl ca -gencrl`. |
| `RANDFILE` | Semilla de aleatoriedad (en sistemas modernos OpenSSL usa el RNG del sistema). |
| `new_certs_dir` | Copia `<serial>.pem` de cada certificado emitido. |
| `unique_subject` | `no` permite reutilizar el mismo *subject* (por ejemplo, al renovar). |
| `copy_extensions` | `copy` copia a la CSR extensiones como `subjectAltName`; `none` las ignora. |
| `default_days` | Validez por defecto del certificado emitido (3650 días). |
| `default_crl_days` | Validez por defecto de la CRL (300 días). |
| `default_md` | Hash de firma (SHA-256). |
| `policy` | Sección que decide qué campos del *subject* son obligatorios, opcionales o deben coincidir. |

La subCA cambia las rutas y el certificado:

```ini
[CA_default]
home = /home/user1/PKI_root/PKI_sub
database = $home/$db/index.txt
serial = $home/$db/serie_emitidos.txt
crlnumber = $home/$db/serie_revocados.txt
certificate = $home/certificado-subCA.crt
private_key = $home/privado/subCA.key
crl = $home/$db/subCA.crl
new_certs_dir = $home/certs
unique_subject = no
copy_extensions = copy      # la subCA sí copia el SAN de la CSR
default_days = 3650
default_crl_days = 300
default_md = sha256
policy = policy_c_o_match
```

!!! warning "`copy_extensions` y el SAN"
    La raíz usa `copy_extensions = none`; la subCA usa `copy`. Sin `copy` en la subCA, el `subjectAltName` pedido con `-addext` no llegaría al certificado final. Los navegadores exigen SAN; los certificados del laboratorio de `lab-certs` no lo tienen y por eso no sirven fuera del laboratorio.

## `[policy_c_o_match]`

La política se aplica **al emitir**: decide qué campos del *subject* de la CSR se aceptan.

```ini
# Raíz
[policy_c_o_match]
countryName = match
stateOrProvinceName = optional
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional
```

```ini
# SubCA: el correo es obligatorio
[policy_c_o_match]
countryName = match
stateOrProvinceName = optional
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = supplied
```

| Valor | Significado |
| --- | --- |
| `match` | Debe coincidir exactamente con el valor de la CA. |
| `supplied` | Debe venir en la CSR, pero puede ser distinto. |
| `optional` | Puede faltar. |

Consecuencias prácticas:

- `C` y `O` tienen que ser los mismos que los de la CA. Si faltan, `openssl ca` aborta con `The mandatory countryName field was missing`.
- La subCA exige `emailAddress`: `gen_solicitud.sh` pide `-e` para usuarios y servicios.
- `CN` siempre es obligatorio (`supplied`).

## `[req]`

Configuración de `openssl req` para generar la CSR de la CA.

```ini
[req]
default_bits = 2048
encrypt_key = yes
default_md = sha256
utf8 = yes
string_mask = utf8only
prompt = no
distinguished_name = ca_dn
```

| Directiva | Función |
| --- | --- |
| `default_bits` | Tamaño RSA por defecto. Los scripts del laboratorio usan 3072 explícitamente. |
| `encrypt_key` | Cifra la clave privada con passphrase. |
| `default_md` | Hash de la firma de la CSR. |
| `utf8` / `string_mask` | Codificación UTF-8 y máscara de caracteres permitidos. |
| `prompt = no` | No pregunta: toma el DN de `[ca_dn]`. |
| `distinguished_name` | Sección con el DN de la CA. |

## `[crl_info]` e `[issuer_info]`

Secciones referenciadas por las extensiones mediante `@`.

```ini
[crl_info]
URI.0 = $crl_url

[issuer_info]
caIssuers;URI.0 = $aia_url
OCSP;URI.0 = $ocsp_url
```

- `[crl_info]` se usa en `crlDistributionPoints`: indica dónde está la CRL.
- `[issuer_info]` se usa en `authorityInfoAccess`: dónde descargar el certificado del emisor (`caIssuers`) y dónde consultar el estado (`OCSP`).

## Extensiones

Cada sección se elige con `-extensions <nombre>` al ejecutar `openssl ca`. No todas existen en ambos ficheros.

### `ca_ext` — certificado autofirmado de la raíz

Solo en `ca-root_openssl.cnf`.

```ini
[ca_ext]
basicConstraints = critical,CA:true
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
```

- `CA:true`: puede firmar otros certificados.
- `keyUsage`: solo firma de certificados y de CRL.
- `subjectKeyIdentifier`: identifica la clave pública de la CA.

### `subca_ext` — certificado de la subCA

Solo en `ca-root_openssl.cnf`; lo usa la raíz para firmar a la subCA.

```ini
[subca_ext]
authorityInfoAccess = @issuer_info
authorityKeyIdentifier = keyid:always
basicConstraints = critical,CA:true,pathlen:0
crlDistributionPoints = @crl_info
extendedKeyUsage = clientAuth,serverAuth
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
```

- `CA:true, pathlen:0`: puede firmar certificados finales, pero **no** otras CAs.
- `authorityKeyIdentifier`: enlaza con la clave de la raíz.
- AIA y CRLDP apuntan a los servicios publicados.

### `server_ext` — servicios

Solo en `ca-sub_openssl.cnf`.

```ini
[server_ext]
authorityInfoAccess = @issuer_info
authorityKeyIdentifier = keyid:always
basicConstraints = critical,CA:false
crlDistributionPoints = @crl_info
extendedKeyUsage = clientAuth,serverAuth
keyUsage = critical,digitalSignature,keyEncipherment
subjectKeyIdentifier = hash
```

- `CA:false`: no puede firmar otros certificados.
- `keyUsage`: firma digital y cifrado de clave (RSA).
- `extendedKeyUsage`: válido para autenticación de servidor y de cliente.

### `user_ext` — usuarios

Solo en `ca-sub_openssl.cnf`.

```ini
[user_ext]
authorityInfoAccess = @issuer_info
authorityKeyIdentifier = keyid:always
basicConstraints = critical,CA:false
crlDistributionPoints = @crl_info
extendedKeyUsage = clientAuth
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
```

- Solo `clientAuth` y firma digital.
- `emitir_cert.sh` con `user_ext` exige la clave hermana de la CSR y genera además un PKCS#12.

### `ocsp_ext` — respondedor OCSP

Presente en ambos ficheros.

```ini
[ocsp_ext]
authorityKeyIdentifier = keyid:always
basicConstraints = critical,CA:false
extendedKeyUsage = OCSPSigning
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
```

- `OCSPSigning` es lo que autoriza al certificado a firmar respuestas OCSP.
- Sin esta extensión, el cliente rechaza las respuestas del respondedor.

## Resumen de diferencias raíz / subCA

| Aspecto | `ca-root_openssl.cnf` | `ca-sub_openssl.cnf` |
| --- | --- | --- |
| `name` / CN | `rootCA` / `bocata_jamon_rootCA` | `subCA` / `bocata_jamon_subCA` |
| `home` | `/home/user1/PKI_root` | `/home/user1/PKI_root/PKI_sub` |
| `copy_extensions` | `none` | `copy` |
| `emailAddress` en la política | `optional` | `supplied` |
| Extensiones de emisión | `ca_ext`, `subca_ext`, `ocsp_ext` | `server_ext`, `user_ext`, `ocsp_ext` |

## Gotchas

- **Rutas absolutas**: si mueves la CA, actualiza `home`; el resto de rutas usan `$home`. Ejecuta siempre `openssl ca -config <ruta>` con la configuración correcta.
- **`unique_subject`**: `no` permite renovar con el mismo *subject*, pero no borra los certificados antiguos; conviven en `index.txt`.
- **`copy_extensions`**: no copies a ciegas extensiones de una CSR no revisada; el administrador actúa como RA.
- **`default_bits = 2048`**: es el valor del fichero, pero los scripts piden 3072. No confundas el tamaño de la clave de la CA con el de los certificados emitidos.
- **CRL caducada**: `default_crl_days = 300`; si la CRL caduca, los clientes que la consultan pueden rechazar certificados válidos.
- **OCSP**: el responder necesita `ocsp_ext` y el cliente debe confiar en la cadena (`-CAfile`), no solo en el certificado del respondedor.

## Enlaces

- [OpenSSL y PKI](../tema1/comandos/openssl.md)
- [Scripts del laboratorio PKI](../tema1/lab-pki/scripts.md)
- [Guía del laboratorio PKI](../tema1/lab-pki/guia.md)
- [`ca-root_openssl.cnf`](../assets/config/ca-root_openssl.cnf)
- [`ca-sub_openssl.cnf`](../assets/config/ca-sub_openssl.cnf)
