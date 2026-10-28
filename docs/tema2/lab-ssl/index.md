# Laboratorio SSL

[:material-file-pdf-box: Enunciado del laboratorio (PDF)](../../assets/pdf/lab-ssl-actividad.pdf){ .md-button }
[:material-file-pdf-box: Material de teoría (PDF)](../../assets/pdf/lab-ssl-teoria.pdf){ .md-button }
[:material-file-pdf-box: Informe completo (PDF)](../../assets/pdf/informe-ssl.pdf){ .md-button }

## Objetivo

Proteger con OpenSSL el protocolo de aplicación `cli-infouser`/`serv-infouser`, que en su versión original viaja en claro sobre TCP, y analizar las alertas TLS que se producen ante dos errores con los certificados: un certificado de servidor inexistente y un certificado firmado por una CA que el cliente no reconoce.

La aplicación permite al administrador obtener la lista de usuarios conectados. El cliente solicita la información, el servidor ejecuta `w`, guarda la salida en un fichero temporal y la envía; el cliente la almacena en el fichero indicado como segundo parámetro.

## Tareas

1. **Ejercicio 1 — migración a OpenSSL**: sustituir las llamadas TCP (`read`/`write`) por la API de sockets seguros (`SSL_accept`/`SSL_connect`, `SSL_read`/`SSL_write`) manteniendo el protocolo de aplicación y el puerto 1064.
2. **Ejercicio 2 — alertas TLS**: reproducir y capturar dos escenarios de error:
   - certificado del servidor inexistente → alerta `handshake_failure` (40);
   - CA del servidor desconocida por el cliente → alerta `unknown_ca` (48).
3. **Captura y análisis**: capturar el tráfico de `lo` con `dumpcap`, analizarlo con `tshark` y descifrar el caso correcto con el *keylog* exportado por el cliente.

## Entregables

- Cliente y servidor migrados a OpenSSL: `cli-infouser.c` y `serv-infouser.c`.
- Certificados de servidor y de las dos CAs usados en el laboratorio.
- Capturas `.pcapng` de los tres escenarios, *keylog* y análisis textual `.tshark.txt`.
- Capturas de pantalla de Wireshark con el handshake y las alertas.
- Informe de la práctica con el análisis de las alertas y la valoración de la actividad.

## Checklist de la práctica

- [ ] El servidor y el cliente compilan con `gcc -Wall -O2 ... -lssl -lcrypto`.
- [ ] El servidor carga `certificados/s_cert.pem` y `certificados/s_key.pem` y comprueba que la clave corresponde al certificado.
- [ ] El cliente confía en `certificados/s-ca_cert.pem`, fija TLS 1.2 y los cifrados del enunciado.
- [ ] El escenario correcto transfiere el listado de `w` y el cliente muestra `Verificacion del servidor: OK`.
- [ ] El escenario sin certificado produce `handshake_failure` (40) en el servidor.
- [ ] El escenario con CA desconocida produce `unknown_ca` (48) en el cliente.
- [ ] La captura correcta se descifra en Wireshark con `01_ok.keylog` y se lee la salida de `w`.
- [ ] El informe recoge las capturas, la tabla de alertas y el tiempo dedicado.

## Contenido

- [Guía rápida](guia.md): compilación, ejecución, reproducción de los tres escenarios y captura.
- [Código](codigo.md): recorrido del servidor y del cliente por la API de OpenSSL.
- [Capturas y alertas](capturas.md): análisis del handshake y de las dos alertas TLS.
- [Informe completo](informe.md): documento entregado, con resultados y valoración.
- [OpenSSL TLS/DTLS](../comandos/openssl-tls.md): sintaxis de `s_server`, `s_client` y verificación de certificados.
- [Wireshark y capturas](../comandos/wireshark.md): `dumpcap`, `tshark`, filtros y descifrado TLS.

!!! note "Material original"
    Las fuentes, los certificados y las capturas originales están en `Tema 2: Seguridad en la comunicación/lab-ssl/` (`source_files/` y `capturas/`). Esta documentación no modifica ese material: lo describe y enlaza copias en `docs/assets/`.
