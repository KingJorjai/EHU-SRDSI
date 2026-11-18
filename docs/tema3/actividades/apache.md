# Actividad Apache (2.4)

Práctica de servidor web sobre la VM Debian: sitio virtual, zonas con autenticación básica y *digest*, HTTPS con un certificado emitido por una CA propia, autenticación de cliente por certificado y análisis del tráfico con Wireshark.

[:material-file-pdf-box: Enunciado de la actividad (PDF)](../../assets/pdf/lab-apache-actividad.pdf){ .md-button }

!!! warning "Requiere la VM"
    La instalación de Apache, el navegador y las capturas se hacen en la VM Debian (`user1`, `192.168.56.110`). Los pasos que dependen de ella están marcados como **VM**. Los certificados y su verificación sí se han comprobado en local.

## Material

Los certificados de la actividad están en el repositorio y publicados como descarga:

| Fichero | Contenido |
| --- | --- |
| [`ca_cert.pem`](../../assets/certs/apache/ca_cert.pem) | CA raíz `CA-SRDSI` (autofirmada). |
| [`subca_cert.pem`](../../assets/certs/apache/subca_cert.pem) | SubCA `SubCA-SRDSI`, firmada por la raíz. |
| [`serv_cert.pem`](../../assets/certs/apache/serv_cert.pem) | Certificado del sitio `www.srdsi.lab` (con SAN). |
| [`serv_key.pem`](../../assets/certs/apache/serv_key.pem) | Clave privada del servidor, sin *passphrase*. |
| [`user.p12`](../../assets/certs/apache/user.p12) | Certificado y clave de `Usuario-SRDSI` (contraseña `abc`). |
| [`user2.p12`](../../assets/certs/apache/user2.p12) | Certificado y clave de `Usuario2-SRDSI` (contraseña `abcd`). |
| [`README`](../../assets/certs/apache/README) | Descripción original del paquete. |

Detalle de los certificados, cadena y rarezas: [Certificados y claves de laboratorio](../../recursos/certificados.md#apache-ca-subca-y-certificados-de-usuario).

## 1. Sitio virtual HTTP

**VM**. Instala Apache y crea el contenido:

```bash
sudo apt-get update
sudo apt-get install apache2 apache2-utils

sudo mkdir -p /var/www/srdsi-lab/docs/zona-privada
sudo mkdir -p /etc/apache2/ssl

sudo tee /var/www/srdsi-lab/docs/index.html >/dev/null <<'HTML'
<html><title>Test</title>
<body><h1>Laboratorio SRDSI</h1></body></html>
HTML
```

El contenido estático queda de `root:root` con modo `755`; el dinámico, de `www-data:www-data`.

Resuelve el nombre. En la VM:

```bash
echo "127.0.0.1 www.srdsi.lab srdsi.lab" | sudo tee -a /etc/hosts
```

Si navegas desde el anfitrión, añade en **tu** `/etc/hosts` la IP de la VM:

```text
192.168.56.110 www.srdsi.lab srdsi.lab
```

Crea `/etc/apache2/sites-available/srdsi-lab.conf`:

```apache
<VirtualHost *:80>
    ServerName www.srdsi.lab
    ServerAlias srdsi.lab
    ServerAdmin webadmin@srdsi.lab
    DocumentRoot /var/www/srdsi-lab/docs

    <Directory /var/www/srdsi-lab/docs>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/srdsi-lab-error.log
    CustomLog ${APACHE_LOG_DIR}/srdsi-lab-access.log combined
</VirtualHost>
```

También está como fichero listo para copiar: [`srdsi-lab.conf`](../../assets/config/apache/srdsi-lab.conf).

```bash
sudo a2ensite srdsi-lab
sudo apache2ctl configtest
sudo apache2ctl graceful
sudo apache2ctl -S                 # debe listar www.srdsi.lab:80
curl -s http://www.srdsi.lab/ | grep -o "Laboratorio SRDSI"
```

Si falla, revisa `sudo tail /var/log/apache2/error.log`. Abre `http://www.srdsi.lab` en una **ventana privada** y comprueba que se ve la página.

## 2. Zona privada con autenticación básica

**VM**. Página de prueba y usuario:

```bash
sudo tee /var/www/srdsi-lab/docs/zona-privada/index.html >/dev/null <<'HTML'
<html><title>Test</title>
<body><h1>Laboratorio SRDSI ACCESO RESTRINGIDO</h1></body></html>
HTML

sudo htpasswd -c /etc/apache2/usersweb admin1
sudo htpasswd    /etc/apache2/usersweb admin2
sudo a2enmod auth_basic
```

Añade el directorio al sitio:

```apache
<Directory /var/www/srdsi-lab/docs/zona-privada>
    AuthType Basic
    AuthName "Zona acceso restringido a personal autorizado"
    AuthUserFile /etc/apache2/usersweb
    Require valid-user
</Directory>
```

```bash
sudo apache2ctl graceful
curl -i http://www.srdsi.lab/zona-privada/                  # 401
curl -iu admin1:password http://www.srdsi.lab/zona-privada/   # 200
```

`htpasswd` usa MD5 por defecto; puedes forzar bcrypt con `-B`.

### Captura: credenciales en claro

**VM** (o anfitrión, si navegas desde él). Captura el tráfico HTTP y filtra:

```bash
sudo dumpcap -i lo -w apache-basic.pcapng -a duration:20
```

En Wireshark: `http.request && http.authorization`. La cabecera viaja así:

```http
Authorization: Basic YWRtaW4xOnBhc3N3b3Jk
```

```bash
echo YWRtaW4xOnBhc3N3b3Jk | base64 -d
# admin1:password
```

Conclusión: **Basic no cifra**, solo codifica. Sobre HTTP cualquiera con acceso al medio lee las credenciales; la solución es HTTPS.

## 3. Autenticación Digest

**VM**. Activa el módulo y crea el fichero de usuarios:

```bash
sudo a2enmod auth_digest
sudo htdigest -c /etc/apache2/digest_users "Area privada" admin1
sudo htdigest    /etc/apache2/digest_users "Area privada" admin2
```

Sustituye el bloque de la zona privada:

```apache
<Directory /var/www/srdsi-lab/docs/zona-privada>
    AuthType Digest
    AuthName "Area privada"
    AuthDigestAlgorithm MD5
    AuthDigestDomain http://www.srdsi.lab/zona-privada/
    AuthDigestProvider file
    AuthUserFile /etc/apache2/digest_users
    Require valid-user
</Directory>
```

```bash
sudo apache2ctl graceful
curl -i --digest -u admin1:password http://www.srdsi.lab/zona-privada/
```

El fichero de `htdigest` guarda `usuario:realm:hash`:

```text
admin1:Area privada:f64f2af9501033efe7c402417681e05b
```

La contraseña solo vale para ese **realm** (`AuthName`). Apache 2.4 usa MD5 por defecto; `AuthDigestAlgorithm SHA-256` está disponible desde 2.4.20.

### Captura: qué viaja con Digest

En Wireshark, `http.request` y mira la cabecera `Authorization`:

```http
Authorization: Digest username="admin1", realm="Area privada",
              nonce="...", uri="/zona-privada/", response="..."
```

Se ve el **usuario** y el **hash de la respuesta**, pero no la contraseña. Aun así, Digest no cifra el contenido y un *nonce* mal gestionado o una contraseña débil permiten ataques de diccionario contra el hash. La protección real del canal sigue siendo TLS.

## 4. HTTPS con el certificado de la CA

**VM**. Copia los certificados y prepara la cadena:

```bash
sudo install -m 644 ca_cert.pem subca_cert.pem serv_cert.pem  /etc/apache2/ssl/
sudo install -m 600 serv_key.pem                                /etc/apache2/ssl/
sudo sh -c 'cat /etc/apache2/ssl/subca_cert.pem /etc/apache2/ssl/ca_cert.pem \
            > /etc/apache2/ssl/cadena-cas.pem'
sudo chmod 644 /etc/apache2/ssl/cadena-cas.pem

sudo a2enmod ssl
sudo mkdir -p /var/www/srdsi-ssl/docs
sudo cp /var/www/srdsi-lab/docs/index.html /var/www/srdsi-ssl/docs/
```

Comprueba que el puerto 443 está habilitado en `/etc/apache2/ports.conf`:

```apache
Listen 443
```

Crea `/etc/apache2/sites-available/srdsi-ssl.conf`:

```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName www.srdsi.lab
    ServerAlias srdsi.lab
    DocumentRoot /var/www/srdsi-ssl/docs

    SSLEngine on
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    SSLCertificateFile      /etc/apache2/ssl/serv_cert.pem
    SSLCertificateKeyFile   /etc/apache2/ssl/serv_key.pem
    SSLCertificateChainFile /etc/apache2/ssl/subca_cert.pem

    <Directory /var/www/srdsi-ssl/docs>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
</IfModule>
```

Fichero listo: [`srdsi-ssl.conf`](../../assets/config/apache/srdsi-ssl.conf).

```bash
sudo a2ensite srdsi-ssl
sudo apache2ctl configtest
sudo apache2ctl graceful
```

Antes de importar la CA, Firefox muestra un aviso de certificado no confiable. Para confiar en la CA:

1. **Ajustes → Privacidad y seguridad → Certificados → Ver certificados → Autoridades → Importar**.
2. Selecciona `ca_cert.pem`.
3. Marca **«Confiar en esta CA para identificar sitios web»**.

La subCA viaja en la cadena que envía el servidor, así que basta con importar la raíz. Vuelve a abrir `https://www.srdsi.lab`: el candado debe ser válido.

```bash
# Comprobación sin navegador
openssl s_client -connect www.srdsi.lab:443 -servername www.srdsi.lab \
  -CAfile ca_cert.pem -verify_return_error </dev/null
# Verificación del certificado y de la cadena
openssl verify -CAfile ca_cert.pem -untrusted subca_cert.pem serv_cert.pem
```

!!! note "El certificado caduca en 2031"
    `serv_cert.pem` es válido del **2025-11-02** al **2031-04-25** (GMT) y lleva `subjectAltName = www.srdsi.lab, srdsi.lab`. Si el reloj de la VM está mal, aparecerá un error de certificado caducado o no válido todavía.

## 5. Autenticación del cliente con certificado

**VM**. Todo el sitio exige certificado de cliente:

```apache
SSLVerifyClient require
SSLVerifyDepth 2
SSLCACertificateFile /etc/apache2/ssl/cadena-cas.pem
```

Fichero completo: [`srdsi-ssl-mutual.conf`](../../assets/config/apache/srdsi-ssl-mutual.conf).

```bash
sudo apache2ctl graceful
```

Importa el certificado de usuario en Firefox: **Ajustes → Privacidad y seguridad → Certificados → Ver certificados → Sus certificados → Importar**, con la contraseña `abc` (`user.p12`) o `abcd` (`user2.p12`).

| Usuario | `O` | `OU` | Resultado esperado |
| --- | --- | --- | --- |
| `Usuario-SRDSI` | `SRDSI` | `LABS` | Acceso permitido. |
| `Usuario2-SRDSI` | `SRDSI` | `FAKE` | El handshake TLS funciona, pero la condición de la zona privada lo rechaza. |

Los dos certificados de usuario **no llevan extensiones** (`extendedKeyUsage` vacío), por lo que valen para cualquier propósito y el navegador los ofrece. La diferencia entre ambos está en el `OU`, no en la firma.

## 6. Zona privada solo con certificado válido

**VM**. Deja el sitio accesible sin certificado y protege solo el directorio:

```apache
SSLVerifyClient optional
SSLVerifyDepth 2
SSLCACertificateFile /etc/apache2/ssl/cadena-cas.pem

<Directory /var/www/srdsi-ssl/docs/zona-privada>
    SSLRequireSSL
    Require ssl-verify-client
    SSLVerifyDepth 5
    SSLRequire ( %{SSL_CLIENT_S_DN_O} eq "SRDSI" and %{SSL_CLIENT_S_DN_OU} in {"LABS", "ALUM", "PROF"} )
</Directory>
```

Crea la página de la zona privada:

```bash
sudo mkdir -p /var/www/srdsi-ssl/docs/zona-privada
sudo cp /var/www/srdsi-lab/docs/zona-privada/index.html \
        /var/www/srdsi-ssl/docs/zona-privada/
sudo apache2ctl graceful
```

Fichero completo: [`srdsi-ssl.conf`](../../assets/config/apache/srdsi-ssl.conf).

Resultados esperados en `https://www.srdsi.lab/zona-privada/`:

| Certificado presentado | Resultado | Motivo |
| --- | --- | --- |
| Ninguno | **403 Forbidden** | `Require ssl-verify-client` exige certificado; `optional` permite el handshake. |
| `user.p12` (`OU=LABS`) | **200 OK** | Cumple `O=SRDSI` y `OU ∈ {LABS, ALUM, PROF}`. |
| `user2.p12` (`OU=FAKE`) | **403 Forbidden** | El certificado es válido, pero no cumple `SSLRequire`. |

!!! warning "`SSLRequire` está obsoleto"
    Sigue disponible en Apache 2.4 por compatibilidad. La alternativa moderna es `Require expr`:

    ```apache
    Require expr "%{SSL_CLIENT_S_DN_O} == 'SRDSI' && %{SSL_CLIENT_S_DN_OU} in {'LABS','ALUM','PROF'}"
    ```

## Anexo: descifrar HTTPS con Wireshark

**VM**. Con TLS 1.3 no se puede descifrar con la clave privada del servidor: hace falta el secreto de sesión.

```bash
export SSLKEYLOGFILE=$HOME/sslkeys.log
touch "$SSLKEYLOGFILE"
firefox-esr --ssl-key-log-file="$SSLKEYLOGFILE" --private-window https://www.srdsi.lab
```

En Wireshark: **Editar → Preferencias → Protocolos → TLS → (Pre)-Master-Secret log filename**, selecciona el fichero. Después, `tls` y `http` muestran el contenido descifrado.

!!! note "Wireshark 4.7 ya no tiene RSA keys list"
    En versiones recientes se eliminó la lista de claves RSA. Para TLS 1.3 el *keylog* es la única vía; para TLS 1.2 con intercambio RSA se podría usar la clave privada, pero los cifrados modernos usan ECDHE.

## Entregables

- [ ] Sitio `www.srdsi.lab` activo y visible desde un cliente.
- [ ] Zona privada con autenticación básica y captura que muestre las credenciales.
- [ ] Zona privada con Digest y captura que muestre usuario y hash, sin contraseña.
- [ ] HTTPS con el certificado del sitio, antes y después de importar la CA.
- [ ] Autenticación de cliente con `user.p12` y comprobación de `user2.p12`.
- [ ] Zona privada con `SSLRequire` y tabla de resultados.
- [ ] Capturas de Wireshark (HTTP, Digest, handshake TLS y, opcionalmente, tráfico descifrado con *keylog*).

## Comprobado en local

Estas comprobaciones no necesitan la VM y se han ejecutado con OpenSSL 4.1.0 sobre los ficheros del paquete:

```console
$ openssl verify -CAfile ca_cert.pem -untrusted subca_cert.pem serv_cert.pem
serv_cert.pem: OK

$ openssl x509 -in serv_cert.pem -noout -pubkey | openssl md5
MD5(stdin)= 7051ec7089b52fe0c75eb8163740d43f
$ openssl pkey -in serv_key.pem -pubout | openssl md5
MD5(stdin)= 7051ec7089b52fe0c75eb8163740d43f

$ openssl x509 -in serv_cert.pem -noout -ext subjectAltName
X509v3 Subject Alternative Name:
    DNS:www.srdsi.lab, DNS:srdsi.lab

$ openssl pkcs12 -in user.p12  -passin pass:abc  -nokeys -clcerts | \
    openssl x509 -noout -subject
subject=C=ES, ST=GI, L=SS, O=SRDSI, OU=LABS, CN=Usuario-SRDSI, ...

$ openssl pkcs12 -in user2.p12 -passin pass:abcd -nokeys -clcerts | \
    openssl x509 -noout -subject
subject=C=ES, ST=GI, L=SS, O=SRDSI, OU=FAKE, CN=Usuario2-SRDSI, ...
```

| Comprobación | Resultado |
| --- | --- |
| Cadena `serv_cert` ← `subca_cert` ← `ca_cert` | Válida (`OK`). |
| Clave privada ↔ certificado del servidor | Coinciden (mismo MD5 de clave pública). |
| SAN del servidor | `www.srdsi.lab`, `srdsi.lab`. |
| Contraseñas de los `.p12` | `abc` (`user`) y `abcd` (`user2`). |
| `user` / `user2` | `OU=LABS` / `OU=FAKE`. |

!!! note "Pendiente de la VM"
    La instalación de Apache, la importación en Firefox, los códigos HTTP reales y las capturas de Wireshark no se han ejecutado en este entorno. No se han inventado resultados: se documenta el resultado esperado y el comando para obtenerlo.
