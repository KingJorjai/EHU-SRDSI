# GnuPG

GnuPG implementa OpenPGP: cifrado simétrico y asimétrico, gestión de claves, firmas digitales y confianza distribuida (*web of trust*). Esta página recoge los comandos de las actividades de los bloques de confidencialidad, integridad y firma.

[:material-file-pdf-box: Transparencias — Comunicación segura (PDF)](../../assets/pdf/SRDSI_T1-3.pdf){ .md-button }
[:material-file-pdf-box: Transparencias — Gestión de claves (PDF)](../../assets/pdf/SRDSI_T1-4.pdf){ .md-button }

!!! note "Versiones"
    Comandos comprobados con **GnuPG 2.4.9** y `libgcrypt 1.12.4`. Las claves de los ejemplos son de usar y tirar.

## Trabajar en un llavero aislado

Para probar sin tocar el llavero real, crea un `GNUPGHOME` temporal con permisos `700`:

```bash
LABGPG=$(mktemp -d)
chmod 700 "$LABGPG"
export GNUPGHOME="$LABGPG"
```

Todo lo que hagas en esa shell queda en el directorio temporal. Para volver al llavero normal:

```bash
unset GNUPGHOME
```

También puedes usar `gpg --homedir "$LABGPG"` en cada comando. Si `GNUPGHOME` no tiene permisos `700`, GnuPG avisa y puede rechazar la operación.

## Versión y algoritmos

```bash
gpg --version
```

La salida muestra la versión, el *home* del llavero y las listas de **algoritmos de clave pública**, **cifrados**, **hashes** y **compresión** disponibles. En GnuPG 2.4 aparecen, entre otros, RSA/ElGamal/ECDSA/EdDSA, AES/AES256, SHA-2/SHA-3, BLAKE2 y ZIP/ZLIB/BZIP2. La lista exacta depende de `libgcrypt` y de la compilación.

```console
gpg (GnuPG) 2.4.9
libgcrypt 1.12.4
Home: /tmp/.../gnupg
Supported algorithms:
Pubkey: RSA, ELG, DSA, ECDH, ECDSA, EDDSA
Cipher: IDEA, 3DES, CAST5, BLOWFISH, AES, AES192, AES256, TWOFISH,
        CAMELLIA128, CAMELLIA192, CAMELLIA256
Hash: SHA1, RIPEMD160, SHA256, SHA384, SHA512, SHA224
Compression: Uncompressed, ZIP, ZLIB, BZIP2
```

## Cifrado simétrico

Una sola contraseña cifra y descifra. GnuPG deriva la clave de la contraseña y añade integridad.

```bash
gpg --symmetric --cipher-algo AES256 mensaje.txt
gpg --symmetric --cipher-algo AES256 -a -v mensaje.txt   # texto ASCII y verbose
gpg --decrypt mensaje.txt.gpg
```

- `--symmetric` (o `-c`) pide la contraseña por terminal.
- `-a` / `--armor` genera ASCII en lugar de binario (`.asc`).
- El descifrado detecta si el fichero ha sido manipulado.

Para scripts, sin interacción:

```bash
gpg --batch --yes --passphrase 'Passw0rd!' --symmetric --cipher-algo AES256 mensaje.txt
gpg --batch --yes --passphrase 'Passw0rd!' --decrypt mensaje.txt.gpg
```

!!! warning "Contraseña en la línea de comandos"
    `--passphrase` queda visible en el historial y en la lista de procesos. Para uso real, deja que GnuPG pregunte o usa `--pinentry-mode loopback` con un fichero/agente adecuado. En los ejemplos se usa solo para pruebas reproducibles.

## Cifrado asimétrico

### Generar un par de claves

Modo interactivo (pregunta tipo de clave, tamaño, validez, nombre y correo):

```bash
gpg --full-generate-key
# equivalente abreviado:
gpg --gen-key
```

Modo no interactivo para pruebas:

```bash
gpg --batch --passphrase '' --quick-generate-key \
  'Alice Test <alice@example.test>' rsa3072 default 1d
```

`default` crea una clave primaria de certificación y firma, **sin subclave de cifrado**. Si intentas cifrar verás `Unusable public key` (comprobado). Añade una subclave de cifrado:

```bash
FPR=$(gpg --with-colons --list-keys alice@example.test |
      awk -F: '/^fpr/{print $10; exit}')

gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-add-key "$FPR" rsa3072 encr 1d
```

Sin `--batch`, `--quick-generate-key` también funciona y pide la contraseña por terminal.

### Listar claves

```bash
gpg -k                    # claves públicas (--list-keys)
gpg -K                    # claves privadas (--list-secret-keys)
gpg --fingerprint         # huellas completas
gpg -k --keyid-format=long
gpg --with-colons -k      # formato estable para scripts
```

En la salida, `pub` es la clave pública y `sub` una subclave; `[SC]` indica certificación/firma, `[E]` cifrado y `[A]` autenticación. La **huella** (*fingerprint*) es el identificador que hay que validar por un canal seguro.

### Cifrar y descifrar

```bash
# Cifrar para el destinatario (busca su clave pública)
gpg --recipient alice@example.test --encrypt mensaje.txt

# Forzar una clave concreta (evita búsquedas WKD/keyserver)
gpg --recipient "${FPR}!" --encrypt -o mensaje.txt.gpg mensaje.txt

gpg --decrypt mensaje.txt.gpg
```

`--encrypt` (o `-e`) usa la subclave de cifrado del destinatario. El criptograma solo lo puede abrir él con su clave privada.

## Exportar, importar y hacer copia de seguridad

```bash
# Clave pública en ASCII
gpg -a --output publica.asc --export "$FPR"

# Clave privada (¡contiene el secreto!) en ASCII
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
  --armor --output privada.asc --export-secret-keys "$FPR"

# Importar en otro llavero
GNUPGHOME="$OTRO_HOME" gpg --import publica.asc
```

- `--export` exporta solo claves públicas.
- `--export-secret-keys` exporta la clave privada y las subclaves; pide la contraseña si la tiene. El fichero resultante debe guardarse cifrado y con permisos `600`.
- `--export-secret-subkeys` es una alternativa para copias de seguridad que no incluyen la clave primaria.
- La copia de seguridad debe incluir también el **certificado de revocación** (ver abajo).

## Revocación

Al crear una clave, GnuPG guarda un certificado de revocación en `openpgp-revocs.d/<huella>.rev`. Consérvalo *offline*: si pierdes la clave privada o se compromete, es lo que permite anunciar la revocación.

Generar otro certificado de revocación de forma interactiva (necesita terminal):

```bash
gpg --output revocacion.asc --gen-revoke "$FPR"
```

El diálogo pide confirmación, el motivo (0 = sin motivo, 1 = clave comprometida, 2 = reemplazada, 3 = ya no se usa) y una descripción. Después:

```bash
gpg --import revocacion.asc        # aplica la revocación en tu llavero
gpg --keyserver hkps://keys.openpgp.org --send-keys "$FPR"
```

!!! danger "La revocación es irreversible"
    Una vez importado y distribuido el certificado, la clave queda marcada como revocada para siempre. No lo importes por error en el llavero real.

## Confianza y firma de claves públicas

En OpenPGP no hay una CA central: cada usuario decide en quién confía. La **validez** de una clave depende de las firmas que tenga; la **confianza** (*trust*) es la opinión sobre su propietario.

Interactivo:

```bash
gpg --edit-key "$FPR"
gpg> trust          # 1 desconocido, 2 nunca, 3 marginal, 4 plena, 5 ultimate
gpg> sign           # firma la clave con tu clave
gpg> save
```

No interactivo (útil en laboratorio):

```bash
# Firmar la clave de Bob con la clave de Alice
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
  --local-user "$ALICE_FPR" --quick-sign-key "$BOB_FPR"

# Asignar confianza plena (4) o ultimate (6) al propietario
printf '%s:4:\n' "$BOB_FPR" | gpg --import-ownertrust
```

Niveles de confianza en `--import-ownertrust`: `2` nunca, `3` marginal, `4` plena y `6` ultimate (el `5` del menú de `--edit-key` no se usa en este formato). La validez de una clave se calcula combinando firmas y niveles de confianza; por eso una firma correcta de una clave no confiable puede mostrarse con un aviso.

### Keyservers

```bash
gpg --keyserver hkps://keys.openpgp.org --send-keys "$FPR"
gpg --keyserver hkps://keys.openpgp.org --search-keys alice@example.test
gpg --keyserver hkps://keys.openpgp.org --recv-keys "$FPR"
```

`hkps://` usa HKP sobre TLS. El servidor y la red pueden no estar disponibles; `keys.openpgp.org` exige verificar el correo para publicar el UID. En el laboratorio, la distribución por fichero (`--export`/`--import`) es más reproducible.

## Integridad y firma digital

### Resúmenes con GnuPG

```bash
gpg --print-mds mensaje.txt
```

Muestra MD5, SHA1, RMD160, SHA224, SHA256, SHA384 y SHA512 del fichero. Sirve para comparar con `md5sum`, `sha256sum`, etc. (ver [Hashes e integridad](hash.md)).

### Firmar

```bash
# Mensaje + firma en texto claro (clearsign)
gpg --clearsign mensaje.txt

# Firma separada, en ASCII
gpg --detach-sign -a mensaje.txt

# Mensaje + firma en un fichero binario
gpg --sign mensaje.txt

# Mensaje cifrado + firmado
gpg --sign --encrypt --recipient "${FPR}!" mensaje.txt
```

`--clearsign` deja el mensaje legible y añade un bloque `-----BEGIN PGP SIGNED MESSAGE-----`. `--detach-sign` genera `mensaje.txt.asc` (o `.sig` sin `-a`) y deja el mensaje intacto. `--sign` produce un fichero binario `.gpg`.

### Verificar

```bash
gpg --verify mensaje.txt.asc              # clearsign
gpg --verify mensaje.txt.asc mensaje.txt  # firma separada: firma + datos
gpg --decrypt mensaje.txt.gpg             # descifra y verifica si va firmado
```

Salida correcta (resumida):

```console
gpg: Good signature from "Alice Test <alice@example.test>" [ultimate]
```

Si el fichero se modifica después de firmar, la verificación falla:

```console
gpg: BAD signature from "Alice Test <alice@example.test>" [ultimate]
```

Comprobado modificando un carácter del mensaje firmado.

### Inspeccionar paquetes OpenPGP

```bash
gpg --list-packets mensaje.txt.asc
gpg --list-packets mensaje.txt.gpg
```

Muestra las etiquetas (*tags*) OpenPGP: paquete de firma, algoritmo de clave, algoritmo de *digest*, identificador del firmante, etc. **No verifica** la firma; solo parsea la estructura. Para saber si es válida, usa `--verify`.

## Actividades del curso

- [Confidencialidad: cifrado simétrico y asimétrico (T1-3, p. 9)](../../assets/pdf/SRDSI_T1-3.pdf#page=9)
- [Integridad: resúmenes con `md5sum` y `gpg --print-mds` (T1-3, p. 13)](../../assets/pdf/SRDSI_T1-3.pdf#page=13)
- [Firma digital: clearsign, detach-sign y verify (T1-3, p. 24)](../../assets/pdf/SRDSI_T1-3.pdf#page=24)
- [Gestión de claves: exportar, importar, keyserver, revocar y firmar claves (T1-4, p. 34)](../../assets/pdf/SRDSI_T1-4.pdf#page=34)
- [Ejercicios de confianza y web of trust (T1-4, p. 39)](../../assets/pdf/SRDSI_T1-4.pdf#page=39)

## Gotchas

- **Contraseña y agente**: sin `--batch`, GnuPG usa `pinentry` y el agente. En scripts, `--batch --pinentry-mode loopback --passphrase '...'` evita el diálogo, pero expone la contraseña; en producción usa el agente.
- **Clave sin subclave de cifrado**: `--quick-generate-key ... default` crea solo firma/certificación. Añade `encr` o elige un uso que incluya cifrado.
- **Destinatario ambiguo**: un correo puede coincidir con varias claves o provocar búsquedas WKD. Usa la huella con `!` para forzar la clave exacta.
- **Confianza**: una firma puede ser criptográficamente correcta y aun así mostrar un aviso si la clave no es de confianza. Firma la clave y asigna *trust* antes de sacar conclusiones.
- **`--list-packets` no es `--verify`**: el primero describe paquetes; el segundo comprueba la firma.
- **Revocación**: `--gen-revoke` requiere terminal; no funciona en modo `--batch`. Guarda el `.rev` en un medio separado.
- **Copia de la clave privada**: `--export-secret-keys` genera un fichero con el secreto. Cifra el backup y no lo subas a un repositorio.
- **Llavero temporal**: si olvidas `unset GNUPGHOME`, los comandos siguientes siguen usando el llavero de pruebas.

## Enlaces

- [GnuPG: actividades del Tema 1](../actividades/gnupg.md)
- [Gestión de claves y PKI (teoría)](../teoria/gestion-claves.md)
- [Hashes e integridad](hash.md)
- [Transparencias — Comunicación segura](../../assets/pdf/SRDSI_T1-3.pdf)
- [Transparencias — Gestión de claves](../../assets/pdf/SRDSI_T1-4.pdf)
