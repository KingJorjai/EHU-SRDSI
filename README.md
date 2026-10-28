# EHU-SRDSI

Prácticas de Seguridad, Rendimiento y Disponibilidad de Servicios e Infraestructuras (SRDSI). Autores: Jorge Arévalo y Jon González.

**Documentación:** <https://kingjorjai.github.io/EHU-SRDSI/>

La documentación incluye teoría resumida, programas de línea de comandos, ejercicios resueltos, laboratorios, PDFs originales y un bundle offline.

## Contenido

- `General/` — programa, anexo de laboratorios, personalización del entorno, protocolo de plagio y bibliografía.
- `Tema 1: Introducción a la seguridad informática/` — teoría, actividad de criptografía, estudio de CA y laboratorio PKI.
- `Tema 2: Seguridad en la comunicación/` — teoría, laboratorio SSL, laboratorio OpenSSH y ejercicios TLS/DTLS.
- `docs/` — fuente del sitio MkDocs (la documentación publicada).
- `mkdocs.yml`, `requirements.txt`, `scripts/prepare_docs_assets.sh` y `.github/workflows/docs.yml` — construcción y despliegue.

## Documentación local

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
bash scripts/prepare_docs_assets.sh
.venv/bin/mkdocs serve
```

- `mkdocs build --strict` construye el sitio online en `site/`.
- `mkdocs build -f mkdocs.offline.yml -d site-offline --strict` construye la variante offline.
- `docs/assets/` es generado y está ignorado por git; el material original vive en `General/` y en los directorios `Tema N/`.

## Máquina virtual

La VM del laboratorio (`SRDSI_Debian13/`, VirtualBox, usuario `user1`, host `bocata-jamon`) no se versiona. Las claves y certificados del repositorio son **sintéticos** y solo se usan en el laboratorio.
