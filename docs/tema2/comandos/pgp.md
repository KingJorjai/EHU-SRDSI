# PGP con GnuPG

OpenPGP combina cifrado híbrido, firmas y una *web of trust* para proteger correo y ficheros. GnuPG es la implementación práctica que se usa en el laboratorio. Esta página se centra en lo que añade el Tema 2: cifrar para varios receptores, interpretar los paquetes OpenPGP y firmar/verificar de forma aplicada.

!!! info "Lo básico está en el Tema 1"
    Para crear claves, cifrado simétrico, listar llaveros, revocación y keyservers, consulta [GnuPG (Tema 1)](../../tema1/comandos/gpg.md). Aquí se asume que ya sabes generar un par de claves y moverte por `gpg`.

[:material-file-pdf-box: Transparencias — SSH y PGP/S/MIME (PDF)](../../assets/pdf/SRDSI_T2-2.pdf#page=26){ .md-button }

## Versión y llavero aislado

```bash
gpg --version
```

Comprobado con **GnuPG 2.4.9**. Para no tocar el llavero real:

```bash
LABGPG=$(mktemp -d)
chmod 700 "$LABGPG"
export GNUPGHOME="$LABGPG"
```

Al terminar:

```bash
unset GNUPGHOME
rm -rf "$LABGPG"
```

Crear dos identidades de prueba sin passphrase (solo laboratorio):

```bash
gpg --batch --passphrase '' --quick-gen-key "Alice <alice@srdsi.lab>" default default never
gpg --batch --passphrase '' --quick-gen-key "Bob <bob@srdsi.lab>" default default never

gpg --list-keys --keyid-format long
gpg --list-keys --with-colons alice@srdsi.lab | awk -F: '/^fpr/{print $10; exit}'
```

```console
pub   ed25519/38D42227A9F4A988 2026-10-28 [SC]
uid           [ultimate] Alice <alice@srdsi.lab>
sub   cv25519/7BFEAC4EE24796CD 2026-10-28 [E]
```

La clave de firma/certificación es Ed25519 y la de cifrado es Curve25519. Para cifrar hace falta una subclave con uso `[E]`; una clave solo de firma no sirve.

## Cifrar para varios receptores

```bash
printf 'mensaje secreto\n' > mensaje.txt

gpg --encrypt --recipient alice@srdsi.lab --recipient bob@srdsi.lab \
  --output mensaje.gpg mensaje.txt

gpg --decrypt mensaje.gpg
```

Para evitar ambigüedades o búsquedas en keyservers, usa la **huella completa sin `!`**; así GnuPG selecciona esa clave y sus subclaves:

```bash
gpg --encrypt --recipient '4BB87FA4F60F878537F4555938A6762F94116780' \
  --recipient 'A857048B4734D9D0FAEC499AE93A1DDD9DF0C6D6' \
  --output mensaje.gpg mensaje.txt
```

!!! warning "El sufijo `!` fija la clave exacta"
    `-r 'huella!'` obliga a usar esa clave y **excluye sus subclaves**. Si la huella es la de la clave primaria (solo firma/certificación), GnuPG falla con `Unusable public key` al cifrar. Para cifrar, omite el `!` o usa la huella de la subclave de cifrado (`[E]`).

Opciones prácticas:

```bash
gpg -a -e -r alice@srdsi.lab mensaje.txt          # ASCII armor
gpg -e -r alice@srdsi.lab -o - mensaje.txt        # salida estándar
gpg -e -R alice@srdsi.lab mensaje.txt             # destinatario oculto
gpg -e --throw-keyids -r alice@srdsi.lab mensaje.txt
```

- `-e` / `--encrypt`; `-r` / `--recipient`; `-o` / `--output`.
- `-a` genera texto ASCII (`.asc`); sin `-a`, binario (`.gpg`).
- `-R` / `--hidden-recipient` oculta el key ID del destinatario en el paquete.
- `--throw-keyids` oculta todos los key IDs; el receptor prueba sus claves.
- Todos los destinatarios comparten la misma clave de sesión, pero cada uno recibe su propio paquete PKESK. El mensaje cifrado no se repite.

Descifrar:

```bash
gpg --decrypt mensaje.gpg
gpg -d -o mensaje.descifrado mensaje.gpg
```

## Interpretar paquetes con `--list-packets`

```bash
gpg --list-packets mensaje.gpg
```

Salida real de un cifrado para Alice y Bob:

```console
# off=0 ctb=84 tag=1 hlen=2 plen=94
:pubkey enc packet: version 3, algo 18, keyid 7BFEAC4EE24796CD
	data: [263 bits]
	data: [392 bits]
# off=96 ctb=84 tag=1 hlen=2 plen=94
:pubkey enc packet: version 3, algo 18, keyid A5757A7810654202
	data: [263 bits]
	data: [392 bits]
# off=192 ctb=d2 tag=18 hlen=2 plen=80 new-ctb
:encrypted data packet:
	length: 80
	mdc_method: 2
# off=213 ctb=a3 tag=8 hlen=1 plen=0 indeterminate
:compressed packet: algo=2
# off=215 ctb=ac tag=11 hlen=2 plen=27
:literal data packet:
	mode b (62), created 1793187803, name="m.txt",
	raw data: 16 bytes
```

Lectura:

1. **Dos paquetes `tag=1` (PKESK)**: uno por destinatario. Cada uno lleva la clave de sesión cifrada con la clave pública correspondiente (`keyid` distinto).
2. **`tag=18` (SEIPD)**: datos cifrados con integridad. `mdc_method: 2` indica que incluye el código de detección de modificaciones.
3. **`tag=8` (Compressed Data)**: el contenido se comprimió antes de cifrar.
4. **`tag=11` (Literal Data)**: el mensaje original, con nombre y fecha.

### Tabla de tags OpenPGP

| Tag | Paquete | Papel |
| --- | --- | --- |
| 1 | PKESK | Clave de sesión cifrada con clave pública (un paquete por receptor). |
| 2 | Signature | Firma de datos, clave o identidad. |
| 3 | SKESK | Clave de sesión cifrada con contraseña (cifrado simétrico). |
| 5 / 6 | Secret Key / Public Key | Clave privada o pública. |
| 7 / 14 | Secret Subkey / Public Subkey | Subclave privada o pública. |
| 8 | Compressed Data | Datos comprimidos. |
| 9 | Symmetrically Encrypted Data | Cifrado simétrico **sin integridad** (legacy). |
| 11 | Literal Data | Datos originales con nombre, modo y fecha. |
| 13 | User ID | Identidad asociada a la clave. |
| 18 | SEIPD | Cifrado simétrico con integridad (MDC o AEAD). |
| 19 | MDC | Código de detección de modificaciones, dentro de un `tag=18`. |

Aclaraciones importantes:

- **`tag=9` es el formato antiguo sin MDC**. GnuPG moderno no lo genera por defecto: usa `tag=18`, que añade integridad. Si ves `tag=9`, el mensaje es legacy y no tiene la misma protección.
- **`tag=19` no suele aparecer como paquete independiente** en `--list-packets`: va encapsulado en el `tag=18` y se resume como `mdc_method: 2`. No busques una línea `tag=19` en la salida.
- En cifrado simétrico (`gpg -c`) aparece un `tag=3` (SKESK) seguido de `tag=18`:

```console
# off=0 ctb=8c tag=3 hlen=2 plen=13
:symkey enc packet: version 4, cipher 9, aead 0, s2k 3, hash 10
# off=15 ctb=d2 tag=18 hlen=2 plen=68 new-ctb
:encrypted data packet:
	length: 68
	mdc_method: 2
```

`--list-packets` **no verifica** nada: solo describe la estructura. Para comprobar una firma, usa `--verify`.

## Firmar

### Firma adjunta

El mensaje y la firma viajan juntos en un mismo fichero:

```bash
gpg --sign mensaje.txt                 # binario: mensaje.txt.gpg
gpg --armor --sign mensaje.txt         # ASCII: mensaje.txt.asc
gpg --sign --output firmado.gpg mensaje.txt
```

### Firma en claro (`clearsign`)

El texto queda legible y la firma va delimitada:

```bash
gpg --clearsign mensaje.txt
```

```text
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

mensaje secreto
-----BEGIN PGP SIGNATURE-----
...
-----END PGP SIGNATURE-----
```

Útil para correo, documentación y comunicados: el contenido se puede leer sin GnuPG, pero la firma permite detectar modificaciones.

### Firma separada (`detach-sign`)

La firma es un fichero aparte; el mensaje no se modifica:

```bash
gpg --detach-sign mensaje.txt              # mensaje.txt.sig (binario)
gpg --armor --detach-sign mensaje.txt      # mensaje.txt.asc (ASCII)
gpg --detach-sign --output mensaje.sig mensaje.txt
```

Es el formato habitual para firmar software, PDFs o *commits*: distribuyes el fichero y su `.sig`.

### Firmar y cifrar

```bash
gpg --sign --encrypt --recipient alice@srdsi.lab mensaje.txt
gpg -se -r alice@srdsi.lab mensaje.txt
```

El orden es **firmar → comprimir → cifrar**. Al descifrar, GnuPG descomprime y verifica.

## Verificar

```bash
gpg --verify mensaje.txt.asc            # clearsign o firma adjunta
gpg --verify mensaje.txt.sig mensaje.txt  # firma separada: firma + datos
gpg --verify --status-fd 1 mensaje.txt.sig mensaje.txt
```

Salida esperada con una firma válida y clave de confianza:

```console
gpg: Good signature from "Alice <alice@srdsi.lab>" [ultimate]
```

Si modificas un solo byte:

```console
gpg: BAD signature from "Alice <alice@srdsi.lab>" [ultimate]
```

Códigos de estado útiles con `--status-fd`:

| Línea | Significado |
| --- | --- |
| `GOODSIG` | Firma criptográficamente válida. |
| `BADSIG` | Los datos no coinciden con la firma. |
| `ERRSIG` | No se pudo verificar (clave ausente, algoritmo, etc.). |
| `EXPKEYSIG` | Firma válida con clave caducada. |
| `REVKEYSIG` | Firma válida con clave revocada. |
| `TRUST_ULTIMATE`, `TRUST_FULLY` | Nivel de confianza en la clave. |

## Exportar e importar claves

```bash
# Clave pública (para que otros cifren o verifiquen)
gpg --armor --export alice@srdsi.lab > alice.pub

# Clave privada (¡secreto! solo para copia de seguridad)
gpg --armor --export-secret-keys alice@srdsi.lab > alice.sec

# Importar en otro llavero
export GNUPGHOME=$(mktemp -d); chmod 700 "$GNUPGHOME"
gpg --import alice.pub
gpg --list-keys
```

```console
gpg:               imported: 1
uid           [ unknown] Alice <alice@srdsi.lab>
```

La clave importada aparece como `[unknown]`: GnuPG no confía en ella solo porque esté en el llavero. Para cifrar sin configurar confianza (solo laboratorio):

```bash
gpg --trust-model always --encrypt -r alice@srdsi.lab mensaje.txt
```

Para una copia completa con confianza y revocaciones:

```bash
gpg --export-ownertrust > ownertrust.txt
gpg --import-ownertrust ownertrust.txt
```

No publiques `alice.sec` ni lo subas a un repositorio. Si necesitas transportarlo, cífralo con una passphrase robusta y guárdalo en un medio separado.

## Confianza y *web of trust*

```bash
gpg --edit-key alice@srdsi.lab
```

Dentro de la sesión interactiva:

```text
gpg> trust
  1 = I don't know or won't say
  2 = I do NOT trust
  3 = I trust marginally
  4 = I trust fully
  5 = I trust ultimately
gpg> save
```

También se puede firmar la clave de otra persona (certificación):

```bash
gpg --sign-key alice@srdsi.lab
```

- `ultimate` solo se usa para tus propias claves.
- `full` o `marginal` permiten que una firma cuente para la validez de otras claves según la configuración de confianza.
- La confianza no se deduce de que la clave esté en un keyserver: hay que verificarla por un canal independiente (huella, reunión, firma cruzada).

Para el detalle de la *web of trust* y los niveles de confianza, consulta [GnuPG del Tema 1](../../tema1/comandos/gpg.md#confianza-y-firma-de-claves-publicas).

## OpenPGP en el Tema 2: correo y S/MIME

PGP/OpenPGP y S/MIME resuelven el mismo problema con modelos distintos:

| Aspecto | OpenPGP (GnuPG) | S/MIME |
| --- | --- | --- |
| Confianza | *Web of trust* descentralizada. | PKI X.509 jerárquica. |
| Formato | Paquetes OpenPGP (RFC 4880/9580). | CMS/PKCS#7 sobre MIME. |
| Cliente | GnuPG, Thunderbird+Enigmail, Mailvelope. | Clientes de correo con certificado X.509. |
| Revocación | Certificado de revocación + keyservers. | CRL/OCSP de la CA. |
| Uso típico | Correo, ficheros, software, *commits*. | Correo corporativo, firma de documentos. |

En ambos casos, la firma garantiza integridad y autenticación, y el cifrado garantiza confidencialidad, pero **ninguno ofrece forward secrecy**: si se compromete la clave privada, se pueden descifrar mensajes antiguos.

## Flujo completo de laboratorio

```bash
# 1. Llavero aislado
LABGPG=$(mktemp -d); chmod 700 "$LABGPG"; export GNUPGHOME="$LABGPG"

# 2. Dos identidades
gpg --batch --passphrase '' --quick-gen-key "Alice <alice@srdsi.lab>" default default never
gpg --batch --passphrase '' --quick-gen-key "Bob <bob@srdsi.lab>" default default never

# 3. Huellas
ALICE=$(gpg --list-keys --with-colons alice@srdsi.lab | awk -F: '/^fpr/{print $10; exit}')
BOB=$(gpg --list-keys --with-colons bob@srdsi.lab | awk -F: '/^fpr/{print $10; exit}')

# 4. Cifrar para los dos y revisar paquetes
printf 'mensaje secreto\n' > mensaje.txt
gpg --trust-model always -e -r "$ALICE" -r "$BOB" -o mensaje.gpg mensaje.txt
gpg --list-packets mensaje.gpg

# 5. Descifrar
gpg -d mensaje.gpg

# 6. Firmar en claro y verificar
gpg --trust-model always --clearsign -o mensaje.asc mensaje.txt
gpg --verify mensaje.asc

# 7. Firma separada
gpg --trust-model always --detach-sign -o mensaje.sig mensaje.txt
gpg --verify mensaje.sig mensaje.txt

# 8. Limpiar
unset GNUPGHOME
rm -rf "$LABGPG" mensaje.txt mensaje.gpg mensaje.asc mensaje.sig
```

## Problemas frecuentes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `No secret key` al descifrar | El mensaje no es para esa clave o falta la privada. | Comprueba `--list-packets` y el llavero. |
| `public key not found` | Falta la clave pública del destinatario. | Impórtala con `gpg --import`. |
| `WARNING: This key is not certified with a trusted signature` | Firma válida pero clave sin confianza. | Firma la clave o ajusta el *trust*. |
| `INV_RECP` / `No encryption key` | La clave no tiene subclave de cifrado. | Añade una subclave `[E]`. |
| `BAD signature` | Datos modificados o fichero equivocado. | Verifica el par firma/datos correcto. |
| `gpg: cannot open /dev/tty` | Intento interactivo en un script. | `--batch --pinentry-mode loopback` o usa el agente. |
| No aparece `tag=19` | El MDC va dentro del `tag=18`. | Mira `mdc_method: 2`. |

## Enlaces

- [GnuPG: lo básico (Tema 1)](../../tema1/comandos/gpg.md)
- [PGP, OpenPGP y S/MIME (teoría)](../teoria/pgp-smime.md)
- [SSH y túneles](ssh.md)
- [Transparencias — SSH y PGP/S/MIME](../../assets/pdf/SRDSI_T2-2.pdf#page=26)
