# SSH y túneles

OpenSSH es la implementación de referencia de SSH-2: sustituye a Telnet, cifra la sesión y permite autenticar usuario y servidor, ejecutar comandos remotos, copiar ficheros y crear túneles. Esta página recoge los comandos del laboratorio OpenSSH y los patrones que aparecen en los ejercicios de la asignatura.

[:material-file-pdf-box: Transparencias — SSH y PGP/S/MIME (PDF)](../../assets/pdf/SRDSI_T2-2.pdf#page=6){ .md-button }
[:material-file-pdf-box: Enunciado — Laboratorio OpenSSH (PDF)](../../assets/pdf/lab-openssh.pdf){ .md-button }

!!! note "Versiones y alcance"
    Cliente comprobado con **OpenSSH 10.6p1** en el host de documentación. En la VM Debian 13 del laboratorio se observó **OpenSSH 10.0p2** con OpenSSL 3.5.7. En el host **no hay `sshd` escuchando**, así que los comandos marcados **VM** se documentan con el resultado esperado y deben probarse en la VM (`SRDSI`, `user1@192.168.56.110`).

## Conexión básica

```bash
ssh user1@192.168.56.110
ssh -p 2222 user1@192.168.56.110
ssh user1@192.168.56.110 'uptime'
ssh -t user1@192.168.56.110 'sudo systemctl status ssh'
```

- `-p` cambia el puerto (por defecto 22); no confundir con `-P` de `scp`/`sftp`.
- `-t` fuerza pseudo-terminal, necesario para `sudo` o programas interactivos.
- Para cerrar una sesión interactiva: `exit`, `Ctrl-D` o la secuencia de escape `~.`.
- `~^Z` suspende la sesión SSH y la deja en segundo plano; `~?` muestra la ayuda de escapes.

## Diagnóstico con `-v`, `-vv` y `-vvv`

```bash
ssh -v  user2@localhost
ssh -vv user2@localhost
ssh -vvv user2@localhost
```

Cada nivel añade detalle. En la VM, `ssh -v user2@localhost` mostró el intercambio de claves y la autenticación:

```console
debug1: Remote protocol version 2.0, remote software version OpenSSH_10.0p2 Debian-7+deb13u4
debug1: kex: algorithm: mlkem768x25519-sha256
debug1: kex: host key algorithm: ssh-ed25519
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: Authentications that can continue: publickey,password
debug1: Next authentication method: publickey
debug1: Next authentication method: password
Authenticated to localhost ([::1]:22) using "password".
debug1: Entering interactive session.
```

Qué mirar:

| Línea | Significado |
| --- | --- |
| `Reading configuration data ...` | Ficheros de configuración aplicados. |
| `Remote protocol version ...` | Banner y versión del servidor. |
| `kex: algorithm`, `host key algorithm`, `cipher` | Algoritmos negociados. |
| `Server host key: ssh-ed25519 SHA256:...` | Huella de la host key. |
| `Host '...' is known and matches ...` | `known_hosts` válido. |
| `Authentications that can continue` | Métodos que acepta el servidor. |
| `Authenticated to ... using "publickey"` | Método finalmente usado. |

En `-vv` aparecen las propuestas completas de cliente y servidor (`KEX algorithms`, `host key algorithms`, `ciphers`, `MACs`, `compression`) y detalles de canales; en `-vvv` se añaden los paquetes y el estado interno.

## Claves de usuario

Crear una clave Ed25519 con passphrase y comentario identificativo:

```bash
ssh-keygen -t ed25519 -a 100 -C "user1@bocata-jamon"
```

Crear una clave sin passphrase solo para laboratorio:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_lab -N '' -C "lab user1"
```

Inspeccionar la huella y el tipo:

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
ssh-keygen -lf ~/.ssh/id_ed25519          # también calcula la del fichero privado
```

RSA sigue siendo válido, pero se recomienda Ed25519 (o ECDSA); si necesitas RSA, usa al menos 3072 bits:

```bash
ssh-keygen -t rsa -b 4096 -C "user1@bocata-jamon"
```

### Permisos correctos

OpenSSH rechaza claves y ficheros de configuración con permisos demasiado abiertos (`StrictModes`):

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_lab
chmod 600 ~/.ssh/config ~/.ssh/authorized_keys ~/.ssh/known_hosts
chmod 644 ~/.ssh/*.pub
chmod g-w,o-w ~
```

| Ruta | Permisos | Motivo |
| --- | --- | --- |
| `~/.ssh` | `700` | Solo el propietario entra. |
| Clave privada | `600` | El cliente se niega a usarla si es legible por otros. |
| `authorized_keys` | `600` | Evita que otros añadan claves. |
| `config`, `known_hosts` | `600` | Contienen identidades y confianza. |
| Clave pública (`.pub`) | `644` | No es secreta. |

Además, el directorio *home* no debe ser escribible por grupo u otros, y los ficheros deben pertenecer al usuario.

## Copiar la clave pública

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user2@localhost
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 2222 user2@host
```

`ssh-copy-id` pide la contraseña de la cuenta remota y añade la clave a `~/.ssh/authorized_keys` con los permisos adecuados. Después:

```bash
ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes user2@localhost
```

`IdentitiesOnly=yes` evita que el cliente pruebe todas las claves del agente.

Instalación manual (por ejemplo, si no hay `ssh-copy-id`):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cat id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

En el servidor, `authorized_keys` se lee del *home* del usuario indicado en el login. Comprueba el propietario:

```bash
ls -ld ~ ~/.ssh ~/.ssh/authorized_keys
```

## `ssh-agent` y `ssh-add`

El agente mantiene las claves descifradas en memoria y evita escribir la passphrase en cada conexión:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add -l
ssh-add -L
```

- `ssh-add -l` lista huellas; `-L` muestra las claves públicas completas.
- `ssh-add -t 8h ~/.ssh/id_ed25519` caduca la clave del agente a las 8 horas.
- `ssh-add -d ~/.ssh/id_ed25519` la elimina del agente; `ssh-add -D` borra todas.
- `eval "$(ssh-agent -k)"` mata el agente de la shell actual.

En la VM, `ssh -v` mostró `agent contains no identities` antes de añadir la clave; después la autenticación pasó a `publickey` sin pedir contraseña.

!!! warning "Agent forwarding"
    `ssh -A` reenvía el agente al servidor remoto. Es cómodo, pero el administrador remoto puede usar tus claves mientras dure la sesión. Prefiere `ProxyJump` o claves específicas por salto antes que `ForwardAgent yes` global.

## `~/.ssh/config`

```sshconfig
Host SRDSI
    HostName 192.168.56.110
    User user1
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host ehu
    HostName ehu.eus
    User usuario
    IdentityFile ~/.ssh/id_ed25519
```

Uso y comprobación:

```bash
ssh SRDSI
ssh -G SRDSI | grep -E '^(hostname|user|identityfile|port) '
```

- `Host` acepta patrones (`Host *.lab`); las opciones del primer bloque que coincide se aplican.
- `ssh -G` muestra la configuración efectiva sin conectar.
- `ProxyJump bastion` sustituye a un túnel manual para atravesar un salto.
- Un bloque `Host *` al final sirve para valores por defecto; colócalo después de los bloques específicos.

## `known_hosts`

La primera conexión es *trust on first use*: el cliente guarda la host key. Si cambia, SSH aborta con un aviso de posible ataque de intermediario.

```bash
ssh-keygen -F localhost                 # busca la entrada (incluye hashes)
ssh-keygen -F '[localhost]:2222'
ssh-keygen -R localhost                 # elimina la entrada
ssh-keygen -R '[localhost]:2222'
ssh-keyscan -t ed25519 localhost >> ~/.ssh/known_hosts
ssh-keygen -lf ~/.ssh/known_hosts
```

Tras reinstalar el servidor SSH (ejercicio 2 del laboratorio) cambia la host key y aparece:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

La solución correcta es comprobar la nueva huella por un canal fiable y eliminar la entrada antigua con `ssh-keygen -R`. `StrictHostKeyChecking=no` o `UserKnownHostsFile=/dev/null` solo son aceptables en un laboratorio aislado.

## Túneles

### Reenvío local (`-L`)

El puerto se abre en la máquina cliente y el tráfico sale por el servidor SSH:

```bash
ssh -L 12000:ehu.eus:443 user1@SRDSI
ssh -N -f -L 12000:ehu.eus:443 user1@SRDSI
ssh -N -f -o ExitOnForwardFailure=yes -L 12000:servidor-web:80 user1@SRDSI
```

- `-L [bind:]puerto_local:host_destino:puerto_destino`
- Por defecto escucha solo en `127.0.0.1`; `-g` permite otras interfaces (peligroso en redes compartidas).
- `-N` no abre shell; `-f` pasa a segundo plano.
- El nombre `host_destino` lo resuelve **el servidor SSH**, no el cliente.
- `ExitOnForwardFailure=yes` evita quedarse con una sesión sin túnel.

Ejercicio 3 del laboratorio (el informe usó HTTPS y el enunciado propone HTTP):

```bash
ssh -L 12000:ehu.eus:443 user1@SRDSI
sudo netstat -tanp | grep 12000
ss -tanp | grep 12000
```

Salida observada en la VM:

```console
tcp  0  0  127.0.0.1:12000  0.0.0.0:*  LISTEN  324823/ssh
tcp6 0  0  ::1:12000        :::*       LISTEN  324823/ssh
```

Sin el túnel, `http://localhost:12000` no conecta; con el túnel se alcanza el servicio remoto. Si usas HTTPS, el navegador avisará de que el certificado es de `ehu.eus` y no de `localhost`: es el comportamiento esperado.

### Reenvío remoto (`-R`)

El puerto se abre en el servidor SSH y el tráfico vuelve al cliente:

```bash
ssh -N -R 8080:localhost:80 user1@SRDSI
ssh -N -R 0.0.0.0:8080:localhost:80 user1@SRDSI
```

En el servidor:

```bash
ss -tlnp | grep 8080
```

Para escuchar en todas las interfaces del servidor hace falta `GatewayPorts yes` (o `clientspecified`) en `sshd_config`. Sin eso, el puerto queda en loopback del servidor. `AllowTcpForwarding` debe permitir el reenvío.

### Proxy SOCKS (`-D`)

```bash
ssh -N -D 1080 user1@SRDSI
curl --socks5-hostname 127.0.0.1:1080 https://ehu.eus
```

`-D` crea un proxy SOCKS5 local que envía cada conexión a través del servidor SSH. El cliente resuelve o delega la resolución según `--socks5`/`--socks5-hostname`.

!!! note "Cierre y limpieza"
    Los túneles viven mientras dure la conexión SSH. Cierra con `exit`, `Ctrl-C` (si usaste `-N`) o `ssh -O exit SRDSI` (si hay multiplexación). Comprueba con `ss` que el puerto local ya no está en `LISTEN`.

## Multiplexación de conexiones

Reutiliza una sola conexión TCP para varias sesiones, túneles y `scp`/`sftp`:

```sshconfig
Host SRDSI
    HostName 192.168.56.110
    User user1
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```

```bash
ssh SRDSI                 # crea el socket de control
ssh -O check SRDSI        # comprueba que el maestro sigue vivo
ssh -O exit SRDSI         # cierra el maestro y todos los canales
```

- `ControlPersist 10m` mantiene el maestro 10 minutos después del último canal.
- `ControlPath` debe estar en un directorio con permisos `700`; si la ruta es demasiado larga, usa `%C` (hash de la conexión).
- Es la opción más sencilla para el ejercicio 6a del laboratorio: la segunda conexión no repite el handshake.

## Certificados SSH

Una CA de SSH firma claves de usuario y de host; el servidor confía en la CA y deja de depender de `authorized_keys` por usuario.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/lab_ca -C "CA SSH del laboratorio"
ssh-keygen -s ~/.ssh/lab_ca -I user1 -n user1 -V +52w ~/.ssh/id_ed25519.pub
ssh-keygen -s ~/.ssh/lab_ca -h -I host-bocata -n bocata-jamon -V +52w /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

- `-s` firma; `-I` es el identificador del certificado; `-n` son los *principals* (usuarios o nombres DNS).
- `-h` genera un certificado de host; sin `-h`, de usuario.
- `-V +52w` fija validez; también admite `-V 20261001:20271001`.
- `ssh-keygen -L` muestra validez, principals, extensiones y CA firmante.

Configuración del servidor (**VM**):

```sshconfig
TrustedUserCAKeys /etc/ssh/lab_ca.pub
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
```

En el cliente, si el certificado no está junto a la clave:

```sshconfig
Host SRDSI
    CertificateFile ~/.ssh/id_ed25519-cert.pub
```

Los *principals* deben coincidir con el usuario (`user1`) o el nombre del host (`bocata-jamon`); si no, el certificado se rechaza aunque la firma sea válida.

## 2FA: clave + contraseña

En `/etc/ssh/sshd_config` (**VM**):

```sshconfig
PubkeyAuthentication yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
AuthenticationMethods publickey,password
```

Aplicar y comprobar:

```bash
sudo sshd -t
sudo systemctl reload ssh
ssh -v user1@localhost
```

`AuthenticationMethods publickey,password` exige **ambos** factores, en ese orden. El segundo puede ser la contraseña de PAM o un código TOTP si instalas `libpam-google-authenticator` y lo configuras en PAM. Comprueba en `-v` que aparecen `publickey` y `password`/`keyboard-interactive`, y que la sesión no se abre hasta completar los dos.

!!! warning "No te bloquees fuera"
    Antes de recargar `sshd`, deja una sesión SSH abierta y valida la configuración con `sshd -t`. Un error en `AuthenticationMethods` o en PAM puede impedir el acceso.

## `scp` y `sftp`

```bash
scp fichero.txt user1@host:/tmp/
scp -r directorio user1@host:/tmp/
scp -P 2222 -i ~/.ssh/id_ed25519 user1@host:/tmp/fichero.txt .
scp user1@host:/var/log/syslog ./syslog-copia
```

`scp` usa SSH por debajo. `-P` es el puerto (mayúscula, a diferencia de `ssh -p`); `-i` selecciona la clave; `-r` copia directorios.

```bash
sftp user1@host
sftp -P 2222 -i ~/.ssh/id_ed25519 user1@host
```

Dentro de `sftp`: `pwd`, `ls`, `lcd`, `get remoto local`, `put local remoto`, `mkdir`, `rm`, `bye`. En modo desatendido:

```bash
sftp -b comandos.txt user1@host
```

```text
get /var/log/syslog /tmp/syslog
put /tmp/informe.pdf /home/user1/
bye
```

## Puertos y servicios

```bash
ss -tan                 # todas las conexiones TCP
ss -tlnp                # TCP en escucha con proceso
ss -ulnp                # UDP en escucha
ss -tanp | grep :22
sudo ss -tlnp | grep ':22\|:23\|:12000'
netstat -tanp           # equivalente clásico (net-tools)
```

`ss` es la herramienta actual; `netstat` puede no estar instalado. `-p` necesita privilegios para ver procesos de otros usuarios. En la VM, `ss -tan` mostró SSH en `:22` y Telnet en `:23`:

```console
LISTEN  0  128  0.0.0.0:22  0.0.0.0:*
LISTEN  0  10   0.0.0.0:23  0.0.0.0:*
LISTEN  0  128  [::]:22     [::]:*
```

## Gestión del servicio

En Debian/Ubuntu la unidad se llama `ssh` (en RHEL es `sshd`):

```bash
systemctl status ssh
sudo systemctl restart ssh
sudo systemctl reload ssh
sudo systemctl enable --now ssh
journalctl -u ssh -n 50 --no-pager
sudo sshd -t                         # valida la configuración
sudo sshd -T | grep -E 'port|permitrootlogin|passwordauthentication'
```

- `reload` relee la configuración sin cortar sesiones; `restart` las corta.
- `sshd -T` muestra la configuración efectiva (incluidos los valores por defecto).
- Tras cambiar el puerto, abre el firewall antes de reiniciar y prueba en otra sesión.

## `sshd_config`: opciones habituales

| Directiva | Valor recomendado | Efecto |
| --- | --- | --- |
| `Port` | `22` o uno alternativo | Puerto de escucha. |
| `PermitRootLogin` | `no` | Prohíbe login directo de root. |
| `PasswordAuthentication` | `no` (con claves) | Desactiva contraseñas. |
| `PubkeyAuthentication` | `yes` | Autenticación con clave pública. |
| `PermitEmptyPasswords` | `no` | Rechaza cuentas sin contraseña. |
| `MaxAuthTries` | `3` | Limita intentos por conexión. |
| `LoginGraceTime` | `30` | Segundos para autenticarse. |
| `AllowUsers` | `user1` | Lista blanca de usuarios. |
| `X11Forwarding` | `no` | Desactiva X11 si no se usa. |
| `AllowTcpForwarding` | `local` o `no` | Controla túneles. |
| `GatewayPorts` | `no` | Evita exponer `-R` en todas las interfaces. |
| `ClientAliveInterval` | `300` | Keepalive del servidor. |
| `ClientAliveCountMax` | `2` | Desconexión tras keepalives perdidos. |
| `Subsystem sftp` | `internal-sftp` | `sftp` sin binario externo. |
| `Banner` | `/etc/issue.net` | Aviso legal antes del login. |

Flujo seguro para editar (**VM**):

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudoedit /etc/ssh/sshd_config
sudo sshd -t && sudo systemctl reload ssh
```

## Telnet: comparación en el laboratorio

Telnet envía la sesión en claro; sirve para demostrar por qué SSH es necesario. En la VM se instaló y se habilitó en `inetd` (**VM**):

```bash
sudo apt install telnet telnetd
sudo vi /etc/inetd.conf
# Descomentar:
# telnet  stream  tcp  nowait  root  /usr/sbin/tcpd  /usr/sbin/telnetd
sudo systemctl restart inetd
ss -tan | grep :23
telnet -l user1 192.168.56.110
```

En Wireshark, `Follow → TCP Stream` sobre el puerto 23 muestra usuario, contraseña y comandos en texto claro. SSH, en cambio, negocia claves y a partir de `NEWKEYS` solo deja ver paquetes cifrados. Al terminar la práctica, deshabilita Telnet:

```bash
sudo systemctl stop inetd
sudo systemctl disable inetd
```

Si tu Debian usa `inetutils-inetd` o `xinetd`, el nombre del servicio y el fichero de configuración cambian; comprueba con `systemctl list-unit-files | grep -i inet`.

## Comandos concretos del laboratorio OpenSSH

| Ejercicio | Comando | Resultado esperado |
| --- | --- | --- |
| Telnet vs SSH | `telnet -l user1 192.168.56.110` / `ssh user1@192.168.56.110` | Telnet legible en Wireshark; SSH cifrado tras `NEWKEYS`. |
| 1. Verbose | `ssh -v user2@localhost`, `ssh -vv user2@localhost` | Negociación, host key, métodos y sesión clasificados por capas. |
| 2. Reinstalar servidor | `sudo apt install --reinstall openssh-server` y reconectar | Aviso de host key cambiada; corregir con `ssh-keygen -R localhost`. |
| 3. Reenvío local | `ssh -L 12000:ehu.eus:443 user1@SRDSI` | `ss`/`netstat` muestran `127.0.0.1:12000`; Firefox alcanza el servicio. |
| 4. Clave pública | `ssh-keygen -t ed25519`, `ssh-copy-id user2@localhost` | Segundo login sin contraseña. |
| 5. Agente | `eval "$(ssh-agent -s)"`, `ssh-add` | `ssh-add -l` lista la clave; login sin passphrase. |
| 6a. Multiplexación | Bloque `ControlMaster`/`ControlPath`/`ControlPersist` | `ssh -O check SRDSI` confirma el maestro. |
| 6b. Reenvío remoto | `ssh -N -R 8080:localhost:80 user1@SRDSI` | El puerto aparece en el servidor. |
| 6c. Certificados | `ssh-keygen -s`, `TrustedUserCAKeys` | Login con certificado, sin `authorized_keys`. |
| 6d. 2FA | `AuthenticationMethods publickey,password` | Pide clave y contraseña. |

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `Permission denied (publickey)` | Clave no instalada, usuario incorrecto o permisos abiertos. | Revisa `authorized_keys`, `ls -ld`, `ssh -vv`. |
| `UNPROTECTED PRIVATE KEY FILE` | Clave privada legible por otros. | `chmod 600`. |
| `Host key verification failed` | Host key cambiada o entrada obsoleta. | Verifica la huella y `ssh-keygen -R`. |
| `Connection refused` | `sshd` parado o puerto/firewall incorrecto. | `systemctl status ssh`, `ss -tlnp`, firewall. |
| `Agent admitted failure to sign` | Clave no añadida al agente. | `ssh-add`, `ssh-add -l`. |
| `Too many authentication failures` | El cliente prueba demasiadas claves. | `IdentitiesOnly yes` y `IdentityFile`. |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Reinstalación o ataque MITM. | Comprueba la huella antes de borrar la entrada. |

## Enlaces

- [SSH (teoría)](../teoria/ssh.md)
- [Laboratorio OpenSSH](../../recursos/pdfs.md)
- [OpenSSL TLS/DTLS](openssl-tls.md)
- [Wireshark y capturas](wireshark.md)
- [Transparencias — SSH y PGP/S/MIME](../../assets/pdf/SRDSI_T2-2.pdf)
