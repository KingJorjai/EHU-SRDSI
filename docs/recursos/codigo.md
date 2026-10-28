# Código de los laboratorios

Fuentes, scripts y configuraciones que acompañan a las prácticas. Están publicados como copia de solo lectura en `docs/assets/`; el material original vive en sus directorios de tema y no se modifica.

## Cliente y servidor TLS (`lab-ssl`)

| Fichero | Papel |
| --- | --- |
| [`serv-infouser.c`](../assets/codigo/lab-ssl/serv-infouser.c) | Servidor TLS: carga `certificados/s_cert.pem` y `s_key.pem`, acepta conexiones en el puerto 1064 y envía la salida de `w`. |
| [`cli-infouser.c`](../assets/codigo/lab-ssl/cli-infouser.c) | Cliente TLS: verifica al servidor con `certificados/s-ca_cert.pem`, descarga el listado y escribe `keylog-ssl.log`. |
| [`tcp_server.c`](../assets/codigo/lab-ssl/tcp_server.c) | Versión TCP en claro del servidor (punto de partida). |
| [`tcp_client.c`](../assets/codigo/lab-ssl/tcp_client.c) | Versión TCP en claro del cliente. |
| [`ssl_server-auth.c`](../assets/codigo/lab-ssl/ssl_server-auth.c) | Ejemplo de la teoría con autenticación mutua; no es la versión entregada. |
| [`ssl_client-auth.c`](../assets/codigo/lab-ssl/ssl_client-auth.c) | Ejemplo de la teoría con autenticación mutua; no es la versión entregada. |

La versión entregada (`serv-infouser` / `cli-infouser`) autentica **solo al servidor**: el servidor no pide certificado de cliente y el cliente no presenta `c_cert.pem`. Los ejemplos `ssl_*-auth.c` sí muestran autenticación mutua.

[:octicons-arrow-right-24: Ver más — Código del laboratorio SSL](../tema2/lab-ssl/codigo.md)
[:octicons-arrow-right-24: Ver más — Guía del laboratorio SSL](../tema2/lab-ssl/guia.md)

### Compilación

Sin Makefile. Desde el directorio que contenga las fuentes:

```bash
gcc -Wall -O2 -g -o serv-infouser serv-infouser.c -lssl -lcrypto
gcc -Wall -O2 -g -o cli-infouser  cli-infouser.c  -lssl -lcrypto
gcc -Wall -O2 -o tcp_server tcp_server.c
gcc -Wall -O2 -o tcp_client tcp_client.c
gcc -Wall -O2 -o ssl_server-auth ssl_server-auth.c -lssl -lcrypto
gcc -Wall -O2 -o ssl_client-auth ssl_client-auth.c -lssl -lcrypto
```

En la VM del laboratorio se usan las cabeceras del sistema (`libssl-dev`):

```bash
gcc -Wall -O2 -o serv-infouser serv-infouser.c -lssl -lcrypto
```

### Ejecución

```bash
# Terminal 1: servidor (puerto fijo 1064)
./serv-infouser

# Terminal 2: cliente <host> <fichero>
./cli-infouser 127.0.0.1 salida.txt
```

El cliente escribe el keylog en `keylog-ssl.log` (en el directorio de trabajo). Ese fichero permite descifrar la captura TLS 1.2 en Wireshark.

!!! warning "Ejecuta desde `source_files/`"
    Las rutas de los certificados son relativas (`certificados/s_cert.pem`, `certificados/s_key.pem`, `certificados/s-ca_cert.pem`). Si ejecutas desde otro directorio, `SSL_CTX_use_certificate_file` falla y el handshake acaba en `no shared cipher` / `handshake_failure` (40).

Para reproducir la disposición esperada, crea un directorio de trabajo con los binarios, las fuentes y una carpeta `certificados/` que contenga los PEM de [`docs/assets/certs/lab-ssl/`](../assets/certs/lab-ssl/s_cert.pem):

```text
source_files/
├── serv-infouser
├── cli-infouser
├── keylog-ssl.log          # lo crea el cliente
└── certificados/
    ├── s_cert.pem
    ├── s_key.pem
    ├── s-ca_cert.pem
    ├── c_cert.pem
    ├── c_key.pem
    └── c-ca_cert.pem
```

Los ficheros publicados en `docs/assets/certs/lab-ssl/` están planos (sin la carpeta `certificados/`); al copiarlos, respeta la estructura que espera el código.

## Scripts PKI

| Script | Función | Documentación |
| --- | --- | --- |
| [`gen_solicitud.sh`](../assets/scripts/gen_solicitud.sh) | Clave privada cifrada + CSR (PKCS#10). | [Scripts PKI](../tema1/lab-pki/scripts.md) |
| [`emitir_cert.sh`](../assets/scripts/emitir_cert.sh) | Firma una CSR con la subCA; con `user_ext` empaqueta PKCS#12. | [Scripts PKI](../tema1/lab-pki/scripts.md) |
| [`revocar_cert.sh`](../assets/scripts/revocar_cert.sh) | Marca un certificado como revocado en `index.txt`. | [Scripts PKI](../tema1/lab-pki/scripts.md) |

```bash
bash -n gen_solicitud.sh                 # comprobación de sintaxis
KEY_PASS='...' ./gen_solicitud.sh -t usuario -n "Nombre" -e n@srdsi.lab -C ES -O "Bocata de Jamon"
CA_PASS='...' ./emitir_cert.sh solicitud-Nombre.csr user_ext
CA_PASS='...' ./revocar_cert.sh certificado-Nombre.crt cessationOfOperation
```

Los scripts exigen OpenSSL >= 1.1.1 (`-addext`) y usan `set -euo pipefail` y `umask 077`. Las rutas por defecto apuntan a la VM (`/home/user1/PKI_root/PKI_sub`); se sobrescriben con `PKI_DIR`, `CONF_CA`, `CERTS_DIR`, `P12_DIR` y `-o`.

[:octicons-arrow-right-24: Ver más — OpenSSL y PKI](../tema1/comandos/openssl.md)

## Configuraciones OpenSSL

| Fichero | Uso |
| --- | --- |
| [`ca-root_openssl.cnf`](../assets/config/ca-root_openssl.cnf) | Configuración de la CA raíz (`ca_ext`, `subca_ext`, `ocsp_ext`). |
| [`ca-sub_openssl.cnf`](../assets/config/ca-sub_openssl.cnf) | Configuración de la subCA (`server_ext`, `user_ext`, `ocsp_ext`). |

Se copian junto a la CA correspondiente y se ajusta `home`. La explicación sección a sección está en [Configuración OpenSSL](../chuletas/openssl-config.md).

## Otros recursos de código

- [Certificados y claves de laboratorio](certificados.md)
- [PDFs y enunciados](pdfs.md)
- [Benchmarks](benchmarks.md)
- [Descargas](descargas.md)
