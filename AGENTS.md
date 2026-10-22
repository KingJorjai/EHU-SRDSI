# AGENTS.md — EHU-SRDSI

Repo privado de prácticas SRDSI (Jorge Arévalo y Jon González). Rama: `main`. Sin CI, tests ni linters.

Layout: `lab-pki/` (PKI: `scripts/`, `pki-config-files/`, `docs/`, `informe/`), `lab-openssh/`, `lab-ssl/`, `ascon/`. La VM `SRDSI_Debian13/` no se versiona (ver `.gitignore`).

## lab-ssl: C + OpenSSL (`lab-ssl/source_files/`)

Enunciado en `lab-ssl/Lab-ssl-actividad.pdf` (teoría en `Lab-ssl-teoria.pdf`). El cliente/servidor de la actividad (`cli-infouser.c`/`serv-infouser.c`) **ya están migrados a OpenSSL** (Ejercicio 1); los ejemplos de la teoría sin migrar son `tcp_*.c` y `ssl_*-auth.c`. El Ejercicio 2 = analizar alertas con cert inexistente / CA desconocida.

- Sin Makefile. Compilar: `gcc -Wall -o <bin> <fuente>.c -lssl -lcrypto` (el PDF pide `[-g] [-O2]`).
- **Ejecutar siempre desde `source_files/`**: los certificados van por ruta relativa (`certificados/s_cert.pem`, `certificados/c-ca_cert.pem`, etc.); desde otro cwd `SSL_CTX_use_certificate_file` falla.
- Certs ya generados en `certificados/`: dos CAs independientes, servidor (`s-ca_cert.pem`, CN=CA_SERV-SRDSI) y cliente (`c-ca_cert.pem`, CN=CA_CLI-SRDSI), más `s_cert/s_key` y `c_cert/c_key`. Sustituidos el 2026-10-19; caducan el **2037-10-01**.
- Cliente: fija cifrados (`AES128-SHA256:AES256-CCM:AES256-GCM-SHA384`) + TLS 1.2 (`SSL_CTX_set_max_proto_version(..., TLS1_2_VERSION)`) para descifrar en Wireshark (solo TLSv1.2); el callback escribe `keylog-ssl.log`. **El cliente no presenta certificado** (solo verifica al servidor con `s-ca_cert.pem`); el servidor no pide cert de cliente y usa `SO_REUSEADDR`.
- Uso: servidor `serv-infouser` (puerto fijo 1064, sin args); cliente `cli-infouser <hostip> <filename>`. Los ejemplos usan `<hostname> <portnum>`.
- `.gitignore` ignora los binarios de `source_files/` (`tcp-*`, `cli/serv-infouser`) y `*.log` (incluye `keylog-ssl.log`).

## lab-ssl: automatización y capturas (`lab-ssl/run-lab.sh`)

- `run-lab.sh [--gui]` controla la VM por SSH (alias `SRDSI`, carpeta compartida `/media/sf_SRDSI` == este repo): compila, reproduce 3 escenarios con `dumpcap -i lo` y analiza con `tshark`. Evidencia en `lab-ssl/capturas/` (`.pcapng`, `.keylog`, `.tshark.txt`; `.png` con `--gui`). `ws_shot.sh` hace las capturas GUI en un **display virtual Xvfb dentro de la VM** (`Xvfb :99` + `openbox` + `scrot`): no abre ninguna ventana en el host. Pasos y análisis en `lab-ssl/guion-capturas.md`.
- La VM ya tiene instalados `libssl-dev`, `xvfb`, `scrot`, `openbox`, `xdotool`, `dumpcap` y `wireshark`; `sudo` disponible para instalar más paquetes. Se compila con las cabeceras del sistema: `gcc -Wall -O2 -o <bin> <fuente>.c -lssl -lcrypto`.
- Informe en `lab-ssl/informe/informe.md` → PDF con `make informe` (mismo método que lab-pki: Pandoc + pdflatex + clase `ifreport`); figuras en `lab-ssl/capturas/*.png`.

## lab-pki: scripts openssl (`lab-pki/scripts/`)

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

## lab-pki: informe (`lab-pki/informe/`)

Fuente única `informe.md` (Markdown) → PDF con Pandoc + **pdflatex** + clase `ifreport` (`iflatex/`, UPV/EHU, `[es]`).

```bash
make informe   # informe.pdf (TEXINPUTS=./iflatex: ya en el Makefile)
```

Notas verificadas: Pandoc 3.12 no tiene `--documentclass` (usar `-V documentclass=ifreport`); `xelatex` no tiene formato generado e `ifreport.cls` usa `\pdfpagewidth` (incompatible con XeTeX) → quedarse en pdflatex; `babel-spanish` viene del paquete `extra/texlive-langspanish` y se activa con `lang: es` en el YAML. Imágenes con caption son floats: fijadas con `\usepackage{float}` + `\floatplacement{figure}{H}`; solo 6 figuras en el PDF, el resto queda en `img/` como respaldo. Salidas largas en bloques `console` truncadas con marca `[... salida truncada: N líneas ...]`. PENDIENTEs actuales: mockups a mano (`img/web/`) y horas manuales (§7).
