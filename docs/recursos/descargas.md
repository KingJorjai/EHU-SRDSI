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

### Teoría, actividades e informes

La lista completa está en [PDFs originales](pdfs.md). Accesos rápidos:

- **Teoría**: [Tema 1](../assets/pdf/SRDSI_T1-1.pdf) · [Tema 2](../assets/pdf/SRDSI_T2-1.pdf) · [Tema 3 (3.1-3.2)](../assets/pdf/SRDSI_T3-1-2.pdf) · [3.3 DNS](../assets/pdf/SRDSI_T3-3.pdf) · [3.4 Correo](../assets/pdf/SRDSI_T3-4.pdf)
- **Actividades**: [Lab PKI](../assets/pdf/lab-pki-enunciado.pdf) · [PKI2](../assets/pdf/lab-pki2-enunciado.pdf) · [Lab SSL](../assets/pdf/lab-ssl-actividad.pdf) · [OpenSSH](../assets/pdf/lab-openssh.pdf) · [TLS/DTLS](../assets/pdf/lab-tls-dtls.pdf) · [MACsec](../assets/pdf/lab-macsec-comandos.pdf) · [Apache](../assets/pdf/lab-apache-actividad.pdf) · [Lynis](../assets/pdf/lab-lynis.pdf) · [DNS](../assets/pdf/lab-dns-actividad.pdf) · [Correo](../assets/pdf/actividad-correo.pdf)
- **Informes**: [PKI](../assets/pdf/informe-pki.pdf) · [PKI2](../assets/pdf/informe-pki2.pdf) · [SSL](../assets/pdf/informe-ssl.pdf) · [OpenSSH](../assets/pdf/informe-openssh.pdf) · [MACsec](../assets/pdf/informe-macsec.pdf) · [IMAP](../assets/pdf/informe-imap.pdf)

## Otros recursos

- [PDFs originales](pdfs.md)
- [Código de los laboratorios](codigo.md)
- [Certificados y claves](certificados.md)
- [Benchmarks](benchmarks.md)
