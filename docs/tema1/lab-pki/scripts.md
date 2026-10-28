# Scripts del laboratorio PKI

Los tres scripts del laboratorio automatizan el ciclo de vida de los certificados de la subCA. Están en `Tema 1: Introducción a la seguridad informática/lab-pki/scripts/` y también se copian a `docs/assets/scripts/` al preparar el sitio.

| Script | Función | Salidas |
| --- | --- | --- |
| `gen_solicitud.sh` | Genera clave privada cifrada y CSR. | `clave-privada-<nombre>.key`, `solicitud-<nombre>.csr` |
| `emitir_cert.sh` | Firma una CSR revisada con la subCA. | `certificado-<nombre>.crt` y, con `user_ext`, `certificado-<nombre>.p12` |
| `revocar_cert.sh` | Marca un certificado como revocado. | Actualiza `index.txt`; la CRL se regenera aparte |

Para los comandos manuales equivalentes, consulta [OpenSSL y PKI](../comandos/openssl.md).

## Consideraciones comunes

- Requieren `bash` y `openssl` en el `PATH`. `gen_solicitud.sh` exige OpenSSL >= 1.1.1 por `-addext`; con LibreSSL u OpenSSL anterior aborta.
- Usan `set -euo pipefail`; cualquier error de `openssl` interrumpe el script.
- `gen_solicitud.sh` aplica `umask 077`: la clave y la CSR se crean en un directorio temporal y solo se mueven al destino si todo termina bien.
- Ningún script sobrescribe salidas existentes. `gen_solicitud.sh` solo lo hace con `-f`; `emitir_cert.sh` y `revocar_cert.sh` nunca.
- Las contraseñas se pasan por variables de entorno (`KEY_PASS`, `P12_PASS`, `CA_PASS`). Evita `-p`: queda en `ps` y en el historial.
- Las rutas por defecto apuntan a la VM (`/home/user1/...`). Se pueden cambiar con variables de entorno (`PKI_DIR`, `CONF_CA`, `CERTS_DIR`, `P12_DIR`) sin editar los scripts.

## `gen_solicitud.sh`

### Uso

```console
./gen_solicitud.sh -t {usuario|servicio} -n <nombre_comun> {-p <password> | KEY_PASS=<password>} [opciones]
```

### Opciones

| Opción | Significado |
| --- | --- |
| `-t` | Tipo: `usuario` o `servicio` (obligatorio). |
| `-n` | Common Name, CN (obligatorio). |
| `-p` | Contraseña de la clave. Alternativa a `KEY_PASS`; menos segura. |
| `-e` | Correo. Obligatorio para usuario y servicio. |
| `-d` | DNS separados por comas. Obligatorio para servicio. |
| `-b` | Bits RSA, entero >= 2048 (por defecto 3072). |
| `-C` | País ISO de 2 letras. Obligatorio para servicio; opcional para usuario. |
| `-S` / `-L` | Provincia / localidad (opcionales). |
| `-O` | Organización. Obligatoria para servicio; opcional para usuario. |
| `-U` | Unidad organizativa (opcional). |
| `-o` | Directorio de salida (por defecto `/home/user1/PKI_root/PKI_sub/solicitudes`). |
| `-f` | Sobrescribe clave y CSR existentes. **La clave anterior se pierde.** |
| `-h` | Muestra la ayuda y sale con código 0. |

### Variables de entorno

| Variable | Efecto |
| --- | --- |
| `KEY_PASS` | Contraseña de la clave privada. Obligatoria si no se usa `-p`; mínimo 4 caracteres. |

### Salidas

El nombre de fichero deriva del CN: espacios a `_` y solo se conservan `[A-Za-z0-9_.-]`.

```text
<OUTDIR>/clave-privada-<nombre>.key   # cifrada, modo 600
<OUTDIR>/solicitud-<nombre>.csr      # PKCS#10
```

La CSR incluye:

- **Usuario**: `subjectAltName=email:<correo>`, `keyUsage=critical,digitalSignature,keyEncipherment` y `extendedKeyUsage=clientAuth,emailProtection`.
- **Servicio**: `subjectAltName=DNS:<dns1>,DNS:<dns2>...`; el correo va solo en el `subject`.

Los usos finales del certificado los fija la CA con `server_ext`/`user_ext`, no la CSR.

### Códigos de salida

| Código | Situación |
| --- | --- |
| `0` | Éxito o `-h`. |
| `1` | Cualquier error de validación, argumentos u `openssl`. |

### Validaciones

- `-t` y `-n` presentes; `-t` es `usuario` o `servicio`.
- `usuario` exige `-e`; `servicio` exige `-d`, `-e`, `-C` y `-O`.
- Correo con formato válido; `-C` de dos letras (se pasa a mayúsculas).
- `-b` entero >= 2048.
- Contraseña presente y de al menos 4 caracteres.
- Nombres DNS válidos (admite comodín `*.ejemplo.com`).
- El CN debe producir un nombre de fichero no vacío.
- No sobrescribe sin `-f`.

### Errores típicos

| Mensaje | Causa |
| --- | --- |
| `falta la contraseña: use -p <password> o defina ... KEY_PASS` | No se definió `KEY_PASS` ni `-p`. |
| `para tipo 'servicio' se requiere -d dns` | Falta un campo obligatorio del servicio. |
| `email no válido: '...'` | Correo mal formado. |
| `ya existen ... use -f para sobrescribirlos` | La clave o la CSR ya están en el directorio. |
| `se necesita OpenSSL >= 1.1.1` | Versión de OpenSSL demasiado antigua. |

### Ejemplo: usuario Paco

```bash
KEY_PASS='Contraseña segura1234_' ~/PKI_scripts/gen_solicitud.sh \
  -t usuario -n "Paco Antonio Gutierrez" \
  -e paco@bocata-jamon.srdsi.lab -C ES -O "Bocata de Jamon" \
  -o ~/PKI_root/PKI_sub/solicitudes -f
```

Salida resumida:

```console
Generando solicitud para usuario: Paco Antonio Gutierrez
Solicitud generada correctamente:
   Clave privada: /home/user1/PKI_root/PKI_sub/solicitudes/clave-privada-Paco_Antonio_Gutierrez.key (cifrada, RSA 3072)
   CSR:           /home/user1/PKI_root/PKI_sub/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr
   Subject:       /C=ES/O=Bocata de Jamon/CN=Paco Antonio Gutierrez/emailAddress=paco@bocata-jamon.srdsi.lab
```

!!! warning "Usuario sin `C`/`O`"
    Para un usuario el script solo exige `-e`, pero la política de la subCA exige que `C` y `O` coincidan con los de la CA. Si se omiten, `emitir_cert.sh` falla con `The mandatory countryName field was missing`. En el ejemplo se pasan `-C ES -O "Bocata de Jamon"`.

### Ejemplo: servicio OCSP

```bash
KEY_PASS='user1Sub_CA_ocsp' ~/PKI_scripts/gen_solicitud.sh \
  -t servicio -n "ocsp" -d ocsp.bocata-jamon.srdsi.lab \
  -e ocsp@bocata-jamon.srdsi.lab -C ES -S GP -L Donostia \
  -O "Bocata de Jamon" -U PKI -o ~/PKI_root/PKI_sub/ocsp
```

Genera `clave-privada-ocsp.bocata-jamon.srdsi.lab.key` y `solicitud-ocsp.bocata-jamon.srdsi.lab.csr` en `PKI_sub/ocsp/`. La clave se mueve después a `private/` antes de arrancar el respondedor.

## `emitir_cert.sh`

### Uso

```console
./emitir_cert.sh <solicitud.csr> {server_ext|user_ext|ocsp_ext}
```

El script **no valida la CSR**: asume la revisión manual del administrador (RA). Solo comprueba que la sección de extensión exista en la configuración de la subCA.

| Extensión | Uso | Resultado |
| --- | --- | --- |
| `server_ext` | Servicios | Solo `.crt`; la clave la conserva el solicitante. |
| `user_ext` | Usuarios | `.crt` + `.p12` con certificado y clave. |
| `ocsp_ext` | Respondedor OCSP | Solo `.crt` con `OCSPSigning`. |

### Variables de entorno

| Variable | Efecto |
| --- | --- |
| `KEY_PASS` | Contraseña de la clave privada. Obligatoria solo con `user_ext`. |
| `P12_PASS` | Contraseña del PKCS#12 (por defecto, `KEY_PASS`). Solo `user_ext`. |
| `PKI_DIR` | Directorio de la subCA (por defecto `/home/user1/PKI_root/PKI_sub`). |
| `CONF_CA` | Configuración de la CA (por defecto `$PKI_DIR/ca-sub_openssl.cnf`). |
| `CERTS_DIR` | Directorio de salida de los `.crt` (por defecto `$PKI_DIR/certs`). |
| `P12_DIR` | Directorio de salida de los `.p12` (por defecto `$PKI_DIR/certs.p12`). |
| `CA_PASS` | Contraseña de la CA. Si no se define, `openssl` la pide por terminal. |

### Salidas

```text
<CERTS_DIR>/certificado-<nombre>.crt
<P12_DIR>/certificado-<nombre>.p12     # solo user_ext, modo 600
```

`<nombre>` es el nombre de la CSR sin `solicitud-` ni `.csr`.

### Códigos de salida

| Código | Situación |
| --- | --- |
| `0` | Certificado emitido (y PKCS#12 creado si aplica). |
| `1` | CSR o clave ilegible, `KEY_PASS` ausente o clave que no corresponde a la CSR. |
| `2` | Extensión no válida o sección `[ext]` ausente en la configuración. |
| `3` | Configuración/directorio incorrecto, `openssl` ausente o salida ya existente. |
| `4` | El `.crt` se emitió, pero falló la creación del `.p12` (el `.crt` se conserva). |

### Validaciones

- La CSR existe y la configuración y los directorios son legibles/escribibles.
- La extensión pertenece a `server_ext`, `user_ext` u `ocsp_ext` y su sección existe en el `.cnf`.
- Con `user_ext`: existe `clave-privada-<nombre>.key` junto a la CSR, `KEY_PASS` está definida y la clave pública de la clave coincide con la de la CSR.
- No sobrescribe un `.crt` o `.p12` existente.
- Antes de firmar valida todo lo necesario para el `.p12`, de modo que un fallo de empaquetado no deje un certificado emitido a medias. Si `openssl ca` falla antes de emitir, se borra el `.crt` parcial.

### Errores típicos

| Mensaje | Causa |
| --- | --- |
| `falta la contraseña de la clave privada: defina KEY_PASS` | `user_ext` sin `KEY_PASS`. |
| `no existe la clave privada '...' (debe estar junto a la solicitud)` | La clave no acompaña a la CSR o el nombre no coincide. |
| `la clave privada '...' no corresponde a la solicitud` | Se cruzaron clave y CSR. |
| `ya existe ...; no se sobrescribe` | El certificado o el `.p12` ya se emitieron. |
| `la sección [x] no está definida` | La extensión no está en `ca-sub_openssl.cnf`. |
| `The mandatory countryName field was missing` | La CSR no lleva `C`/`O` que exige la política. |
| `TXT_DB error number 2` | Ya existe una entrada con ese `subject` y `unique_subject` está activo. |

### Ejemplo: emitir a Paco con PKCS#12

```bash
CA_PASS='user1Sub_CA' ~/PKI_scripts/emitir_cert.sh \
  ~/PKI_root/PKI_sub/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr user_ext
```

Salida resumida:

```console
Check that the request matches the signature
Signature ok
Certificate is to be certified until Oct  7 12:54:39 2036 GMT (3650 days)
Write out database with 1 new entries
Database updated
Certificado emitido: /home/user1/PKI_root/PKI_sub/certs/certificado-Paco_Antonio_Gutierrez.crt
PKCS#12 generado:    /home/user1/PKI_root/PKI_sub/certs.p12/certificado-Paco_Antonio_Gutierrez.p12
```

`CA_PASS` evita que `openssl ca` pida la contraseña por terminal. `P12_PASS` toma el valor de `KEY_PASS` si no se define.

### Ejemplo: emitir el certificado OCSP

```bash
CA_PASS='user1Sub_CA' ~/PKI_scripts/emitir_cert.sh \
  ~/PKI_root/PKI_sub/ocsp/solicitud-ocsp.bocata-jamon.srdsi.lab.csr ocsp_ext
```

Salida resumida:

```console
Certificate is to be certified until Oct  7 12:55:12 2036 GMT (3650 days)
Write out database with 1 new entries
Database updated
Certificado emitido: /home/user1/PKI_root/PKI_sub/certs/certificado-ocsp.bocata-jamon.srdsi.lab.crt
Entregar al solicitante solo el certificado (no se genera PKCS#12 para ocsp_ext).
```

## `revocar_cert.sh`

### Uso

```console
./revocar_cert.sh <certificado.crt> [motivo]
```

| Motivo | Uso |
| --- | --- |
| `unspecified` | Por defecto; sin motivo concreto. |
| `keyCompromise` | Compromiso de la clave privada. |
| `CACompromise` | Compromiso de la CA. |
| `affiliationChanged` | Cambio de afiliación. |
| `superseded` | Sustituido por otro certificado. |
| `cessationOfOperation` | Cese de la operación. |
| `certificateHold` | Suspensión temporal. |

### Variables de entorno

| Variable | Efecto |
| --- | --- |
| `CONF_CA` | Configuración de la subCA (por defecto `/home/user1/PKI_root/PKI_sub/ca-sub_openssl.cnf`). |
| `CA_PASS` | Contraseña de la CA. Si no se define, `openssl` la pide por terminal. |

### Funcionamiento

Antes de revocar, el script lee el serial del certificado y consulta su estado con `openssl ca -status <serial>` (solo lectura). Así evita que `openssl ca -revoke` añada una entrada espuria a `index.txt` si el serial no existe o ya está revocado. La revocación solo actualiza `index.txt`; hay que regenerar y publicar la CRL.

```bash
openssl ca -gencrl -batch -config ~/PKI_root/PKI_sub/ca-sub_openssl.cnf \
  -passin env:CA_PASS -out ~/PKI_root/PKI_sub/DB/crl-sub.pem
```

### Códigos de salida

| Código | Situación |
| --- | --- |
| `0` | Certificado revocado. |
| `1` | Argumentos incorrectos, certificado inexistente o no es un X.509 PEM legible. |
| `2` | Motivo no válido. |
| `3` | Configuración incorrecta, `openssl` ausente, certificado ya revocado o serial ausente en la base de datos. |

### Validaciones

- El `.crt` existe y `openssl x509` puede leerlo.
- El motivo pertenece a la lista admitida.
- El serial está en `index.txt` y su estado es `Valid (V)` o `Expired (E)`. Si ya está `Revoked (R)`, aborta.
- Si el estado no se puede consultar, aborta en lugar de arriesgarse a ensuciar la base de datos.

### Errores típicos

| Mensaje | Causa |
| --- | --- |
| `motivo '...' no válido` | Motivo fuera de la lista. |
| `'...' no es un certificado X.509 válido en formato PEM` | Ruta incorrecta o fichero corrupto. |
| `el certificado (serial ...) ya está revocado` | Se intentó revocar dos veces. |
| `el serial ... no figura en la base de datos de esta CA` | El certificado lo emitió otra CA o `index.txt` no es el correcto. |

### Ejemplo: revocar a Paco y publicar la CRL

```bash
~/PKI_scripts/revocar_cert.sh \
  ~/PKI_root/PKI_sub/certs/*Paco*.crt cessationOfOperation

openssl ca -gencrl -config ~/PKI_root/PKI_sub/ca-sub_openssl.cnf \
  -passin env:CA_PASS -out ~/PKI_root/PKI_sub/DB/crl-sub.pem
```

Salida resumida:

```console
Revocando certificado (motivo: cessationOfOperation):
   serial=C42D6FD8EADFACE74B94C31BE0EC7AB6
   subject=C=ES, O=Bocata de Jamon, CN=Paco Antonio Gutierrez, emailAddress=paco@bocata-jamon.srdsi.lab
Revoking Certificate C42D6FD8EADFACE74B94C31BE0EC7AB6.
Database updated
Certificado revocado: /home/user1/PKI_root/PKI_sub/certs/certificado-Paco_Antonio_Gutierrez.crt
Recuerda regenerar y publicar la CRL (openssl ca -gencrl).
```

## Flujo completo

```bash
# 1. CSR de usuario
KEY_PASS='...' gen_solicitud.sh -t usuario -n "Nombre Apellido" -e ... -C ES -O "Bocata de Jamon"

# 2. Revisión manual de la CSR (RA)
openssl req -in solicitud-Nombre_Apellido.csr -noout -subject -verify

# 3. Emisión (y PKCS#12 para usuario)
CA_PASS='...' emitir_cert.sh solicitud-Nombre_Apellido.csr user_ext

# 4. Revocación y CRL
revocar_cert.sh certificado-Nombre_Apellido.crt cessationOfOperation
openssl ca -gencrl -config ca-sub_openssl.cnf -passin env:CA_PASS -out DB/crl-sub.pem
```

Los comandos manuales equivalentes y la verificación de la cadena están en [OpenSSL y PKI](../comandos/openssl.md).
