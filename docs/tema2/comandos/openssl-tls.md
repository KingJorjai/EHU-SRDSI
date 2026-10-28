# OpenSSL TLS/DTLS: `s_server` y `s_client`

`openssl s_server` y `openssl s_client` son un servidor y un cliente TLS de laboratorio. Sirven para negociar versiones y cifrados, probar certificados, reanudar sesiones, enviar datos tempranos (0-RTT), usar DTLS o algoritmos post-cuánticos, y generar el *keylog* que permite descifrar el tráfico en Wireshark.

[:material-file-pdf-box: Transparencias — TLS, DTLS y QUIC (PDF)](../../assets/pdf/SRDSI_T2-3.pdf){ .md-button }

!!! note "Versiones y certificados"
    Comandos verificados con **OpenSSL 4.0.3** en el host, usando los certificados de `Tema 2: Seguridad en la comunicación/ejercicio-tls-dtls/lab-certs/`. En la VM del laboratorio hay OpenSSL 3.5.7. Los ejemplos usan puertos altos (`4433`–`4435`); en las pruebas se usaron puertos temporales equivalentes. `server2.crt`/`server2.key` **no existen** en el repositorio, aunque el README los mencione.

## Preparar el directorio y la cadena

Todos los comandos se ejecutan desde `lab-certs` para que las rutas de los certificados sean relativas. La ruta del repositorio lleva espacios y dos puntos: cítala entre comillas.

```bash
cd "Tema 2: Seguridad en la comunicación/ejercicio-tls-dtls/lab-certs"

# Cadena de confianza: raíz + subCA
cat ca-root.crt subca.crt > /tmp/ca-chain.pem
```

Comprobar la cadena:

```bash
openssl verify -CAfile /tmp/ca-chain.pem server.crt client.crt
openssl verify -CAfile ca-root.crt -untrusted subca.crt server.crt
```

```console
server.crt: OK
client.crt: OK
server.crt: OK
```

`server.crt` y `client.crt` están firmados por `SUBCA-SRDSI`, no directamente por la raíz. Por eso:

- `openssl verify -CAfile ca-root.crt server.crt` **falla**: el fichero `server.crt` no incluye la subCA.
- `-untrusted subca.crt` aporta el intermedio, o se usa como almacén de confianza la cadena completa (`/tmp/ca-chain.pem`).
- En TLS, el servidor envía el intermedio con `-cert_chain subca.crt`; entonces el cliente puede confiar solo en `ca-root.crt`.

Inspeccionar los certificados:

```bash
openssl x509 -in server.crt -noout -subject -issuer -dates -ext subjectAltName
openssl x509 -in serverpq.crt -noout -text | grep -E 'Public Key Algorithm|Signature Algorithm'
```

Los certificados **no tienen SAN**; solo CN (`www.srdsi.lab`, `client`). OpenSSL acepta el CN como respaldo cuando no hay SAN, pero los navegadores y las CAs públicas exigen SAN. No uses estos certificados fuera del laboratorio.

## Dos terminales, `s_server` y `s_client`

Patrón general:

```bash
# Terminal 1: servidor
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_2 -www -naccept 1

# Terminal 2: cliente
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -brief
```

- `-accept 4433` escucha en todas las interfaces; para limitar a loopback usa `-accept 127.0.0.1:4433`.
- `-www` hace que el servidor responda con una página HTTP de diagnóstico a las peticiones; es cómodo para probar con `curl`.
- `-naccept 1` cierra el servidor después de una conexión. Sin `-naccept`, se detiene con `Ctrl-C`.
- En el cliente, para terminar escribe `Q` y pulsa `Intro` (o `Ctrl-D`). Con la entrada redirigida, el cliente termina al llegar a EOF.
- `-brief` resume la conexión; sin `-brief` se muestran certificado, cadena, sesión y datos.

Salida esperada con TLS 1.2:

```console
Connecting to 127.0.0.1
CONNECTION ESTABLISHED
Protocol version: TLSv1.2
Ciphersuite: ECDHE-RSA-AES256-GCM-SHA384
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Verification: OK
```

`Verification: OK` confirma que el cliente validó la cadena hasta la raíz. Si aparece `verify error:num=20:unable to get local issuer certificate`, falta el intermedio o el `-CAfile` correcto.

## Opciones de `s_server` y `s_client`

| Opción | Uso |
| --- | --- |
| `-accept puerto` | (`s_server`) Escucha en ese puerto. Admite `host:puerto`. |
| `-connect host:puerto` | (`s_client`) Conecta al servidor. |
| `-cert fichero` | Certificado del servidor o del cliente. |
| `-key fichero` | Clave privada correspondiente al certificado. |
| `-cert_chain fichero` | Cadena de intermedios que el servidor envía al cliente. |
| `-CAfile fichero` | CAs en las que confiar. En `s_server`, para verificar al cliente. |
| `-tls1_2` | Fuerza TLS 1.2. |
| `-tls1_3` | Fuerza TLS 1.3. |
| `-dtls1_2` | Fuerza DTLS 1.2 (UDP). |
| `-cipher lista` | Cifrados TLS ≤ 1.2 (p. ej. `RSA`, `AES256-GCM-SHA384`). |
| `-ciphersuites lista` | Cifrados TLS 1.3 (p. ej. `TLS_AES_256_GCM_SHA384`). |
| `-keylogfile fichero` | (`s_client`) Exporta secretos de sesión para Wireshark. |
| `-verify N` | (`s_client`) Verifica el certificado del servidor hasta profundidad `N`. |
| `-Verify N` | (`s_server`) Exige certificado de cliente hasta profundidad `N`. |
| `-sess_out fichero` | Guarda la sesión para reutilizarla. |
| `-sess_in fichero` | Reutiliza una sesión guardada. |
| `-early_data [fichero]` | 0-RTT. En el servidor habilita su lectura; en el cliente 4.x el argumento es el fichero a enviar. |
| `-alpn lista` | Negocia ALPN (p. ej. `h2,http/1.1`). |
| `-brief` | Salida resumida. |
| `-state` | Traza las transiciones del handshake. |
| `-www` / `-WWW` | (`s_server`) Responde con diagnóstico HTTP / sirve ficheros. No válido con DTLS. |
| `-naccept N` | (`s_server`) Atiende `N` conexiones y sale. |

`-verify` y `-Verify` son opciones distintas y sensibles a mayúsculas: la minúscula verifica al servidor en el cliente; la mayúscula exige certificado al cliente en el servidor.

## TLS 1.2

```bash
# Terminal 1
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_2 -www -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
Protocol version: TLSv1.2
Ciphersuite: ECDHE-RSA-AES256-GCM-SHA384
Verification: OK
```

En el handshake de TLS 1.2 se ven `ClientHello`, `ServerHello`, `Certificate`, `ServerKeyExchange` (con ECDHE), `ServerHelloDone`, `ClientKeyExchange`, `ChangeCipherSpec` y `Finished`. `openssl s_client ... -state` muestra cada transición.

## TLS 1.3

```bash
# Terminal 1
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_3 -www -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4433 -tls1_3 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Verification: OK
```

Diferencias prácticas frente a TLS 1.2:

- El `ServerHello` va seguido inmediatamente de mensajes cifrados: el certificado y la verificación del servidor ya no son visibles en claro.
- No hay `ServerKeyExchange` ni `ChangeCipherSpec` con el mismo papel; el intercambio de claves va en extensiones.
- El servidor envía varios `NewSessionTicket` después del handshake.
- Los cifrados son AEAD (`TLS_AES_*`, `TLS_CHACHA20_*`); `-cipher` no los selecciona, hay que usar `-ciphersuites`.

## DTLS 1.2

DTLS es TLS sobre UDP. No admite `-www`; se usa `-quiet` y se envían datos por la entrada estándar:

```bash
# Terminal 1
openssl s_server -dtls1_2 -accept 4434 -cert server.crt -key server.key \
  -cert_chain subca.crt -quiet -naccept 1

# Terminal 2
printf 'hola dtls\n' | openssl s_client -dtls1_2 -connect 127.0.0.1:4434 \
  -CAfile /tmp/ca-chain.pem
```

```console
Verification: OK
New, TLSv1.2, Cipher is ECDHE-RSA-AES256-GCM-SHA384
Protocol: DTLSv1.2
```

`openssl s_client` imprime `New, TLSv1.2` porque comparte el motor TLS, pero la línea `Protocol: DTLSv1.2` y la captura en Wireshark confirman que el transporte es **UDP** con handshake DTLS. No hay `-www`; si lo añades, el servidor falla con `Can't use -HTTP, -www or -WWW with DTLS`.

## Autenticación del cliente

El servidor exige un certificado de cliente firmado por una CA de confianza:

```bash
# Terminal 1
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -CAfile /tmp/ca-chain.pem -Verify 1 \
  -tls1_2 -quiet -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -cert client.crt -key client.key
```

El servidor muestra `verify return:1` y el cliente completa el handshake. Si el cliente **no** presenta certificado:

```bash
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem
```

```console
error:...:tls alert handshake failure:SSL alert number 40
```

El servidor envía `handshake_failure` (40) porque `-Verify` obliga a presentar certificado. El mismo montaje funciona con `-tls1_3`; en TLS 1.3 el `Certificate` y el `CertificateVerify` del cliente viajan **cifrados**, así que en Wireshark solo se ven como *Application Data* salvo que cargues el keylog.

## Reutilización de sesión (resumption)

TLS 1.2:

```bash
# Terminal 1: dos conexiones
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_2 -quiet -naccept 2

# Terminal 2: primera conexión, guarda la sesión
(echo primera; sleep 0.5) | openssl s_client -connect 127.0.0.1:4433 \
  -tls1_2 -CAfile /tmp/ca-chain.pem -sess_out /tmp/sess.pem

# Terminal 2: segunda conexión, reutiliza la sesión
(echo segunda; sleep 0.5) | openssl s_client -connect 127.0.0.1:4433 \
  -tls1_2 -CAfile /tmp/ca-chain.pem -sess_in /tmp/sess.pem
```

Salida relevante:

```console
New, TLSv1.2, Cipher is ECDHE-RSA-AES256-GCM-SHA384
Reused, TLSv1.2, Cipher is ECDHE-RSA-AES256-GCM-SHA384
```

Inspeccionar la sesión guardada:

```bash
openssl sess_id -in /tmp/sess.pem -noout -text
```

Muestra `Protocol`, `Cipher`, `Session-ID` y la clave maestra. En la sesión reutilizada no se repite el intercambio de claves completo: se envía el identificador de sesión (TLS 1.2) o el *ticket* (TLS 1.3).

## 0-RTT (TLS 1.3)

0-RTT permite enviar datos en el primer vuelo, antes de completar el handshake, reutilizando un ticket. El servidor debe habilitarlo y el cliente debe disponer de una sesión previa con ticket:

```bash
# Terminal 1
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_3 -early_data -quiet -naccept 2

# Preparar los datos tempranos
printf 'datos 0-rtt\n' > /tmp/early.txt

# Primera conexión: obtiene el ticket y guarda la sesión
(echo primera; sleep 2) | openssl s_client -connect 127.0.0.1:4433 \
  -tls1_3 -CAfile /tmp/ca-chain.pem -sess_out /tmp/sess13.pem -ign_eof

# Segunda conexión: reutiliza la sesión y envía datos tempranos
(echo segunda; sleep 1) | openssl s_client -connect 127.0.0.1:4433 \
  -tls1_3 -CAfile /tmp/ca-chain.pem -sess_in /tmp/sess13.pem \
  -early_data /tmp/early.txt -ign_eof
```

```console
# Primera conexión
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Early data was not sent
Post-Handshake New Session Ticket arrived:
    Max Early Data: 16384

# Segunda conexión
Reused, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Early data was accepted
```

El servidor `-quiet` escribe en su salida los bytes recibidos (`datos 0-rtt`). Detalles importantes:

- En **OpenSSL 4.x**, `s_client -early_data` exige un **fichero** (`-early_data /tmp/early.txt`); en OpenSSL 3.x era un flag y los datos se tomaban de la entrada estándar.
- `-ign_eof` mantiene la conexión abierta tras el EOF de la entrada, para que lleguen los tickets y se pueda guardar la sesión.
- 0-RTT no es idempotente por naturaleza: un atacante puede reenviar los datos tempranos. En producción se limita a peticiones seguras de repetir y se activa `-anti_replay` (por defecto) en el servidor.

## PQC: ML-DSA-65 con `serverpq`

`serverpq.crt` tiene una clave pública **ML-DSA-65** (post-cuántica), aunque el certificado esté firmado por la subCA con RSA. El servidor y el cliente negocian TLS 1.3:

```bash
# Terminal 1
openssl s_server -accept 4435 -cert serverpq.crt -key serverpq.key \
  -cert_chain subca.crt -tls1_3 -www -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4435 -tls1_3 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
CONNECTION ESTABLISHED
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Hash used: UNDEF
Signature type: mldsa65
Verification: OK
Negotiated TLS1.3 group: X25519MLKEM768
```

- `Signature type: mldsa65` confirma que el servidor firmó el handshake con la clave ML-DSA-65.
- `X25519MLKEM768` es el grupo híbrido (X25519 + ML-KEM-768) que OpenSSL 4 negocia por defecto. Puedes forzarlo con `-groups X25519MLKEM768` y listar los disponibles con `openssl list -tls-groups | grep -i mlkem`.
- El algoritmo de firma del **certificado** (`sha256WithRSAEncryption`) es independiente de la clave pública (`ML-DSA-65`): la subCA sigue siendo RSA.
- `serverpq` solo funciona con TLS 1.3; ML-DSA no está disponible en TLS 1.2.

## Keylog y ALPN

Exportar secretos para Wireshark:

```bash
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -keylogfile /tmp/keys.log
```

El fichero contiene líneas `CLIENT_RANDOM <random> <master_secret>`. Wireshark y `tshark -o tls.keylog_file:` lo usan para descifrar **TLS 1.2**; con TLS 1.3 el keylog también incluye los secretos necesarios, pero el laboratorio fija TLS 1.2 para que coincida con el material y las capturas.

ALPN:

```bash
# Servidor
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_2 -alpn h2,http/1.1 -www -naccept 1

# Cliente
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -alpn h2
```

La salida incluye `ALPN protocol: h2`. Si no hay coincidencia, el servidor puede rechazar la conexión o continuar sin ALPN según la implementación.

## Cifrado RSA sin forward secrecy (ejercicio 4)

```bash
# Terminal 1
openssl s_server -accept 4433 -cert server.crt -key server.key \
  -cert_chain subca.crt -tls1_2 -cipher RSA -www -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -cipher RSA -brief
```

```console
Protocol version: TLSv1.2
Ciphersuite: AES256-GCM-SHA384
Verification: OK
```

El cifrado `AES256-GCM-SHA384` con intercambio RSA no proporciona *forward secrecy*: la clave de sesión va cifrada con la clave pública RSA del servidor. Quien obtenga después la clave privada del servidor puede descifrar las capturas antiguas. En Wireshark se puede descifrar aportando la clave privada del servidor (*Preferences → Protocols → TLS → RSA keys list*), sin keylog. Con ECDHE, en cambio, la clave privada del servidor no basta.

## Ejercicios TLS/DTLS y comando asociado

| Ejercicio | Comando clave |
| --- | --- |
| 1. Sesión TLS 1.2 | `s_server -tls1_2` + `s_client -tls1_2`, captura con `dumpcap`. |
| 2. TLS 1.2 vs 1.3 | Repetir con `-tls1_3`; comparar mensajes visibles y `NewSessionTicket`. |
| 3. Interoperación | Cliente `-tls1_2` contra servidor `-tls1_3` (y viceversa): falla si no hay versión común. |
| 4. Sin forward secrecy | `-cipher RSA` en ambos lados y descifrado con la clave privada del servidor. |
| 5. Autenticación de cliente | `s_server -Verify 1 -CAfile ...` + `s_client -cert client.crt -key client.key`. |
| 6. Resumption | `-sess_out` / `-sess_in`; comparar `New` y `Reused`. |
| 7. 0-RTT | `-early_data` en servidor y cliente; comprobar `Early data was accepted`. |
| 8. DTLS 1.2 | `-dtls1_2` en ambos lados; captura UDP en Wireshark. |
| 9. PQC | `serverpq` con ML-DSA-65 y grupo híbrido `X25519MLKEM768`. |

## Errores frecuentes

| Error | Causa | Solución |
| --- | --- | --- |
| `unable to get local issuer certificate` | Falta la subCA en el almacén. | `-CAfile /tmp/ca-chain.pem` o `-cert_chain subca.crt`. |
| `no shared cipher` | Cifrado o versión incompatibles. | Revisa `-tls1_2`/`-tls1_3` y `-cipher`/`-ciphersuites`. |
| `alert handshake failure` (40) | El servidor exige cliente y no lo hay, o no hay cifrados comunes. | Añade `-cert client.crt -key client.key`. |
| `alert unknown ca` (48) | El cliente no confía en la CA del servidor. | Usa la cadena correcta. |
| `Option -early_data needs a value` | OpenSSL 4 exige fichero para 0-RTT. | `-early_data /tmp/early.txt`. |
| `Can't use -HTTP, -www or -WWW with DTLS` | `-www` no existe en DTLS. | Usa `-quiet` y datos por stdin. |
| `BIO_new_file: No such file` en `-sess_in` | La primera conexión no guardó la sesión. | Mantén la conexión con `-ign_eof` y espera los tickets. |
| `address already in use` | Puerto ocupado por otra prueba. | Usa otro puerto o `ss -tlnp | grep 4433`. |

## Enlaces

- [TLS, DTLS y QUIC (teoría)](../teoria/tls-dtls.md)
- [Wireshark y capturas](wireshark.md)
- [SSH y túneles](ssh.md)
- [OpenSSL y PKI (Tema 1)](../../tema1/comandos/openssl.md)
- [Transparencias — TLS, DTLS y QUIC](../../assets/pdf/SRDSI_T2-3.pdf)
