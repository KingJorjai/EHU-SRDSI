# Actividades: GnuPG

[:material-file-pdf-box: Transparencias — Comunicación segura (PDF)](../../assets/pdf/SRDSI_T1-3.pdf){ .md-button }
[:material-file-pdf-box: Transparencias — Gestión de claves (PDF)](../../assets/pdf/SRDSI_T1-4.pdf){ .md-button }

Esta página resuelve las actividades de **confidencialidad, integridad, firma digital y gestión de claves** de T1-3 (pp. 9–14 y 24–28) y T1-4 (pp. 34–39). Los comandos están comprobados con **GnuPG 2.4.9** y `libgcrypt 1.12.4` en Debian 13.

!!! note "Qué se ha ejecutado"
    Todas las pruebas se hicieron en llaveros temporales con `GNUPGHOME=$(mktemp -d)`. No se tocó el llavero real. Las claves, huellas y tiempos son de una ejecución concreta: sirven para interpretar la salida, no como valores fijos.

## Preparar un llavero de laboratorio

```bash
export GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"
echo "$GNUPGHOME"
```

Todo lo que se ejecute en esa shell usa ese directorio. Al terminar:

```bash
gpgconf --kill gpg-agent
rm -rf "$GNUPGHOME"
unset GNUPGHOME
```

Para usar el llavero real (`~/.gnupg`), abre otra shell sin `GNUPGHOME` o ejecuta `unset GNUPGHOME`. No importes las claves de laboratorio en el llavero real.

También se puede usar `gpg --homedir /ruta/llavero` en cada comando. Si el directorio no tiene permisos `700`, GnuPG avisa y puede rechazar la operación.

## 1. Confidencialidad (T1-3, pp. 9–12)

### 1.1 Comprobar algoritmos

```bash
gpg --version
```

Salida resumida:

```console
gpg (GnuPG) 2.4.9
libgcrypt 1.12.4
Home: /tmp/tmp.XXXXXXXXXX
Supported algorithms:
Pubkey: RSA, ELG, DSA, ECDH, ECDSA, EDDSA
Cipher: IDEA, 3DES, CAST5, BLOWFISH, AES, AES192, AES256, TWOFISH,
        CAMELLIA128, CAMELLIA192, CAMELLIA256
Hash: SHA1, RIPEMD160, SHA256, SHA384, SHA512, SHA224
Compression: Uncompressed, ZIP, ZLIB, BZIP2
```

- **Pubkey**: algoritmos de clave pública. RSA y ECDSA/EdDSA son los habituales hoy; ELG y DSA se mantienen por compatibilidad.
- **Cipher**: cifrados simétricos. Para uso nuevo, AES256 o, si el entorno lo soporta, ChaCha20 (no aparece en esta compilación de GnuPG).
- **Hash**: resúmenes para firmas y verificación. SHA-256 o superior; SHA-1 solo por compatibilidad.
- **Compression**: compresión previa al cifrado. Por defecto GnuPG comprime; para comparar tamaños se puede usar `--compress-algo none`.

### 1.2 Cifrado simétrico y descifrado

```bash
printf 'Mensaje secreto de prueba.\n' > mensaje.txt

gpg --symmetric --cipher-algo AES256 mensaje.txt
# equivale a: gpg -c --cipher-algo AES256 mensaje.txt

gpg --decrypt mensaje.txt.gpg
```

Salida esperada (resumida):

```console
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase
Mensaje secreto de prueba.
```

`--symmetric` pide una contraseña, deriva una clave con una función de derivación (S2K) y cifra. El descifrado detecta modificaciones porque GnuPG añade un código de integridad (MDC).

Opciones útiles:

```bash
gpg --symmetric --cipher-algo AES256 -a mensaje.txt   # salida ASCII (.asc)
gpg --symmetric --cipher-algo AES256 -v mensaje.txt   # verbose
gpg --output otro-nombre.gpg --symmetric mensaje.txt
```

Para scripts, sin interacción (solo laboratorio):

```bash
gpg --batch --yes --pinentry-mode loopback \
    --passphrase 'clave-de-prueba' \
    --symmetric --cipher-algo AES256 mensaje.txt

gpg --batch --yes --pinentry-mode loopback \
    --passphrase 'clave-de-prueba' --decrypt mensaje.txt.gpg
```

!!! warning "Contraseña en la línea de comandos"
    `--passphrase` queda en el historial y en la lista de procesos. En uso real, deja que GnuPG pregunte por terminal o usa el agente/pinentry. En esta página se usa solo para que los ejemplos sean reproducibles.

### 1.3 Generar claves asimétricas

Modo interactivo:

```bash
gpg --full-generate-key
# o la forma abreviada:
gpg --gen-key
```

GnuPG pregunta el tipo de clave, tamaño, caducidad, nombre, correo y contraseña. Una elección razonable para el laboratorio es **RSA y RSA** de 3072 bits, caducidad de 1 año y una contraseña fuerte.

Modo no interactivo para pruebas:

```bash
gpg --batch --passphrase '' --pinentry-mode loopback --gen-key <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: Alice Ejemplo
Name-Email: alice@example.test
Expire-Date: 1y
%commit
EOF
```

`%no-protection` crea la clave **sin contraseña**. Es cómodo en un llavero temporal, pero no debe usarse para claves reales.

!!! tip "`--quick-generate-key` y la subclave de cifrado"
    `gpg --quick-generate-key 'Alice <alice@example.test>' rsa3072 default 1y` crea una clave primaria de firma/certificación **sin subclave de cifrado**. Si se intenta cifrar con ella, GnuPG responde `Unusable public key`. Añade la subclave con:

    ```bash
    FPR=$(gpg --with-colons --list-keys alice@example.test |
          awk -F: '/^fpr/{print $10; exit}')
    gpg --batch --pinentry-mode loopback --passphrase '' \
        --quick-add-key "$FPR" rsa3072 encr 1y
    ```

### 1.4 Listar claves

```bash
gpg --list-keys          # gpg -k
gpg --list-secret-keys   # gpg -K
gpg --fingerprint
gpg --fingerprint --with-subkey-fingerprint
```

Salida de ejemplo:

```console
/home/alice/.gnupg/pubring.kbx
-----------------------------
pub   rsa2048/A450923588B2DE76 2026-10-28 [SCEAR] [expires: 2027-10-28]
      A9FFF77D26E8A9136308F565A450923588B2DE76
uid                 [ultimate] Alice Ejemplo <alice@example.test>
sub   rsa2048/A63D3EA372EB917F 2026-10-28 [SEA] [expires: 2027-10-28]
```

- `pub` es la clave pública primaria; `sub`, una subclave.
- `[SCEAR]` resume las capacidades de la clave: **S**ign (firma), **C**ertify (certificación), **E**ncrypt (cifrado), **A**uthenticate (autenticación) y **R**evoke (revocable). En la práctica, la primaria suele ser `SC` y la subclave `E`.
- `[ultimate]` significa que esa clave es la del propietario del llavero; no es una valoración de terceros.
- La **huella** (*fingerprint*) es el identificador que hay que comparar por un canal seguro antes de confiar en una clave.

### 1.5 Cifrar y descifrar con clave pública

```bash
FPR=$(gpg --with-colons --list-keys alice@example.test |
      awk -F: '/^fpr/{print $10; exit}')

gpg --recipient "$FPR" --encrypt --output mensaje-pub.gpg mensaje.txt
gpg --decrypt mensaje-pub.gpg
```

Salida esperada:

```console
gpg: encrypted with rsa2048 key, ID A63D3EA372EB917F, created 2026-10-28
      "Alice Ejemplo <alice@example.test>"
Mensaje secreto de prueba.
```

El criptograma solo lo puede abrir Alice con su clave privada. La clave pública sirve para cifrar; la privada, para descifrar y firmar.

Si la clave del destinatario no está firmada ni tiene confianza asignada, GnuPG puede avisar de que no hay garantía de que pertenezca a esa persona. En el laboratorio se puede forzar con `--trust-model always`, pero **no es una buena práctica** en producción: primero hay que verificar la huella y firmar/confiar en la clave.

### 1.6 Copia de seguridad de la clave privada

```bash
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --armor --output privada-alice.asc --export-secret-key "$FPR"

ls -l privada-alice.asc
grep -c 'BEGIN PGP PRIVATE KEY BLOCK' privada-alice.asc
```

Salida esperada:

```console
-rw------- 1 alice alice 3949 ... privada-alice.asc
1
```

Restauración en otro llavero:

```bash
OTRO=$(mktemp -d); chmod 700 "$OTRO"
GNUPGHOME="$OTRO" gpg --import privada-alice.asc
GNUPGHOME="$OTRO" gpg --list-secret-keys
```

Salida resumida:

```console
gpg: key A450923588B2DE76: public key "Alice Ejemplo <alice@example.test>" imported
gpg: key A450923588B2DE76: secret key imported
gpg:       secret keys read: 1
gpg:   secret keys imported: 1
```

- `--export-secret-keys` exporta la primaria y las subclaves. `--export-secret-subkeys` es una alternativa que no incluye la primaria.
- El fichero contiene material secreto: guárdalo cifrado, con permisos `600` y fuera del repositorio.
- Guarda también el **certificado de revocación** (`openpgp-revocs.d/<huella>.rev`).
- Si la clave tiene contraseña, GnuPG la pedirá al exportar; no uses `--passphrase ''` en ese caso.

## 2. Integridad (T1-3, pp. 13–14 y 28)

### 2.1 Calcular resúmenes con `md5sum` y GnuPG

```bash
printf 'linea uno\nlinea dos\n' > a.txt
printf 'linea uno\nlinea dOs\n' > b.txt

md5sum a.txt b.txt
gpg --print-mds a.txt
```

Salida (resumida):

```console
5fbbe2939ca252727608241e56164495  a.txt
fc696a36af9709ce2b5bd18d586fdc1f  b.txt

a.txt:    MD5 = 5F BB E2 93 9C A2 52 72  76 08 24 1E 56 16 44 95
a.txt:   SHA1 = 0024 3BB8 0AF7 EA36 BC0C  9D4E 3CA5 497C B52E 899F
a.txt: RMD160 = A491 8952 3D0C 64F9 3079  14A6 C1D7 2601 F79D 43FB
a.txt: SHA224 = 4CC69A88 27EA5230 5FBBCFE1 86B9F71D 4E8B1923 5CE74B41 A0251CFD
a.txt: SHA256 = A150FCC5 BFF580B3 0CB78767 E2C0E9C8 0447C0BE 406A3A2E
               B39191B3 02053FFB
a.txt: SHA384 = ...
a.txt: SHA512 = ...
```

Los dos ficheros solo difieren en una letra (`dos` frente a `dOs`) y sus resúmenes son completamente distintos. Eso es exactamente lo que se busca: cualquier cambio, por pequeño que sea, produce otro resumen.

`md5sum` sigue siendo útil para comprobar descargas accidentales, pero **MD5 está roto** frente a colisiones. Para seguridad usa SHA-256 o superior y, cuando haga falta autenticar el origen, una firma.

### 2.2 Modificar un fichero cifrado

Cifra sin compresión para que el cambio afecte al paquete cifrado y no a la compresión:

```bash
printf 'Mensaje secreto de prueba.\n' > mensaje.txt
gpg --batch --yes --trust-model always --compress-algo none \
    --recipient "$FPR" --encrypt --output mensaje-pub.gpg mensaje.txt

cp mensaje-pub.gpg manipulado.gpg
python3 - <<'PY'
from pathlib import Path
p = Path('manipulado.gpg')
b = bytearray(p.read_bytes())
b[-20] ^= 0x01          # cambia un bit cerca del final (zona del MDC)
p.write_bytes(b)
PY

gpg --batch --yes --pinentry-mode loopback --decrypt manipulado.gpg
```

Salida esperada:

```console
gpg: encrypted with rsa2048 key, ID A63D3EA372EB917F, created 2026-10-28
      "Alice Ejemplo <alice@example.test>"
Mensaje secreto de prueba.
gpg: WARNING: encrypted message has been manipulated!
```

GnuPG ha descifrado el mensaje, pero ha detectado que el código de integridad no coincide. Si se modifica otra zona (por ejemplo, la cabecera de la clave de sesión), el mensaje puede ser `public key decryption failed: Wrong secret key used` o `decryption failed: Bad session key`. Si se deja la compresión activada, es frecuente ver `zlib inflate problem: invalid distance too far back`. En todos los casos, **el descifrado falla o avisa**: el cifrado autenticado no acepta el fichero manipulado como válido.

### 2.3 Modificar un fichero firmado

```bash
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --detach-sign -a -o a.sig a.txt

cp a.txt a-manipulado.txt
sed -i 's/linea uno/linea unX/' a-manipulado.txt

gpg --verify a.sig a-manipulado.txt
```

Salida esperada:

```console
gpg: Signature made Wed 28 Oct 2026 12:16:40 PM CET
gpg:                using RSA key 994C973CDF24585836E841D9A63D3EA372EB917F
gpg: BAD signature from "Alice Ejemplo <alice@example.test>" [ultimate]
```

Lo mismo ocurre con `--clearsign`: si se cambia el texto entre las marcas `BEGIN PGP SIGNED MESSAGE` y `BEGIN PGP SIGNATURE`, la verificación devuelve `BAD signature`. La firma no cifra; solo demuestra integridad y origen.

## 3. Firma digital (T1-3, pp. 24–28)

### 3.1 Las cuatro formas de firmar

```bash
# 1) Mensaje legible + firma en el mismo fichero
gpg --clearsign a.txt                 # genera a.txt.asc

# 2) Solo la firma, en un fichero aparte, en ASCII
gpg --detach-sign -a a.txt            # genera a.txt.asc
gpg --detach-sign a.txt               # genera a.txt.sig (binario)

# 3) Mensaje + firma en un fichero binario
gpg --sign a.txt                      # genera a.txt.gpg

# 4) Mensaje cifrado + firmado
gpg --sign --encrypt --recipient "$FPR" a.txt
```

| Opción | Resultado | Cuándo usarla |
| --- | --- | --- |
| `--clearsign` | Texto visible + bloque de firma ASCII | Correos, documentos que deben leerse sin GnuPG |
| `--detach-sign -a` | Firma ASCII separada | Distribuir un binario o un tarball junto a su `.sig`/`.asc` |
| `--sign` | Mensaje y firma en un `.gpg` binario | Cuando no importa que el mensaje sea legible |
| `--sign --encrypt` | Cifrado y firma en un solo paso | Enviar un mensaje confidencial y autenticado |

### 3.2 Verificar

```bash
gpg --verify a.txt.asc                 # clearsign
gpg --verify a.sig a.txt               # firma separada: firma + datos
gpg --verify a.txt.gpg                 # mensaje firmado (sin cifrar)
gpg --decrypt mensaje-firmado.gpg      # descifra y verifica si va firmado
```

Salida de una firma correcta:

```console
gpg: Signature made Wed 28 Oct 2026 12:16:40 PM CET
gpg:                using RSA key 994C973CDF24585836E841D9A63D3EA372EB917F
gpg: Good signature from "Alice Ejemplo <alice@example.test>" [ultimate]
```

`Good signature` significa que la firma es criptográficamente válida. La etiqueta entre corchetes (`[ultimate]`, `[full]`, `[marginal]`, `[unknown]`) indica la **confianza calculada** en la clave, no la calidad de la firma. En el apartado 5 se analiza con detalle.

### 3.3 Descargar un ejecutable y comprobar su firma

El ejercicio pide descargar un ejecutable de una página autenticada y cotejarlo con su firma. El flujo es:

```bash
# 1. Descargar el programa y su firma (o la lista de sumas firmada)
curl -LO https://ejemplo.org/programa
curl -LO https://ejemplo.org/programa.sig

# 2. Verificar la firma contra el fichero descargado
gpg --verify programa.sig programa
```

Si el proveedor publica `SHA256SUMS` y `SHA256SUMS.asc`:

```bash
sha256sum -c SHA256SUMS
gpg --verify SHA256SUMS.asc SHA256SUMS
```

No se ha ejecutado una descarga real en esta página porque depende de un proveedor externo. El equivalente local (firmar un fichero y verificarlo) sí está comprobado en los apartados anteriores. Recuerda que HTTPS autentica el transporte, no el binario: la firma sigue siendo necesaria.

## 4. Ejercicios comparativos (T1-3, p. 28)

### 4.1 Tiempos: simétrico frente a asimétrico

Medición con un fichero aleatorio de 5 MiB y otro de 64 B, 5 repeticiones, `--compress-algo none`, misma máquina:

| Operación | 64 B | 5 MiB |
| --- | ---: | ---: |
| Cifrado simétrico AES256 (con contraseña) | 0,379 s | 0,374 s |
| Descifrado simétrico AES256 | 0,354 s | 0,332 s |
| Cifrado asimétrico RSA-2048 | 0,006 s | 0,030 s |
| Descifrado asimétrico RSA-2048 | 0,017 s | 0,035 s |
| Cifrado asimétrico RSA-4096 | — | 0,031 s |
| Descifrado asimétrico RSA-4096 | — | 0,076 s |

Interpretación:

- En el caso **simétrico con contraseña**, el tiempo está dominado por la **derivación de clave (S2K)**, no por AES. Por eso 64 B y 5 MiB tardan parecido. Es una decisión de diseño: encarecer el ataque por diccionario.
- En el caso **asimétrico**, RSA solo cifra/descifra la clave de sesión; el grueso de los 5 MiB lo procesa AES. Por eso el cifrado de 5 MiB no es 80.000 veces más lento que el de 64 B.
- RSA-4096 tarda más que RSA-2048, sobre todo al descifrar, y aporta poco margen adicional frente a RSA-3072 en la mayoría de escenarios. Para claves nuevas, 3072 bits es una opción equilibrada; Ed25519/Ed448 son alternativas modernas.
- Los tiempos absolutos dependen de la CPU, la caché, el agente y la carga. Lo relevante es la **tendencia**, no el valor exacto.

Para reproducir la medición:

```bash
TIMEFORMAT='%R'
time gpg --batch --yes --passphrase 'pw' --pinentry-mode loopback \
     --compress-algo none --symmetric --cipher-algo AES256 \
     -o prueba.gpg fichero.bin
```

### 4.2 Tamaños: simétrico frente a asimétrico

| Texto claro | Simétrico AES256 | RSA-2048 | RSA-3072 | RSA-4096 |
| ---: | ---: | ---: | ---: | ---: |
| 64 B | 140 B | 396 B | 524 B | 652 B |
| 5 MiB | 5.242.963 B | 5.243.219 B | — | — |

El sobrecoste del asimétrico es aproximadamente el tamaño de la clave RSA (256, 384 o 512 bytes) más la cabecera de paquetes. En mensajes grandes ese sobrecoste es despreciable; en mensajes muy cortos puede multiplicar el tamaño. Por eso los protocolos híbridos usan RSA/ECDH solo para intercambiar una clave de sesión y cifran los datos con AES o ChaCha20.

Comprobación:

```bash
wc -c mensaje.txt mensaje-sim.gpg mensaje-rsa2048.gpg
```

### 4.3 Exportar la clave pública

```bash
gpg -a --output publica.asc --export "$FPR"
gpg --fingerprint "$FPR"
```

`--export` no incluye la clave privada. El fichero `.asc` se puede publicar, enviar por correo o subir a un keyserver. Antes de usarlo, el receptor debe comprobar la huella por un canal independiente.

## 5. Gestión de claves (T1-4, pp. 34–39)

### 5.1 Exportar, validar e importar una clave pública

```bash
# En el llavero de Alice
gpg -a --output alice-pub.asc --export "$ALICE_FPR"
gpg --fingerprint "$ALICE_FPR"

# En el llavero de User1
GNUPGHOME="$USER1_HOME" gpg --import alice-pub.asc
GNUPGHOME="$USER1_HOME" gpg --fingerprint "$ALICE_FPR"
```

Salida resumida:

```console
gpg: key A450923588B2DE76: public key "Alice Ejemplo <alice@example.test>" imported
gpg: Total number processed: 1
gpg:               imported: 1

pub   rsa2048 2026-10-28 [SCEAR] [expires: 2027-10-28]
      A9FF F77D 26E8 A913 6308  F565 A450 9235 88B2 DE76
uid           [ unknown] Alice Ejemplo <alice@example.test>
```

La huella debe coincidir **carácter a carácter** con la que Alice publicó por otro canal (web oficial, tarjeta, reunión presencial). Importar una clave no es confiar en ella: solo la añade al llavero.

### 5.2 Distribuir por keyserver

```bash
gpg --keyserver hkps://keys.openpgp.org --send-keys "$FPR"
gpg --keyserver hkps://keys.openpgp.org --search-keys alice@example.test
gpg --keyserver hkps://keys.openpgp.org --recv-keys "$FPR"
```

- `hkps://` es HKP sobre TLS.
- `--send-keys` **publica** la clave; cualquiera puede descargarla. No se ha ejecutado en el laboratorio para no publicar claves de prueba.
- `keys.openpgp.org` exige verificar el correo antes de mostrar el UID y permite borrar la clave.
- En un entorno controlado, la distribución por fichero (`--export`/`--import`) es más reproducible y no depende de la red.

### 5.3 Firmar una clave pública y asignar confianza

Interactivo:

```bash
gpg --edit-key "$ALICE_FPR"
gpg> sign          # firma la clave con tu clave
gpg> trust         # 1 desconocido, 2 nunca, 3 marginal, 4 plena, 5 ultimate
gpg> save
```

No interactivo:

```bash
# Firmar la clave de Alice con la clave de User1
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --local-user "$USER1_FPR" --quick-sign-key "$ALICE_FPR"

# Asignar confianza plena (4)
printf '%s:4:\n' "$ALICE_FPR" | gpg --import-ownertrust
gpg --check-trustdb
```

`--quick-sign-key` firma con la clave por defecto; si se quiere usar otra, se indica con `--local-user`. El segundo argumento de `--quick-sign-key` son **nombres de UID** que se quieren firmar, no una huella de la clave firmante.

Valores de `--import-ownertrust`: `2` nunca, `3` marginal, `4` plena y `6` ultimate. La confianza es una opinión sobre el propietario; la validez de una clave se calcula combinando firmas y confianza.

### 5.4 Revocar una clave

Generar un certificado de revocación (interactivo, necesita terminal):

```bash
gpg --output revocacion.asc --gen-revoke "$FPR"
```

El diálogo pide confirmación, el motivo y una descripción. Motivos habituales: `0` sin motivo, `1` clave comprometida, `2` reemplazada, `3` ya no se usa. Después:

```bash
gpg --import revocacion.asc
gpg --keyserver hkps://keys.openpgp.org --send-keys "$FPR"
```

GnuPG ya crea un certificado de revocación al generar la clave, en `openpgp-revocs.d/<huella>.rev`. Ese fichero lleva dos puntos delante de las cinco rayas para evitar un uso accidental; hay que quitarlos antes de importarlo:

```bash
sed 's/^://' "$GNUPGHOME/openpgp-revocs.d/$DFPR.rev" > revocacion.asc
gpg --import revocacion.asc
gpg --list-keys "$DFPR"
```

Salida esperada:

```console
gpg: Total number processed: 1
gpg:    new key revocations: 1
pub   rsa2048 2026-10-28 [SCEAR] [revoked: 2026-10-28]
      ...
uid           [ revoked] Dave <dave@example.test>
```

!!! danger "La revocación es irreversible"
    Una vez importado y distribuido el certificado, la clave queda revocada para siempre. No importes por error un certificado de revocación en el llavero real. Guarda el certificado original *offline*.

### 5.5 Escenario A/B/C: confianza y mensajes de GnuPG

Se preparan tres llaveros separados (A, B y C) y uno para User1. A firma la clave pública de B; B firma la de C. Después User1 verifica ficheros firmados por cada uno.

```bash
# A importa la clave de B y la firma
GNUPGHOME="$A_HOME"  gpg --import b-pub.asc
GNUPGHOME="$A_HOME"  gpg --quick-sign-key "$B_FPR"
GNUPGHOME="$A_HOME"  gpg -a --export "$B_FPR" > b-firmada-por-a.asc

# B importa la clave de C y la firma
GNUPGHOME="$B_HOME"  gpg --import c-pub.asc
GNUPGHOME="$B_HOME"  gpg --quick-sign-key "$C_FPR"
GNUPGHOME="$B_HOME"  gpg -a --export "$C_FPR" > c-firmada-por-b.asc
```

Cada usuario firma un mensaje:

```bash
printf 'Mensaje firmado por A\n' > msg-A.txt
GNUPGHOME="$A_HOME" gpg --detach-sign -a -o msg-A.sig msg-A.txt
```

#### Caso 1: A sin firmar, marcada como «no confiable»

```bash
GNUPGHOME="$USER1_HOME" gpg --import a-pub.asc
printf '%s:2:\n' "$A_FPR" | GNUPGHOME="$USER1_HOME" gpg --import-ownertrust
GNUPGHOME="$USER1_HOME" gpg --verify msg-A.sig msg-A.txt
```

```console
gpg: Good signature from "A <a@example.test>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
```

La firma es correcta, pero User1 no ha certificado la clave de A ni confía en su propietario. GnuPG no puede afirmar que esa clave pertenezca realmente a A.

#### Caso 2: A firmada por User1 y marcada como «confiable»

```bash
GNUPGHOME="$USER1_HOME" gpg --quick-sign-key "$A_FPR"
printf '%s:4:\n' "$A_FPR" | GNUPGHOME="$USER1_HOME" gpg --import-ownertrust
GNUPGHOME="$USER1_HOME" gpg --verify msg-A.sig msg-A.txt
```

```console
gpg: Good signature from "A <a@example.test>" [full]
```

Ya no aparece el aviso: User1 ha firmado la clave de A y le ha asignado confianza plena. La etiqueta `[full]` indica que la clave es válida para User1.

#### Caso 3: B firmada por A, con A de confianza plena

```bash
GNUPGHOME="$USER1_HOME" gpg --import b-firmada-por-a.asc
GNUPGHOME="$USER1_HOME" gpg --verify msg-B.sig msg-B.txt
```

```console
gpg: Good signature from "B <b@example.test>" [marginal]
gpg: WARNING: This key is not certified with sufficiently trusted signatures!
gpg:          It is not certain that the signature belongs to the owner.
```

La firma de B es buena y A certifica la clave de B, pero **una sola firma de un introductor de confianza plena deja la validez en marginal**. Para elevarla a plena, GnuPG necesita más certificaciones independientes o un nivel de confianza superior en la cadena. Por eso avisa de que no hay garantía suficiente.

#### Caso 4: C firmada por B, con B marcada como «no confiable»

```bash
GNUPGHOME="$USER1_HOME" gpg --import c-firmada-por-b.asc
printf '%s:2:\n' "$B_FPR" | GNUPGHOME="$USER1_HOME" gpg --import-ownertrust
GNUPGHOME="$USER1_HOME" gpg --verify msg-C.sig msg-C.txt
```

```console
gpg: Good signature from "C <c@example.test>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
```

B certifica a C, pero User1 no confía en B; la cadena se corta. La firma de C sigue siendo válida criptográficamente, pero su identidad no está autenticada para User1.

#### Resumen de los mensajes

| Caso | Cadena de confianza | Resultado de `--verify` |
| --- | --- | --- |
| A sin firmar, trust `never` | User1 no certifica a A | `Good signature ... [unknown]` + aviso de clave no certificada |
| A firmada por User1, trust `full` | User1 → A | `Good signature ... [full]`, sin aviso |
| B firmada por A, A `full` | User1 → A → B | `Good signature ... [marginal]` + aviso de firmas insuficientes |
| C firmada por B, B `never` | User1 ⇥ B → C (cadena cortada) | `Good signature ... [unknown]` + aviso de clave no certificada |

**Qué significa cada mensaje:**

- `Good signature`: la firma corresponde al mensaje y a la clave indicada. No dice nada por sí solo sobre si esa clave pertenece a la persona correcta.
- `BAD signature`: el mensaje o la firma han cambiado, o la firma no corresponde a esos datos.
- `[ultimate]`: clave propia del llavero (o marcada como tal). No se debe usar para terceros.
- `[full]`: clave validada por una firma directa de confianza suficiente.
- `[marginal]`: hay alguna certificación, pero no alcanza el umbral configurado.
- `[unknown]`: no hay certificaciones o no se ha asignado confianza.
- `WARNING: This key is not certified with a trusted signature!`: la clave no tiene una certificación de confianza para el usuario.
- `WARNING: This key is not certified with sufficiently trusted signatures!`: hay certificaciones, pero no las suficientes para el modelo de confianza.

Para corregir un aviso: verifica la huella por un canal seguro, firma la clave (`--quick-sign-key` o `gpg --edit-key ... sign`) y asigna la confianza adecuada. No basta con importar la clave.

## 6. Limpieza y uso del llavero real

```bash
gpgconf --kill gpg-agent
unset GNUPGHOME
```

Para consultar el llavero real:

```bash
gpg -k
gpg -K
gpg --fingerprint
```

No copies `privada-alice.asc` ni las claves de laboratorio al repositorio. Si necesitas practicar con el llavero real, haz una copia de seguridad antes y no importes certificados de revocación de prueba.

## Enlaces

- [GnuPG: comandos](../comandos/gpg.md)
- [Hashes e integridad](../comandos/hash.md)
- [Comunicación segura (teoría)](../teoria/comunicacion-segura.md)
- [Gestión de claves y PKI (teoría)](../teoria/gestion-claves.md)
- [Transparencias T1-3](../../assets/pdf/SRDSI_T1-3.pdf)
- [Transparencias T1-4](../../assets/pdf/SRDSI_T1-4.pdf)
- [GnuPG — documentación oficial](https://www.gnupg.org/documentation/)
