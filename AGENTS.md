# AGENTS.md — EHU-SRDSI

## TL;DR

- **Fuente de verdad:** el material original está en `General/` y `Tema N/`. `docs/` es la documentación derivada que se publica.
- **Nunca edites `docs/assets/`:** se borra y regenera con `scripts/prepare_docs_assets.sh`; está ignorado por git.
- **Toda página nueva debe añadirse a `nav` en `mkdocs.yml`** o no aparecerá en el sitio.
- **Verificación mínima:** `bash scripts/prepare_docs_assets.sh` → `.venv/bin/mkdocs build --strict` → `.venv/bin/mkdocs build -f mkdocs.offline.yml -d site-offline --strict`.
- **No inventes resultados:** si un paso depende de la VM y no está disponible, márcalo como **VM**; no simules salidas.

## Qué es este repo

Repo público de prácticas de **Seguridad, Rendimiento y Disponibilidad de Servicios e Infraestructuras** (SRDSI, UPV/EHU), de Jorge Arévalo y Jon González.

- Documentación: <https://kingjorjai.github.io/EHU-SRDSI/>
- Rama: `main`. Sin tests ni linters; la CI (`.github/workflows/docs.yml`) solo construye y publica la documentación.
- Claves y certificados **sintéticos**, solo para el laboratorio.
- El contenido propio está bajo CC BY-NC-SA 4.0 (`LICENSE`). Los PDFs, slides y enunciados de la asignatura quedan excluidos.

## Mapa del repositorio

- `General/` — programa, anexo de laboratorios, personalización del entorno, protocolo de plagio y bibliografía. `SRDSI_26_27_ Bibliografía _ eGela EHU_files/` es el volcado de una web (HTML/CSS/JS), no código.
- `Tema 1: Introducción a la seguridad informática/`
  - `SRDSI_T1-1..4.pdf` — teoría (image-based).
  - `lab-pki/` — PKI privada: `scripts/`, `pki-config-files/`, `docs/`, `informe/`.
  - `actividad-criptografia/` — enunciados y `benchmark_*.txt`; **no hay fuentes de Ascon**.
  - `actividad-estudio-CAs/` — estudio de GlobalSign.
  - `Material extra/` — material de clase.
- `Tema 2: Seguridad en la comunicación/`
  - `SRDSI_T2-1..4.pdf` — teoría (image-based).
  - `lab-ssl/` — SSL/TLS: `source_files/` (C+OpenSSL), `capturas/`, `run-lab.sh`, `ws_shot.sh`, `informe/`.
  - `lab-openssh/` — notas Markdown, enunciados y `informe_open_ssh.tex` (clase `article`).
  - `ejercicio-tls-dtls/` — `Lab-TLS_y_DTLS.pdf` + `lab-certs/`.
  - `SRDSI_T2-5_parcial.pdf` — teoría 2.5, seguridad en el nivel de enlace (parcial).
  - `actividad-macsec/` — enunciado `Lab_macsec_comandos.pdf`, `capturas/` e `informe/`.
- `docs/` — fuente MkDocs del sitio:
  - `guia/`, `tema1/{teoria,comandos,actividades,lab-pki}/`, `tema2/{teoria,comandos,actividades,lab-ssl}/`, `chuletas/`, `recursos/`.
  - T2-5 y MACsec: `docs/tema2/teoria/nivel-enlace.md` y `docs/tema2/actividades/macsec.md`.
- `assets/banner.svg`, `assets/preview.png` — solo para el README; no forman parte del sitio.
- `mkdocs.yml`, `mkdocs.offline.yml`, `requirements.txt`, `scripts/prepare_docs_assets.sh`, `.github/workflows/docs.yml` — construcción, bundle offline y despliegue.
- `docs/superpowers/` — planes internos excluidos del sitio con `exclude_docs`; no añadir a `nav`.
- `SRDSI_Debian13/` — VM VirtualBox, **no versionada** (usuario `user1`, host `bocata-jamon`, carpeta compartida `/media/sf_SRDSI` == raíz del repo).

## Fuente de verdad y ficheros generados

| Ruta | Papel |
| --- | --- |
| `General/`, `Tema N/` | Material original. No se reescribe para arreglar la documentación. |
| `docs/` | Páginas escritas a mano. Aquí sí se edita. |
| `docs/assets/` | **Generado** por `scripts/prepare_docs_assets.sh`; ignorado por git. |
| `site/`, `site-offline/`, `.venv/`, `EHU-SRDSI-docs-offline.zip` | Artefactos locales; ignorados por git. |
| `assets/` | Banner y captura del README; se versionan. `assets/` no entra en el build de MkDocs. |
| `docs/superpowers/` | Planes internos; excluidos del sitio. |

## Comandos esenciales

```bash
# Documentación
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
bash scripts/prepare_docs_assets.sh
.venv/bin/mkdocs serve
.venv/bin/mkdocs build --strict
.venv/bin/mkdocs build -f mkdocs.offline.yml -d site-offline --strict

# Laboratorio SSL (ejecutar desde source_files/)
cd "Tema 2: Seguridad en la comunicación/lab-ssl/source_files"
gcc -Wall -O2 -o serv-infouser serv-infouser.c -lssl -lcrypto
gcc -Wall -O2 -o cli-infouser  cli-infouser.c  -lssl -lcrypto
./serv-infouser &
./cli-infouser 127.0.0.1 /tmp/usuarios.txt

# Scripts PKI (rutas relativas a Tema 1: .../lab-pki/)
KEY_PASS=xxx ./scripts/gen_solicitud.sh -t usuario -n "Nombre" -e user@ejemplo.com -o ./out
CA_PASS=xxx ./scripts/emitir_cert.sh ./out/solicitud-Nombre.csr user_ext
CA_PASS=xxx ./scripts/revocar_cert.sh certificado-Nombre.crt cessationOfOperation

# Informes
cd "Tema 1: Introducción a la seguridad informática/lab-pki/informe" && make informe
cd "Tema 2: Seguridad en la comunicación/lab-ssl/informe" && make informe
cd "Tema 2: Seguridad en la comunicación/lab-openssh" && pdflatex informe_open_ssh.tex
cd "Tema 2: Seguridad en la comunicación/actividad-macsec/informe" && make informe

# Estado del despliegue
gh run list --workflow docs.yml --limit 1
```

## Documentación: cómo trabajar

- El material original manda. Las páginas de `docs/` resumen, enlazan y explican; no copies PDFs enteros ni reescribas resultados.
- Enlaza PDFs con anclas de página 1-based: `../../assets/pdf/SRDSI_T1-1.pdf#page=38`.
- Añade cada página nueva a `nav` en `mkdocs.yml`. Si no, MkDocs la construye pero no se navega.
- Contenido en español. Usa tablas, admoniciones y bloques `bash` copiables.
- Ejemplos GnuPG con `GNUPGHOME=$(mktemp -d)` para no tocar el llavero real.
- Ejemplos TLS/DTLS con directorios temporales (`mktemp -d`) y puertos altos; cierra los procesos al terminar.
- El sitio usa sintaxis específica de Material: `grid cards`, iconos `:material-...:`/`:octicons-...:`, `{ .md-button }`, admoniciones y `pymdownx`. Cambiar de tema obliga a reescribir esas partes.
- `docs/assets/` se regenera. El script también borra los `.md` copiados (p. ej. `img/lab-pki/MANIFIESTO.md`) para que no se rendericen.
- El enlace al ZIP offline en `docs/recursos/descargas.md` es un `<a>` HTML, no Markdown: un enlace relativo al ZIP haría fallar `--strict` porque el fichero no existe en la fuente.
- **README.md, AGENTS.md, `assets/` y `LICENSE` no disparan el workflow de docs** (no están en `paths`). Si cambias solo esos ficheros, no habrá redeploy.

## Verificación y despliegue

1. `bash scripts/prepare_docs_assets.sh`
2. `.venv/bin/mkdocs build --strict`
3. `.venv/bin/mkdocs build -f mkdocs.offline.yml -d site-offline --strict`
4. Comprueba enlaces relativos y que `site/search/search_index.json` contiene los términos clave.
5. Haz commit y push a `main`; `.github/workflows/docs.yml` construye online + offline, publica en Pages y sube el ZIP como artifact.
6. Verifica el sitio live y el workflow: `gh run list --workflow docs.yml --limit 1`.

GitHub Pages debe estar configurado con **Source: GitHub Actions** en Settings → Pages. El ZIP offline se copia a `site/recursos/EHU-SRDSI-docs-offline.zip`.

## Tema 1

- Teoría: `docs/tema1/teoria/{conceptos,criptografia,comunicacion-segura,gestion-claves}.md`.
- Comandos: `docs/tema1/comandos/{openssl,gpg,hash}.md`.
- Actividades: `docs/tema1/actividades/{amenazas,gnupg,criptografia,estudio-ca}.md`.
- Lab PKI: `docs/tema1/lab-pki/{index,guia,scripts,informe,web}.md`.

Lab PKI:

- `gen_solicitud.sh` — clave privada cifrada + CSR.
- `emitir_cert.sh` — firma con la subCA (`openssl ca -batch`); `user_ext` empaqueta PKCS#12.
- `revocar_cert.sh` — `openssl ca -revoke`; después hay que regenerar la CRL (`openssl ca -gencrl`).
- Rutas por defecto hardcodeadas a la VM (`PKI_DIR=/home/user1/PKI_root/PKI_sub`). Override por env (`PKI_DIR`, `CONF_CA`, `CERTS_DIR`, `P12_DIR`, `-o`), nunca editando scripts.
- `KEY_PASS` es obligatoria; `P12_PASS` cae a `KEY_PASS`; `CA_PASS` evita el prompt de OpenSSL.
- `-t servicio` exige `-d`, `-e`, `-C`, `-O`; la política exige C/O iguales a los de la CA. `-t usuario` exige `-e`.
- `emitir_cert.sh` NO valida la CSR (la RA es el admin); extensiones válidas: `server_ext`, `user_ext`, `ocsp_ext`.
- El informe está en `Tema 1: .../lab-pki/informe/informe.md`; los pendientes del informe son mockups a mano (`img/web/`) y horas manuales (§7), no fallos del sitio.
- Ascon: el código no está en el repo; los benchmarks se ejecutaron en la VM (`~/gcrypt-test/ascon-c/build`). La página `docs/tema1/actividades/criptografia.md` resume los resultados.

## Tema 2

- Teoría: `docs/tema2/teoria/{ssh,pgp-smime,tls-dtls,ipsec}.md`.
- Comandos: `docs/tema2/comandos/{ssh,openssl-tls,wireshark,pgp}.md`.
- Actividades: `docs/tema2/actividades/{openssh,pgp,tls-dtls}.md`.
- Lab SSL: `docs/tema2/lab-ssl/{index,guia,codigo,capturas,informe}.md`.

Lab SSL:

- Cliente/servidor `cli-infouser.c`/`serv-infouser.c` ya migrados a OpenSSL (Ejercicio 1); `tcp_*.c` y `ssl_*-auth.c` son ejemplos de teoría.
- Compilar con `gcc -Wall -O2 ... -lssl -lcrypto`. **Ejecutar desde `source_files/`**: los certificados van por ruta relativa.
- Servidor en puerto fijo 1064, sin args; cliente `cli-infouser <hostip> <filename>`.
- Cliente: TLS 1.2 + cifrados fijados + keylog para Wireshark; no presenta certificado. Servidor: no pide cert de cliente y usa `SO_REUSEADDR`.
- Certs en `source_files/certificados/`: CAs `CA_SERV-SRDSI` y `CA_CLI-SRDSI`, válidos hasta 2037-10-01.
- `run-lab.sh [--gui]` requiere el alias SSH `SRDSI`, la VM encendida y la carpeta compartida. Usa `RREPO=/media/sf_SRDSI/Tema 2: Seguridad en la comunicación`; `ws_shot.sh` deriva la ruta con `git rev-parse --show-toplevel`.
- Wireshark 4.7.4 ya no tiene *RSA keys list*: la falta de *forward secrecy* se demuestra por el handshake (`Encrypted PreMaster`, sin `ServerKeyExchange`), no descifrando con la clave privada.

OpenSSH y TLS/DTLS:

- `docs/tema2/actividades/openssh.md` resuelve los ejercicios 1–6; `informe_open_ssh.tex` solo cubre 1–4. Los pasos que requieren servidor SSH están marcados **VM**.
- `docs/tema2/actividades/tls-dtls.md` resuelve los 9 ejercicios con `lab-certs/`.
- Certificados de `lab-certs/`: `server.crt` está firmado por `subca.crt`, no directamente por `ca-root.crt`; hay que pasar la cadena (`-cert_chain` o concatenar en `-CAfile`).
- No hay SAN; `server2.crt/.key` se menciona en el README de `lab-certs/` pero **no existe**.
- `serverpq` usa ML-DSA-65. El host de documentación tiene OpenSSL 4.0.3; la VM, OpenSSL 3.5.7. Ambos soportan ML-DSA.

### Actividad MACsec

- Enunciado: `actividad-macsec/Lab_macsec_comandos.pdf`. Teoría: `SRDSI_T2-5_parcial.pdf`.
- Páginas: `docs/tema2/teoria/nivel-enlace.md` y `docs/tema2/actividades/macsec.md`.
- Informe: `actividad-macsec/informe/informe.md` → `make informe` (Pandoc + pdflatex + `iflatex`).
- VM1: `SRDSI_Debian13` (`bocata-jamon`, host-only 192.168.56.110). VM2: `SRDSI_Debian13_DNS` (`bocata-jamon2`, host-only 192.168.56.111).
- MACsec va sobre la interfaz de una **NAT Network** `macsecnet` (10.0.3.0/24), que en el guest es `enp0s9`. La host-only se usa para administración.
- MV1: `macsec0` 1.1.1.1/24, TX key 01, RX key 02. MV2: `macsec1` 1.1.1.2/24, TX key 02, RX key 01.
- Evidencia: `actividad-macsec/capturas/` (`.pcapng`, `.txt`, `.png`). Scripts de captura: `screenshot-terminal.sh` y `screenshot-wireshark.sh`.
- No hay `tcpdump` en las VM; se usa `dumpcap` y se analiza con `tshark` en el host.

## Limitaciones y gotchas

- La VM no siempre está accesible. No simules capturas ni conexiones: documenta el comando, marca **VM** y usa pruebas locales cuando sea posible.
- La VM2 (`SRDSI_Debian13_DNS`) se clonó de la VM1 y traía **las mismas MAC/IP**. Se regeneraron sus MAC, se le asignó `192.168.56.111` en host-only y se usó NAT port-forward `localhost:2222` para el primer arranque. No arranques las dos sin corregir eso.
- `run-lab.sh`/`ws_shot.sh` dependen del alias SSH `SRDSI` y de `/media/sf_SRDSI` apuntando a la raíz del repo. Si cambia el layout, revisa ambos.
- En la actividad MACsec, el PDF usa `enp0s3`/`ens33`, pero en este entorno `enp0s3` es NAT y no conecta las VM. Usa `enp0s9` (NAT Network `macsecnet`); si el EtherType `0x88e5` no pasara, cambia esa NIC a **Internal Network**.
- Wireshark muestra las tramas MACsec como `[UNVERIFIED]` sin la SAK; `ip macsec show` solo muestra el ID de clave y ceros, no la clave completa. Con `encrypt off`, el payload es visible pero la autenticación sigue activa.
- `lab-certs/server2.crt` no existe; los certs no tienen SAN.
- Material carga Roboto desde Google Fonts. En el ZIP offline hay fallback tipográfico; si se quiere 100 % offline, habría que autoalojar fuentes y tocar el tema.
- `docs/assets/` ocupa ~88 MB y no se versiona. No lo añadas a git.
- No hay tests ni linters. La única verificación automática es `mkdocs build --strict` y el workflow de Pages.

## No tocar / no commitear

- `docs/assets/`, `site/`, `site-offline/`, `.venv/`, `EHU-SRDSI-docs-offline.zip`, `package-lock.json`.
- `SRDSI_Debian13/`, `SRDSI_Debian13_DNS/` y `/SRDSI/`: son VM locales, no se versionan.
- Los PDFs, slides, enunciados y código de ejemplo originales: se enlazan, no se reescriben.
- No cambies el tema ni la estructura de `nav` sin revisar la sintaxis específica de Material y el build offline.

## Terminología

`script` = programa (p. ej. `run-lab.sh`); `guion` = guía/secuencia de pasos (`guion-capturas.md`). No traducir `script` como `guion`.
