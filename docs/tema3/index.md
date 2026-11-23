# Tema 3 — Seguridad en los servicios

Seguridad de los servicios de red: endurecimiento del servidor, servicio web (Apache), DNS y correo electrónico. En este repositorio están disponibles las transparentas de **3.1 Servicios seguros**, **3.2 Servicio WWW**, **3.3 DNS** y **3.4 Correo electrónico**, junto con sus actividades.

[:material-file-pdf-box: Transparencias — Tema 3 (3.1 y 3.2) (PDF)](../assets/pdf/SRDSI_T3-1-2.pdf){ .md-button }
[:material-file-pdf-box: Transparencias — 3.3 DNS (PDF)](../assets/pdf/SRDSI_T3-3.pdf){ .md-button }
[:material-file-pdf-box: Transparencias — 3.4 Correo (PDF)](../assets/pdf/SRDSI_T3-4.pdf){ .md-button }

## Teoría

- [Servicios seguros](teoria/servicios-seguros.md): servidores, endurecimiento, herramientas de *hardening* y Lynis.
- [Servicio WWW](teoria/servicio-www.md): Apache, seguridad del servidor web, HTTPS, validación de certificados, CT y SNI/ECH.
- [Seguridad en DNS](teoria/dns.md): BIND, resolución, *cache poisoning*, DNSSEC, *split horizon* y registro de consultas.
- [Correo electrónico](teoria/correo.md): SMTP, POP3, IMAP, autenticación, TLS y SPF/DKIM/DMARC.

## Actividades

- [Actividad Apache](actividades/apache.md): sitios virtuales, autenticación básica y *digest*, HTTPS, certificado de cliente y capturas con Wireshark.
- [Actividad Lynis](actividades/lynis.md): auditoría de seguridad y *hardening* del sistema.
- [Actividad DNS con BIND](actividades/dns.md): servidor de nombres, zonas, reenviadores y `dig`/`rndc`.
- [Actividad de correo](actividades/correo.md): SMTP y POP3 con `telnet` y capturas con Wireshark.
- [Actividad IMAPv4](actividades/imap.md): extensiones de seguridad, autenticación y capturas de IMAPS/STARTTLS.

## Relación con otras prácticas

- La **[2ª fase del laboratorio PKI](../tema1/lab-pki/pki2.md)** usa el sitio HTTPS de Apache y un respondedor OCSP de OpenSSL para analizar OCSP regular, *stapling* y *must-staple*.
- Los certificados de la actividad Apache están en [Certificados y claves de laboratorio](../recursos/certificados.md#apache-ca-subca-y-certificados-de-usuario).

!!! note "Alcance del material"
    Los PDFs cubren **3.1**, **3.2**, **3.3 (DNS)** y **3.4 (correo electrónico)**. El **Tema 4** no está en este repositorio; consulta el material oficial en eGela.
