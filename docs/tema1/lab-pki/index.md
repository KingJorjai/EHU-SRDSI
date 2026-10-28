# Laboratorio PKI

[:material-file-pdf-box: Enunciado del laboratorio (PDF)](../../assets/pdf/lab-pki-enunciado.pdf){ .md-button }
[:material-file-pdf-box: Informe completo (PDF)](../../assets/pdf/informe-pki.pdf){ .md-button }

## Objetivo

Poner en marcha una PKI privada de dos niveles —una autoridad raíz (*rootCA*) y una autoridad subordinada (*subCA*)— capaz de emitir, verificar y revocar certificados de usuario y de servicio, publicar CRL y responder consultas OCSP. Además se diseña la interfaz web de la subCA con roles de usuario y administrador.

El laboratorio se ejecuta en la VM Debian (`user1`, `/home/user1`) y usa OpenSSL desde la línea de comandos.

## Tareas

1. **CA raíz y subCA**: crear la estructura de directorios, configurar ambas autoridades, generar la clave y el certificado autofirmado de la raíz y firmar el certificado de la subCA.
2. **Certificados finales**: generar solicitudes (CSR) para usuarios y servicios, revisarlas y emitirlas con las extensiones adecuadas.
3. **Revocación y CRL**: revocar un certificado, regenerar la CRL y comprobar el estado por CRL y por OCSP.
4. **Respondedor OCSP**: emitir el certificado de firma OCSP, arrancar el respondedor y consultar certificados buenos y revocados.
5. **Verificación**: inspeccionar certificados, validar la cadena hasta la raíz y exportar/inspeccionar PKCS#12.
6. **Diseño web**: definir la interfaz de la subCA para usuarios y administradores.

## Entregables

- PKI funcional en la VM (`~/PKI_root` y `~/PKI_root/PKI_sub`) con `index.txt`, series, certificados y CRL.
- Certificados de usuario, de servicio y de firma OCSP emitidos por la subCA.
- Evidencias de revocación, consulta OCSP y verificación de cadena.
- Scripts `gen_solicitud.sh`, `emitir_cert.sh` y `revocar_cert.sh` funcionales.
- Informe de la práctica y diseño de la interfaz web de la subCA.

## Checklist de la práctica

- [ ] Directorios `private` con permisos `700`; claves y `.p12` con modo `600`.
- [ ] `index.txt` vacío y cuatro ficheros de serie (`serie_emitidos.txt` y `serie_revocados.txt` en raíz y subCA).
- [ ] Configuraciones `ca-root_openssl.cnf` y `ca-sub_openssl.cnf` copiadas y con `home` correcto.
- [ ] Certificado de la rootCA autofirmado con `ca_ext` y CRL inicial generada.
- [ ] Certificado de la subCA firmado por la raíz con `subca_ext` (`CA:true,pathlen:0`).
- [ ] Certificado de usuario emitido con `user_ext` y PKCS#12 generado.
- [ ] Certificado de servicio (OCSP) emitido con `ocsp_ext` y SAN correcto.
- [ ] Certificado revocado, CRL regenerada y estado consultado con `openssl ca -status`.
- [ ] Respondedor OCSP en el puerto 4747 y consultas con resultado `good` y `revoked`.
- [ ] Cadena verificada con `openssl verify` y certificados inspeccionados con `openssl x509`.
- [ ] `.p12` inspeccionado y extraído (certificado y clave por separado).
- [ ] Diseño web con roles, pantallas y mapeo a operaciones de la PKI.

## Contenido

- [Guía rápida](guia.md): flujo completo y verificable, desde los directorios hasta OCSP y PKCS#12.
- [Scripts](scripts.md): uso, opciones, variables de entorno, códigos de salida y errores típicos.
- [Informe completo](informe.md): documento entregado, con salidas de comandos y capturas.
- [Diseño web](web.md): interfaz de la subCA, roles y mapeo UI → operación.
- [OpenSSL y PKI](../comandos/openssl.md): referencia de los comandos manuales.

!!! note "Material original"
    Los ficheros de configuración y los scripts están en `Tema 1: Introducción a la seguridad informática/lab-pki/` (`pki-config-files/` y `scripts/`). Esta documentación no modifica ese material: lo describe y enlaza.
