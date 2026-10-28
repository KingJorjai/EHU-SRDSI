# Código del laboratorio SSL

Recorrido de la migración de `serv-infouser.c` y `cli-infouser.c` a la API de sockets seguros de OpenSSL. Las copias que se enlazan son las de `docs/assets/codigo/lab-ssl/`; el material original está en `Tema 2: Seguridad en la comunicación/lab-ssl/source_files/`.

| Fichero | Papel |
| --- | --- |
| [`serv-infouser.c`](../../assets/codigo/lab-ssl/serv-infouser.c) | Servidor TLS: carga su certificado y clave, acepta conexiones y envía la salida de `w`. |
| [`cli-infouser.c`](../../assets/codigo/lab-ssl/cli-infouser.c) | Cliente TLS: verifica al servidor, descarga el listado y exporta el *keylog*. |
| [`tcp_server.c`](../../assets/codigo/lab-ssl/tcp_server.c) / [`tcp_client.c`](../../assets/codigo/lab-ssl/tcp_client.c) | Versión TCP en claro de partida. |
| [`ssl_server-auth.c`](../../assets/codigo/lab-ssl/ssl_server-auth.c) / [`ssl_client-auth.c`](../../assets/codigo/lab-ssl/ssl_client-auth.c) | Ejemplos de la teoría con autenticación mutua; no son la versión entregada. |

## 1. Protocolo de aplicación

El transporte cambia, pero el protocolo se mantiene. El servidor ejecuta `w > /tmp/file_users` y envía una cabecera ASCII `OK:<tamaño>` seguida del contenido del fichero por bloques. El cliente valida la cabecera, lee exactamente ese número de bytes y los escribe en el fichero local.

En la versión TCP se usaban `read`/`write` sobre el socket; en la versión TLS se sustituyen por `SSL_read`/`SSL_write` sobre un objeto `SSL` asociado al mismo descriptor.

## 2. Servidor

### 2.1. Contexto y certificados

El servidor crea un contexto con el método de servidor TLS y carga su certificado y su clave privada:

```c
method = TLS_server_method();
ctx = SSL_CTX_new(method);
CHK_NULL(ctx);

err = SSL_CTX_use_certificate_file(ctx, CERTFILE, SSL_FILETYPE_PEM);
CHK_SSL(err);
err = SSL_CTX_use_PrivateKey_file(ctx, KEYFILE, SSL_FILETYPE_PEM);
CHK_SSL(err);
err = SSL_CTX_check_private_key(ctx);
CHK_ERR(err, "La clave privada no corresponde al certificado\n");
```

`CERTFILE` y `KEYFILE` son `certificados/s_cert.pem` y `certificados/s_key.pem` (`serv-infouser.c:26-27`). `SSL_CTX_check_private_key` comprueba que la clave privada se corresponde con la clave pública del certificado; si no, el servidor no debe arrancar.

El servidor **no** llama a `SSL_CTX_load_verify_locations` ni a `SSL_CTX_set_verify` (`serv-infouser.c:106-107`): no pide certificado al cliente y, por tanto, no hace autenticación mutua.

!!! warning "Macros de error"
    `CHK_SSL` solo aborta cuando el valor devuelto es `-1`, pero muchas funciones de OpenSSL devuelven `0` al fallar. Por eso, si falta el fichero del certificado, la carga falla sin detener el proceso y el fallo se manifiesta más tarde, durante el handshake, como `no shared cipher` y `handshake_failure` (40). Es el comportamiento observado en el escenario 02.

### 2.2. Socket de escucha y `SO_REUSEADDR`

El socket TCP se crea, se configura y se pone a escuchar en el puerto fijo 1064 (`IPPORT_RESERVED + 40`):

```c
s = socket(PF_INET, SOCK_STREAM, 0);
setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
...
dir.sin_port = htons(PUERTO);
bind(s, (struct sockaddr *)&dir, sizeof(dir));
listen(s, 5);
```

`SO_REUSEADDR` permite reiniciar el servidor aunque queden conexiones en `TIME_WAIT` (`serv-infouser.c:115`).

### 2.3. Bucle de servicio

Por cada conexión aceptada se crea un estado TLS, se asocia al descriptor y se ejecuta el handshake:

```c
do {
    c = accept(s, NULL, 0);
    ssl = SSL_new(ctx);
    SSL_set_fd(ssl, c);
    err = SSL_accept(ssl);          /* handshake TLS */
    enviar_usuarios(ssl);            /* SSL_write por bloques */
    SSL_shutdown(ssl);
    SSL_free(ssl);
    close(c);
} while (1);
```

`SSL_accept` completa el handshake como servidor (`serv-infouser.c:136`). `enviar_usuarios` mantiene la lógica original, pero escribe la cabecera y los bloques del fichero con `SSL_write` (`serv-infouser.c:55` y `66`). Al terminar, `SSL_shutdown` envía el `close_notify` y `SSL_free` libera el estado TLS (`serv-infouser.c:144-145`).

## 3. Cliente

### 3.1. Contexto, cifrados y versión

El cliente crea un contexto con el método de cliente TLS y fija los cifrados y la versión máxima:

```c
method = TLS_client_method();
ctx = SSL_CTX_new(method);

SSL_CTX_set_cipher_list(ctx, "AES128-SHA256:AES256-CCM:AES256-GCM-SHA384");
SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION);
```

Los tres cifrados usan intercambio de clave RSA. La versión se limita a TLS 1.2 siguiendo el enunciado, que asume que Wireshark descifra TLS 1.2 con un fichero de secretos; así la captura se puede analizar en el montaje previsto del laboratorio.

### 3.2. Verificación del servidor

El cliente carga la CA del servidor y exige verificar su certificado:

```c
SSL_CTX_load_verify_locations(ctx, CA_CERT, NULL);    /* certificados/s-ca_cert.pem */
SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, NULL);
SSL_CTX_set_verify_depth(ctx, 1);
```

`CA_CERT` es `certificados/s-ca_cert.pem` (`cli-infouser.c:27`). Con `SSL_VERIFY_PEER` el handshake falla si el certificado del servidor no encadena hasta esa CA. La profundidad 1 basta porque el servidor presenta un certificado firmado directamente por `CA_SERV-SRDSI`.

### 3.3. Keylog

El callback de *keylog* recibe cada secreto de sesión y lo añade a `keylog-ssl.log`:

```c
void key_log_cb(const SSL *ssl, const char *line) {
    FILE *f = fopen("keylog-ssl.log", "a");
    if (f) {
        fprintf(f, "%s\n", line);
        fclose(f);
    }
}

SSL_CTX_set_keylog_callback(ctx, key_log_cb);
```

Ese fichero es el que se carga en Wireshark para descifrar la captura. El fichero se crea en el directorio de trabajo del cliente; en el laboratorio se ejecuta desde `source_files/`.

### 3.4. Conexión y lectura

Tras crear el socket TCP y conectar con el servidor, el cliente asocia el descriptor al objeto `SSL` y ejecuta el handshake:

```c
ssl = SSL_new(ctx);
SSL_set_fd(ssl, sock);
err = SSL_connect(ssl);
```

Después muestra el cifrado negociado y el resultado de la verificación:

```c
printf("Conectado con cifrado %s\n", SSL_get_cipher(ssl));
printf("Verificacion del servidor: %s\n",
       SSL_get_verify_result(ssl) == X509_V_OK ? "OK" : "FALLO");
```

La recepción usa `SSL_read`: primero lee la cabecera `OK:<tamaño>` (`cli-infouser.c:114`) y después itera hasta recibir exactamente ese número de bytes (`cli-infouser.c:135`). Al final cierra la sesión TLS con `SSL_shutdown`, libera el estado con `SSL_free` y cierra el socket.

## 4. Por qué no hay autenticación mutua

El cliente **no presenta certificado** y el servidor **no lo pide**:

- `cli-infouser.c` no llama a `SSL_CTX_use_certificate_file` ni a `SSL_CTX_use_PrivateKey_file`, así que no tiene certificado de cliente que enviar.
- `serv-infouser.c` no carga la CA de cliente y no configura `SSL_CTX_set_verify`, de modo que no envía un `CertificateRequest` durante el handshake.

El resultado es que TLS autentica **solo al servidor** y protege la confidencialidad e integridad del listado de usuarios, pero no autentica al cliente. Si se quisiera autenticación mutua, el servidor tendría que cargar la CA de cliente y usar `SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, NULL)`, y el cliente tendría que cargar `c_cert.pem` y `c_key.pem`. El laboratorio no lo hace porque el objetivo es únicamente proteger el canal y analizar las alertas.

## 5. Certificados

| Fichero | Sujeto (CN) | Emisor (CN) | Serial | Validez |
| --- | --- | --- | --- | --- |
| [`s-ca_cert.pem`](../../assets/certs/lab-ssl/s-ca_cert.pem) | `CA_SERV-SRDSI` | él mismo (autofirmado) | `69A15E5ACC9A15D1CBFA5E7221AAC361880B3058` | 2026-10-19 → 2037-10-01 |
| [`s_cert.pem`](../../assets/certs/lab-ssl/s_cert.pem) | `SERV-SRDSI` | `CA_SERV-SRDSI` | `865EE37EE2F16ABE` | 2026-10-19 → 2037-10-01 |
| [`s_key.pem`](../../assets/certs/lab-ssl/s_key.pem) | — | — | — | Clave privada del servidor |
| [`c-ca_cert.pem`](../../assets/certs/lab-ssl/c-ca_cert.pem) | `CA_CLI-SRDSI` | él mismo (autofirmado) | `65D3E2A35AEDB9C6A2B59C1EE8BBAC0B10DAEABE` | 2026-10-19 → 2037-10-01 |
| [`c_cert.pem`](../../assets/certs/lab-ssl/c_cert.pem) | `CLI-SRDSI` | `CA_CLI-SRDSI` | `16B61DD2792713CF` | 2026-10-19 → 2037-10-01 |
| [`c_key.pem`](../../assets/certs/lab-ssl/c_key.pem) | — | — | — | Clave privada del cliente (no usada) |

El escenario 03 consiste precisamente en sustituir la CA de confianza del cliente (`s-ca_cert.pem`) por la CA de cliente (`c-ca_cert.pem`), que no firma el certificado del servidor. Las dos CAs son independientes.
