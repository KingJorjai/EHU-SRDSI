# SRDSI — Documentación de examen

Documentación de **Seguridad, Rendimiento y Disponibilidad de Servicios e Infraestructuras** (UPV/EHU). Reúne la teoría resumida, los programas de línea de comandos, los ejercicios propuestos y los laboratorios ya resueltos.

<div class="grid cards" markdown>

- :material-console: **Chuleta de comandos**

    Todos los comandos de la asignatura agrupados por tarea: PKI, TLS/DTLS, SSH, GnuPG y Wireshark.

    [:octicons-arrow-right-24: Ir a la chuleta](chuletas/comandos.md)

- :material-shield-lock: **Tema 1 — PKI y criptografía**

    Conceptos de seguridad, criptografía, GnuPG y laboratorio PKI resuelto.

    [:octicons-arrow-right-24: Tema 1](tema1/index.md)

- :material-lan: **Tema 2 — Comunicaciones seguras**

    SSH, PGP, TLS/DTLS, IPsec y los laboratorios SSL y OpenSSH.

    [:octicons-arrow-right-24: Tema 2](tema2/index.md)

- :material-clipboard-check: **Ejercicios resueltos**

    GnuPG, PGP, TLS/DTLS, OpenSSH y modelo de amenazas, con comandos y resultados esperados.

    [:octicons-arrow-right-24: Ejercicios](tema2/actividades/tls-dtls.md)

- :material-file-pdf-box: **PDFs originales**

    Enunciados, teoría, informes y material de clase, listos para abrir o descargar.

    [:octicons-arrow-right-24: PDFs](recursos/pdfs.md)

- :material-download: **Descarga offline**

    ZIP del sitio completo con búsqueda, para consultarlo sin conexión.

    [:octicons-arrow-right-24: Descargas](recursos/descargas.md)

</div>

## Cómo usar esta documentación

- Usa la **búsqueda** (`/` o la lupa) para localizar un comando, una alerta TLS o un ejercicio.
- Cada página de comandos incluye el **contexto mínimo**, la sintaxis y un ejemplo copiable.
- Los laboratorios tienen una **guía rápida** y el **informe completo** en PDF.
- Los ejercicios indican qué está **resuelto y verificado** y qué depende de la VM.

## Durante el examen

1. Abre la [chuleta de comandos](chuletas/comandos.md) y el [checklist previo](chuletas/antes-del-examen.md).
2. Si no hay internet, descarga antes el [bundle offline](recursos/descargas.md).
3. Para dudas concretas, busca por el nombre del comando o del fichero (`openssl ca`, `s_client`, `sshd_config`, `keylog`, `unknown_ca`).

!!! info "Material de laboratorio"
    Las claves y certificados del repositorio son **sintéticos** y solo se usan en la máquina virtual del laboratorio. No son credenciales reales.
