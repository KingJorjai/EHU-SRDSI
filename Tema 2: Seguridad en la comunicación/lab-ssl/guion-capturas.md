# Lab SSL — Guion de ejecución y capturas

Convierte el protocolo `cli-infouser`/`serv-infouser` (TCP plano) a OpenSSL y documenta
las alertas TLS de los dos casos del Enunciado (Ejercicio 2).

## Requisitos

- VM de VirtualBox encendida con el alias SSH `SRDSI` (`~/.ssh/config` → `user1@192.168.56.110`).
- Carpeta compartida de la VM `/media/sf_SRDSI` apuntando a este repo.
- En el host: `tshark` (análisis) y `python3`. No hace falta servidor X: las capturas
  GUI se hacen en un display virtual dentro de la VM.
- La VM debe tener `gcc`, `libssl-dev`, `dumpcap` (grupo `wireshark`) y `wireshark`; para
  las capturas GUI, `xvfb`, `scrot` y `openbox`. **Ya están instalados** (y `sudo` está
  disponible por si hicieran falta más paquetes).

## Automático (recomendado)

```bash
cd lab-ssl
./run-lab.sh          # compila, reproduce los 3 escenarios, captura y analiza con tshark
./run-lab.sh --gui    # además captura screenshots de Wireshark en un display virtual
                      # (Xvfb) dentro de la VM: no abre ninguna ventana en el host
```

Deja la evidencia en `lab-ssl/capturas/`:

| Escenario | Fichero | Qué se observa |
|-----------|---------|----------------|
| Handshake correcto | `01_ok.*` | ClientHello, ServerHello+Certificate, CKE/Finished, `Application Data` descifrable |
| Certificado inexistente | `02_cert_inexistente.*` | **Alert (Fatal, Handshake Failure, 40)** del servidor al cliente |
| CA desconocida | `03_ca_desconocida.*` | **Alert (Fatal, Unknown CA, 48)** del cliente al servidor |

Cada escenario genera `.pcapng` (tráfico de `lo`), `.keylog` (secretos TLS) y `.tshark.txt`
(análisis textual). Con `--gui` también `.png` (Wireshark);

## Manual (equivalente)

Todo se ejecuta **desde `source_files/`** (los certificados van por ruta relativa).

```bash
cd lab-ssl/source_files
gcc -Wall -O2 -o serv-infouser serv-infouser.c -lssl -lcrypto
gcc -Wall -O2 -o cli-infouser  cli-infouser.c  -lssl -lcrypto

./serv-infouser &                                  # escucha en 1064
./cli-infouser 127.0.0.1 /tmp/usuarios.txt         # recibe el listado (salida de w)
```

(`libssl-dev` ya está instalado en la VM, así que `-lssl -lcrypto` funciona directamente.)

### Escenario 2 — certificado inexistente
Elimina/renombra `certificados/s_cert.pem` y arranca el servidor. OpenSSL no carga el
certificado; con los cifrados con intercambio RSA el servidor no puede negociar y responde
al ClientHello con **`handshake_failure` (40)**.

### Escenario 3 — CA desconocida
En `cli-infouser.c`, cambia `CA_CERT` a `certificados/c-ca_cert.pem` (la CA equivocada).
El handshake llega hasta el `Certificate` del servidor y el cliente aborta con
**`unknown_ca` (48)**.

## Capturar en Wireshark

1. Captura en la VM: `dumpcap -i lo -w captura.pcapng` (parar con Ctrl-C).
2. Descifrado: Wireshark → *Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log
   filename* → `keylog-ssl.log` (lo genera el cliente). **Solo TLS 1.2**, por eso el cliente
   fija `SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION)`.
3. Filtro útil: `tls` o `tls.alert_message`.

## Notas

- El cliente **no presenta certificado** (solo verifica al servidor contra `s-ca_cert.pem`);
  el servidor **no** pide certificado de cliente.
- `serv-infouser.c` usa `SO_REUSEADDR` para poder reiniciar el servidor sin chocar con
  sockets en `TIME_WAIT`.
- `.gitignore` ignora los binarios compilados en `source_files/` y `keylog-ssl.log`.
