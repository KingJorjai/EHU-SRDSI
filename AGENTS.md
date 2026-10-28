# AGENTS.md — EHU-SRDSI

Repo de prácticas SRDSI (Jorge Arévalo y Jon González). Rama: `main`. Sin tests ni linters. La CI (`.github/workflows/docs.yml`) solo construye y publica la documentación. El repo es público y las claves/certificados son sintéticos de laboratorio.

## Layout actual (por temas)

Los directorios de prácticas **ya no están en la raíz**: viven dentro de un directorio por tema. Las rutas llevan espacios y `:`; cítalas siempre entre comillas en la shell.

- `docs/` — fuente del sitio MkDocs publicado en <https://kingjorjai.github.io/EHU-SRDSI/>. `docs/assets/` es **generado** (ignorado por git); no lo edites a mano.
- `mkdocs.yml`, `mkdocs.offline.yml`, `requirements.txt`, `scripts/prepare_docs_assets.sh` y `.github/workflows/docs.yml` — construcción, bundle offline y despliegue.
- `General/` — material común del curso (programa, anexo de laboratorios, personalización del entorno, plagio). `SRDSI_26_27_ Bibliografía _ eGela EHU_files/` es el volcado de una web (HTML/CSS/JS), no código del repo.
- `Tema 1: Introducción a la seguridad informática/`
  - `lab-pki/` — PKI privada (rootCA + subCA): `scripts/`, `pki-config-files/`, `docs/`, `informe/`.
  - `actividad-criptografia/` — enunciados y `benchmark_*.txt`; **no contiene fuentes de Ascon**.
  - `actividad-estudio-CAs/` — PDF del estudio de una CA.
  - `Material extra/` — material de clase.
- `Tema 2: Seguridad en la comunicación/`
  - `lab-ssl/` — SSL/TLS: teoría, `source_files/` (C+OpenSSL), `capturas/`, `run-lab.sh`, `informe/`.
  - `lab-openssh/` — notas Markdown, enunciados y el informe LaTeX `informe_open_ssh.tex`.
  - `ejercicio-tls-dtls/` — enunciado `Lab-TLS_y_DTLS.pdf` + `lab-certs/`.

`README.md` enlaza el sitio y describe el layout actual. No restaures los antiguos `lab-*`/`ascon/` de la raíz: el material vive ahora bajo `Tema N/`. `docs/assets/` se regenera con el script de preparación; no lo edites ni lo añadas a git.

La VM `SRDSI_Debian13/` (VirtualBox, usuario `user1`, host `bocata-jamon`, carpeta compartida `/media/sf_SRDSI` == raíz del repo) no se versiona.

Terminología: `script` = programa (p. ej. `run-lab.sh`); `guion` = guía/secuencia de pasos (`guion-capturas.md`). No traducir `script` como `guion`.

## Documentación (MkDocs + GitHub Pages)

- Sitio: <https://kingjorjai.github.io/EHU-SRDSI/>. Fuente en `docs/`; `docs/assets/` es generado por `scripts/prepare_docs_assets.sh` (copia PDFs, imágenes, capturas, scripts, C, configs y certs desde `General/` y `Tema N/`).
- Dependencias: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`. La CI usa Python 3.12; en local funciona 3.15.
- Ciclo de construcción: `bash scripts/prepare_docs_assets.sh` → `.venv/bin/mkdocs build --strict` (online) → `.venv/bin/mkdocs build -f mkdocs.offline.yml -d site-offline --strict` (offline).
- `docs/superpowers/` está excluido del sitio con `exclude_docs`. El ZIP offline se genera en CI, se copia a `site/recursos/` y se enlaza desde `docs/recursos/descargas.md` con un `<a>` HTML: un enlace Markdown relativo al ZIP haría fallar `--strict` porque el ZIP no existe en la fuente.
- El script borra los `.md` copiados dentro de `docs/assets/` (p. ej. `img/lab-pki/MANIFIESTO.md`) para que no se rendericen como páginas.
- Despliegue: push a `main` → `.github/workflows/docs.yml` → GitHub Pages. Pages debe estar activado con **Source: GitHub Actions** en Settings → Pages.

## lab-ssl: C + OpenSSL

Rutas relativas a `Tema 2: Seguridad en la comunicación/`.

Enunciado en `lab-ssl/Lab-ssl-actividad.pdf` (teoría en `Lab-ssl-teoria.pdf`). El cliente/servidor de la actividad (`cli-infouser.c`/`serv-infouser.c`) **ya están migrados a OpenSSL** (Ejercicio 1); los ejemplos de la teoría sin migrar son `tcp_*.c` y `ssl_*-auth.c`. El Ejercicio 2 = analizar alertas con cert inexistente / CA desconocida.

- Sin Makefile. Compilar: `gcc -Wall -o <bin> <fuente>.c -lssl -lcrypto` (el PDF pide `[-g] [-O2]`).
- **Ejecutar siempre desde `source_files/`**: los certificados van por ruta relativa (`certificados/s_cert.pem`, `certificados/c-ca_cert.pem`, etc.); desde otro cwd `SSL_CTX_use_certificate_file` falla.
- Certs ya generados en `certificados/`: dos CAs independientes, servidor (`s-ca_cert.pem`, CN=CA_SERV-SRDSI) y cliente (`c-ca_cert.pem`, CN=CA_CLI-SRDSI), más `s_cert/s_key` y `c_cert/c_key`. Sustituidos el 2026-10-19; caducan el **2037-10-01**.
- Cliente: fija cifrados (`AES128-SHA256:AES256-CCM:AES256-GCM-SHA384`) + TLS 1.2 (`SSL_CTX_set_max_proto_version(..., TLS1_2_VERSION)`) para descifrar en Wireshark (solo TLSv1.2); el callback escribe `keylog-ssl.log`. **El cliente no presenta certificado** (solo verifica al servidor con `s-ca_cert.pem`); el servidor no pide cert de cliente y usa `SO_REUSEADDR`.
- Uso: servidor `serv-infouser` (puerto fijo 1064, sin args); cliente `cli-infouser <hostip> <filename>`. Los ejemplos usan `<hostname> <portnum>`.
- `.gitignore` ignora los binarios de `lab-ssl/source_files/` en cualquier ubicación (`**/lab-ssl/source_files/...`) y `*.log` (incluye `keylog-ssl.log`), pero **no** `*.keylog` (evidencia de capturas, se versiona).

## lab-ssl: automatización y capturas

- `run-lab.sh [--gui]` controla la VM por SSH (alias `SRDSI`, carpeta compartida `/media/sf_SRDSI` == raíz del repo): compila, reproduce 3 escenarios con `dumpcap -i lo` y analiza con `tshark`. Evidencia en `lab-ssl/capturas/` (`.pcapng`, `.keylog`, `.tshark.txt`; `.png` con `--gui`). Pasos y análisis en `lab-ssl/guion-capturas.md`.
- `run-lab.sh` usa `RREPO=/media/sf_SRDSI/Tema 2: Seguridad en la comunicación` y `ws_shot.sh` deriva la ruta relativa desde `git rev-parse --show-toplevel`; si cambia el layout, revisa ambos. Requiere el alias SSH `SRDSI` y la carpeta compartida `/media/sf_SRDSI` apuntando a la raíz del repo.
- `ws_shot.sh` hace las capturas GUI en un **display virtual Xvfb dentro de la VM** (`Xvfb :99` + `openbox` + `scrot`): no abre ninguna ventana en el host. Con `--gui`, `01_ok` se captura con el frame de *Application Data* seleccionado y un clic (`xdotool`, coord. fija `60,740`) en la fila `Data` para mostrar la fuente **Decrypted TLS**.
- La VM ya tiene instalados `libssl-dev`, `xvfb`, `scrot`, `openbox`, `xdotool`, `dumpcap` y `wireshark`; `sudo` disponible para instalar más paquetes. Se compila con las cabeceras del sistema: `gcc -Wall -O2 -o <bin> <fuente>.c -lssl -lcrypto`.

## lab-pki: scripts openssl

Rutas relativas a `Tema 1: Introducción a la seguridad informática/`.

- `gen_solicitud.sh` — clave privada cifrada + CSR (`clave-privada-<nombre>.key`, `solicitud-<nombre>.csr`).
- `emitir_cert.sh` — firma con la subCA (`openssl ca -batch`); `user_ext` además empaqueta PKCS#12.
- `revocar_cert.sh` — `openssl ca -revoke`; la CRL hay que regenerarla aparte (`openssl ca -gencrl`).

```bash
bash -n <script>.sh                                          # syntax check
KEY_PASS=xxx ./gen_solicitud.sh -t usuario -n "Nombre" -e user@ejemplo.com -o ./out
./emitir_cert.sh ./out/solicitud-Nombre.csr user_ext
./revocar_cert.sh <certificado.crt> [motivo]
```

Requires OpenSSL >= 1.1.1 (`gen_solicitud.sh` lo exige por `-addext`).

Gotchas:

- Rutas por defecto hardcodeadas a la VM (`PKI_DIR=/home/user1/PKI_root/PKI_sub`, `OUTDIR=.../solicitudes`). Override por env (`PKI_DIR`, `CONF_CA`, `CERTS_DIR`, `P12_DIR`, `-o`), nunca editando scripts.
- `set -euo pipefail`, `umask 077`; claves/`.p12` a 600. No sobrescriben salidas (`-f` solo en `gen_solicitud.sh`).
- Passwords por env: `KEY_PASS` (requerida), `P12_PASS` (=`KEY_PASS` por defecto), `CA_PASS` (si no, openssl pregunta). Preferir `KEY_PASS=...` a `-p` (visible en `ps`/historial).
- `-t servicio` exige `-d`, `-e`, `-C`, `-O` (la política de la subCA exige C y O iguales a los de la CA); `-t usuario` exige `-e`. RSA 3072 por defecto, mínimo 2048.
- `emitir_cert.sh` NO valida la CSR (revisión manual = el admin es la RA); extensiones solo `server_ext|user_ext|ocsp_ext` con sección en `ca-sub_openssl.cnf`. `user_ext` necesita la clave hermana junto a la CSR.
- `revocar_cert.sh` consulta `openssl ca -status` antes para no ensuciar `index.txt`. Motivos válidos: `unspecified,keyCompromise,CACompromise,affiliationChanged,superseded,cessationOfOperation,certificateHold`.

## Informes (lab-pki y lab-ssl)

Cada `informe/` tiene su copia de `iflatex/` y un `Makefile`: fuente única `informe.md` (Markdown) → PDF con Pandoc + **pdflatex** + clase `ifreport` (UPV/EHU, `[es]`).

```bash
make informe   # informe.pdf (TEXINPUTS=./iflatex: ya en el Makefile)
```

- En lab-pki, `make check` valida `hola-mundo.pdf` (prueba de compilación), **no** `informe.pdf`.
- Notas verificadas: Pandoc 3.12 no tiene `--documentclass` (usar `-V documentclass=ifreport`); `xelatex` no tiene formato generado e `ifreport.cls` usa `\pdfpagewidth` (incompatible con XeTeX) → quedarse en pdflatex; `babel-spanish` viene del paquete `extra/texlive-langspanish` y se activa con `lang: es` en el YAML. Imágenes con caption son floats: fijadas con `\usepackage{float}` + `\floatplacement{figure}{H}`; solo 6 figuras en el PDF de lab-pki, el resto queda en `img/` como respaldo. Salidas largas en bloques `console` truncadas con marca `[... salida truncada: N líneas ...]`. PENDIENTEs actuales (lab-pki): mockups a mano (`img/web/`) y horas manuales (§7).

## lab-openssh

Rutas relativas a `Tema 2: Seguridad en la comunicación/`.

- Solo documentación: notas de Jon y Jorge (`.md`), enunciados (`Lab_SSH.pdf`, `SSH_PORT-FORWARDING.pdf`) y el informe `informe_open_ssh.tex` (clase `article`, **no** usa `ifreport`).
- Regenerar el PDF: `pdflatex informe_open_ssh.tex` (repetir para el TOC). Sin Makefile; las figuras `firefox-*.png` están en el mismo directorio.

## ejercicio-tls-dtls

Rutas relativas a `Tema 2: Seguridad en la comunicación/ejercicio-tls-dtls/`.

- `Lab-TLS_y_DTLS.pdf`: 9 ejercicios con `openssl s_server`/`s_client` (TLS 1.2/1.3, DTLS 1.2, session resumption, 0-RTT, PQC), capturando en loopback con Wireshark. No hay scripts ni código en el repo.
- `lab-certs/`: `ca-root.crt` (CN=CA-SRDSI), `subca.crt` (CN=SUBCA-SRDSI), `server.crt/.key` (CN=www.srdsi.lab), `client.crt/.key` (CN=client) y `serverpq.crt/.key` (misma CN, clave **ML-DSA-65**). Claves sin passphrase; no las cifres.
- El servidor está firmado por `subca`, no directamente por la raíz: `openssl verify -CAfile ca-root.crt server.crt` falla; hay que pasar la cadena (concatenar `ca-root.crt` + `subca.crt` en `-CAfile`, o `-cert_chain`).
- Los certificados solo tienen CN, sin SAN. El README de `lab-certs/` menciona `server2.crt/.key` (`www.srdsi2.lab`), pero **no existen** en el repo.
- `serverpq` requiere OpenSSL con ML-DSA (la VM tiene OpenSSL 3.5.7).

## actividad-criptografia

Rutas relativas a `Tema 1: Introducción a la seguridad informática/`.

- Solo enunciados y logs `benchmark_*.txt`; el código de Ascon/libgcrypt **no está aquí** (se ejecutó en la VM, p. ej. `~/gcrypt-test/ascon-c/build`). No busques fuentes para recompilar.
