# Laboratorio OpenSSH

[:material-file-pdf-box: Enunciado del laboratorio (PDF)](../../assets/pdf/lab-openssh.pdf){ .md-button }
[:material-file-pdf-box: Esquema de port forwarding (PDF)](../../assets/pdf/lab-openssh-port-forwarding.pdf){ .md-button }
[:material-file-pdf-box: Informe completo (PDF)](../../assets/pdf/informe-openssh.pdf){ .md-button }

Esta página resuelve los **ejercicios 1–6** del laboratorio OpenSSH: análisis de una conexión en modo *verbose*, reinstalación del servidor y gestión de `known_hosts`, reenvío local de puertos, autenticación con clave pública, uso de `ssh-agent` y una selección de funcionalidades avanzadas (multiplexación, reenvío remoto, certificados SSH y 2FA).

!!! note "Alcance y fuentes"
    El informe original `informe_open_ssh.tex` documenta los ejercicios 1–4 con las pruebas hechas en la VM Debian (`bocata-jamon`, usuarios `user1` y `user2`, OpenSSH 10.0p2). Los ejercicios 5 y 6 no estaban incluidos y se añaden aquí. Las notas de Jorge y Jon recogen las salidas reales de las pruebas; esta página las ordena y las complementa con comprobaciones locales.

!!! warning "Qué se ha podido verificar sin servidor"
    En el host de documentación **no hay `sshd` escuchando**, por lo que no se han simulado conexiones reales. Se han ejecutado y comprobado localmente, en directorios temporales con `mktemp -d`, la generación de claves, `ssh-keygen` (huellas, certificados y `known_hosts`), `ssh-agent`/`ssh-add`, `ssh -G` y la validación de configuraciones con `sshd -t`. Los pasos marcados **VM** requieren la máquina virtual o un servidor SSH real.

## 1. Enunciado y entorno

El objetivo es comparar **Telnet** con **SSH** y comprobar las funciones básicas de OpenSSH. El enunciado permite dos montajes equivalentes:

| Montaje | Máquina cliente | Máquina servidor | Observaciones |
| --- | --- | --- | --- |
| Dos VM en red | VM A | VM B | Hay que abrir el puerto 22 entre ambas. |
| Dos usuarios | `user1` | `user2` en la misma máquina | Es el montaje del informe; se usa `localhost`. |

Herramientas necesarias:

```bash
sudo apt update
sudo apt install wireshark
sudo apt install telnet telnetd
sudo apt install openssh-server openssh-client
sudo apt install apache2          # opcional, para el ejercicio 3
```

En Debian, el servicio SSH se llama `ssh`:

```bash
sudo systemctl enable --now ssh
systemctl status ssh --no-pager
ss -tan | grep -E ':22|:23'
```

Salida observada en la VM tras habilitar también Telnet:

```console
State      Recv-Q      Send-Q           Local Address:Port           Peer Address:Port
LISTEN     0           128                    0.0.0.0:22                  0.0.0.0:*
LISTEN     0           10                     0.0.0.0:23                  0.0.0.0:*
LISTEN     0           128                       [::]:22                     [::]:*
```

Telnet se habilitó descomentando su línea en `/etc/inetd.conf` y reiniciando `inetd`:

```text
telnet  stream  tcp  nowait  root  /usr/sbin/tcpd  /usr/sbin/telnetd
```

```bash
sudo systemctl restart inetd
```

La diferencia que se quiere demostrar con Wireshark es directa:

| Aspecto | Telnet | SSH |
| --- | --- | --- |
| Cifrado | Ninguno | Negociado en el transporte SSH |
| Credenciales | Usuario y contraseña en claro | Dentro del canal cifrado |
| Integridad | No | MAC/AEAD por paquete |
| Identidad del servidor | No se comprueba | *Host key* en `known_hosts` |
| Puerto habitual | 23 | 22 |

Con Wireshark se captura en `lo` (dos usuarios) o en la interfaz de red (dos VM). En Telnet, *Follow → TCP Stream* muestra la sesión legible. En SSH solo se ven el banner y los paquetes de handshake; a partir de `SSH2_MSG_NEWKEYS` el contenido aparece cifrado.

## 2. Ejercicio 1: conexión SSH en modo verbose

Se establece una conexión desde `user1` hacia `user2` en la misma máquina, primero con `-v` y después con `-vv`:

```bash
ssh -v  user2@localhost
ssh -vv user2@localhost
```

### 2.1. Salida de referencia

Fragmento de `ssh -v user2@localhost` en la VM:

```console
debug1: OpenSSH_10.0p2 Debian-7+deb13u4, OpenSSL 3.5.7 9 Jun 2026
debug1: Reading configuration data /etc/ssh/ssh_config
debug1: Connecting to localhost [::1] port 22.
debug1: Connection established.
debug1: Local version string SSH-2.0-OpenSSH_10.0p2 Debian-7+deb13u4
debug1: Remote protocol version 2.0, remote software version OpenSSH_10.0p2 Debian-7+deb13u4
debug1: Authenticating to localhost:22 as 'user2'
debug1: SSH2_MSG_KEXINIT sent
debug1: SSH2_MSG_KEXINIT received
debug1: kex: algorithm: mlkem768x25519-sha256
debug1: kex: host key algorithm: ssh-ed25519
debug1: kex: server->client cipher: chacha20-poly1305@openssh.com MAC: <implicit> compression: none
debug1: SSH2_MSG_KEX_ECDH_REPLY received
debug1: Server host key: ssh-ed25519 SHA256:fiVXvroD0pHkDSJAUdvUNS2gWp/KZ9ffVNK6Q8AdU0w
debug1: Host 'localhost' is known and matches the ED25519 host key.
debug1: Found key in /home/user1/.ssh/known_hosts:1
debug1: SSH2_MSG_NEWKEYS sent
debug1: SSH2_MSG_NEWKEYS received
debug1: Authentications that can continue: publickey,password
debug1: Next authentication method: publickey
debug1: Next authentication method: password
user2@localhost's password:
Authenticated to localhost ([::1]:22) using "password".
debug1: channel 0: new session [client-session] (inactive timeout: 0)
debug1: Requesting no-more-sessions@openssh.com
debug1: Entering interactive session.
```

### 2.2. Clasificación por protocolos SSH

SSH se organiza en tres protocolos principales: **transporte** (RFC 4253), **autenticación de usuario** (RFC 4252) y **conexión** (RFC 4254). La *host key* pertenece al transporte, aunque el cliente la valide contra `known_hosts` antes de autenticar al usuario.

| Componente | Mensajes o líneas | Qué ocurre |
| --- | --- | --- |
| Transporte SSH | Banner `SSH-2.0-...`, `SSH2_MSG_KEXINIT`, `SSH2_MSG_NEWKEYS` | Se anuncia la versión, se negocian algoritmos y se activa el cifrado. |
| Intercambio de claves (KEX) | `mlkem768x25519-sha256`, `SSH2_MSG_KEX_ECDH_REPLY` | Cliente y servidor derivan un secreto compartido; el servidor firma el intercambio. |
| Clave de host | `Server host key: ssh-ed25519 SHA256:...`, `known_hosts` | El cliente comprueba que la clave pública del servidor es la esperada. |
| Autenticación | `Authentications that can continue`, `Trying private key`, `password` | El servidor ofrece métodos y el cliente demuestra su identidad. |
| Conexión/sesión | `channel 0: new session`, `pty-req`, `shell`, `env` | Se abre un canal, se pide una pseudo-terminal y se lanza la shell remota. |

Con `-vv` se añaden las propuestas completas del cliente y del servidor:

```console
debug2: local client KEXINIT proposal
debug2: KEX algorithms: mlkem768x25519-sha256,sntrup761x25519-sha512,...
debug2: host key algorithms: ssh-ed25519-cert-v01@openssh.com,...
debug2: ciphers ctos: chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,...
debug2: MACs ctos: umac-64-etm@openssh.com,...
debug2: peer server KEXINIT proposal
debug2: channel 0: request pty-req confirm 1
debug2: PTY allocation request accepted on channel 0
debug2: shell request accepted on channel 0
```

En Wireshark se puede filtrar `ssh` y seleccionar *Follow → TCP Stream*. Antes de `NEWKEYS` se leen los nombres de los algoritmos y la clave de host; después, el flujo es binario cifrado. Eso demuestra que la contraseña no viaja en claro: se envía dentro del canal protegido.

**Resultado**: la conexión termina correctamente, la host key ED25519 coincide con la de `known_hosts` y la autenticación acaba en `password` porque el usuario aún no tenía una clave pública instalada. El modo `-vv` no cambia la conexión, solo el nivel de detalle.

## 3. Ejercicio 2: reinstalar el servidor y corregir `known_hosts`

### 3.1. Reinstalación y nueva host key

Una reinstalación “desde cero” del servidor genera nuevas claves de host. En Debian se puede reproducir así (**VM**):

```bash
sudo apt install --reinstall openssh-server
sudo systemctl restart ssh
```

`apt install --reinstall` reinstala el paquete, pero puede conservar `/etc/ssh/ssh_host_*`. Para forzar claves nuevas hay que eliminarlas o regenerarlas:

```bash
sudo mkdir -p /root/ssh-host-keys-backup
sudo mv /etc/ssh/ssh_host_* /root/ssh-host-keys-backup/
sudo ssh-keygen -A
sudo systemctl restart ssh
```

También existe `sudo dpkg-reconfigure openssh-server`, que regenera las claves. Al terminar, el servidor presenta una host key distinta de la que el cliente guardó la primera vez.

### 3.2. Aviso en el cliente

El cliente no sabe que el servidor se ha reinstalado: solo ve que la clave pública ya no coincide con la entrada de `~/.ssh/known_hosts`. El resultado es un aviso de posible ataque de intermediario:

```console
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
Please contact your system administrator.
Add correct host key in /home/user1/.ssh/known_hosts to get rid of this message.
Offending ED25519 key in /home/user1/.ssh/known_hosts:1
Host key verification failed.
```

La línea `Offending ... key in ...:1` indica la entrada conflictiva. En el informe se observó además que, tras borrar `known_hosts`, `ssh` avisaba de que no podía determinar la autenticidad del host, mostraba la clave ED25519 y preguntaba si se quería continuar; al aceptar, la guardaba permanentemente.

### 3.3. Corrección

Primero se comprueba la nueva huella por un canal fiable (consola de la VM, panel de virtualización o administrador del sistema):

```bash
# En el servidor
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Si coincide con la que muestra el aviso, se elimina la entrada antigua en el cliente:

```bash
ssh-keygen -F localhost
ssh-keygen -R localhost
```

`ssh-keygen -F` busca la entrada, incluso si está *hasheada*; `-R` la elimina y guarda una copia en `known_hosts.old`. Salida típica:

```console
# Host localhost found: line 1
localhost ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
# Host localhost found: line 1
known_hosts updated.
Original contents retained as known_hosts.old
```

Después se vuelve a conectar y se acepta la nueva clave tras verificar la huella. Si el puerto no es el 22, la entrada incluye el puerto:

```bash
ssh-keygen -R '[localhost]:2222'
```

También se puede borrar la línea a mano, pero con `HashKnownHosts yes` (valor habitual en Debian) la entrada está hasheada y es más fiable usar `ssh-keygen -R`.

### 3.4. Alternativas y riesgo

| Opción | Efecto | Cuándo usarla |
| --- | --- | --- |
| `StrictHostKeyChecking=accept-new` | Acepta hosts nuevos, pero sigue rechazando un cambio de clave | Laboratorio o primer despliegue |
| `StrictHostKeyChecking=no` | Acepta cualquier clave, incluso si cambió | Nunca en producción; solo en un entorno aislado |
| `UserKnownHostsFile=/dev/null` | No guarda ni comprueba hosts | Pruebas desechables; elimina la protección MITM |
| `ssh-keygen -R` + verificar huella | Corrige la entrada concreta | Caso correcto tras una reinstalación |

!!! warning "No desactives la comprobación para “que funcione”"
    El aviso es una protección, no un obstáculo. Antes de borrar la entrada hay que confirmar que la nueva huella es la del servidor legítimo. Si no se puede verificar, la conexión no debe continuar.

## 4. Ejercicio 3: reenvío local de puertos

### 4.1. Esquema y comando

El reenvío local abre un puerto en la máquina cliente. Todo lo que llegue a ese puerto se envía por la conexión SSH y el servidor SSH lo dirige al destino indicado:

```text
navegador -> localhost:12000 -> túnel SSH -> servidor SSH -> servidor_web:80
```

El comando del enunciado es:

```bash
ssh -L 12000:servidor:80 user@host
```

- `12000` es el puerto local que se abre.
- `servidor:80` es el destino; el nombre `servidor` lo resuelve **el servidor SSH**, no el cliente.
- `user@host` es la máquina SSH por la que pasa el túnel.

Si el servicio web está en la propia máquina SSH, el destino es `localhost:80`:

```bash
ssh -L 12000:localhost:80 user@host
```

En el informe se usó un servicio HTTPS remoto (`ehu.eus:443`) para disponer de un destino real. Para el enunciado, con Apache en la máquina remota, sirve `ssh -L 12000:localhost:80 user@host`.

Opciones útiles:

```bash
ssh -N -f -L 12000:localhost:80 user@host
ssh -N -f -o ExitOnForwardFailure=yes -L 12000:localhost:80 user@host
```

`-N` no abre shell y `-f` pasa a segundo plano. `ExitOnForwardFailure=yes` evita que la sesión quede abierta si el puerto local no se puede abrir.

### 4.2. Comprobar que el túnel está abierto

En el cliente, mientras la conexión SSH sigue activa:

```bash
ss -tanp | grep 12000
sudo netstat -tanp | grep 12000
```

Salida esperada (el PID y el nombre del proceso pueden variar):

```console
LISTEN  0  128  127.0.0.1:12000  0.0.0.0:*  users:(("ssh",pid=324823,fd=4))
LISTEN  0  128      [::1]:12000     [::]:*  users:(("ssh",pid=324823,fd=3))
```

Con `netstat`:

```console
tcp   0   0  127.0.0.1:12000  0.0.0.0:*  LISTEN  324823/ssh
tcp6  0   0  ::1:12000        :::*       LISTEN  324823/ssh
```

Por defecto el puerto se abre solo en `127.0.0.1` y `::1`. La opción `-g` permite acceder desde otras interfaces, pero expone el túnel a la red local y no es recomendable en un equipo compartido.

### 4.3. Prueba desde el navegador

Antes de establecer el túnel, `http://localhost:12000` no tiene ningún servicio escuchando:

![Firefox sin túnel: no se puede conectar a localhost:12000](../../assets/img/lab-openssh/firefox-notunnel.png)

Con el túnel activo, la petición llega al servicio remoto:

![Firefox con el túnel: se alcanza el servicio remoto](../../assets/img/lab-openssh/firefox-withtunnel.png)

En el informe se usó HTTPS y Firefox mostró `SSL_ERROR_BAD_CERT_DOMAIN`: el certificado presentado es válido para `ehu.eus`, no para `localhost`. Ese error **no significa que el túnel haya fallado**; significa que se alcanzó el servicio HTTPS remoto y falló la comprobación del nombre del certificado. Con HTTP en el puerto 80 no aparece ese aviso; si el sitio redirige a HTTPS o usa HSTS, puede seguir apareciendo.

Para una prueba sin navegador:

```bash
curl -v http://localhost:12000/
```

**Resultado**: sin túnel no hay conexión; con túnel el servicio remoto responde a través de `localhost:12000`. La única diferencia de seguridad es que el tráfico entre cliente y servidor SSH viaja cifrado, pero el tramo servidor SSH → servicio web puede seguir siendo HTTP en claro.

## 5. Ejercicio 4: autenticación con clave pública

### 5.1. Punto de partida

Se comprueba que la conexión a `user2` pide contraseña:

```bash
ssh user2@localhost
```

```console
user2@localhost's password:
```

### 5.2. Generar el par de claves

En la cuenta de `user1`:

```bash
ssh-keygen -t ed25519 -a 100 -C "user1@bocata-jamon"
```

`-t ed25519` elige Ed25519; `-a 100` aumenta las iteraciones de la passphrase (opcional); `-C` añade un comentario para identificar la clave. La clave privada queda en `~/.ssh/id_ed25519` y la pública en `~/.ssh/id_ed25519.pub`.

Salida resumida de una generación real:

```console
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/user1/.ssh/id_ed25519):
Enter passphrase for "/home/user1/.ssh/id_ed25519" (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/user1/.ssh/id_ed25519
Your public key has been saved in /home/user1/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:CYaV3atqkdOvqHiQSWKXBA/VAI1GXnOiGK336QGyCaU user1@bocata-jamon
```

Comprobación de la huella:

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

```console
256 SHA256:CYaV3atqkdOvqHiQSWKXBA/VAI1GXnOiGK336QGyCaU user1@bocata-jamon (ED25519)
```

### 5.3. Instalar la clave pública en el servidor

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user2@localhost
```

`ssh-copy-id` pide la contraseña de `user2`, crea `~user2/.ssh` si hace falta y añade la clave a `~user2/.ssh/authorized_keys`:

```console
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/user1/.ssh/id_ed25519.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
user2@localhost's password:

Number of key(s) added: 1

Now try logging into the machine, with: "ssh 'user2@localhost'"
and check to make sure that only the key(s) you wanted were added.
```

Solo se copia la clave **pública**. La privada permanece en `user1` y no debe salir de allí.

Instalación manual equivalente:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 5.4. Permisos y comprobación

En el servidor, OpenSSH comprueba los permisos de `~`, `~/.ssh` y `~/.ssh/authorized_keys` (`StrictModes`):

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

| Ruta | Permisos | Motivo |
| --- | --- | --- |
| `~/.ssh` | `700` | Solo el propietario puede entrar. |
| Clave privada | `600` | El cliente se niega a usarla si es legible por otros. |
| `authorized_keys` | `600` | Evita que otros añadan claves. |
| Clave pública (`.pub`) | `644` | No es secreta. |

Si la clave privada tiene permisos demasiado abiertos, `ssh-keygen` y `ssh` avisan:

```console
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for '/home/user1/.ssh/id_ed25519' are too open.
It is required that your private key files are NOT accessible by others.
This private key will be ignored.
```

Se corrige con `chmod 600 ~/.ssh/id_ed25519`.

### 5.5. Conexión sin contraseña

```bash
ssh user2@localhost
```

La conexión debe abrir la shell de `user2` sin pedir la contraseña de la cuenta remota. Si la clave tiene passphrase, se pedirá esa passphrase (o se usará `ssh-agent`, ejercicio 5). Para ver el método elegido:

```bash
ssh -v user2@localhost 2>&1 | grep -E 'Offering|Server accepts|Authenticated'
```

```console
debug1: Offering public key: /home/user1/.ssh/id_ed25519 ED25519 SHA256:...
debug1: Server accepts key: /home/user1/.ssh/id_ed25519 ED25519 SHA256:...
Authenticated to localhost ([::1]:22) using "publickey".
```

**Resultado**: el segundo login se autentica con `publickey` y no con `password`. La contraseña de la cuenta remota sigue existiendo, pero ya no se usa para esta conexión.

!!! note "Si sigue pidiendo contraseña"
    Revisa con `ssh -vv` si el cliente ofrece la clave y si el servidor la acepta. Causas habituales: `authorized_keys` en otra ruta (`AuthorizedKeysFile`), permisos incorrectos en el *home*, `PubkeyAuthentication no`, usuario equivocado o una clave distinta de la que se copió. Prueba también `ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes user2@localhost`.

## 6. Ejercicio 5: gestión de claves con `ssh-agent`

`ssh-agent` mantiene las claves privadas descifradas en memoria y las ofrece a `ssh` a través de un socket. Así se escribe la passphrase una vez por sesión del agente, no en cada conexión.

### 6.1. Arrancar el agente y añadir la clave

```bash
eval "$(ssh-agent -s)"
```

Salida esperada:

```console
Agent pid 345247
```

`eval` es necesario porque `ssh-agent -s` imprime las variables `SSH_AUTH_SOCK` y `SSH_AGENT_PID`; sin `eval`, no quedan definidas en la shell actual. Después:

```bash
ssh-add ~/.ssh/id_ed25519
```

```console
Enter passphrase for /home/user1/.ssh/id_ed25519:
Identity added: /home/user1/.ssh/id_ed25519 (user1@bocata-jamon)
```

Para un agente aislado en pruebas se puede usar un socket propio:

```bash
TMP=$(mktemp -d)
eval "$(ssh-agent -s -a "$TMP/agent.sock")"
ssh-add "$TMP/id_ed25519"
# ...
ssh-agent -k
rm -rf "$TMP"
```

### 6.2. Listar y comprobar identidades

```bash
ssh-add -l
ssh-add -L
```

`-l` muestra la huella; `-L` muestra la clave pública completa:

```console
256 SHA256:TKoSxY37mhS/ajiTiaYfdjcXAQQb5lX2pn2MJ9Y8vD4 user1@bocata-jamon (ED25519)
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYTo4l91a02l+rZUOBa/GBL0m/Q5B+WodurjxC01oIv user1@bocata-jamon
```

Si el agente no tiene identidades:

```console
The agent has no identities.
```

y `ssh-add -l` devuelve código de salida `1`. Es útil en scripts:

```bash
ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519
```

### 6.3. Caducidad y eliminación

```bash
ssh-add -t 8h ~/.ssh/id_ed25519    # caduca a las 8 horas
ssh-add -d ~/.ssh/id_ed25519       # elimina esa clave
ssh-add -D                         # elimina todas
ssh-add -x                         # bloquea el agente
ssh-add -X                         # lo desbloquea
```

Salidas esperadas:

```console
Identity added: /home/user1/.ssh/id_ed25519 (user1@bocata-jamon)
Lifetime set to 08:00:00
Identity removed: /home/user1/.ssh/id_ed25519 ED25519 (user1@bocata-jamon)
All identities removed.
```

`-t` fija una vida máxima para la identidad; al volver a añadirla, el contador se reinicia. `-d` y `-D` solo afectan al agente, no borran los ficheros de `~/.ssh`.

Para terminar el agente de la shell actual:

```bash
eval "$(ssh-agent -k)"
```

### 6.4. Varias sesiones y terminales

Todas las shells que compartan el mismo `SSH_AUTH_SOCK` usan el mismo agente:

```bash
echo "$SSH_AUTH_SOCK"
env | grep SSH_
```

Si el agente se arrancó en otra terminal, hay que exportar allí las variables o repetir `eval "$(ssh-agent -s)"`. En un escritorio, el gestor de sesión o el llavero pueden arrancar el agente automáticamente. En `tmux`/`screen`, cada nueva ventana hereda el entorno de la sesión, así que suele funcionar sin más.

Comprobación de que `ssh` usa el agente:

```bash
ssh -v user2@localhost 2>&1 | grep -E 'agent|Offering|Authenticated'
```

```console
debug1: get_agent_identities: agent contains no identities
debug1: Offering public key: /home/user1/.ssh/id_ed25519 ED25519 SHA256:...
Authenticated to localhost ([::1]:22) using "publickey".
```

La primera línea aparece antes de `ssh-add`; después desaparece y la clave se ofrece desde el agente.

### 6.5. `ForwardAgent` y sus riesgos

`ssh -A user@host` reenvía el agente al servidor remoto. En el servidor se crea un socket y cualquier proceso con acceso a él puede pedir firmas con las claves cargadas, sin necesidad de copiar la clave privada. Es cómodo para saltar a un segundo servidor, pero peligroso en hosts no confiables: un usuario con privilegios en el servidor (incluido `root`) puede usar el agente mientras dure la sesión.

Configuración equivalente en `~/.ssh/config`:

```sshconfig
Host salto
    HostName 192.168.56.110
    User user1
    ForwardAgent yes
```

Recomendaciones:

- No activar `ForwardAgent` de forma global con `Host *`.
- Usarlo solo con servidores propios y de confianza.
- Preferir `ProxyJump` para atravesar un salto sin reenviar el agente.
- Cerrar la sesión al terminar y usar `ssh-add -t` para limitar la vida de las claves.

### 6.6. Resumen de comandos

| Comando | Efecto |
| --- | --- |
| `eval "$(ssh-agent -s)"` | Arranca el agente y exporta el socket. |
| `ssh-add ~/.ssh/id_ed25519` | Añade una clave (pide la passphrase). |
| `ssh-add -l` / `-L` | Lista huellas / claves públicas. |
| `ssh-add -t 8h clave` | Añade con caducidad. |
| `ssh-add -d clave` / `-D` | Elimina una / todas. |
| `ssh-add -x` / `-X` | Bloquea / desbloquea el agente. |
| `eval "$(ssh-agent -k)"` | Mata el agente actual. |
| `ssh -A host` | Reenvía el agente (usar con cuidado). |

## 7. Ejercicio 6: funcionalidades avanzadas

El enunciado pide elegir al menos una funcionalidad. Aquí se resuelven las dos principales, **multiplexación** y **reenvío remoto**, y se añaden **certificados SSH** y **2FA** como opciones.

### 7.1. Multiplexación de conexiones

La multiplexación reutiliza una única conexión TCP para varias sesiones, túneles y transferencias `scp`/`sftp`. La primera conexión crea un socket de control; las siguientes se conectan a él y se ahorran el handshake y la autenticación.

En `~/.ssh/config` (**cliente**):

```sshconfig
Host SRDSI
    HostName 192.168.56.110
    User user1
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```

- `ControlMaster auto` crea el maestro si no existe y reutiliza el que haya.
- `ControlPath` es el socket; `%r`, `%h` y `%p` son usuario, host y puerto.
- `ControlPersist 10m` mantiene el maestro 10 minutos después de cerrar el último canal.

Comprobar la configuración efectiva sin conectar:

```bash
ssh -G SRDSI | grep -Ei 'control(master|path|persist)'
```

```console
controlmaster auto
controlpath /home/user1/.ssh/cm-user1@192.168.56.110:22
controlpersist 600
```

`ControlPersist 10m` se muestra como `600` segundos. Uso:

```bash
ssh SRDSI                 # crea el maestro y abre la primera sesión
ssh -O check SRDSI        # comprueba que el maestro sigue vivo
ssh SRDSI                 # segunda sesión: reutiliza el socket
ssh -O exit SRDSI         # cierra el maestro y todos sus canales
```

Salidas esperadas:

```console
Master running (pid=12345)
Control socket connect(/home/user1/.ssh/cm-user1@192.168.56.110:22): No such file or directory
```

La segunda línea aparece si se ejecuta `ssh -O check` cuando no hay maestro. Si el socket no existe, `ssh SRDSI` lo crea de nuevo. Para diagnosticar:

```bash
ls -l ~/.ssh/cm-*
ssh -O check SRDSI; echo "rc=$?"
```

Si la ruta del socket es demasiado larga para el límite de `AF_UNIX`, usa `%C`:

```sshconfig
ControlPath ~/.ssh/cm-%C
```

`%C` es un hash de la conexión (usuario, host, puerto y dirección local). El directorio de `ControlPath` debe tener permisos `700`; `~/.ssh` ya los tiene.

**Resultado**: la segunda sesión no repite el intercambio de claves ni la autenticación. Es especialmente útil con `scp`/`rsync` repetidos y con túneles que se abren y cierran.

### 7.2. Reenvío remoto de puertos

El reenvío remoto abre un puerto en el **servidor SSH** y envía el tráfico hacia el **cliente**:

```text
usuario del servidor -> servidor:8080 -> túnel SSH -> cliente:80
```

Comando (**cliente**):

```bash
ssh -N -R 8080:localhost:80 user@host
```

- `8080` es el puerto que se abre en el servidor.
- `localhost:80` es el destino, resuelto en el cliente.
- `-N` evita abrir una shell; el túnel queda activo mientras dure la conexión.

En el servidor se comprueba que el puerto está en escucha:

```bash
ss -tlnp | grep 8080
```

```console
LISTEN 0 128 127.0.0.1:8080 0.0.0.0:* users:(("sshd",pid=...,fd=...))
```

Por defecto solo escucha en loopback del servidor. Para que otros equipos puedan usarlo:

```sshconfig
# /etc/ssh/sshd_config (servidor)
GatewayPorts clientspecified
```

Con `GatewayPorts clientspecified`, el cliente decide la dirección de escucha:

```bash
ssh -N -R 0.0.0.0:8080:localhost:80 user@host
```

Con `GatewayPorts yes`, el servidor fuerza el *binding* a todas las interfaces aunque el cliente no lo pida. `GatewayPorts no` (valor por defecto) restringe todo a loopback. Además, `AllowTcpForwarding` debe permitir el reenvío (`yes`, `local` o `remote`; `no` lo desactiva).

Comprobación desde el servidor:

```bash
curl http://localhost:8080/
ss -tlnp | grep 8080
```

**Resultado**: el servicio que corre en el cliente queda accesible desde el servidor a través de SSH, sin abrir un puerto en el cliente ni exponer el servicio directamente a la red.

!!! warning "Exponer un servicio con `-R`"
    `-R 0.0.0.0:...` con `GatewayPorts yes` puede publicar un servicio interno en toda la red del servidor. Comprueba el firewall, limita `AllowUsers`/`AllowTcpForwarding` y cierra el túnel con `Ctrl-C` o `ssh -O exit` al terminar.

### 7.3. Certificados SSH

Una CA de SSH firma claves de usuario y de host. El servidor confía en la CA y deja de necesitar una entrada por usuario en `authorized_keys`. No confundir esta CA con la PKI X.509 de TLS: el formato y las herramientas son distintos, aunque ambas usen `ssh-keygen`.

#### Crear la CA y firmar la clave del usuario

```bash
ssh-keygen -t ed25519 -f ~/.ssh/lab_ca -C "CA SSH del laboratorio"
ssh-keygen -s ~/.ssh/lab_ca -I user1 -n user1 -V +52w ~/.ssh/id_ed25519.pub
```

- `-s` firma con la CA.
- `-I` es el identificador del certificado (queda en el log).
- `-n` son los *principals*; deben incluir el nombre de usuario con el que se inicia sesión.
- `-V +52w` da un año de validez.

Salida real de la firma:

```console
Signed user key /home/user1/.ssh/id_ed25519-cert.pub: id "user1" serial 0 for user1 valid from 2026-10-28T12:54:00 to 2027-10-27T13:55:30
```

Se genera `id_ed25519-cert.pub` junto a la clave pública. Inspección:

```bash
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

```console
./id_ed25519-cert.pub:
        Type: ssh-ed25519-cert-v01@openssh.com user certificate
        Public key: ED25519-CERT SHA256:TKoSxY37mhS/ajiTiaYfdjcXAQQb5lX2pn2MJ9Y8vD4
        Signing CA: ED25519 SHA256:Lx5pr7BgADOu79HIZHlxHsVZcQX8CfH7xE8vVvwPgDA (using ssh-ed25519)
        Key ID: "user1"
        Serial: 0
        Valid: from 2026-10-28T12:54:00 to 2027-10-27T13:55:30
        Principals:
                user1
        Critical Options: (none)
        Extensions:
                permit-X11-forwarding
                permit-agent-forwarding
                permit-port-forwarding
                permit-pty
                permit-user-rc
```

#### Confiar en la CA en el servidor

```bash
sudo cp ~/.ssh/lab_ca.pub /etc/ssh/lab_ca.pub
sudo chmod 644 /etc/ssh/lab_ca.pub
```

En `/etc/ssh/sshd_config` (**VM**):

```sshconfig
TrustedUserCAKeys /etc/ssh/lab_ca.pub
PubkeyAuthentication yes
```

Validar y recargar:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

El cliente usa el certificado automáticamente si `id_ed25519-cert.pub` está junto a `id_ed25519`; si no:

```sshconfig
Host SRDSI
    CertificateFile ~/.ssh/id_ed25519-cert.pub
```

Comprobación:

```bash
ssh -v user1@SRDSI 2>&1 | grep -E 'certificate|Authenticated'
```

Debe aparecer la carga del certificado y `Authenticated ... using "publickey"`. Si el *principal* no coincide con el usuario, el servidor rechaza el certificado aunque la firma sea válida.

Para certificados de host (el cliente verifica el servidor sin `known_hosts`):

```bash
sudo ssh-keygen -s ~/.ssh/lab_ca -h -I host-bocata -n bocata-jamon -V +52w \
    /etc/ssh/ssh_host_ed25519_key.pub
```

Y en `sshd_config`:

```sshconfig
HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
```

**Resultado**: el servidor acepta la clave del usuario por estar firmada por la CA, sin añadirla a `authorized_keys`. La CA privada debe protegerse: quien la tenga puede emitir certificados para cualquier *principal* permitido.

### 7.4. 2FA: clave pública + contraseña

La autenticación de dos factores exige superar dos métodos. En OpenSSH se configura con `AuthenticationMethods`, que respeta el orden indicado.

En `/etc/ssh/sshd_config` (**VM**):

```sshconfig
PubkeyAuthentication yes
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
AuthenticationMethods publickey,password
```

`publickey,password` significa: primero clave pública y, solo si esta es válida, contraseña. No es lo mismo que `publickey|password`, que permitiría cualquiera de los dos.

Validar antes de recargar:

```bash
sudo sshd -t
```

Sin salida significa que la sintaxis es correcta. Después:

```bash
sudo systemctl reload ssh
```

Prueba:

```bash
ssh -v user1@localhost
```

La traza debe mostrar la oferta de la clave, su aceptación y, después, la petición de contraseña. La sesión no se abre hasta completar ambos factores:

```console
debug1: Authentications that can continue: publickey,password
debug1: Offering public key: /home/user1/.ssh/id_ed25519 ED25519 SHA256:...
debug1: Server accepts key: /home/user1/.ssh/id_ed25519 ED25519 SHA256:...
user1@localhost's password:
Authenticated to localhost ([::1]:22) using "publickey"
```

El mensaje final puede variar según la versión; lo importante es que la shell no aparece hasta introducir la contraseña. En el servidor, `journalctl -u ssh -n 20 --no-pager` muestra los intentos y el resultado.

!!! warning "No te quedes fuera"
    Antes de recargar `sshd`, deja una sesión SSH abierta y valida con `sudo sshd -t`. Un error en `AuthenticationMethods`, en `UsePAM` o en la configuración de PAM puede impedir cualquier acceso. Si necesitas un segundo factor distinto de la contraseña, se puede usar TOTP con `libpam-google-authenticator` y `keyboard-interactive`, pero eso ya requiere configurar PAM además de `sshd_config`.

**Resultado**: el usuario debe presentar la clave privada y la contraseña. La clave aporta algo que se tiene; la contraseña, algo que se sabe. Si se pierde uno de los dos, no se completa el login.

## 8. Problemas típicos

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| `Permission denied (publickey)` | Clave no instalada, usuario equivocado o permisos abiertos. | Revisa `~/.ssh/authorized_keys`, `ls -ld ~ ~/.ssh`, `ssh -vv` y `AuthorizedKeysFile`. |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!` | La clave privada es legible por otros. | `chmod 600 ~/.ssh/id_ed25519`. |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | Reinstalación del servidor o ataque MITM. | Verifica la huella y `ssh-keygen -R localhost`. |
| `bind: Address already in use` | El puerto local del túnel ya está ocupado. | `ss -tlnp | grep :12000`; elige otro puerto o cierra el proceso. |
| `channel ... open failed: administratively prohibited` | `AllowTcpForwarding no` en el servidor. | Permite `local`/`remote`/`yes` en `sshd_config` y recarga. |
| `-R` no responde desde otros equipos | El puerto escucha solo en loopback. | `GatewayPorts clientspecified` o `yes`, según el caso. |
| `Agent admitted failure to sign using the key` | La clave no está en el agente o el agente no es el esperado. | `ssh-add`, `ssh-add -l`, revisa `SSH_AUTH_SOCK`. |
| `Permission denied (publickey)` con certificado | *Principal* distinto del usuario, CA no confiada o certificado caducado. | `ssh-keygen -L -f ...-cert.pub`, `TrustedUserCAKeys`, `-n usuario`. |
| 2FA no pide el segundo factor | `AuthenticationMethods` mal escrito o `PasswordAuthentication no`. | Revisa `sshd -T`, `UsePAM`, recarga y prueba en una sesión nueva. |
| `Connection refused` | `sshd` parado, puerto distinto o firewall. | `systemctl status ssh`, `ss -tlnp | grep :22`, reglas de firewall. |

## 9. Enlaces

- [Informe completo del laboratorio (PDF)](../../assets/pdf/informe-openssh.pdf)
- [Enunciado del laboratorio (PDF)](../../assets/pdf/lab-openssh.pdf)
- [Esquema de port forwarding (PDF)](../../assets/pdf/lab-openssh-port-forwarding.pdf)
- [Comandos SSH y túneles](../comandos/ssh.md): sintaxis de `ssh`, `ssh-keygen`, `ssh-agent`, `-L`, `-R`, `-D`, multiplexación y certificados.
- [Teoría SSH](../teoria/ssh.md): protocolo, capas y modelos de confianza.
- [Wireshark y capturas](../comandos/wireshark.md): filtros y análisis de tráfico SSH/Telnet.
- [Recursos y PDFs](../../recursos/pdfs.md): material del curso.

!!! note "Material original"
    Las fuentes del laboratorio están en `Tema 2: Seguridad en la comunicación/lab-openssh/`: `Lab_SSH.pdf`, `SSH_PORT-FORWARDING.pdf`, `informe_open_ssh.tex`, las notas de Jorge y Jon y las capturas de Firefox. Esta página no modifica ese material; las copias usadas en el sitio están en `docs/assets/pdf/` y `docs/assets/img/lab-openssh/`.
