# Servicio WWW

Apache es el servidor web de referencia de la asignatura: multiplataforma, modular y con dominios virtuales. Esta página resume su configuración, las medidas de seguridad del servicio y los mecanismos de validación de certificados en HTTPS.

[:material-file-pdf-box: Transparencias — 3.2 Servicio WWW (PDF)](../../assets/pdf/SRDSI_T3-1-2.pdf#page=11){ .md-button }

## Servidor web Apache

Modelo cliente/servidor sobre **HTTP**, contenido en **HTML**. Apache destaca por ser el servidor más extendido, multiplataforma, modular y capaz de alojar varios sitios virtuales.

```bash
sudo apt-get update
sudo apt-get install apache2
sudo apache2ctl {start|stop|restart|status|configtest|graceful}
```

### Estructura de configuración

Todo vive en `/etc/apache2`:

| Ruta | Contenido |
| --- | --- |
| `apache2.conf` | Configuración principal del servidor. |
| `ports.conf` | Puertos e interfaces de escucha. |
| `mods-available/`, `mods-enabled/` | Módulos disponibles y activados. |
| `sites-available/`, `sites-enabled/` | Sitios virtuales disponibles y activados. |
| `conf-available/`, `conf-enabled/` | Configuraciones adicionales. |
| `envvars`, `magic` | Variables de entorno y reglas `mod_mime_magic`. |

Directivas globales habituales:

```apache
ServerRoot /etc/apache2          # ubicación de configuración y logs
KeepAlive On                     # mantener sesiones abiertas
MaxKeepAliveRequests 100         # máximo de peticiones por conexión
KeepAliveTimeout 15              # inactividad máxima de una sesión

IncludeOptional mods-enabled/*.load
IncludeOptional mods-enabled/*.conf
IncludeOptional sites-enabled/*.conf
```

`ports.conf` decide en qué direcciones y puertos se atiende:

```apache
Listen 80
Listen 81                        # también en el puerto 81
Listen 127.0.0.1:84              # solo accesos desde localhost
Listen [2001:db8::ccea]:80       # IPv6
```

### Contenedores

Un contenedor agrupa directivas y las aplica solo al recurso indicado. Pueden anidarse:

```apache
<Directory /var/www/sitio>
    <Files "secreto.txt">
        Require all denied
    </Files>
</Directory>

<Location "/admin">
    Require ip 10.0.0.0/8
</Location>
```

`<Directory>` actúa sobre el sistema de ficheros; `<Location>` sobre la URL.

### Registro

| Directiva | Efecto |
| --- | --- |
| `ErrorLog fichero` | Errores del servicio. |
| `LogLevel nivel` | `info`, `warn`, `error`, `crit`, `alert`… |
| `LogFormat formato [nickname]` | Define formatos con nombre (`combined`, `common`, `referer`…). |
| `CustomLog fichero nickname` | Accesos con el formato indicado. |

### Sitios virtuales

Cada sitio se declara en `sites-available/` con un contenedor `<VirtualHost>` y se activa con `a2ensite`:

```apache
<VirtualHost *:80>
    ServerName www.pruebas.eus
    ServerAlias pruebas.eus
    DocumentRoot /var/www/pruebas.eus
    ServerAdmin webmaster@pruebas.eus
    DirectoryIndex index.php index.html
</VirtualHost>
```

| Directiva | Función |
| --- | --- |
| `DocumentRoot` | Directorio raíz del contenido público. |
| `ServerName` | Nombre con el que se accede al sitio. |
| `ServerAlias` | Nombres alternativos. |
| `ServerAdmin` | Correo del responsable. |
| `DirectoryIndex` | Ficheros que actúan como índice (`index.html` por defecto). |
| `ErrorDocument` | Página o acción ante un error (por ejemplo, un 404). |

Se puede distinguir un sitio por **IP/puerto** (`Listen` + `<VirtualHost 195.168.1.5:8008>`) o por **nombre** (`ServerName`, misma IP y puerto). La segunda opción es la recomendada.

```bash
sudo a2ensite www.pruebas.eus      # o a2dissite
sudo a2enmod ssl                   # o a2dismod
sudo apache2ctl -S                 # sitios virtuales activos
sudo apache2ctl configtest         # sintaxis
sudo apache2ctl graceful           # recarga sin cortar conexiones
```

## Seguridad del servidor web

El servicio web está muy expuesto: es fácil ponerlo en marcha, pero una configuración segura es compleja, las aplicaciones dinámicas ocultan fallos y los usuarios no perciben el riesgo. Referencias: **NIST SP 800-44 v2**, las guías de seguridad HTTP de Mozilla y la documentación de seguridad de Apache.

### Lista de comprobación

- El servidor **no ofrece ningún otro servicio de red** aparte de HTTP/HTTPS.
- Cortafuegos: bloquear salidas y permitir entradas solo a **80/TCP** y **443/TCP**.
- Mantener actualizados Apache, los módulos y las aplicaciones.
- Instalar desde **fuentes autenticadas**.
- Revisar los *logs* al menos a diario.
- Contenido web en una partición dedicada y con *backup*.
- Eliminar ficheros por defecto: páginas de ejemplo, *scripts* CGI, manuales.
- Habilitar solo los módulos necesarios (`a2dismod` para el resto).
- Trazar llamadas al sistema si se investiga un comportamiento: `sudo strace apache2 -X`.
- Evaluar la configuración con herramientas específicas (por ejemplo, *hardening* de Apache/PHP).

### Aislar Apache

- **`chroot`**: cambia la raíz del sistema de ficheros del servidor y sus hijos. Hay que copiar dentro de la jaula binarios, librerías y ficheros necesarios.
- **`mod_security`**: cortafuegos de aplicaciones web (WAF). Filtra peticiones, aplica expresiones regulares, valida codificaciones de URI y monitoriza HTTP/HTTPS para detectar ataques.

### Directivas globales

```apache
ServerSignature off
ServerTokens Prod                 # Full | OS | Minimal | Minor | Major | Prod
TraceEnable off                   # deshabilita HTTP TRACE
LimitRequestBody 1048576          # 1 MiB máximo por petición
```

La firma del servidor revela versión y sistema operativo. Con `ServerSignature off` y `ServerTokens Prod` las páginas de error dejan de mostrar `Apache/2.4.x (Debian)`.

Ejecuta Apache con una cuenta propia y sin privilegios:

```bash
sudo groupadd apache
sudo useradd apache -g apache -d /dev/null -s /usr/sbin/nologin
```

```apache
User apache
Group apache
```

Los directorios `bin`, `conf`, `logs`, `.htaccess`, ficheros de contraseñas y claves privadas deben quedar **fuera del `DocumentRoot`** y accesibles solo por esa cuenta (`chown apache:apache`, `chmod 700`).

### Ocultar información

Desactiva el listado de directorios y las opciones que no necesites:

```apache
Options -Indexes -FollowSymLinks -Includes -MultiViews
```

Sustituye las páginas de error por defecto, que revelan demasiado:

```apache
ErrorDocument 404 /errors/404.html
ErrorDocument 500 /errors/500.html
```

### Limitar recursos (DoS)

Cada modelo de gestión de procesos (**MPM**) tiene directivas para acotar recursos: `StartServers`, `MinSpareServers`, `MaxSpareServers`, `MaxRequestWorkers`, `MaxConnectionsPerChild`, `Timeout`, `KeepAlive`, `MaxKeepAliveRequests`, `KeepAliveTimeout`.

### Control de accesos

Dos formas de proteger un directorio:

| Mecanismo | Quién lo gestiona | Valoración |
| --- | --- | --- |
| `.htaccess` en el directorio | Administrador del sitio | Requiere `AllowOverride`; peor rendimiento y seguridad. |
| `<Directory>` en la configuración | Administrador del servidor (root) | Recomendado. |

Opciones de `Options`:

| Valor | Efecto |
| --- | --- |
| `Indexes` | Lista el contenido si no hay página índice. |
| `FollowSymLinks` | Sigue enlaces simbólicos. |
| `ExecCGI` | Permite ejecutar CGI. |
| `None` | Ninguna opción; tampoco lee `.htaccess`. |
| `All` | Todas las opciones salvo las que requieren `AllowOverride`. |

En Apache 2.4 el control se hace con `Require`:

```apache
Require all granted
Require all denied
Require ip 10 172.20 192.168.2
Require host example.org
Require expr %{HTTP_USER_AGENT} != 'BadBot'
```

Y se combinan con `<RequireAny>`, `<RequireAll>` y `<RequireNone>`:

```apache
<RequireAny>
    <RequireAll>
        Require user root
        Require ip 10.0.0.11
    </RequireAll>
    <RequireAny>
        Require group sysadmins
        Require group useraccounts
        Require user ana
    </RequireAny>
    <RequireNone>
        Require group restrictedadmin
        Require host host.com
    </RequireNone>
</RequireAny>
```

!!! note "Order/Deny es legado"
    Las directivas `Order Deny,Allow` / `Deny from all` / `Allow from all` de Apache 2.2 siguen funcionando por compatibilidad, pero en 2.4 se sustituyen por `Require`.

### Autenticación básica y digest

| Esquema | Qué viaja | Riesgo |
| --- | --- | --- |
| **Basic** | Usuario y contraseña en Base64 en cada petición. | Base64 no cifra: cualquiera con acceso a la red los lee. Solo aceptable sobre HTTPS o en un laboratorio. |
| **Digest** | Usuario, *realm*, nonce y un hash de la contraseña. | No envía la contraseña, pero sigue sin cifrar el contenido; tampoco protege frente a todos los ataques. |

La actividad pide comprobar con Wireshark qué se ve en cada caso: en Basic aparecen las credenciales decodificables; en Digest, el usuario y el hash, no la contraseña.

## Conexiones seguras

**HTTPS** es HTTP sobre TLS (RFC 2818): mismo protocolo de aplicación, otro puerto (443) y una API distinta en el servidor.

### HSTS

**HSTS** (RFC 6797) permite a un sitio declararse accesible solo por HTTPS. El servidor envía la cabecera y el navegador recuerda la decisión:

```apache
Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains"
```

Requiere `mod_headers` (`sudo a2enmod headers`).

`preload` solicita la inclusión en la lista que los navegadores llevan embebida. También existen modos «solo HTTPS» configurados por el usuario.

### SSL stripping y HSTS

En un **SSL stripping**, el atacante se coloca en medio, habla HTTP con el cliente y HTTPS con el servidor. El cliente cree estar en HTTP y el atacante ve el tráfico en claro. HSTS lo evita: el navegador se niega a usar HTTP tras la primera visita segura. La primera visita sigue siendo vulnerable, de ahí el `preload`.

### Perfect Forward Secrecy

**PFS** protege comunicaciones pasadas: si se compromete la clave privada del servidor, no se pueden descifrar sesiones anteriores. Se consigue con intercambio de claves efímero (**ECDHE** o **DHE**):

```apache
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLHonorCipherOrder on
SSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+aRSA+SHA256 !3DES !MD5 !RC4"
```

!!! warning "Una directiva, una línea"
    Apache no admite la continuación de línea con `\` en su configuración. `SSLCipherSuite`, `SSLRequire` y el resto de directivas deben escribirse en una sola línea.

La transparencia añade el intercambio híbrido **post-cuántico**:

```apache
SSLOpenSSLConfCmd Curves X25519MLKEM768:X25519:prime256v1
```

Requiere una versión de OpenSSL con ML-KEM y un Apache que permita `SSLOpenSSLConfCmd`.

### Validación del certificado

Pregunta clave: **¿es apropiado el certificado presentado por el servidor?** Un atacante puede crear un sitio fraudulento con un certificado falso y redirigir al usuario (MiM). También existen CA comprometidas y proxies corporativos que inspeccionan TLS actuando como intermediarios (*resign* o *replace*), lo que produce avisos al usuario.

Mecanismos de defensa:

| Mecanismo | Qué aporta | Estado |
| --- | --- | --- |
| **HPKP** (RFC 7469) | *Pinning* de la clave pública vía cabecera HTTP. | Obsoleto: un cambio de clave legítimo bloquea el sitio; los navegadores lo eliminaron. |
| **DNS CAA** (RFC 8659/8657) | Registro DNS que autoriza qué CAs pueden emitir para el dominio. | Recomendado, mejor con DNSSEC. |
| **DANE** (RFC 6698/6394/7929) | Publica asociaciones `TLSA` en DNSSEC para certificados o claves. | Requiere DNSSEC. |
| **Certificate Transparency** (RFC 6962/9162) | Registros públicos, monitorización y auditoría de certificados emitidos. | Implantado en navegadores. |

CAA se comprueba antes de emitir:

```dns
certs.example.com.      CAA 0 issue "ca1.example.net"
certs.example.com.      CAA 0 issue "ca2.example.org; policy=ev"
nocerts.example.com.    CAA 0 issue ";"        ; prohíbe emitir
```

Otras etiquetas: `issuewild` e `iodef`.

DANE publica, por ejemplo:

```dns
_443._tcp.www.example.com. IN TLSA 3 1 1 ( d2abde24... )
```

**Certificate Transparency** se apoya en *logs* (árboles de Merkle solo-añadir), **monitores** que buscan certificados sospechosos y **auditores** que comprueban el funcionamiento de los logs. Los certificados llegan al navegador con **SCT** (*Signed Certificate Timestamp*) de tres formas: extensión dentro del certificado (recomendada), extensión TLS en el *Server Hello* o *staple* OCSP. Se consultan en [crt.sh](https://crt.sh/).

### SNI y ECH

**SNI** (RFC 6066) permite alojar varios sitios HTTPS en la misma IP y puerto: el cliente envía el nombre del sitio en el *handshake*. Sin SNI solo había un certificado por IP y puerto.

```apache
SSLStrictSNIVHostCheck on
```

**ECH** (*Encrypted Client Hello*, RFC 9849) cifra el SNI y otras extensiones sensibles en TLS 1.3.

Alternativas al SNI: certificados **multidominio** (UCC) con varias entradas en `subjectAltName` y certificados **wildcard** (`*.srdsi.lab`), estos últimos no recomendados por RFC 6125.

### Mitos sobre HTTPS

- «TLS es seguro»: depende de la configuración y de la versión.
- «Una página HTTPS no tiene problemas de seguridad»: la aplicación puede seguir siendo vulnerable.
- «HTTPS no se almacena en caché»: sí se almacena.
- «Por HTTPS puede enviarse cualquier información en la URL»: la URL queda en logs e historial.
- «El candado significa que el sitio es fiable»: solo indica que la conexión está cifrada y el certificado es válido para ese dominio.

### Aplicaciones web y navegadores

Los servidores alojan aplicaciones web que pueden no ser seguras. Referencias: **WASC** (clasificación de amenazas), **OWASP Top 10** y *Web Security Testing Guide*, guías de Mozilla y **WAF** para filtrar tráfico a nivel de aplicación.

Los navegadores también son objetivo (*exploits*, *watering hole*, *malvertising*, ingeniería social). Medidas: actualizar, desactivar *plugins* y ventanas emergentes, no guardar contraseñas, bloquear cookies de terceros, pedir permiso antes de ejecutar o guardar ficheros y usar HTTPS.

## Actividades

- [Actividad Apache](../actividades/apache.md): sitio virtual, autenticación básica y digest, HTTPS y certificado de cliente.
- [PKI — 2ª fase: OCSP](../../tema1/lab-pki/pki2.md): OCSP regular, *stapling* y *must-staple* sobre el sitio HTTPS.
