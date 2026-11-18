# PKI — 2ª fase: validación OCSP

La primera fase construyó la PKI y comprobó la revocación con `openssl` actuando como cliente OCSP. En esta segunda fase se pone un sitio web seguro delante de la PKI: el navegador (o el servidor) consulta al respondedor OCSP y se analizan los tres modos de operación —**OCSP regular**, **OCSP stapling** y **Must-Staple**— más la validación del certificado de usuario.

[:material-file-pdf-box: Enunciado de la 2ª fase (PDF)](../../assets/pdf/lab-pki2-enunciado.pdf){ .md-button }
[:material-file-pdf-box: Enunciado de la 1ª fase (PDF)](../../assets/pdf/lab-pki-enunciado.pdf){ .md-button }
[:material-file-pdf-box: Informe de la 2ª fase (PDF)](../../assets/pdf/informe-pki2.pdf){ .md-button }
[:material-download: Entrega completa (ZIP)](../../assets/pdf/entrega-pki2.zip){ .md-button }

!!! warning "Requiere la VM"
    El respondedor OCSP, Apache, el navegador y Wireshark se ejecutan en la VM Debian. Aquí están los comandos, las configuraciones y el análisis de cada ejercicio; las capturas y los resultados de navegador quedan marcados como **VM**. El flujo OCSP por línea de comandos sí se ha verificado en local.

## Punto de partida

Se reutiliza la PKI de la [1ª fase](guia.md): raíz, subCA, base de datos `index.txt`, certificado de firma OCSP (`ocsp_ext`) y respondedor en el puerto **4747**. El sitio web se monta como en la [actividad Apache](../../tema3/actividades/apache.md).

Nombres usados en esta guía (ajústalos si tu PKI es distinta):

| Elemento | Valor |
| --- | --- |
| Sufijo de dominio | `bocata-jamon.srdsi.lab` |
| Sitio web | `www.bocata-jamon.srdsi.lab` |
| Respondedor OCSP | `ocsp.bocata-jamon.srdsi.lab:4747` |
| SubCA | `/home/user1/PKI_root/PKI_sub` |
| Certificado de firma OCSP | `certificado-ocsp.bocata-jamon.srdsi.lab.crt` |

Resolución de nombres en la VM y, si navegas desde el anfitrión, también en el anfitrión:

```bash
# En la VM
echo "127.0.0.1 www.bocata-jamon.srdsi.lab ocsp.bocata-jamon.srdsi.lab" | \
  sudo tee -a /etc/hosts

# En el anfitrión (IP host-only de la VM)
echo "192.168.56.110 www.bocata-jamon.srdsi.lab ocsp.bocata-jamon.srdsi.lab" | \
  sudo tee -a /etc/hosts
```

## 1. Respondedor OCSP

**VM**. El respondedor lee `index.txt` **al arrancar**: si revocas un certificado, hay que reiniciarlo para que lo vea.

```bash
cd ~/PKI_root/PKI_sub
rm -f log-subCA.txt

# La clave del respondedor se generó cifrada con gen_solicitud.sh. -passin evita
# el prompt y es obligatorio si el respondedor se lanza en segundo plano.
export OCSP_PASS='pass_de_la_clave_ocsp'

openssl ocsp -port 4747 \
  -index DB/index.txt \
  -CA certificado-subCA.crt \
  -rsigner certs/certificado-ocsp.bocata-jamon.srdsi.lab.crt \
  -rkey private/clave-privada-ocsp.bocata-jamon.srdsi.lab.key \
  -passin env:OCSP_PASS \
  -text -out log-subCA.txt
```

Si lo dejas en segundo plano:

```bash
nohup openssl ocsp -port 4747 \
  -index DB/index.txt -CA certificado-subCA.crt \
  -rsigner certs/certificado-ocsp.bocata-jamon.srdsi.lab.crt \
  -rkey private/clave-privada-ocsp.bocata-jamon.srdsi.lab.key \
  -passin env:OCSP_PASS -text -out log-subCA.txt >/dev/null 2>&1 &
ss -ltnp | grep 4747
```

!!! warning "Clave del respondedor cifrada"
    `gen_solicitud.sh` genera siempre la clave cifrada. Sin `-passin`, OpenSSL pide la contraseña por terminal; en segundo plano o con `nohup` el proceso no arranca. Comprueba el log (`log-subCA.txt`) y que el puerto 4747 está a la escucha antes de seguir.

Comprueba con el cliente de OpenSSL antes de tocar el navegador:

```bash
openssl ocsp -issuer certificado-subCA.crt \
  -cert certs/certificado-www.bocata-jamon.srdsi.lab.crt \
  -CAfile certificado-subCA.crt \
  -url http://ocsp.bocata-jamon.srdsi.lab:4747 -resp_text
```

Debe responder `Cert Status: good`. En el [apartado de verificación](#verificado-en-local) hay una salida real de este flujo.

### Certificado de la subCA y respondedor de la raíz

En esta PKI el certificado de la subCA también lleva AIA
(`OCSP - URI:http://ocsp.bocata-jamon.srdsi.lab:4747`). Cuando
`SSLOCSPEnable` valida el certificado del usuario, Apache comprueba **toda la
cadena**, incluida la subCA. El respondedor de la subCA no puede responder por
ella misma (la emitió la raíz) y devuelve `unknown`, con lo que la verificación
falla aunque el usuario sea válido.

La solución es un segundo respondedor, el de la raíz, en el puerto 4748:

```bash
cd ~/PKI_root
OCSP_ROOT_PASS='pass_ocsp_root'
openssl ocsp -port 4748 -index DB/index.txt -CA certificado-rootCA.crt \
  -rsigner certs/certificado-ocsp-root.bocata-jamon.srdsi.lab.crt \
  -rkey ocsp-root/clave-privada-ocsp-root.bocata-jamon.srdsi.lab.key \
  -passin env:OCSP_ROOT_PASS -text -out log-root.txt
```

Los comandos completos (emisión del certificado de firma OCSP con la raíz y
re-firma de la subCA con AIA al 4748) están en
[`root-ocsp.txt`](../../assets/config/pki2/root-ocsp.txt).

Además, las URL de AIA deben resolver y servir los certificados:

```apache
# pki-aia.conf: publica subCA.crt y rootCA.crt en /var/www/pki/
<VirtualHost *:80>
    ServerName subCA.bocata-jamon.srdsi.lab
    DocumentRoot /var/www/pki
</VirtualHost>
<VirtualHost *:80>
    ServerName rootCA.bocata-jamon.srdsi.lab
    DocumentRoot /var/www/pki
</VirtualHost>
```

```bash
sudo cp ~/PKI_root/PKI_sub/certificado-subCA.crt /var/www/pki/subCA.crt
sudo cp ~/PKI_root/certificado-rootCA.crt        /var/www/pki/rootCA.crt
echo "127.0.0.1 subCA.bocata-jamon.srdsi.lab rootCA.bocata-jamon.srdsi.lab" | \
  sudo tee -a /etc/hosts
```

Fichero: [`pki-aia.conf`](../../assets/config/pki2/pki-aia.conf).

Si tu subCA no lleva AIA, con el respondedor de la subCA es suficiente; si lo
lleva, añade el de la raíz y apunta el AIA de la subCA al 4748.

## 2. Certificado del sitio web
**VM**. Pide un certificado de servicio con SAN y emítelo con `server_ext` (que incluye el AIA con la URL OCSP):

```bash
cd ~/PKI_scripts
KEY_PASS='pass_de_la_clave' ./gen_solicitud.sh \
  -t servicio -n "www.bocata-jamon.srdsi.lab" \
  -d "www.bocata-jamon.srdsi.lab,bocata-jamon.srdsi.lab" \
  -e webadmin@bocata-jamon.srdsi.lab -C ES -S GP -L Donostia \
  -O "Bocata de Jamon" -U LABS -o ~/PKI_root/PKI_sub/servidor

CA_PASS='pass_de_la_CA' ./emitir_cert.sh \
  ~/PKI_root/PKI_sub/servidor/solicitud-www.bocata-jamon.srdsi.lab.csr server_ext
```

`-O` debe coincidir con el `O` de la subCA (`Bocata de Jamon`); si no, la política de la CA rechaza la solicitud. Comprueba las extensiones:

```bash
openssl x509 -in ~/PKI_root/PKI_sub/certs/certificado-www.bocata-jamon.srdsi.lab.crt \
  -noout -subject -ext subjectAltName,authorityInfoAccess,extendedKeyUsage
```

Debe aparecer el SAN con los dos nombres y `OCSP - URI:http://ocsp.bocata-jamon.srdsi.lab:4747`.

Prepara los ficheros de Apache:

```bash
sudo mkdir -p /etc/apache2/ssl/pki2 /var/www/pki2/docs
sudo install -m 644 ~/PKI_root/PKI_sub/certs/certificado-www.bocata-jamon.srdsi.lab.crt \
  /etc/apache2/ssl/pki2/servidor.crt
# La clave se genera cifrada: Apache no puede pedir la passphrase al arrancar
# como servicio. Descífrala antes de instalarla.
KEY_PASS='pass_de_la_clave' openssl pkey \
  -in ~/PKI_root/PKI_sub/servidor/clave-privada-www.bocata-jamon.srdsi.lab.key \
  -passin env:KEY_PASS -out /tmp/servidor-pki2.key
sudo install -m 600 /tmp/servidor-pki2.key /etc/apache2/ssl/pki2/servidor.key
sudo install -m 644 ~/PKI_root/PKI_sub/certificado-subCA.crt /etc/apache2/ssl/pki2/subCA.crt

sudo sh -c 'cat /etc/apache2/ssl/pki2/subCA.crt \
            ~/PKI_root/certificado-rootCA.crt > /etc/apache2/ssl/pki2/cadena-cas.pem'
```

```bash
sudo tee /var/www/pki2/docs/index.html >/dev/null <<'HTML'
<html><title>PKI2</title>
<body><h1>www.bocata-jamon.srdsi.lab — OCSP</h1></body></html>
HTML
```

## 3. OCSP regular

El navegador consulta directamente al respondedor usando la URL del AIA. Apache no necesita nada especial.

```bash
sudo cp pki2-ocsp-regular.conf /etc/apache2/sites-available/
sudo a2enmod ssl
sudo a2ensite pki2-ocsp-regular
sudo apache2ctl configtest
sudo apache2ctl graceful
```

Si vienes de la actividad Apache, el puerto 443 ya está en `ports.conf` (`Listen 443`) y `mod_ssl` ya está activo.

Fichero: [`pki2-ocsp-regular.conf`](../../assets/config/pki2/pki2-ocsp-regular.conf).

En Firefox, comprueba que la validación OCSP está activa (**Ajustes → Privacidad y seguridad → Certificados → Ver certificados → Validación** o `about:config` → `security.OCSP.enabled = 1`). Importa la CA raíz y la subCA como autoridades.

### Ejercicio 1

| Escenario | Qué ocurre | Quién contacta con el OCSP |
| --- | --- | --- |
| Respondedor **parado** | Los navegadores actuales tratan el fallo de red como **soft-fail**: dan el certificado por válido y muestran la página. Antes mostraban un error y bloqueaban el acceso. | Nadie: el navegador no obtiene respuesta. |
| Respondedor **en marcha** | El navegador valida el estado y la página carga. | **El navegador**, no Apache. |
| Certificado del servidor **revocado** | El respondedor devuelve `revoked` y el navegador **bloquea** el acceso. | El navegador. |

El soft-fail es el agujero que motiva *stapling* y *must-staple*: un atacante que bloquee el tráfico al respondedor puede hacer que se acepte un certificado revocado.

Para revocar y reiniciar:

```bash
CA_PASS='pass_de_la_CA' ~/PKI_scripts/revocar_cert.sh \
  ~/PKI_root/PKI_sub/certs/certificado-www.bocata-jamon.srdsi.lab.crt cessationOfOperation

# El respondedor lee index.txt al arrancar: hay que reiniciarlo
pkill -f "openssl ocsp -port 4747"
# y volver a lanzar el comando del apartado 1
```

Captura con Wireshark:

- Filtro de captura: `tcp port 443 or tcp port 4747`.
- Los mensajes OCSP del navegador viajan por **HTTP en claro** al puerto 4747: se ven la petición y la respuesta.
- Si Wireshark no disecciona el puerto 4747, usa **Decode As… → HTTP** y luego el filtro `ocsp`.
- El tráfico al 443 está cifrado; para ver el handshake completo necesitas el *keylog* (anexo).

!!! tip "Caché del navegador"
    Firefox guarda respuestas OCSP. Para ver cada escenario limpio, navega en **ventana privada** y borra la caché desactivando y volviendo a activar la comprobación OCSP. Si el resultado no cambia, reinicia el navegador.

!!! tip "Forzar el comportamiento antiguo (hard-fail)"
    Con `security.OCSP.require = true` en `about:config`, Firefox rechaza el certificado si no puede contactar con el respondedor. Sirve para comparar el hard-fail clásico con el soft-fail actual; vuelve a ponerlo en `false` al terminar.

## 4. OCSP stapling

Ahora es **Apache** quien consulta al respondedor y envía la respuesta firmada en el *handshake*. El navegador no contacta con el OCSP.

```bash
sudo a2enmod socache_shmcb ssl
sudo cp pki2-ocsp-stapling.conf /etc/apache2/sites-available/
sudo a2dissite pki2-ocsp-regular
sudo a2ensite pki2-ocsp-stapling
sudo apache2ctl configtest
sudo apache2ctl graceful
```

Fichero: [`pki2-ocsp-stapling.conf`](../../assets/config/pki2/pki2-ocsp-stapling.conf).

Puntos clave de la configuración:

- `SSLStaplingCache "shmcb:/var/run/apache2/ssl_stapling(32768)"` **fuera** de `<VirtualHost>`. La ruta del enunciado (`logs/ssl_stapling`) es relativa a `ServerRoot`; si `/etc/apache2/logs` no existe, falla.
- `SSLCACertificateFile` con la cadena de CAs: Apache necesita localizar al emisor del certificado.
- `SSLUseStapling On`.
- Opcionales para ver los cambios rápido: `SSLStaplingForceURL`, `SSLStaplingResponseMaxAge 90`, `SSLStaplingStandardCacheTimeout 90`.

Comprueba el *staple* sin navegador:

```bash
echo | openssl s_client -connect www.bocata-jamon.srdsi.lab:443 \
  -servername www.bocata-jamon.srdsi.lab -status -CAfile /etc/apache2/ssl/pki2/cadena-cas.pem
```

La primera conexión puede responder `OCSP response: no response sent`: Apache obtiene el *staple* de forma asíncrona. Repite a los pocos segundos; entonces aparece `OCSP Response Status: successful` y el detalle del certificado.

### Ejercicio 2

| Pregunta | Respuesta |
| --- | --- |
| ¿Quién contacta con el OCSP? | **Apache**, no el navegador. |
| ¿En qué momento? | Al arrancar o en la primera conexión, y luego según la caché (`SSLStaplingStandardCacheTimeout`). La primera petición puede quedarse sin *staple*. |
| ¿Qué cambia entre TLS 1.3 y TLS 1.2? | En **TLS 1.2** la respuesta viaja en el mensaje `CertificateStatus`, después del `Certificate`. En **TLS 1.3** va como extensión `status_request` dentro de la entrada de certificado del mensaje `Certificate`. En ambos casos queda cifrada, pero en TLS 1.3 todo el handshake posterior al `ServerHello` está cifrado. |

Con el *keylog* cargado en Wireshark se ve la respuesta OCSP dentro del handshake. Sin él, solo se ve el intercambio cifrado; el tráfico al puerto 4747 entre Apache y el respondedor sí es visible (HTTP).

Si revocas el certificado del servidor y reinicias el respondedor:

- Apache tarda en refrescar el *staple* hasta que caduca su caché. Para la práctica, baja `SSLStaplingResponseMaxAge`/`SSLStaplingStandardCacheTimeout` a 90 s o reinicia Apache.
- Cuando el *staple* ya contiene `revoked`, el navegador rechaza la conexión.
- Si el *staple* aún no se ha refrescado, el navegador puede aceptar la conexión y, según su configuración, hacer su propia consulta OCSP.

## 5. Must-Staple (RFC 7633)

Se añade la extensión `TLS Feature: status_request` al certificado del servidor. Un navegador que la recibe **no debe aceptar** la conexión si no hay *staple*, lo que cierra el soft-fail.

**VM**. Añade la directiva a `[server_ext]` en `~/PKI_root/PKI_sub/ca-sub_openssl.cnf`:

```ini
[server_ext]
authorityInfoAccess = @issuer_info
authorityKeyIdentifier = keyid:always
basicConstraints = critical,CA:false
crlDistributionPoints = @crl_info
extendedKeyUsage = clientAuth,serverAuth
keyUsage = critical,digitalSignature,keyEncipherment
subjectKeyIdentifier = hash
tlsfeature = status_request
```

Copia de la sección: [`server-ext-must-staple.txt`](../../assets/config/pki2/server-ext-must-staple.txt).

Emite un certificado **nuevo** (la extensión no se puede añadir a uno ya emitido). El CN es el mismo, así que usa un directorio de salida distinto para no chocar con el certificado anterior:

```bash
KEY_PASS='pass_de_la_clave' ./gen_solicitud.sh \
  -t servicio -n "www.bocata-jamon.srdsi.lab" \
  -d "www.bocata-jamon.srdsi.lab,bocata-jamon.srdsi.lab" \
  -e webadmin@bocata-jamon.srdsi.lab -C ES -S GP -L Donostia \
  -O "Bocata de Jamon" -U LABS -o ~/PKI_root/PKI_sub/servidor-ms

# El CN es el mismo, así que el .crt se llamaría igual y emitir_cert.sh se
# negaría a sobrescribirlo: usa un directorio de salida distinto.
mkdir -p ~/PKI_root/PKI_sub/certs-ms
CA_PASS='pass_de_la_CA' CERTS_DIR=~/PKI_root/PKI_sub/certs-ms ./emitir_cert.sh \
  ~/PKI_root/PKI_sub/servidor-ms/solicitud-www.bocata-jamon.srdsi.lab.csr server_ext
```

Comprueba la extensión:

```bash
openssl x509 -in ~/PKI_root/PKI_sub/certs-ms/certificado-www.bocata-jamon.srdsi.lab.crt \
  -noout -text | grep -A1 "TLS Feature"
```

```text
TLS Feature:
    status_request
```

Instala el certificado y la clave como `servidor-must-staple.crt`/`.key`:

```bash
sudo install -m 644 ~/PKI_root/PKI_sub/certs-ms/certificado-www.bocata-jamon.srdsi.lab.crt \
  /etc/apache2/ssl/pki2/servidor-must-staple.crt
KEY_PASS='pass_de_la_clave' openssl pkey \
  -in ~/PKI_root/PKI_sub/servidor-ms/clave-privada-www.bocata-jamon.srdsi.lab.key \
  -passin env:KEY_PASS -out /tmp/servidor-ms.key
sudo install -m 600 /tmp/servidor-ms.key /etc/apache2/ssl/pki2/servidor-must-staple.key
```

Activa [`pki2-ocsp-must-staple.conf`](../../assets/config/pki2/pki2-ocsp-must-staple.conf) (misma configuración de *stapling*, distintos ficheros) y recarga Apache.

### Ejercicios

| Escenario | Resultado esperado |
| --- | --- |
| Extensión presente en el certificado | `TLS Feature: status_request`. |
| Respondedor **parado** | Apache no puede obtener el *staple*; el navegador **deniega** el acceso (ya no hay soft-fail). |
| Respondedor **en marcha** | Apache envía el *staple* y el acceso funciona. |

!!! note "Usa Firefox para esta prueba"
    Firefox aplica Must-Staple. Algunos navegadores basados en Chromium no lo exigen y aceptarían la conexión sin *staple*, lo que falsearía el resultado del ejercicio.

## 6. Extra E: validación del certificado de usuario

El servidor también puede comprobar si el certificado **del usuario** está revocado. Por defecto Apache valida la firma y la cadena, pero **no consulta CRL ni OCSP**: un usuario revocado sigue entrando. `SSLOCSPEnable on` activa la consulta.

**VM**. Emite un certificado de usuario con la PKI de la fase 1:

```bash
KEY_PASS='pass_usuario' ./gen_solicitud.sh -t usuario \
  -n "Usuario-PKI2" -e usuario@bocata-jamon.srdsi.lab \
  -C ES -O "Bocata de Jamon" -U LABS -o ~/PKI_root/PKI_sub/usuarios

KEY_PASS='pass_usuario' CA_PASS='pass_de_la_CA' ./emitir_cert.sh \
  ~/PKI_root/PKI_sub/usuarios/solicitud-Usuario-PKI2.csr user_ext
```

El `.p12` resultante se importa en Firefox (**Sus certificados**). La contraseña es `KEY_PASS` (o `P12_PASS`).

Activa [`pki2-usuario-ocsp.conf`](../../assets/config/pki2/pki2-usuario-ocsp.conf), que incluye:

```apache
SSLVerifyClient optional
SSLVerifyDepth 2
SSLCACertificateFile /etc/apache2/ssl/pki2/cadena-cas.pem
SSLOCSPEnable on
```

```bash
sudo a2dissite pki2-ocsp-stapling
sudo a2ensite pki2-usuario-ocsp
sudo apache2ctl configtest
sudo apache2ctl graceful
```

Prueba en `https://www.bocata-jamon.srdsi.lab/zona-privada/`:

| Situación | Sin `SSLOCSPEnable` | Con `SSLOCSPEnable on` |
| --- | --- | --- |
| Certificado de usuario válido | Acceso permitido. | Acceso permitido. |
| Certificado de usuario revocado | **Acceso permitido**: Apache no consulta la revocación. | **Acceso denegado**: la consulta OCSP devuelve `revoked`. |

Para revocar el certificado de usuario:

```bash
CA_PASS='pass_de_la_CA' ~/PKI_scripts/revocar_cert.sh \
  ~/PKI_root/PKI_sub/certs/certificado-Usuario-PKI2.crt cessationOfOperation
# reinicia el respondedor para que lea el nuevo index.txt
```

En Wireshark se ve la consulta **de Apache al respondedor** por el puerto 4747, no la del navegador. Si Apache cachea la respuesta, reinícialo para repetir la prueba.

!!! warning "La cadena completa se valida"
    `SSLOCSPEnable` comprueba el estado de **cada** certificado de la cadena del
    cliente. Si el certificado de la subCA lleva AIA, Apache preguntará también
    por él: hace falta el respondedor de la raíz en 4748 y que las URL de AIA
    resuelvan (ver [Certificado de la subCA y respondedor de la raíz](#certificado-de-la-subca-y-respondedor-de-la-raiz)).
    Con la cadena y la raíz en el almacén del sistema no se necesita
    `SSLOCSPNoVerify`; si aparece `root ca not trusted`, revisa el AIA y el
    almacén antes de desactivar la verificación.

!!! warning "No uses los `.p12` de la actividad Apache"
    Los certificados de `certificados_Apache.zip` no llevan AIA (`OCSP;URI`) ni EKU. Para el extra E usa el certificado emitido por **tu** subCA con `user_ext`, que sí incluye la URL del respondedor.

## Entregables

Según el enunciado: informe con el análisis de los resultados de los ejercicios y pantallazos de los errores del navegador y de los accesos a los sitios virtuales, capturas de Wireshark, los certificados del sitio web y del servidor OCSP y los ficheros de configuración de los sitios virtuales para los tres casos OCSP.

- [x] Respondedor OCSP en marcha y consulta `openssl ocsp` con `good` y `revoked`.
- [x] Certificado del sitio con SAN y AIA; cadena instalada en Apache.
- [x] Ejercicio 1: tres escenarios (sin OCSP, con OCSP, revocado) con capturas.
- [x] Ejercicio 2: *stapling* activo; handshake TLS 1.2 y TLS 1.3 comparado.
- [x] Must-Staple: extensión en el certificado, denegación sin respondedor y acceso con respondedor.
- [x] Extra E: usuario válido y revocado, con y sin `SSLOCSPEnable`.
- [x] Certificados del sitio y del OCSP adjuntos.
- [x] Tres configuraciones de Apache (regular, *stapling*, *must-staple*) adjuntas.
- [x] Informe completo en PDF.

### Guion de capturas para una sola sesión

| # | Acción | Captura |
| --- | --- | --- |
| 1 | OCSP parado, acceso al sitio | Página cargada (soft-fail) + Wireshark sin respuesta del 4747 |
| 2 | OCSP arrancado, acceso | Petición y respuesta OCSP en Wireshark |
| 3 | Revocar servidor y reiniciar OCSP | Error del navegador + respuesta `revoked` |
| 4 | Activar *stapling*, `s_client -status` | Respuesta OCSP en el handshake |
| 5 | Certificado Must-Staple sin respondedor | Error del navegador |
| 6 | Must-Staple con respondedor | Acceso correcto |
| 7 | Extra E con usuario revocado | Antes y después de `SSLOCSPEnable` |

### Estructura del informe

1. **Objetivo y entorno**: PKI de la fase 1, versiones de OpenSSL y Apache, nombres DNS y puertos.
2. **Respondedor OCSP**: comando de arranque, consulta `good`/`revoked` y log.
3. **Certificado del sitio**: SAN, AIA, cadena instalada en Apache.
4. **Ejercicio 1 (OCSP regular)**: los tres escenarios con capturas del navegador y de Wireshark, y el análisis del soft-fail.
5. **Ejercicio 2 (stapling)**: quién consulta, cuándo, y comparación TLS 1.2/TLS 1.3.
6. **Must-Staple**: extensión, denegación sin respondedor y acceso con respondedor.
7. **Extra E**: validación del certificado de usuario, antes y después de `SSLOCSPEnable`.
8. **Conclusiones**: soft-fail, *stapling* y Must-Staple; cuándo usar cada uno.
9. **Anexos**: certificados del sitio y del OCSP y las tres configuraciones de Apache.

## Resultados en la VM

La práctica se ejecutó en la VM Debian 13 (Apache 2.4.71, OpenSSL 3.5.7,
Firefox ESR). El informe completo está en
[`informe-pki2.pdf`](../../assets/pdf/informe-pki2.pdf).

| Escenario | Resultado |
| --- | --- |
| OCSP parado, sitio con OCSP regular | Página **cargada** (soft-fail); el navegador intenta el 4747 y recibe `RST`. |
| OCSP en marcha | El navegador consulta al 4747 y recibe `good`; se ven las peticiones y respuestas en Wireshark. |
| Servidor revocado | `Cert Status: revoked` y Firefox bloquea con `SEC_ERROR_REVOKED_CERTIFICATE`. |
| Stapling | `s_client -status` devuelve `Cert Status: good` en TLS 1.2 y TLS 1.3; el navegador no consulta el 4747. |
| Must-Staple sin respondedor | Acceso denegado con `SEC_ERROR_OCSP_TRY_SERVER_LATER`. |
| Must-Staple con respondedor | Acceso correcto. |
| Usuario válido | `200 OK`; Apache valida subCA (4748) y usuario (4747). |
| Usuario revocado sin `SSLOCSPEnable` | **200 OK** por consola: Apache no consulta la revocación. |
| Usuario revocado con `SSLOCSPEnable` | Alerta TLS `certificate revoked`; Firefox muestra `SSL_ERROR_REVOKED_CERT_ALERT`. |

![OCSP regular sin respondedor: soft-fail](../../assets/img/lab-pki2/01-regular-sin-ocsp.png)

![OCSP regular con el respondedor en marcha](../../assets/img/lab-pki2/02-regular-con-ocsp.png)

![Wireshark: peticiones y respuestas OCSP](../../assets/img/lab-pki2/03-regular-wireshark.png)

![Certificado del servidor revocado](../../assets/img/lab-pki2/04-servidor-revocado.png)

![Sitio con OCSP stapling](../../assets/img/lab-pki2/05-stapling.png)

![Respuesta OCSP en el handshake (TLS 1.2 y 1.3)](../../assets/img/lab-pki2/06-stapling-sclient.png)

![Mensajes de la respuesta OCSP en TLS 1.2 y TLS 1.3](../../assets/img/lab-pki2/13-tls12-tls13-mensajes.png)

![Must-Staple sin respondedor: denegado](../../assets/img/lab-pki2/07-must-staple-sin-ocsp.png)

![Must-Staple con respondedor: acceso correcto](../../assets/img/lab-pki2/08-must-staple-con-ocsp.png)

![Usuario válido con SSLOCSPEnable](../../assets/img/lab-pki2/09-usuario-ok.png)

![Usuario revocado sin SSLOCSPEnable: HTTP 200 por consola](../../assets/img/lab-pki2/10-usuario-revocado-sin-ocsp.png)

![Usuario revocado con SSLOCSPEnable: SSL_ERROR_REVOKED_CERT_ALERT](../../assets/img/lab-pki2/11-usuario-revocado-con-ocsp.png)

En el extra E, Apache consulta **dos veces** al OCSP: al respondedor de la raíz
(4748) por la subCA y al de la subCA (4747) por el usuario. Las capturas
`07-extrae-good.pcapng` y `08-extrae-revoked.pcapng` lo demuestran:

![Apache consulta la subCA (4748) y el usuario (4747)](../../assets/img/lab-pki2/14-extrae-ocsp-good.png)

![Con el usuario revocado, la respuesta del 4747 es revoked](../../assets/img/lab-pki2/15-extrae-ocsp-revoked.png)

![Estados OCSP extraídos de las capturas](../../assets/img/lab-pki2/16-extrae-status.png)

!!! note "OCSP del navegador en el extra E"
    Para el extra E se desactivó la validación OCSP del navegador
    (`security.OCSP.enabled = 0`) y así se observa solo la decisión de Apache.
    Las capturas son de la configuración final, sin `SSLOCSPNoVerify`.

## Verificado en local

El flujo completo se ha reproducido primero en un directorio temporal con los **scripts y la configuración del repositorio** (`gen_solicitud.sh`, `emitir_cert.sh`, `revocar_cert.sh` y `ca-sub_openssl.cnf`) sobre OpenSSL 4.1.0: certificado de servidor con SAN y AIA, certificado de firma OCSP, respondedor, consulta `good`, revocación, reinicio, `revoked`, reemisión con `tlsfeature = status_request` y emisión de un certificado de usuario con su `.p12`. Después se repitió en la VM; los resultados están en el apartado anterior.

```console
$ openssl x509 -in serv.crt -noout -text | grep -A1 "TLS Feature"
            TLS Feature:
                status_request

$ openssl ocsp -issuer subca.crt -cert serv.crt -url http://127.0.0.1:4780 -resp_text
    OCSP Response Status: successful (0x0)
    Cert Status: good
    This Update: Nov 18 08:56:52 2026 GMT

# tras openssl ca -revoke serv.crt y reiniciar el respondedor
$ openssl ocsp -issuer subca.crt -cert serv.crt -url http://127.0.0.1:4780 -resp_text
    OCSP Response Status: successful (0x0)
    Cert Status: revoked
    Revocation Time: Nov 18 08:57:04 2026 GMT
```

| Comprobación | Resultado |
| --- | --- |
| `tlsfeature = status_request` en `[server_ext]` | El certificado muestra `TLS Feature: status_request`. |
| Respondedor + cliente OCSP, certificado válido | `Cert Status: good`. |
| Revocación + reinicio del respondedor | `Cert Status: revoked`. |
| Emisión con los scripts del repositorio | Certificado de servidor con SAN y AIA; `.p12` con `clientAuth` y AIA. |
| Clave del respondedor | Cifrada: hace falta `-passin env:OCSP_PASS` para arrancarlo sin prompt. |
| Sintaxis de los cuatro vhosts OCSP | `httpd -t` con Apache 2.4.71 en un contenedor: `Syntax OK` (rutas remapeadas). |
| Apache, navegador y Wireshark en la VM | Verificado; capturas y `.pcapng` en [Resultados en la VM](#resultados-en-la-vm). |

## Anexo: Wireshark con TLS 1.3

```bash
export SSLKEYLOGFILE=$HOME/keyslog.log
touch "$SSLKEYLOGFILE"
firefox-esr --ssl-key-log-file="$SSLKEYLOGFILE" --private-window \
  https://www.bocata-jamon.srdsi.lab
```

En Wireshark: **Editar → Preferencias → Protocolos → TLS → (Pre)-Master-Secret log filename**. Con TLS 1.3 el *keylog* es la única forma de descifrar; la clave privada del servidor no basta.

- Para el handshake y el *staple*: filtro `tls.handshake`.
- Para OCSP regular: captura el puerto 4747 y usa **Decode As… → HTTP** si no lo disecciona; después `ocsp`.
- Para el certificado: **TLS → Certificate** y revisa `TLS Feature` y `Authority Information Access`.

## Enlaces

- [Laboratorio PKI: guía de la 1ª fase](guia.md)
- [Scripts de la PKI](scripts.md)
- [OpenSSL y PKI](../comandos/openssl.md)
- [Actividad Apache](../../tema3/actividades/apache.md)
- [Certificados de laboratorio](../../recursos/certificados.md)
