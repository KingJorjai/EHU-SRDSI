# Diseño web de la subCA

La aplicación web es únicamente el frontal de la **subCA**; la autoridad raíz no tiene interfaz. El diseño parte del [apartado 6 del informe](informe.md#6-diseno-de-la-aplicacion-web-de-la-subca) y de los bocetos a mano del repositorio. Su objetivo es que usuarios y administradores ejecuten las operaciones de la PKI sin usar la línea de comandos, manteniendo la revisión manual de solicitudes y la entrega personal del PKCS#12.

## Roles

### Usuario

- Solicita un certificado de usuario mediante formulario.
- Sube la CSR de un servicio (`.csr`) si actúa en nombre de un servicio.
- Consulta sus certificados, ve el detalle y comprueba si están revocados.
- Descarga el certificado público (`.crt`).
- **No** descarga el PKCS#12: contiene su clave privada y se entrega en persona.

### Administrador de la subCA

Acceso restringido. Actúa como autoridad de registro (RA) y ejecuta las operaciones de la CA:

- Revisa las solicitudes pendientes y las acepta o deniega.
- Busca certificados, ve su información y descarga el PKCS#12 para entregarlo al usuario.
- Revoca certificados indicando el motivo en un popup.
- Controla el respondedor OCSP (Online/Offline, encender/apagar).
- Publica la CRL y ve si quedan revocaciones pendientes.

## Pantallas y flujo

### 1. Solicitar certificado (usuario)

![Boceto del formulario de solicitud](../../assets/img/lab-pki/web/mockup-user-solicitar.png)

Formulario "Bocata de Jamón" con Nombre, Apellidos, Contraseña, Correo, País, Organización, Provincia y Departamento, y el botón **Solicitar certificado**.

Flujo propuesto:

1. El usuario rellena el formulario. Los campos `C` y `O` deben coincidir con los de la CA; el correo es obligatorio.
2. La aplicación genera la clave privada cifrada y la CSR con los mismos campos que `gen_solicitud.sh -t usuario`.
3. La CSR queda en `solicitudes/` pendiente de revisión del administrador.
4. Cuando el administrador la acepta, se emite el certificado y se crea el PKCS#12.

### 2. Subir solicitud de servicio (usuario)

![Boceto de subida de CSR de servicio](../../assets/img/lab-pki/web/mockup-user-subirservicio.png)

El panel de servicios permite seleccionar un archivo `.csr` y subirlo. La aplicación debe validar que es una CSR legible y guardarla en `solicitudes/` para la revisión del administrador. La clave privada del servicio nunca sale del solicitante.

### 3. Certificados (usuario)

![Boceto de certificados del usuario](../../assets/img/lab-pki/web/mockup-user-certificados.png)

La sección **Certificados** permite:

- Buscar por nombre, CN o correo.
- Ver la información detallada del certificado (subject, issuer, serial, validez, SAN, usos).
- Comprobar el estado: `No revocado` o `Revocado`, consultando la CRL publicada o el respondedor OCSP.
- Descargar el `.crt` público.

El `.p12` no se ofrece en esta pantalla.

### 4. Panel de administración

![Boceto del panel de administración](../../assets/img/lab-pki/web/mockup-admin.png)

| Sección | Contenido |
| --- | --- |
| **Solicitudes** | Lista de CSR pendientes con su información; botones **Aceptar** y **Denegar**. |
| **Certificados** | Búsqueda, detalle, descarga del PKCS#12 y botón **Revocar** (abre un popup para elegir el motivo). |
| **OCSP** | Estado del respondedor (Online/Offline) y botón **Apagar**/**Encender**. |
| **CRL** | Aviso de revocaciones sin publicar y botón **Publicar**. |

## Mapeo UI → operación de la PKI

| Elemento de la interfaz | Operación del procedimiento |
| --- | --- |
| Formulario de solicitud (usuario) | `gen_solicitud.sh -t usuario/servicio` (crea clave + CSR). |
| Botón **Solicitar certificado** | Envío de la CSR a `solicitudes/` para revisión del administrador (RA). |
| Subir solicitud (servicios) | Subida del `.csr`; queda en `solicitudes/` pendiente de revisión. |
| Certificados (usuario): buscar | Búsqueda sobre `certs/` e `index.txt`. |
| Certificados (usuario): detalle y estado | `openssl x509 -text` + estado OCSP (`openssl ocsp ... -url ...:4747`) o CRL publicada. |
| Certificados (usuario): descargar | Descarga del `.crt` público de `certs/`. |
| Solicitudes (admin): ver información | Revisión manual previa que exige `emitir_cert.sh` (el admin actúa como RA). |
| **Aceptar** (admin) | `emitir_cert.sh <csr> {server_ext,user_ext,ocsp_ext}`. |
| **Denegar** (admin) | Rechazo de la CSR: no se emite y se descarta. |
| Certificados (admin): buscar y ver | Búsqueda sobre `certs/`/`index.txt` + `openssl x509 -text`. |
| Certificados (admin): descargar PKCS#12 | Descarga del `.p12` de `certs.p12` (solo `user_ext`); entrega en persona. |
| Certificados (admin): **Revocar** | Popup de motivo + `revocar_cert.sh <crt> [motivo]`. |
| CRL (admin): aviso y **Publicar** | Aviso de revocaciones sin publicar + `openssl ca -gencrl -out DB/crl-sub.pem` (y conversión DER si aplica). |
| OCSP (admin): Online/Offline y **Apagar/Encender** | Estado y arranque/parada de `openssl ocsp -port 4747 ...`. |
| Ver certificado (ambos) | `openssl x509 -text` sobre el `.crt`. |

## Reglas de seguridad del diseño

- La clave privada del usuario se genera en el servidor solo si el flujo del formulario lo exige; el `.p12` resultante se protege con `umask 077` (modo `600`) y nunca se publica en la zona de usuario.
- El administrador debe revisar la CSR antes de emitir: la aplicación no debe firmar automáticamente.
- La revocación exige un motivo válido y no debe permitir revocar dos veces el mismo serial.
- La CRL se regenera tras cada revocación; el panel debe avisar mientras haya cambios sin publicar.
- El acceso al panel de administración está restringido y separado del área de usuario.

Para el detalle de las operaciones subyacentes, consulta [Scripts](scripts.md) y [OpenSSL y PKI](../comandos/openssl.md).
