# Hashes e integridad

Una función **hash** (o *message digest*) convierte datos de tamaño arbitrario en un resumen de tamaño fijo. Sirve para detectar modificaciones accidentales y, combinada con una clave o una firma, para autenticar el origen. Esta página recoge las herramientas habituales del sistema y su relación con MAC y AEAD.

[:material-file-pdf-box: Transparencias — Introducción a la criptografía (PDF)](../../assets/pdf/SRDSI_T1-2.pdf){ .md-button }

## Resúmenes con coreutils

| Comando | Longitud | Uso recomendado |
| --- | --- | --- |
| `md5sum` | 128 bits | Compatibilidad y comprobaciones no criptográficas. **Roto** frente a colisiones. |
| `sha1sum` | 160 bits | Compatibilidad. **No usar** para seguridad. |
| `sha256sum` | 256 bits | Opción por defecto razonable. |
| `sha512sum` | 512 bits | Alternativa de SHA-2; habitual en descargas. |

```bash
md5sum fichero.txt
sha1sum fichero.txt
sha256sum fichero.txt
sha512sum fichero.txt
```

Salida típica (hash + dos espacios + nombre):

```console
7749b778654a5e507cf22184ac945ef2c364ba75172d15b3677ba0af32844bf6  fichero.txt
```

## Calcular y verificar un fichero de resúmenes

```bash
sha256sum fichero.txt > fichero.sha256
sha256sum -c fichero.sha256
```

```console
fichero.txt: OK
```

Si el contenido cambia, la comprobación falla:

```console
fichero.txt: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
```

Para varios ficheros, genera un único fichero de sumas:

```bash
sha256sum *.iso *.tar.gz > SHA256SUMS
sha256sum -c SHA256SUMS
```

`md5sum`, `sha1sum`, `sha256sum` y `sha512sum` aceptan el mismo formato de fichero (`<hash>  <ruta>`). La opción `--tag` genera el formato BSD (`SHA256 (fichero) = ...`), útil para otros sistemas.

!!! tip "Rutas relativas"
    `sha256sum -c` busca los ficheros tal como aparecen en el fichero de sumas. Ejecútalo desde el directorio donde están los ficheros o genera el fichero desde ese directorio.

## Comparar dos resúmenes

```bash
sha256sum original.txt copia.txt
```

Si los hashes coinciden, los ficheros son idénticos con abrumadora probabilidad. Para comparar solo los valores:

```bash
diff <(sha256sum original.txt | cut -d' ' -f1) \
     <(sha256sum copia.txt   | cut -d' ' -f1) \
  && echo 'iguales' || echo 'distintos'
```

También se puede usar `cmp -s original.txt copia.txt`, que compara byte a byte y no calcula ningún hash. Es más directo para ficheros locales; el hash es útil cuando los ficheros están separados o solo se dispone del resumen.

## Resúmenes con GnuPG

```bash
gpg --print-mds fichero.txt
```

Salida (resumida; una línea por algoritmo):

```console
fichero.txt:    MD5 = 36 D6 B8 EA 47 C8 61 E7  DB 68 D3 98 64 93 DF 16
fichero.txt:   SHA1 = 9665 F837 3E1C 798E 9D42  A31A C748 297A CC38 C8DE
fichero.txt: RMD160 = 079E A8CF 3D61 33AE B0BC  A2CD DE79 20D8 8AF9 CE0D
fichero.txt: SHA224 = 287BD5BC 6B111A17 ECE711BA A3A14B12 7DC1E13C 6AA9AF62
                  1C95C64F
fichero.txt: SHA256 = 419B7881 BC0A2AF3 AB925DED F0E6A50F 87B4B165 3A521F29
                  3B5C4AA4 160960E0
```

El valor SHA-256 coincide con `sha256sum` (los espacios y mayúsculas cambian, el hash no). GnuPG calcula además MD5, SHA-1 y RIPEMD-160, que se conservan por compatibilidad pero no deben usarse como garantía de seguridad.

## Integridad de descargas

Un hash publicado en la misma web que el fichero **no autentica** nada: si un atacante controla la web, puede cambiar ambos. El flujo correcto combina hash y firma:

```bash
# 1. Descargar fichero, lista de sumas y firma
curl -LO https://ejemplo.org/programa.tar.gz
curl -LO https://ejemplo.org/SHA256SUMS
curl -LO https://ejemplo.org/SHA256SUMS.asc

# 2. Comprobar el hash
sha256sum -c SHA256SUMS

# 3. Verificar que la lista de sumas la firmó el proveedor
gpg --verify SHA256SUMS.asc SHA256SUMS
```

Si la firma es buena y el hash coincide, el fichero no se ha alterado y la lista procede de quien posee la clave privada. La confianza final depende de que la clave pública del proveedor se haya obtenido y validado por un canal seguro (huella publicada, TLS, encuentro presencial, etc.).

!!! warning "HTTPS no sustituye a la firma"
    TLS protege el transporte, pero no demuestra que el servidor sea el proveedor legítimo ni protege frente a un servidor comprometido. Para binarios y paquetes, verifica siempre la firma además del hash.

## Qué garantiza cada mecanismo

| Mecanismo | Clave | Garantiza | No garantiza |
| --- | --- | --- | --- |
| Hash / MDC (`sha256sum`, `gpg --print-mds`) | No | Integridad frente a cambios accidentales | Autenticación del origen; un atacante puede recalcular el hash |
| MAC / HMAC (`HMAC-SHA256`, CMAC, GMAC) | Simétrica compartida | Integridad + autenticación del origen | No repudio; cualquiera con la clave puede generarlo |
| Firma digital (`gpg --sign`, `--detach-sign`) | Asimétrica | Integridad + autenticación + no repudio | Confidencialidad |
| AEAD (`AES-GCM`, `ChaCha20-Poly1305`) | Simétrica | Confidencialidad + integridad + autenticación de datos adicionales | No repudio |

Un **hash** no lleva clave: cualquiera puede calcularlo. Un **MAC** lleva una clave simétrica y por eso autentica, pero no distingue entre los poseedores de la clave. Una **firma** usa la clave privada del firmante y aporta no repudio. **AEAD** integra cifrado y autenticación en un solo modo.

En GnuPG, el cifrado simétrico y asimétrico añade comprobaciones de integridad: al modificar un criptograma, el descifrado falla o la firma se marca como `BAD` (comprobado). Eso no convierte al hash en una firma: la garantía de origen sigue dependiendo de la clave y de la confianza.

## Benchmarks del repositorio

Los logs `Tema 1: Introducción a la seguridad informática/actividad-criptografia/benchmark_*.txt` recogen tiempos de `libgcrypt` para MD5, SHA-1, SHA-2, SHA-3, BLAKE2, HMAC, CMAC, AEAD y generación de claves. En esas pruebas, los resúmenes y HMAC de tamaños pequeños tardan del orden de `0–20 ms`, por lo que las diferencias no son concluyentes sin fijar tamaño, máquina y repeticiones.

- [Benchmarks de algoritmos](../../recursos/benchmarks.md)
- [Actividad de criptografía: Ascon](../actividades/criptografia.md)
- [Criptografía (teoría)](../teoria/criptografia.md)

## Actividades del curso

- [Integridad: calcular resúmenes y verificar (T1-3, p. 13)](../../assets/pdf/SRDSI_T1-3.pdf#page=13)
- [Actividad con `md5sum` y `gpg --print-mds` (T1-3, p. 14)](../../assets/pdf/SRDSI_T1-3.pdf#page=14)
- [Ejercicios de integridad, firma y modificación de criptogramas (T1-3, p. 28)](../../assets/pdf/SRDSI_T1-3.pdf#page=28)

## Gotchas

- **MD5 y SHA-1 no son seguros** para firmas, certificados ni control de integridad frente a un atacante activo. Úsalos solo por compatibilidad.
- **Un hash no autentica**: si el atacante puede modificar el fichero, también puede modificar el hash publicado. Necesitas firma o MAC.
- **Compara el valor completo**: comparar solo los primeros caracteres o ignorar mayúsculas puede dar falsos positivos. Los hashes hexadecimales no distinguen mayúsculas/minúsculas, pero deben compararse completos.
- **Saltos de línea y binarios**: cambiar el fin de línea (`CRLF`/`LF`) cambia el hash. Para texto descargado, verifica el fichero exacto que se distribuye.
- **Ficheros de sumas**: revisa que la ruta del fichero de sumas coincide con el nombre real; un `SHA256SUMS` de otra versión dará `FAILED` aunque el binario sea válido.
- **`gpg --print-mds` no firma**: solo calcula resúmenes. Para firmar usa `--detach-sign` o `--clearsign`.

## Enlaces

- [GnuPG](gpg.md)
- [Criptografía (teoría)](../teoria/criptografia.md)
- [Comunicación segura (teoría)](../teoria/comunicacion-segura.md)
- [GnuPG: actividades](../actividades/gnupg.md)
- [Recursos: benchmarks](../../recursos/benchmarks.md)
