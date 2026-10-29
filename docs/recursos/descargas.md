# Descargas

Material listo para abrir o guardar. Incluye el sitio completo sin conexión y los PDFs principales.

## Sitio offline (ZIP)

<a class="md-button md-button--primary" href="../EHU-SRDSI-docs-offline.zip">Descargar EHU-SRDSI-docs-offline.zip</a>

El ZIP lo genera GitHub Actions en cada publicación: construye una variante offline del sitio (con búsqueda empaquetada), la comprime y copia el resultado a `site/recursos/`. También queda como *artifact* de la ejecución del workflow.

!!! note "Si ya estás en la versión offline"
    Este botón solo funciona en la versión publicada en GitHub Pages. Si has abierto el ZIP, ya tienes todo el contenido descargado y no necesitas volver a descargarlo.

### Cómo usarlo

```bash
unzip EHU-SRDSI-docs-offline.zip -d EHU-SRDSI-docs
cd EHU-SRDSI-docs
python3 -m http.server 8000
```

Abre `http://localhost:8000` en el navegador.

- También puedes abrir `index.html` directamente (`file://`). La navegación y los PDFs suelen funcionar.
- Si el navegador **bloquea la búsqueda** con `file://` (por CORS/`fetch`), sirve el directorio con `python3 -m http.server` como arriba y usa `http://localhost:8000`.
- En Windows, el comando equivalente suele ser `py -m http.server 8000`.
- Para parar el servidor: `Ctrl-C`.

!!! note "Artifact de GitHub Actions"
    En la pestaña **Actions** del repositorio, abre la ejecución del workflow de documentación y descarga el artifact `EHU-SRDSI-docs-offline`. Los artifacts caducan según la retención configurada; el enlace `/recursos/EHU-SRDSI-docs-offline.zip` apunta a la copia publicada con el sitio.

## Chuleta imprimible

La [chuleta de comandos](../chuletas/comandos.md) está pensada para imprimirse: usa `Ctrl+P` (o `Cmd+P`) y el navegador ocultará la navegación. También puedes guardarla como PDF desde el diálogo de impresión.

## PDFs principales

### Guía y material general

- [Programa de la asignatura](../assets/pdf/programa.pdf)
- [Anexo de laboratorios y máquina virtual](../assets/pdf/anexo-laboratorios.pdf)
- [Personalizar entorno de trabajo](../assets/pdf/personalizar-entorno.pdf)
- [Protocolo de plagio](../assets/pdf/protocolo-plagio.pdf)

### Teoría

- [Tema 1 — Introducción (1)](../assets/pdf/SRDSI_T1-1.pdf)
- [Tema 1 — Introducción (2)](../assets/pdf/SRDSI_T1-2.pdf)
- [Tema 1 — Introducción (3)](../assets/pdf/SRDSI_T1-3.pdf)
- [Tema 1 — Introducción (4)](../assets/pdf/SRDSI_T1-4.pdf)
- [Tema 2 — Comunicación (1)](../assets/pdf/SRDSI_T2-1.pdf)
- [Tema 2 — Comunicación (2)](../assets/pdf/SRDSI_T2-2.pdf)
- [Tema 2 — Comunicación (3)](../assets/pdf/SRDSI_T2-3.pdf)
- [Tema 2 — Comunicación (4)](../assets/pdf/SRDSI_T2-4.pdf)
- [Criptografía y Seguridad en Computadores (Lucena)](../assets/pdf/cripto-lucena.pdf)

### Enunciados y actividades

- [Enunciado Lab PKI](../assets/pdf/lab-pki-enunciado.pdf)
- [Actividad de criptografía](../assets/pdf/actividad-criptografia.pdf)
- [Informe Ascon](../assets/pdf/actividad-ascon.pdf)
- [Estudio de una CA: GlobalSign](../assets/pdf/actividad-estudio-ca.pdf)
- [Lab SSL — actividad](../assets/pdf/lab-ssl-actividad.pdf)
- [Lab SSL — teoría](../assets/pdf/lab-ssl-teoria.pdf)
- [Guía rápida de GDB](../assets/pdf/gdb.pdf)
- [Laboratorio OpenSSH](../assets/pdf/lab-openssh.pdf)
- [SSH port forwarding](../assets/pdf/lab-openssh-port-forwarding.pdf)
- [Ejercicios TLS y DTLS](../assets/pdf/lab-tls-dtls.pdf)

## Informes resueltos

- [Informe Lab PKI](../assets/pdf/informe-pki.pdf)
- [Informe Lab SSL](../assets/pdf/informe-ssl.pdf)
- [Informe Lab OpenSSH](../assets/pdf/informe-openssh.pdf)
- [Informe Actividad MACsec](../assets/pdf/informe-macsec.pdf)

## Otros recursos

- [PDFs originales](pdfs.md)
- [Código de los laboratorios](codigo.md)
- [Certificados y claves](certificados.md)
- [Benchmarks](benchmarks.md)
