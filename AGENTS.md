# AGENTS.md — EHU-SRDSI

Repo privado de prácticas SRDSI (Jorge Arévalo y Jon González). Rama: `main`. Sin CI, tests ni linters.

Layout: `lab-pki/` (PKI: `scripts/`, `pki-config-files/`, `docs/`, `informe/`), `lab-openssh/`, `lab-ssl/`, `ascon/`. La VM `SRDSI_Debian13/` no se versiona (ver `.gitignore`).

## lab-ssl: C + OpenSSL (`lab-ssl/source_files/`)

Enunciado en `lab-ssl/Lab-ssl-actividad.pdf` (teoría en `Lab-ssl-teoria.pdf`). Ejercicio 1 = pasar el protocolo `cli-infouser.c`/`serv-infouser.c` (TCP plano) a sockets OpenSSL (`ssl_client-auth.c`/`ssl_server-auth.c`); Ejercicio 2 = analizar alertas con cert inexistente / CA desconocida.

- Sin Makefile. Compilar: `gcc -Wall -o <bin> ssl_<lado>-auth.c -lssl -lcrypto` (los planos, sin flags). El PDF pide `gcc [-g] [-O2] -o ejecutable ssl-fuente.c -Wall -lssl -lcrypto`.
- **Ejecutar siempre desde `source_files/`**: los certificados van por ruta relativa (`certificados/s_cert.pem`, `certificados/c-ca_cert.pem`, etc.); desde otro cwd `SSL_CTX_use_certificate_file` falla.
- Certs ya generados en `certificados/`: dos CAs independientes, servidor (`s-ca_cert.pem`, CN=CA_SERV-SRDSI) y cliente (`c-ca_cert.pem`, CN=CA_CLI-SRDSI), más `s_cert/s_key` y `c_cert/c_key`. Caducan el 2026-08-14.
- `ssl_client-auth.c` fija la lista de cifrados (`AES128-SHA256:AES256-CCM:AES256-GCM-SHA384`) y limita a TLS 1.2 (`SSL_CTX_set_max_proto_version(..., TLS1_2_VERSION)`), imprescindible para descifrar en Wireshark (solo TLSv1.2); el callback escribe `keylog-ssl.log` para cargarlo en Prefs → Protocols → TLS. Ambos exigen verificación mutua (`SSL_VERIFY_PEER`, depth 1).
- Uso: servidor `ssl_server-auth <portnum>`; cliente `ssl_client-auth <hostname> <portnum>`. Los planos usan puerto fijo 1064 y cliente `cli-infouser <hostip> <filename>`.
- `.gitignore` solo ignora los binarios `tcp-server`/`tcp-client`: compilar los `ssl_*` deja binarios y `keylog-ssl.log` sin trackear — no commitear.

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
