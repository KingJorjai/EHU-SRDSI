# Documentación SRDSI en GitHub Pages — Plan de implementación

> **Para agentes:** ejecutar con `superpowers:subagent-driven-development`. Tareas secuenciales, revisión de especificación y calidad después de cada una.

**Objetivo:** publicar una documentación estática en español con teoría resumida, comandos, ejercicios resueltos, laboratorios, PDFs y bundle offline, accesible durante el examen.

**Arquitectura:** MkDocs + Material sobre Markdown en `docs/`. Un script copia PDFs/imágenes/claves de laboratorio a `docs/assets/` (ignorado por git). GitHub Actions construye el sitio online y una variante offline, publica en GitHub Pages y sube el ZIP offline como artifact.

**Stack:** Python 3.12, MkDocs, Material, pymdown-extensions, Pandoc, GitHub Actions, GitHub Pages.

**Decisión del usuario:** el repositorio pasará a público; todas las claves y certificados son sintéticos y pueden publicarse. No se reescribe el historial ni se redactan secretos.

---

## Estructura de ficheros

```text
mkdocs.yml
mkdocs.offline.yml
requirements.txt
scripts/prepare_docs_assets.sh
.github/workflows/docs.yml
docs/
  index.md
  guia/{programa,evaluacion,vm-entorno,bibliografia}.md
  tema1/
    index.md
    teoria/{conceptos,criptografia,comunicacion-segura,gestion-claves}.md
    comandos/{openssl,gpg,hash}.md
    actividades/{amenazas,gnupg,criptografia,estudio-ca}.md
    lab-pki/{index,guia,scripts,informe,web}.md
  tema2/
    index.md
    teoria/{ssh,pgp-smime,tls-dtls,ipsec}.md
    comandos/{ssh,openssl-tls,wireshark,pgp}.md
    actividades/{openssh,pgp,tls-dtls}.md
    lab-ssl/{index,guia,codigo,capturas,informe}.md
  chuletas/{comandos,antes-del-examen,alertas-tls,openssl-config}.md
  recursos/{pdfs,codigo,certificados,descargas,benchmarks}.md
  assets/                      # generado, ignorado por git
```

`mkdocs.yml` debe excluir `superpowers/` del sitio.

---

## Tareas

### Tarea 1 — Commit de reorganización y scaffold

**Ficheros:**
- Crear: `requirements.txt`, `mkdocs.yml`, `mkdocs.offline.yml`, `docs/index.md`, `.github/workflows/docs.yml`, `scripts/prepare_docs_assets.sh`
- Modificar: `.gitignore`

- [ ] Añadir a `.gitignore`: `.venv/`, `site/`, `site-offline/`, `docs/assets/`, `EHU-SRDSI-docs-offline.zip`.
- [ ] `requirements.txt`:
  ```text
  mkdocs-material>=9.6,<10
  pymdown-extensions>=10.0
  mkdocs-glightbox>=0.4
  ```
- [ ] `mkdocs.yml` con `site_name`, `site_url`, `repo_url`, `theme: material`, `language: es`, navegación por pestañas, búsqueda en español, `content.code.copy`, `pymdownx.superfences` con Mermaid, `exclude_docs: superpowers/`.
- [ ] `mkdocs.offline.yml`: `INHERIT: mkdocs.yml` + plugin `offline`.
- [ ] `docs/index.md`: portada con accesos rápidos a comandos, labs, ejercicios, PDFs, chuletas y bundle offline.
- [ ] Workflow `docs.yml`: build online + offline, zip offline, copiar ZIP a `site/recursos/`, publicar Pages y subir artifact.
- [ ] `scripts/prepare_docs_assets.sh`: copiar PDFs, imágenes de informes/capturas, scripts, fuentes C, configs y certs/claves de laboratorio a `docs/assets/`, preservando nombres ASCII y rutas estables.
- [ ] Verificar: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/mkdocs build --strict`.

### Tarea 2 — Guía y entorno

**Ficheros:** `docs/guia/programa.md`, `evaluacion.md`, `vm-entorno.md`, `bibliografia.md`.

Contenido: objetivos, temario T1-T4, evaluación continua/global, VM VirtualBox, usuarios, BIND, carpetas compartidas, red NAT, personalización (hostname/usuario/hosts), `scp`, grupo `wireshark`, `vboxsf`. Enlazar PDFs de `General/`.

### Tarea 3 — Tema 1: teoría, comandos y actividades

**Ficheros:** los de `docs/tema1/`.

- Teoría: conceptos y amenazas; criptografía simétrica/asimétrica/hash/MAC/AEAD; confidencialidad/integridad/no repudio/autenticación; gestión de claves, PKI, CRL/OCSP.
- Comandos: `openssl` (req, ca, x509, verify, crl, ocsp, pkcs12, rand, speed, pkey), `gpg`, hashes.
- Actividades: amenazas con ejemplo CAPEC; GnuPG resuelto (simétrico/asimétrico, hashes, firmas, claves, confianza, revocación); Ascon/benchmarks; estudio GlobalSign.
- Enlazar PDFs originales con `#page=N`.

### Tarea 4 — Lab PKI

**Ficheros:** `docs/tema1/lab-pki/*`.

Adaptar `Tema 1: Introducción a la seguridad informática/lab-pki/informe/informe.md`:
- `guia.md`: pasos condensados y comandos verificados.
- `scripts.md`: uso de `gen_solicitud.sh`, `emitir_cert.sh`, `revocar_cert.sh`, variables y gotchas.
- `informe.md`: informe completo saneado solo de formato (sin reescribir secretos) + figuras.
- `web.md`: diseño de la interfaz de la subCA.
- `index.md`: objetivos, entregables y checklist.

### Tarea 5 — Tema 2: teoría y comandos

**Ficheros:** los de `docs/tema2/`.

- Teoría: SSH, PGP/S-MIME, TLS 1.2/1.3, DTLS, QUIC, IPsec.
- Comandos: `ssh`, `ssh-keygen`, `ssh-copy-id`, `ssh-agent`, `ssh-add`, `scp`, túneles `-L/-R/-D`, `openssl s_server/s_client`, `dumpcap`, `tshark`, `gpg`.
- Incluir tablas de alertas TLS, handshake TLS 1.2/1.3, resumption, 0-RTT y PQC.

### Tarea 6 — Lab SSL y OpenSSH

**Ficheros:** `docs/tema2/lab-ssl/*`, `docs/tema2/actividades/openssh.md`.

- Lab SSL: adaptar `lab-ssl/informe/informe.md` y `guion-capturas.md`; incluir código, compilación, escenarios, alertas y capturas.
- OpenSSH: extraer ejercicios 1-4 del `.tex` y añadir soluciones 5-6 (`ssh-agent`, multiplexación, remote forwarding, certificados, 2FA).

### Tarea 7 — Soluciones nuevas

**Ficheros:** `docs/tema2/actividades/tls-dtls.md`, `docs/tema2/actividades/pgp.md`, `docs/tema1/actividades/gnupg.md`, `docs/tema1/actividades/amenazas.md`, `docs/tema2/actividades/openssh.md`.

- TLS/DTLS: resolver los 9 ejercicios con `lab-certs/`, OpenSSL 4.0.3 local (ML-DSA disponible) y comandos verificados.
- GnuPG/PGP: resolver con `GNUPGHOME` temporal, claves de prueba y salidas esperadas.
- OpenSSH 5-6: comandos y salidas esperadas; marcar lo dependiente de la VM (no accesible).
- Amenazas: ejemplo CAPEC con 4 patrones y plantilla.

### Tarea 8 — Chuletas, recursos y offline

**Ficheros:** `docs/chuletas/*`, `docs/recursos/*`.

- Chuleta de comandos por tarea.
- Checklist pre-examen.
- Tabla de alertas TLS.
- Config OpenSSL rootCA/subCA comentada.
- Recursos: PDFs, código, certificados/claves de laboratorio, benchmarks y descargas.
- Bundle offline y chuleta imprimible.

### Tarea 9 — Verificación y despliegue

- [ ] `mkdocs build --strict`.
- [ ] Comprobar enlaces internos y búsqueda.
- [ ] Probar el ZIP offline con `python3 -m http.server` y `file://`.
- [ ] `rg -n 'BEGIN .*PRIVATE KEY|user1Root_CA' site/` para inventariar (se permite publicar).
- [ ] Hacer público el repo: `gh repo edit KingJorjai/EHU-SRDSI --visibility public --accept-visibility-change-consequences`.
- [ ] Activar Pages con origen GitHub Actions.
- [ ] Push a `main` y verificar `https://kingjorjai.github.io/EHU-SRDSI/`.
- [ ] Actualizar `README.md` y `AGENTS.md`.
