# Ejercicios: TLS y DTLS

[:material-file-pdf-box: Enunciado de los ejercicios (PDF)](../../assets/pdf/lab-tls-dtls.pdf){ .md-button }

Esta página resuelve los **9 ejercicios** del enunciado `Lab-TLS_y_DTLS.pdf`: handshake TLS 1.2 y TLS 1.3, interoperabilidad, *forward secrecy*, autenticación de cliente, reutilización de sesión, 0-RTT, DTLS 1.2 y criptografía post-cuántica (PQC). Cada apartado incluye el objetivo, los comandos, una salida real resumida, la interpretación y los filtros de Wireshark.

!!! note "Versiones, certificados y alcance"
    Comandos comprobados con **OpenSSL 4.0.3** en el host y **Wireshark/tshark 4.7.4**. Se usan los certificados de `Tema 2: Seguridad en la comunicación/ejercicio-tls-dtls/lab-certs/`; no se ha modificado el material original. Las capturas y los ficheros de sesión se generaron en directorios temporales (`/tmp`) y **no se versionan**. En la VM del laboratorio la versión de OpenSSL es 3.5.7 y también están instalados `dumpcap`, `tshark` y Wireshark.

!!! warning "Puertos y capturas"
    Los ejemplos usan los puertos `4433` (TLS) y `4434` (DTLS). En las pruebas se emplearon puertos temporales altos para no chocar con otros procesos; el puerto no cambia el resultado. `dumpcap` necesita privilegios de captura: en el host el usuario pertenece al grupo `wireshark`; si no, usa `sudo dumpcap` o ejecuta la captura en la VM.

## Preparación

Todos los comandos se ejecutan desde `lab-certs`, porque los certificados se referencian por ruta relativa. La ruta del repositorio contiene espacios y dos puntos, así que hay que citarla:

```bash
cd "Tema 2: Seguridad en la comunicación/ejercicio-tls-dtls/lab-certs"
```

La cadena de confianza es **raíz + subCA**. `server.crt` y `client.crt` están firmados por `SUBCA-SRDSI`, no directamente por `CA-SRDSI`:

```bash
cat ca-root.crt subca.crt > /tmp/ca-chain.pem
openssl verify -CAfile /tmp/ca-chain.pem server.crt client.crt
```

```console
server.crt: OK
client.crt: OK
```

Comprobar los certificados que se van a usar:

```bash
openssl x509 -in server.crt -noout -subject -issuer -dates
openssl x509 -in serverpq.crt -noout -subject -issuer
openssl x509 -in serverpq.crt -noout -text | \
  grep -E 'Public Key Algorithm|Signature Algorithm'
```

```console
subject=C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
issuer=C=ES, ST=GI, O=SRDSI, OU=LABS, CN=SUBCA-SRDSI
notBefore=Oct 17 22:59:30 2026 GMT
notAfter=Oct 14 22:59:30 2036 GMT
subject=C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
issuer=C=ES, ST=GI, O=SRDSI, OU=LABS, CN=SUBCA-SRDSI
            Public Key Algorithm: ML-DSA-65
            Signature Algorithm: sha256WithRSAEncryption
```

Los certificados **no tienen SAN**; solo CN. OpenSSL acepta el CN como respaldo, pero los navegadores y las CAs públicas exigen SAN. `server2.crt`/`server2.key` no existen en el repositorio aunque el README los mencione.

Para las capturas se usan tres terminales: una para `dumpcap`, otra para `s_server` y otra para `s_client`.

## 1. Captura TLS 1.2 e identificación de mensajes

### Objetivo

Establecer una sesión TLS 1.2, capturarla en loopback y reconocer cada mensaje del handshake y los datos de aplicación.

### Comandos

Terminal 1, captura:

```bash
dumpcap -i lo -f 'tcp port 4433' -w /tmp/tls12.pcapng
```

Terminal 2, servidor TLS 1.2:

```bash
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_2 -quiet -naccept 1
```

Terminal 3, cliente con *keylog* para poder descifrar en Wireshark:

```bash
(printf 'hola tls12\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -keylogfile /tmp/tls12.keys -brief
```

Parar la captura con `Ctrl-C` en la terminal 1. También se puede enviar el mensaje de forma interactiva y terminar con `Q` + `Intro`.

Salida del cliente:

```console
Connecting to 127.0.0.1
CONNECTION ESTABLISHED
Protocol version: TLSv1.2
Ciphersuite: ECDHE-RSA-AES256-GCM-SHA384
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Hash used: SHA256
Signature type: rsa_pss_rsae_sha256
Verification: OK
Supported Elliptic Curve Point Formats: uncompressed
Peer Temp Key: X25519, 253 bits
```

Mensajes vistos con `tshark`:

```bash
tshark -r /tmp/tls12.pcapng -Y 'tls' \
  -T fields -e frame.number -e _ws.col.Info
```

```console
4	Client Hello
6	Server Hello, Certificate, Server Key Exchange, Server Hello Done
8	Client Key Exchange, Change Cipher Spec, Encrypted Handshake Message
9	New Session Ticket, Change Cipher Spec, Encrypted Handshake Message
10	Application Data
11	Encrypted Alert
13	Encrypted Alert
```

Con el *keylog* cargado, `Finished` se muestra descifrado y la traza queda más legible:

```bash
tshark -r /tmp/tls12.pcapng -o tls.keylog_file:/tmp/tls12.keys \
  -Y 'tls' -T fields -e frame.number -e _ws.col.Info
```

```console
4	Client Hello
6	Server Hello, Certificate, Server Key Exchange, Server Hello Done
8	Client Key Exchange, Change Cipher Spec, Finished
9	New Session Ticket, Change Cipher Spec, Finished
10	Application Data
11	Alert (Level: Warning, Description: Close Notify)
13	Alert (Level: Warning, Description: Close Notify)
```

### Interpretación

| Mensaje | Papel en TLS 1.2 |
| --- | --- |
| `ClientHello` | Versión máxima, `random` del cliente, ID de sesión, lista de *cipher suites* y extensiones (grupos, `key_share`, algoritmos de firma, SNI). |
| `ServerHello` | Versión y *cipher suite* elegidas, `random` del servidor, ID de sesión y extensión `key_share` del servidor. |
| `Certificate` | Certificado del servidor y, si se configura, la cadena de intermedios (`-cert_chain subca.crt`). |
| `ServerKeyExchange` | Parámetros efímeros de ECDHE y firma con la clave del servidor. No aparece si se usa RSA como intercambio. |
| `ServerHelloDone` | El servidor termina su turno. |
| `ClientKeyExchange` | Parte pública efímera del cliente (X25519 en este caso). |
| `ChangeCipherSpec` | Activa el cifrado de los mensajes siguientes. |
| `Finished` | Primer mensaje cifrado; MAC sobre todo el handshake. |
| `Application Data` | Datos de la aplicación ya protegidos. |
| `New Session Ticket` | Ticket de sesión para una reanudación posterior. |
| `Alert` | Cierre ordenado (`close_notify`) o error. |

En Wireshark se puede filtrar el handshake con `tls.handshake.type == 1` (`ClientHello`), `== 2` (`ServerHello`), `== 11` (`Certificate`), `== 12` (`ServerKeyExchange`), `== 14` (`ServerHelloDone`), `== 16` (`ClientKeyExchange`), `== 20` (`Finished`) y `== 4` (`NewSessionTicket`). Para ver el flujo completo: clic derecho sobre un paquete TLS → **Follow → TLS Stream**. Con el keylog cargado en **Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename**, el texto de la aplicación aparece descifrado.

**Resultado**: la sesión negocia TLS 1.2 con `ECDHE-RSA-AES256-GCM-SHA384`, el cliente valida la cadena hasta `CA-SRDSI` y la captura muestra el handshake completo seguido de `Application Data`.

[:material-file-pdf-box: Enunciado — ejercicio 1 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 2. Diferencias entre TLS 1.2 y TLS 1.3

### Objetivo

Repetir la captura con TLS 1.3 y comparar el handshake, la visibilidad de los certificados y el número de viajes.

### Comandos

Terminal 1:

```bash
dumpcap -i lo -f 'tcp port 4433' -w /tmp/tls13.pcapng
```

Terminal 2:

```bash
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_3 -quiet -naccept 1
```

Terminal 3:

```bash
(printf 'hola tls13\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_3 \
  -CAfile /tmp/ca-chain.pem -keylogfile /tmp/tls13.keys -brief
```

Salida:

```console
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Hash used: SHA256
Signature type: rsa_pss_rsae_sha256
Verification: OK
Negotiated TLS1.3 group: X25519MLKEM768
```

Sin *keylog*, Wireshark solo reconoce el `ClientHello` y el `ServerHello`; todo lo demás es `Application Data`:

```console
4	Client Hello
6	Server Hello, Change Cipher Spec, Application Data, Application Data, Application Data, Application Data
8	Change Cipher Spec, Application Data
9	Application Data
10	Application Data
11	Application Data
13	Application Data
```

Con el *keylog* del cliente se descifra el resto:

```console
4	Client Hello
6	Server Hello, Change Cipher Spec, Encrypted Extensions, Certificate, Certificate Verify, Finished
8	Change Cipher Spec, Finished
9	New Session Ticket
10	New Session Ticket
11	Alert (Level: Warning, Description: Close Notify)
13	Alert (Level: Warning, Description: Close Notify)
```

### Interpretación

| Aspecto | TLS 1.2 | TLS 1.3 |
| --- | --- | --- |
| Handshake completo | 2 RTT | 1 RTT |
| Intercambio de claves | `ServerKeyExchange` + `ClientKeyExchange` | `key_share` en las extensiones del `ClientHello`/`ServerHello` |
| Certificado del servidor | En claro, antes de `ChangeCipherSpec` | Cifrado, dentro de `Encrypted Extensions`/`Certificate` |
| `ServerHelloDone` | Sí | No existe |
| `ChangeCipherSpec` | Cambia el cifrado | Solo compatibilidad; el cifrado ya está activo en el `ServerHello` |
| *Cipher suites* | Combinan Kx, autenticación, cifrado y hash | Solo cifrado y hash AEAD (`TLS_AES_256_GCM_SHA384`, etc.) |
| Reanudación | ID de sesión o *ticket* | PSK / *tickets* (`NewSessionTicket`) |
| 0-RTT | No | Sí, con una sesión PSK previa |
| Algoritmos | RSA, ECDHE, DHE, etc. | ECDHE/DHE con grupos modernos; RSA estático fuera del intercambio |

El `ClientHello` de TLS 1.3 mantiene `legacy_version = 0x0303` por compatibilidad; la versión real viaja en la extensión `supported_versions`. En Wireshark se ve `TLS 1.3` en el resumen, pero la cabecera de registro puede seguir mostrando `0x0303`.

**Resultado**: TLS 1.3 reduce el handshake a un viaje, cifra el certificado y la verificación del servidor, y usa *cipher suites* AEAD independientes del intercambio de claves.

[:material-file-pdf-box: Enunciado — ejercicio 2 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 3. Interoperabilidad entre TLS 1.2 y TLS 1.3

### Objetivo

Comprobar si un cliente y un servidor de versiones distintas pueden entenderse y qué ocurre al forzar versiones incompatibles.

### Comandos

Cliente y servidor con la versión por defecto (sin `-tls1_2` ni `-tls1_3`), servidor limitado a 1.2:

```bash
# Terminal 1
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_2 -quiet -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4433 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
Protocol version: TLSv1.2
Ciphersuite: ECDHE-RSA-AES256-GCM-SHA384
Verification: OK
```

Ahora el servidor solo admite 1.3:

```bash
# Terminal 1
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_3 -quiet -naccept 1

# Terminal 2
openssl s_client -connect 127.0.0.1:4433 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Verification: OK
```

Forzar versiones incompatibles:

```bash
# Servidor 1.2 y cliente 1.3
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_2 -quiet -naccept 1

openssl s_client -connect 127.0.0.1:4433 -tls1_3 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
error:...:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version:...:SSL alert number 70
```

Lo mismo ocurre con servidor 1.3 y cliente 1.2. El servidor responde con la alerta **70** (`protocol_version`).

### Interpretación

- **Sí pueden interactuar** si existe al menos una versión común: el cliente ofrece su rango y el servidor elige la versión más alta que ambos soportan. Un cliente moderno sin `-tls1_3` forzado negocia TLS 1.2 con un servidor que solo habla 1.2.
- **No pueden interactuar** si se fija una única versión distinta en cada extremo. No hay *fallback* mágico: el cliente 1.3 no “baja” a 1.2 si se le prohíbe, ni al revés.
- En la captura, un fallo por versión muestra `ClientHello`, una alerta del servidor y el cierre. No llega a haber `Certificate` ni datos de aplicación.
- Filtro útil: `tls.alert_message.desc == 70` (`protocol_version`).

**Resultado**: la negociación funciona cuando hay versiones comunes y falla con `protocol_version` cuando se fuerzan versiones incompatibles.

[:material-file-pdf-box: Enunciado — ejercicio 3 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 4. RSA y ausencia de *forward secrecy*

### Objetivo

Demostrar que el intercambio de claves RSA estático no proporciona *forward secrecy* y compararlo con ECDHE.

### Comandos

Servidor y cliente TLS 1.2 con cifrados de intercambio RSA:

```bash
# Terminal 1: captura
dumpcap -i lo -f 'tcp port 4433' -w /tmp/rsa.pcapng

# Terminal 2
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_2 -cipher RSA -quiet -naccept 1

# Terminal 3
(printf 'hola rsa\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -cipher RSA \
  -CAfile /tmp/ca-chain.pem -brief
```

Salida:

```console
Protocol version: TLSv1.2
Ciphersuite: AES256-GCM-SHA384
Verification: OK
```

No aparece `Peer Temp Key` ni `ServerKeyExchange`: el servidor no aporta una clave efímera. La captura lo confirma:

```console
4	Client Hello
6	Server Hello, Certificate, Server Hello Done
8	Client Key Exchange, Change Cipher Spec, Encrypted Handshake Message
9	New Session Ticket, Change Cipher Spec, Encrypted Handshake Message
```

El `ClientKeyExchange` contiene el secreto premaster cifrado con la clave pública RSA del servidor:

```bash
tshark -r /tmp/rsa.pcapng -Y 'tls.handshake.type == 16' -V | \
  sed -n '/Client Key Exchange/,/Change Cipher Spec/p'
```

```console
Handshake Type: Client Key Exchange (16)
Length: 258
RSA Encrypted PreMaster Secret
    Encrypted PreMaster length: 256
```

En cambio, con ECDHE (ejercicio 1) hay `ServerKeyExchange` y el `ClientKeyExchange` solo lleva una clave pública de 32 bytes:

```console
Handshake Type: Client Key Exchange (16)
Length: 33
EC Diffie-Hellman Client Params
    Pubkey Length: 32
    Pubkey: 521784d24bc7d6a9d4aa1d0240013bae5781ffc1a31322da61dd09dab9cf2a1a
```

### Interpretación

Con RSA estático, el cliente elige el premaster y lo cifra con la clave pública del servidor. La clave de sesión depende solo de:

1. el premaster cifrado que viaja en la captura, y
2. la clave privada RSA del servidor.

Por eso, **quien capture el tráfico y obtenga más tarde la clave privada del servidor puede descifrar la sesión completa**. Eso es precisamente lo que falta de *forward secrecy*: la compromisión futura de la clave privada compromete sesiones pasadas.

Con ECDHE, el servidor firma un par efímero con su clave de larga duración, pero el secreto compartido se calcula con las claves efímeras y se destruye al terminar. La clave privada del servidor ya no basta para recuperar sesiones antiguas.

!!! note "Wireshark 4.7 y la lista de claves RSA"
    En versiones antiguas de Wireshark se podía añadir la clave RSA del servidor en **Edit → Preferences → Protocols → TLS → RSA keys list** y descifrar la captura. Wireshark 4.7.4 ya no expone esa preferencia (`tls.keys_list` aparece como *obsolete preference*). En el host, la demostración se hace con la estructura del handshake: `Encrypted PreMaster length: 256` y ausencia de `ServerKeyExchange`. El *keylog* descifra tanto RSA como ECDHE porque contiene el secreto maestro; por eso **no** sirve para demostrar *forward secrecy*.

**Resultado**: RSA estático cifra el premaster con la clave pública del servidor y no ofrece *forward secrecy*; ECDHE usa claves efímeras y sí la ofrece.

[:material-file-pdf-box: Enunciado — ejercicio 4 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 5. Autenticación de cliente en TLS 1.2

### Objetivo

Exigir certificado de cliente, identificar los mensajes nuevos y comprobar qué se ve en TLS 1.3.

### Comandos

Servidor que exige certificado de cliente firmado por la cadena de confianza:

```bash
# Terminal 1: captura
dumpcap -i lo -f 'tcp port 4433' -w /tmp/mtls12.pcapng

# Terminal 2
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -CAfile /tmp/ca-chain.pem -Verify 1 -tls1_2 -quiet -naccept 1

# Terminal 3
(printf 'hola mtls\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -cert client.crt -key client.key \
  -keylogfile /tmp/mtls12.keys -brief
```

Salida del cliente:

```console
Protocol version: TLSv1.2
Ciphersuite: ECDHE-RSA-AES256-GCM-SHA384
Own signature type: rsa_pss_rsae_sha256
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Verification: OK
```

Salida del servidor:

```console
verify depth is 1, must return a certificate
depth=2 C=ES, ST=GI, O=SRDSI, OU=LABS, CN=CA-SRDSI
verify return:1
depth=1 C=ES, ST=GI, O=SRDSI, OU=LABS, CN=SUBCA-SRDSI
verify return:1
depth=0 C=ES, ST=GI, O=SRDSI, OU=LABS, CN=client, emailAddress=client@srdsi.lab
verify return:1
```

Mensajes TLS 1.2:

```bash
tshark -r /tmp/mtls12.pcapng -Y 'tls' \
  -T fields -e frame.number -e _ws.col.Info
```

```console
4	Client Hello
6	Server Hello, Certificate, Server Key Exchange, Certificate Request, Server Hello Done
8	Certificate, Client Key Exchange, Certificate Verify, Change Cipher Spec, Encrypted Handshake Message
9	New Session Ticket, Change Cipher Spec, Encrypted Handshake Message
10	Application Data
11	Encrypted Alert
13	Encrypted Alert
```

Si el cliente **no** presenta certificado, el servidor corta el handshake:

```bash
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -brief
```

```console
error:...:SSL routines:ssl3_read_bytes:tls alert handshake failure:...:SSL alert number 40
```

### Interpretación

Los mensajes nuevos son:

| Mensaje | Sentido | Contenido |
| --- | --- | --- |
| `CertificateRequest` | Servidor → cliente | Tipos de certificado y CAs aceptadas. |
| `Certificate` | Cliente → servidor | Certificado del cliente (y cadena, si se envía). |
| `CertificateVerify` | Cliente → servidor | Firma con la clave privada del cliente sobre el transcript del handshake. |

`ClientKeyExchange` sigue existiendo, pero ahora el cliente se autentica además con su certificado. La opción **`-Verify`** (mayúscula) del servidor exige certificado de cliente; **`-verify`** (minúscula) del cliente solo verifica al servidor. Son distintas y sensibles a mayúsculas.

**En TLS 1.3 estos mensajes también existen, pero van cifrados**. Sin *keylog*, Wireshark solo muestra `Application Data`; con el *keylog* aparecen `Certificate Request`, `Certificate` y `Certificate Verify` dentro del vuelo del servidor y del cliente:

```console
4	Client Hello
6	Server Hello, Change Cipher Spec, Encrypted Extensions, Certificate Request, Certificate, Certificate Verify
8	Finished
10	Change Cipher Spec, Certificate, Certificate Verify, Finished
```

**Resultado**: el servidor acepta únicamente clientes con un certificado válido emitido por la CA configurada. En TLS 1.2 los mensajes de autenticación de cliente son visibles; en TLS 1.3 están cifrados y requieren el *keylog* para analizarlos.

[:material-file-pdf-box: Enunciado — ejercicio 5 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 6. Reutilización de sesión TLS 1.2

### Objetivo

Guardar una sesión TLS 1.2 y reutilizarla, comparando el handshake completo con el abreviado.

### Comandos

Servidor preparado para atender dos conexiones:

```bash
# Terminal 1: captura
dumpcap -i lo -f 'tcp port 4433' -w /tmp/resume.pcapng

# Terminal 2
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_2 -quiet -naccept 2
```

Primera conexión: handshake completo y guardado de la sesión.

```bash
(printf 'primera\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -keylogfile /tmp/resume1.keys \
  -sess_out /tmp/sess.pem
```

```console
New, TLSv1.2, Cipher is ECDHE-RSA-AES256-GCM-SHA384
```

Segunda conexión: reutilización de la sesión guardada.

```bash
(printf 'segunda\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -keylogfile /tmp/resume2.keys \
  -sess_in /tmp/sess.pem
```

```console
Reused, TLSv1.2, Cipher is ECDHE-RSA-AES256-GCM-SHA384
```

Inspeccionar la sesión guardada:

```bash
openssl sess_id -in /tmp/sess.pem -noout -text | \
  grep -E 'Protocol|Cipher|Session-ID|ticket lifetime|Timeout'
```

```console
Protocol  : TLSv1.2
Cipher    : ECDHE-RSA-AES256-GCM-SHA384
Session-ID: 1A24589D90B39E97FCD1F8CFD0BEA0021142CF62AB0A8295B7D006A01DE32A69
TLS session ticket lifetime hint: 7200 (seconds)
Timeout   : 7200 (sec)
```

Comparación de handshakes en la captura:

```bash
tshark -r /tmp/resume.pcapng \
  -Y 'tls.handshake.type == 1 || tls.handshake.type == 2 || tls.handshake.type == 4 || tls.handshake.type == 11 || tls.handshake.type == 12 || tls.handshake.type == 14 || tls.handshake.type == 16' \
  -T fields -e frame.number -e tcp.stream -e tls.handshake.type -e _ws.col.Info
```

```console
4	0	1	Client Hello
6	0	2,11,12,14	Server Hello, Certificate, Server Key Exchange, Server Hello Done
8	0	16	Client Key Exchange, Change Cipher Spec, Encrypted Handshake Message
9	0	4	New Session Ticket, Change Cipher Spec, Encrypted Handshake Message
18	1	1	Client Hello
20	1	2	Server Hello, Change Cipher Spec, Encrypted Handshake Message
```

### Interpretación

- La primera conexión muestra `New, TLSv1.2`: handshake completo con `Certificate`, `ServerKeyExchange`, `ClientKeyExchange` y `Finished`.
- La segunda muestra `Reused, TLSv1.2`: handshake abreviado. El servidor reconoce el ID de sesión o el *ticket* y reutiliza el secreto maestro; no vuelve a enviar el certificado ni a hacer el intercambio de claves.
- OpenSSL usa **tickets** de sesión por defecto (con `-no_ticket` se desactivan). El ID de sesión y el *ticket* son mecanismos distintos, pero ambos permiten reanudar. El *ticket* lo descifra el servidor con una clave propia y no necesita mantener estado por cliente.
- En Wireshark, la segunda conexión se analiza con `tcp.stream == 1` (o el flujo que corresponda). La diferencia clave es la ausencia de `Certificate` y `ServerKeyExchange` y la presencia de `ChangeCipherSpec` muy pronto.
- La reanudación no debe confundirse con 0-RTT: en TLS 1.2 el cliente sigue esperando al `ServerHello` antes de enviar datos de aplicación.

**Resultado**: `-sess_out` guarda la sesión, `-sess_in` la reutiliza y el servidor responde `Reused`. El handshake abreviado ahorra certificados y operaciones de clave pública.

[:material-file-pdf-box: Enunciado — ejercicio 6 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 7. 0-RTT en TLS 1.3

### Objetivo

Establecer una sesión TLS 1.3 con datos tempranos (*early data*) y analizar el riesgo de *replay*.

### Comandos

Preparar el fichero que se enviará como 0-RTT:

```bash
printf 'datos 0-RTT\n' > /tmp/early.txt
```

Servidor que acepta datos tempranos:

```bash
# Terminal 1: captura
dumpcap -i lo -f 'tcp port 4433' -w /tmp/early.pcapng

# Terminal 2
openssl s_server -accept 127.0.0.1:4433 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -tls1_3 -early_data -quiet -naccept 2
```

Primera conexión para obtener un *ticket* de sesión:

```bash
(printf 'primera\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_3 \
  -CAfile /tmp/ca-chain.pem -sess_out /tmp/sess13.pem \
  -keylogfile /tmp/early1.keys
```

Segunda conexión con datos 0-RTT:

```bash
(printf 'segunda\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_3 \
  -CAfile /tmp/ca-chain.pem -sess_in /tmp/sess13.pem \
  -early_data /tmp/early.txt -keylogfile /tmp/early2.keys
```

Salida relevante del cliente (sin `-brief`, para ver el resumen de sesión):

```console
Reused, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Early data was accepted
    Max Early Data: 16384
```

El servidor imprime el contenido recibido antes del handshake completo:

```console
datos 0-RTT
```

En la captura, el primer vuelo del cliente ya lleva datos de aplicación:

```console
20	1	Client Hello, Change Cipher Spec, Application Data
22	1	Server Hello, Change Cipher Spec, Application Data, Application Data
```

### Interpretación

El cliente reutiliza el PSK del *ticket* y envía `early_data` junto al `ClientHello`, **antes** de recibir el `ServerHello`. El servidor solo lo acepta si el *ticket* es válido, no ha caducado y la política anti-replay lo permite. OpenSSL activa `-anti_replay` por defecto; `-no_anti_replay` es solo para laboratorio.

Riesgos principales:

- **Replay**: un atacante puede reenviar el mismo vuelo 0-RTT. Si la aplicación ejecuta una acción no idempotente (pagar, borrar, cambiar estado), el efecto se repite. Solo deben enviarse operaciones seguras de repetir (por ejemplo, un `GET`).
- **Sin verificación fresca del servidor**: el cliente envía datos antes de ver el certificado actual del servidor. La autenticación se apoya en el PSK de la sesión anterior.
- **Privacidad y forward secrecy**: los datos 0-RTT se protegen con claves derivadas del PSK; no tienen la misma garantía que los datos 1-RTT.
- **Anti-replay no distribuido**: un servidor con varias instancias necesita compartir el estado anti-replay; si no, el mismo vuelo puede aceptarse en otra instancia.

En Wireshark, con el *keylog* cargado, se puede filtrar `tcp.stream == 1 && tls.app_data` y comprobar que el primer `Application Data` aparece antes del `ServerHello`. Sin *keylog*, Wireshark lo marca como `Application Data` y no se puede leer.

**Resultado**: la sesión reutilizada acepta datos tempranos (`Early data was accepted`) y el servidor los recibe antes de completar el handshake. Es una optimización de latencia con riesgos de *replay* que deben gestionarse en la aplicación.

[:material-file-pdf-box: Enunciado — ejercicio 7 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 8. DTLS 1.2

### Objetivo

Capturar una sesión DTLS 1.2 y compararla con TLS 1.2: transporte UDP, *cookies*, fragmentación y retransmisiones.

### Comandos

DTLS no admite `-www`; se usa `-quiet` y se envían datos por la entrada estándar:

```bash
# Terminal 1: captura UDP
dumpcap -i lo -f 'udp port 4434' -w /tmp/dtls.pcapng

# Terminal 2
openssl s_server -dtls1_2 -accept 127.0.0.1:4434 \
  -cert server.crt -key server.key -cert_chain subca.crt \
  -quiet -naccept 1

# Terminal 3
(printf 'hola dtls\n'; sleep 1) | \
openssl s_client -dtls1_2 -connect 127.0.0.1:4434 \
  -CAfile /tmp/ca-chain.pem -brief
```

Salida del cliente:

```console
Protocol version: DTLSv1.2
Ciphersuite: ECDHE-RSA-AES256-GCM-SHA384
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Hash used: SHA256
Signature type: rsa_pss_rsae_sha256
Verification: OK
Supported Elliptic Curve Point Formats: uncompressed
Peer Temp Key: X25519, 253 bits
```

Mensajes en la captura:

```bash
tshark -r /tmp/dtls.pcapng -Y 'dtls' \
  -T fields -e frame.number -e _ws.col.Info
```

```console
1	Client Hello
2	Hello Verify Request
3	Client Hello
4	Server Hello, Certificate (Fragment)
5	Certificate (Fragment)
...
15	Certificate (Reassembled), Server Key Exchange (Fragment)
16	Server Key Exchange (Fragment)
17	Server Key Exchange (Reassembled), Server Hello Done
18	Client Key Exchange, Change Cipher Spec, Encrypted Handshake Message
19	New Session Ticket
20	Change Cipher Spec, Encrypted Handshake Message
21	Application Data
22	Encrypted Alert
23	Encrypted Alert
```

Los registros DTLS dejan claro el transporte:

```bash
tshark -r /tmp/dtls.pcapng \
  -T fields -e frame.number -e udp.srcport -e udp.dstport \
  -e dtls.record.content_type -e dtls.handshake.type -e _ws.col.Info
```

```console
1	44377	14811	22	1	Client Hello
2	14811	44377	22	3	Hello Verify Request
3	44377	14811	22	1	Client Hello
4	14811	44377	22,22	2,11	Server Hello, Certificate (Fragment)
...
18	44377	14811	22,20,22	16	Client Key Exchange, Change Cipher Spec, Encrypted Handshake Message
21	44377	14811	23		Application Data
```

### Interpretación

| Aspecto | TLS 1.2 | DTLS 1.2 |
| --- | --- | --- |
| Transporte | TCP | UDP |
| Entrega | Fiable y ordenada por TCP | No fiable; DTLS añade números de secuencia y retransmisiones |
| Handshake | Directo | `Hello Verify Request` con *cookie* para evitar *flooding* |
| Fragmentación | La maneja TCP | Fragmentos DTLS a nivel de handshake (`Certificate (Fragment)` / `(Reassembled)`) |
| Registro | Contenido, versión, longitud | Añade época, número de secuencia y longitud; el número de secuencia se usa también como nonce |
| `-www` | Disponible en `s_server` | No disponible; usar `-quiet` y entrada estándar |
| Puertos de ejemplo | TCP/4433 | UDP/4434 |

La *cookie* de `Hello Verify Request` obliga al cliente a demostrar que puede recibir en su dirección antes de que el servidor reserve estado. La fragmentación es necesaria porque un datagrama UDP puede ser pequeño y el certificado no cabe en uno solo. Si se pierde un vuelo, DTLS retransmite con el mismo número de secuencia de registro; Wireshark permite verlo con `dtls.record.sequence_number` y comparando los tiempos.

Filtros útiles: `dtls`, `udp.port == 4434`, `dtls.handshake.type == 3` (`HelloVerifyRequest`), `dtls.fragment.error` para fragmentos incompletos.

**Resultado**: DTLS 1.2 establece la sesión sobre UDP, muestra `Hello Verify Request`, fragmenta el certificado y reensambla los mensajes. El handshake es equivalente a TLS 1.2, pero adaptado a un transporte sin fiabilidad.

[:material-file-pdf-box: Enunciado — ejercicio 8 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## 9. TLS 1.3 con algoritmos post-cuánticos

### Objetivo

Usar una clave de servidor **ML-DSA-65** y un grupo híbrido **X25519MLKEM768** en TLS 1.3, y comprobar la firma y el grupo negociados.

### Comandos

El certificado `serverpq.crt` tiene clave pública **ML-DSA-65**, pero está firmado por la subCA RSA (`sha256WithRSAEncryption`). Eso es normal: la clave del servidor autentica el handshake; la firma del certificado la hace la CA.

Servidor y cliente restringidos al grupo híbrido:

```bash
# Terminal 1: captura
dumpcap -i lo -f 'tcp port 4433' -w /tmp/pqc.pcapng

# Terminal 2
openssl s_server -accept 127.0.0.1:4433 \
  -cert serverpq.crt -key serverpq.key -cert_chain subca.crt \
  -tls1_3 -groups X25519MLKEM768 -quiet -naccept 1

# Terminal 3
(printf 'hola pqc\n'; sleep 1) | \
openssl s_client -connect 127.0.0.1:4433 -tls1_3 \
  -groups X25519MLKEM768 -CAfile /tmp/ca-chain.pem \
  -keylogfile /tmp/pqc.keys -brief
```

Salida:

```console
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: C=ES, ST=GI, O=SRDSI, OU=LABS, CN=www.srdsi.lab, emailAddress=webadmin@srdsi.lab
Hash used: UNDEF
Signature type: mldsa65
Verification: OK
Negotiated TLS1.3 group: X25519MLKEM768
```

`Hash used: UNDEF` es esperable: ML-DSA no usa un hash externo al estilo RSA/ECDSA; la firma lleva su propio esquema. El certificado se valida igualmente con la cadena hasta la raíz.

Con el *keylog* cargado, Wireshark descifra el `CertificateVerify` y muestra el algoritmo:

```bash
tshark -r /tmp/pqc.pcapng -o tls.keylog_file:/tmp/pqc.keys \
  -Y 'tls.handshake.type == 15' -V | \
  grep -E 'Signature Algorithm|Signature length|Handshake Type'
```

```console
Handshake Type: Certificate Verify (15)
Signature Algorithm: mldsa65 (0x0905)
Signature length: 3309
```

El grupo negociado se puede comprobar en el `ClientHello`/`ServerHello`:

```bash
tshark -r /tmp/pqc.pcapng \
  -Y 'tls.handshake.type == 1 || tls.handshake.type == 2' \
  -T fields -e frame.number -e tls.handshake.type \
  -e tls.handshake.extensions_supported_group \
  -e tls.handshake.extensions_key_share_selected_group
```

```console
4	1	0x11ec
6	2		4588
```

`0x11ec` = **4588** = `X25519MLKEM768`. Wireshark muestra el nombre si su versión reconoce el grupo; si no, deja el valor numérico. En versiones antiguas puede aparecer como `Unknown`.

### Interpretación

Este ejercicio combina dos piezas PQC distintas:

| Pieza | Algoritmo | Dónde se usa |
| --- | --- | --- |
| Intercambio de claves | `X25519MLKEM768` (híbrido X25519 + ML-KEM-768) | Extensión `key_share` del `ClientHello`/`ServerHello` |
| Autenticación del servidor | `ML-DSA-65` | Firma del `CertificateVerify` con la clave de `serverpq.key` |
| Firma del certificado | RSA de la subCA | Cadena de confianza `serverpq.crt` → `subca.crt` → `ca-root.crt` |

El grupo híbrido combina un intercambio clásico (X25519) con uno post-cuántico (ML-KEM-768). Si uno de los dos se rompe, el otro sigue protegiendo la sesión; es la transición recomendada frente a la amenaza de un ordenador cuántico que ejecute el algoritmo de Shor. ML-DSA-65 protege la autenticación del servidor frente a un atacante cuántico que intente falsificar la firma.

Tamaños observados: la clave privada `serverpq.key` ocupa 5604 bytes y el certificado `serverpq.crt` 14877 bytes, muy por encima de una clave RSA/ECDSA equivalente. Eso aumenta el tamaño del handshake y puede requerir fragmentación en DTLS.

Requisitos: OpenSSL con soporte ML-DSA (3.5 o superior; aquí 4.0.3). Si el cliente no ofrece `X25519MLKEM768`, la negociación puede caer a un grupo clásico; `-groups` permite forzar el conjunto. Para comprobar que el servidor realmente firma con ML-DSA, no basta con mirar el certificado: hay que revisar el `Signature type` del cliente o el `CertificateVerify` descifrado.

**Resultado**: TLS 1.3 negocia el grupo híbrido `X25519MLKEM768` y el servidor firma con `mldsa65`. La cadena de confianza sigue siendo RSA, pero la autenticación del handshake y el intercambio de claves ya incorporan PQC.

[:material-file-pdf-box: Enunciado — ejercicio 9 (PDF)](../../assets/pdf/lab-tls-dtls.pdf#page=1)

## Problemas típicos

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `unable to get local issuer certificate` | Falta la subCA en el almacén de confianza. | Usa `/tmp/ca-chain.pem` o `-untrusted subca.crt`. |
| `alert protocol version` (70) | Cliente y servidor forzados a versiones distintas. | Deja negociar o usa la misma versión en ambos extremos. |
| `no protocols available` | No hay ninguna versión común. | Revisa `-tls1_2`/`-tls1_3` en servidor y cliente. |
| `certificate verify failed` | CA incorrecta, certificado caducado o CN distinto. | Comprueba `-CAfile`, fechas y `openssl verify`. |
| `handshake failure` (40) con `-Verify` | El cliente no presenta certificado o no es de la CA. | Añade `-cert client.crt -key client.key`. |
| `Can't use -HTTP, -www or -WWW with DTLS` | `-www` no es válido en DTLS. | Usa `-quiet` y envía datos por la entrada estándar. |
| `bind: Address already in use` | Otro proceso ocupa el puerto. | `ss -lunp | grep :4434` y elige otro puerto. |
| `Can't open session file` | La primera conexión no guardó la sesión o caducó. | Repite con `-sess_out` y comprueba que el cliente terminó bien. |
| `Early data was not accepted` | *Ticket* caducado, anti-replay o servidor sin `-early_data`. | Revisa `-early_data`, el *ticket* y la política anti-replay. |
| Wireshark no descifra | *Keylog* incorrecto o cargado después de abrir la captura. | Carga el *keylog* correcto (TLS 1.2 y TLS 1.3 usan secretos distintos) y recarga. |
| Un grupo PQC aparece como `Unknown` | Wireshark no reconoce el grupo o el algoritmo. | Actualiza Wireshark o usa el valor numérico (`0x11ec` = 4588). |

## Enlaces

- [Enunciado de los ejercicios (PDF)](../../assets/pdf/lab-tls-dtls.pdf)
- [OpenSSL TLS/DTLS: `s_server` y `s_client`](../comandos/openssl-tls.md): sintaxis completa, opciones y ejemplos.
- [Wireshark, dumpcap y tshark](../comandos/wireshark.md): captura, filtros y descifrado con *keylog*.
- [Teoría: TLS, DTLS y QUIC](../teoria/tls-dtls.md): protocolo, versiones y criptografía.
- [Recursos y PDFs](../../recursos/pdfs.md): material del curso.

!!! note "Material original"
    Las fuentes del laboratorio están en `Tema 2: Seguridad en la comunicación/ejercicio-tls-dtls/`: `Lab-TLS_y_DTLS.pdf`, `lab-certs/` y su `README`. Esta página no modifica ese material; las salidas mostradas se obtuvieron con los certificados y claves originales en directorios temporales.
