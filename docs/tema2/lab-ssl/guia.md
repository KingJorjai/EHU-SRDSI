# Guía rápida del laboratorio SSL

Esta página resume el procedimiento del [informe](informe.md) y del guion de capturas. Para la sintaxis de las herramientas, consulta [OpenSSL TLS/DTLS](../comandos/openssl-tls.md) y [Wireshark y capturas](../comandos/wireshark.md).

!!! info "Entorno"
    Los comandos se ejecutan en la VM Debian del laboratorio (`user1`), que ya tiene `gcc`, `libssl-dev`, `dumpcap`, `tshark` y `wireshark`. El laboratorio está en `Tema 2: Seguridad en la comunicación/lab-ssl/`; cita la ruta entre comillas por los espacios y los dos puntos.

## 1. Compilar cliente y servidor

El cliente y el servidor entregados ya están migrados a OpenSSL. Se compilan en `source_files/`:

```bash
cd "Tema 2: Seguridad en la comunicación/lab-ssl/source_files"

gcc -Wall -O2 -o serv-infouser serv-infouser.c -lssl -lcrypto
gcc -Wall -O2 -o cli-infouser  cli-infouser.c  -lssl -lcrypto
```

`-O2` es opcional (el enunciado pide `[-g] [-O2]`); lo imprescindible es enlazar `-lssl -lcrypto`. Los binarios no se versionan.

## 2. Ejecutar el escenario correcto

Todo se ejecuta **desde `source_files/`**: los certificados se referencian con rutas relativas (`certificados/s_cert.pem`, `certificados/s_key.pem`, `certificados/s-ca_cert.pem`) y desde otro directorio de trabajo la carga falla.

```bash
# Terminal 1: servidor (escucha en el puerto fijo 1064)
./serv-infouser

# Terminal 2: cliente
./cli-infouser 127.0.0.1 /tmp/usuarios.txt
```

Salida esperada del cliente:

```console
Conectado con cifrado AES128-SHA256
Verificacion del servidor: OK
```

El fichero `/tmp/usuarios.txt` debe coincidir con la salida de `w` que el servidor guardó en `/tmp/file_users`.

## 3. Reproducir los tres escenarios

| Escenario | Preparación | Resultado |
| --- | --- | --- |
| `01_ok` | Certificados y CA correctos. | Handshake completo y datos descifrables con el *keylog*. |
| `02_cert_inexistente` | Renombrar `certificados/s_cert.pem`. | El servidor responde `handshake_failure` (40). |
| `03_ca_desconocida` | El cliente confía en `certificados/c-ca_cert.pem`. | El cliente aborta con `unknown_ca` (48). |

### 3.1. Certificado inexistente

Renombra el certificado del servidor (o edita `CERTFILE`) y arranca el servidor:

```bash
mv certificados/s_cert.pem certificados/s_cert.pem.bak
./serv-infouser
./cli-infouser 127.0.0.1 /tmp/usuarios.txt
```

Sin certificado, el servidor no puede negociar los cifrados con intercambio RSA que fija el cliente: registra `no shared cipher` y responde al `Client Hello` con una alerta fatal `handshake_failure` (40). El cliente informa de `ssl/tls alert handshake failure: SSL alert number 40`. Restaura el fichero al terminar:

```bash
mv certificados/s_cert.pem.bak certificados/s_cert.pem
```

### 3.2. CA desconocida

Cambia temporalmente la CA de confianza del cliente en `cli-infouser.c`:

```c
/* #define CA_CERT "certificados/s-ca_cert.pem" */
#define CA_CERT "certificados/c-ca_cert.pem"
```

Recompila el cliente, arranca el servidor con el certificado correcto y ejecuta de nuevo el cliente. El handshake llega hasta el `Certificate` del servidor, pero el cliente no puede construir una cadena de confianza hasta `CA_CLI-SRDSI` y envía `unknown_ca` (48). El cliente muestra `certificate verify failed` y el servidor recibe `tlsv1 alert unknown ca: SSL alert number 48`.

## 4. Capturar y analizar

Con `dumpcap` se captura el tráfico de *loopback* mientras se ejecuta el escenario:

```bash
cd "Tema 2: Seguridad en la comunicación/lab-ssl"
dumpcap -i lo -w capturas/01_ok.pcapng
```

En otra terminal, arranca el servidor y el cliente desde `source_files/`. Detén `dumpcap` con `Ctrl-C`.

La captura manual del cliente escribe `keylog-ssl.log` en su directorio de trabajo. Para descifrar en Wireshark, cárgalo en *Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename*. Solo funciona con TLS 1.2, y por eso el cliente fija `SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION)`.

Análisis equivalente con `tshark`:

```bash
CAP=../../assets/capturas/lab-ssl

tshark -r "$CAP/01_ok.pcapng" -o "tls.keylog_file:$CAP/01_ok.keylog" -Y tls
tshark -r "$CAP/01_ok.pcapng" -o "tls.keylog_file:$CAP/01_ok.keylog" \
  -q -z follow,tls,ascii,0
tshark -r "$CAP/02_cert_inexistente.pcapng" -Y tls.alert_message
tshark -r "$CAP/03_ca_desconocida.pcapng" -Y tls.alert_message
```

El detalle del handshake y de las alertas está en [Capturas y alertas](capturas.md).

## 5. Evidencia de las capturas

### Handshake correcto

![Handshake correcto con TLS 1.2 y datos de aplicación descifrados mediante keylog](../../assets/capturas/lab-ssl/01_ok.png)

### Certificado inexistente

![El servidor responde Handshake Failure (40)](../../assets/capturas/lab-ssl/02_cert_inexistente.png)

### CA desconocida

![El cliente responde Unknown CA (48)](../../assets/capturas/lab-ssl/03_ca_desconocida.png)

## 6. Resumen de alertas

| Situación | Quién genera la alerta | Alerta TLS |
| --- | --- | --- |
| CA correcta | Ninguno | Handshake correcto |
| Certificado del servidor inexistente | Servidor | `handshake_failure` (40, fatal) |
| CA del servidor no reconocida | Cliente | `unknown_ca` (48, fatal) |

## 7. Automatización

`run-lab.sh` reproduce los tres escenarios en la VM por SSH, captura con `dumpcap -i lo` y analiza con `tshark`. Con `--gui` genera además las capturas de Wireshark en un display virtual dentro de la VM:

```bash
./run-lab.sh
./run-lab.sh --gui
```

!!! warning "Rutas de la automatización"
    `run-lab.sh` calcula `REPO` desde su ubicación, pero `RREPO=/media/sf_SRDSI` sigue usando el layout antiguo (`lab-ssl/...` sin el prefijo `Tema 2: Seguridad en la comunicación/`). Para ejecutarlo tras la reorganización hay que ajustar `RREPO`, `SRC` y `CAP`. La guía manual de esta página no depende de esa corrección.
