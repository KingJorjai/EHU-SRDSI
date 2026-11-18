# Tema 3 — Seguridad en los servicios

Seguridad de los servicios de red: endurecimiento del servidor, servicio web (Apache), DNS y correo electrónico. En este repositorio están disponibles las transparentas de **3.1 Servicios seguros** y **3.2 Servicio WWW** y las actividades asociadas.

[:material-file-pdf-box: Transparencias — Tema 3 (3.1 y 3.2) (PDF)](../assets/pdf/SRDSI_T3-1-2.pdf){ .md-button }

## Teoría

- [Servicios seguros](teoria/servicios-seguros.md): servidores, endurecimiento, herramientas de *hardening* y Lynis.
- [Servicio WWW](teoria/servicio-www.md): Apache, seguridad del servidor web, HTTPS, validación de certificados, CT y SNI/ECH.

## Actividades

- [Actividad Apache](actividades/apache.md): sitios virtuales, autenticación básica y *digest*, HTTPS, certificado de cliente y capturas con Wireshark.
- [Actividad Lynis](actividades/lynis.md): auditoría de seguridad y *hardening* del sistema.

## Relación con otras prácticas

- La **[2ª fase del laboratorio PKI](../tema1/lab-pki/pki2.md)** usa el sitio HTTPS de Apache y un respondedor OCSP de OpenSSL para analizar OCSP regular, *stapling* y *must-staple*.
- Los certificados de la actividad Apache están en [Certificados y claves de laboratorio](../recursos/certificados.md#apache-ca-subca-y-certificados-de-usuario).

!!! note "Alcance del material"
    El PDF disponible cubre **3.1** y **3.2**. Los apartados **3.3 (DNS)** y **3.4 (correo electrónico)** no están en este repositorio; consulta el material oficial en eGela.
