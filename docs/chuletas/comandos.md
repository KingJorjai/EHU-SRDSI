# Chuleta de comandos

Índice rápido por tarea. Cada bloque enlaza a la página con sintaxis completa, ejemplos comprobados y errores típicos.

## Entorno y VM

```bash
ssh user1@192.168.56.110                 # acceso a la VM
scp fichero.txt user1@<ip>:.             # host → VM (HOME remoto)
scp -r directorio user1@<ip>:.           # copiar un directorio
scp user1@<ip>:/var/log/syslog ./        # VM → host
sudo usermod -aG vboxsf "$(whoami)"      # carpeta compartida /media/sf_*
sudo usermod -aG wireshark "$(whoami)"   # capturar sin sudo
sudo hostnamectl set-hostname demoG99    # nombre personalizado
sudo visudo                              # editar /etc/sudoers con validación
id                                       # comprobar grupos efectivos
ip -brief address                        # direcciones de red
```

Cierra la sesión y vuelve a entrar (o usa `newgrp`) para que los grupos nuevos surtan efecto.

[:octicons-arrow-right-24: Ver más — VM y entorno](../guia/vm-entorno.md)

## PKI con OpenSSL

```bash
# Claves, CSR y autofirma
openssl req -new -newkey rsa:3072 -keyout ca.key -out ca.csr -config ca.cnf -batch
openssl ca -selfsign -batch -notext -config ca.cnf -extensions ca_ext -in ca.csr -out ca.crt

# Emitir, inspeccionar y verificar
openssl ca -batch -notext -config ca.cnf -in solicitud.csr -out certificado.crt -extensions server_ext
openssl x509 -in certificado.crt -noout -text
openssl x509 -in certificado.crt -noout -subject -issuer -dates -serial
openssl verify -CAfile cadena.crt certificado.crt
openssl verify -CAfile ca-root.crt -untrusted subca.crt certificado.crt

# Revocar, CRL y OCSP
openssl ca -batch -config ca.cnf -revoke certificado.crt -crl_reason keyCompromise
openssl ca -gencrl -batch -config ca.cnf -out crl.pem
openssl crl -in crl.pem -noout -text
openssl ocsp -port 4747 -index index.txt -CA subca.crt -rsigner ocsp.crt -rkey ocsp.key
openssl ocsp -issuer subca.crt -cert certificado.crt -url http://ocsp.srdsi.lab:4747 -CAfile cadena.crt -resp_text

# PKCS#12, aleatoriedad y rendimiento
openssl pkcs12 -export -out usuario.p12 -in usuario.crt -inkey usuario.key -certfile cadena.crt
openssl pkcs12 -in usuario.p12 -info -noout
openssl rand -hex 16
openssl speed -evp aes-128-gcm
```

Contraseñas por entorno (`KEY_PASS`, `CA_PASS`, `P12_PASS`, `OCSP_PASS`) para que no aparezcan en `ps` ni en el historial.

```bash
KEY_PASS='...' bash scripts/gen_solicitud.sh -t usuario -n "Nombre" -e n@srdsi.lab -C ES -O "Bocata de Jamon"
CA_PASS='...' bash scripts/emitir_cert.sh solicitud-Nombre.csr user_ext
CONF_CA=ca-sub_openssl.cnf CA_PASS='...' bash scripts/revocar_cert.sh certificado-Nombre.crt cessationOfOperation
```

!!! warning "Revocar no basta"
    `openssl ca -revoke` solo actualiza `index.txt`. Hay que regenerar y publicar la CRL (`openssl ca -gencrl`) para que los clientes lo sepan.

[:octicons-arrow-right-24: Ver más — OpenSSL y PKI](../tema1/comandos/openssl.md)
[:octicons-arrow-right-24: Ver más — Scripts del laboratorio PKI](../tema1/lab-pki/scripts.md)

## TLS y DTLS

```bash
# Cadena de confianza (raíz + subCA)
cat ca-root.crt subca.crt > /tmp/ca-chain.pem
openssl verify -CAfile /tmp/ca-chain.pem server.crt client.crt

# TLS 1.2
openssl s_server -accept 4433 -cert server.crt -key server.key -cert_chain subca.crt -tls1_2 -www -naccept 1
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem -brief

# TLS 1.3
openssl s_server -accept 4433 -cert server.crt -key server.key -cert_chain subca.crt -tls1_3 -www -naccept 1
openssl s_client -connect 127.0.0.1:4433 -tls1_3 -CAfile /tmp/ca-chain.pem -brief

# DTLS 1.2 (UDP, sin -www)
openssl s_server -dtls1_2 -accept 4434 -cert server.crt -key server.key -cert_chain subca.crt -quiet -naccept 1
printf 'hola dtls\n' | openssl s_client -dtls1_2 -connect 127.0.0.1:4434 -CAfile /tmp/ca-chain.pem

# mTLS: el servidor exige certificado de cliente
openssl s_server -accept 4433 -cert server.crt -key server.key -cert_chain subca.crt -CAfile /tmp/ca-chain.pem -Verify 1 -tls1_2 -quiet -naccept 1
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem -cert client.crt -key client.key

# Resumption TLS 1.2
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem -sess_out /tmp/sess.pem
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem -sess_in /tmp/sess.pem

# 0-RTT TLS 1.3 (OpenSSL 4 exige fichero en el cliente)
openssl s_server -accept 4433 -cert server.crt -key server.key -cert_chain subca.crt -tls1_3 -early_data -quiet -naccept 2
openssl s_client -connect 127.0.0.1:4433 -tls1_3 -CAfile /tmp/ca-chain.pem -sess_in /tmp/sess13.pem -early_data /tmp/early.txt

# PQC: ML-DSA-65 y grupo híbrido
openssl s_server -accept 4435 -cert serverpq.crt -key serverpq.key -cert_chain subca.crt -tls1_3 -groups X25519MLKEM768 -www -naccept 1
openssl s_client -connect 127.0.0.1:4435 -tls1_3 -groups X25519MLKEM768 -CAfile /tmp/ca-chain.pem -brief

# Keylog para Wireshark
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem -keylogfile /tmp/keys.log
```

`-verify` (minúscula, cliente) verifica al servidor; `-Verify` (mayúscula, servidor) exige certificado de cliente. Para descifrar en Wireshark se fija TLS 1.2 y se usa el keylog de esa misma sesión.

[:octicons-arrow-right-24: Ver más — OpenSSL TLS/DTLS](../tema2/comandos/openssl-tls.md)
[:octicons-arrow-right-24: Ver más — Ejercicios TLS y DTLS](../tema2/actividades/tls-dtls.md)

## Apache, HTTPS y OCSP

```bash
# Servicio y sitios virtuales
sudo apache2ctl configtest              # sintaxis
sudo apache2ctl graceful                # recarga sin cortar conexiones
sudo apache2ctl -S                      # sitios virtuales activos
sudo a2ensite srdsi-lab && sudo a2dissite srdsi-lab
sudo a2enmod ssl auth_basic auth_digest socache_shmcb

# Usuarios de la zona privada
sudo htpasswd -c /etc/apache2/usersweb admin1     # Basic (MD5 por defecto; -B bcrypt)
sudo htdigest -c /etc/apache2/digest_users "Area privada" admin1
curl -iu admin1:pass http://www.srdsi.lab/zona-privada/
curl -i --digest -u admin1:pass http://www.srdsi.lab/zona-privada/

# HTTPS y autenticación de cliente
openssl verify -CAfile ca_cert.pem -untrusted subca_cert.pem serv_cert.pem
cat subca_cert.pem ca_cert.pem > /etc/apache2/ssl/cadena-cas.pem
openssl s_client -connect www.srdsi.lab:443 -servername www.srdsi.lab \
  -CAfile ca_cert.pem -verify_return_error </dev/null

# OCSP: respondedor, consulta y stapling
openssl ocsp -port 4747 -index index.txt -CA subca.crt \
  -rsigner ocsp.crt -rkey ocsp.key -passin env:OCSP_PASS -text -out log-ocsp.txt
openssl ocsp -issuer subca.crt -cert servidor.crt \
  -url http://ocsp.bocata-jamon.srdsi.lab:4747 -resp_text
echo | openssl s_client -connect www.bocata-jamon.srdsi.lab:443 \
  -servername www.bocata-jamon.srdsi.lab -status -CAfile cadena-cas.pem
```

`Authorization: Basic ...` viaja en Base64 (no cifrado); Digest envía usuario y hash, no la contraseña. La clave del respondedor OCSP está cifrada: usa `-passin env:OCSP_PASS` si no quieres el prompt (obligatorio en segundo plano). El respondedor lee `index.txt` al arrancar: **reinícialo tras revocar**. `s_client -status` muestra si el servidor envía el *staple*; `TLS Feature: status_request` en el certificado indica Must-Staple.

[:octicons-arrow-right-24: Ver más — Teoría del servicio WWW](../tema3/teoria/servicio-www.md)
[:octicons-arrow-right-24: Ver más — Actividad Apache](../tema3/actividades/apache.md)
[:octicons-arrow-right-24: Ver más — PKI 2ª fase: OCSP](../tema1/lab-pki/pki2.md)

## DNS y correo

```bash
# BIND9: configuración y zonas
sudo apt-get install bind9 bind9-utils bind9-dnsutils
sudo named-checkconf /etc/bind/named.conf
sudo named-checkzone srdsi.lab /etc/bind/db.srdsi.lab
sudo systemctl restart bind9
sudo rndc status
sudo rndc reload
sudo rndc flush
sudo rndc dumpdb -cache

# Consultas
dig @172.16.0.136 dns1.srdsi.lab
dig +short MX dominio
dig -x 172.16.0.136
dig @172.16.0.136 srdsi.lab AXFR
dig +dnssec srdsi.lab DNSKEY
delv @localhost -a trustanchor.key +root=srdsi.lab srdsi.lab NS

# DNSSEC (KSK + ZSK)
sudo dnssec-keygen -a RSASHA256 -b 1024 -f KSK -n ZONE srdsi.lab.
sudo dnssec-keygen -a RSASHA256 -b 1024 -n ZONE srdsi.lab.
sudo dnssec-signzone -t -o srdsi.lab. db.srdsi.lab

# SMTP y POP3 manuales
telnet smtp.ehu.es 25
telnet mailin.ehu.es 110
openssl s_client -starttls smtp -crlf -connect smtp.ehu.es:25
openssl s_client -connect mailin.ehu.es:pop3s
openssl s_client -starttls pop3 -crlf -connect mailin.ehu.es:110

# IMAP
openssl s_client -connect ikasle.ehu.eus:993 -servername ikasle.ehu.eus -brief
openssl s_client -starttls imap -connect ikasle.ehu.eus:143 -servername ikasle.ehu.eus -brief
```

`named-checkzone` valida la zona antes de recargar; `rndc reload` aplica cambios sin reiniciar. En SMTP, `EHLO` muestra las extensiones (`STARTTLS`, `AUTH`…). Un `250` a un `RCPT TO` externo sin autenticarte indica *open relay*: debe rechazarse.

[:octicons-arrow-right-24: Ver más — Seguridad en DNS](../tema3/teoria/dns.md)
[:octicons-arrow-right-24: Ver más — Actividad DNS con BIND](../tema3/actividades/dns.md)
[:octicons-arrow-right-24: Ver más — Correo electrónico](../tema3/teoria/correo.md)
[:octicons-arrow-right-24: Ver más — Actividad de correo](../tema3/actividades/correo.md)

## SSH

```bash
ssh user@host                            # conexión básica
ssh -v user@host                         # diagnóstico (hasta -vvv)
ssh -p 2222 user@host                    # puerto alternativo
ssh-keygen -t ed25519 -C "user1@srdsi"   # par de claves
ssh-copy-id user@host                    # instalar la pública
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
ssh-add -l                               # claves cargadas en el agente
ssh-keygen -R host                       # borrar host key obsoleta

# Túneles
ssh -L 12000:ehu.eus:443 user1@SRDSI     # local: 127.0.0.1:12000 → ehu.eus:443
ssh -N -R 8080:localhost:80 user1@SRDSI  # remoto: servidor:8080 → cliente:80
ssh -D 1080 user1@SRDSI                  # SOCKS en 127.0.0.1:1080

# Multiplexación (~/.ssh/config)
ssh -O check SRDSI                       # maestro vivo
ssh -O exit SRDSI                        # cerrar maestro y canales

# Certificados SSH
ssh-keygen -s ~/.ssh/lab_ca -I user1 -n user1 -V +52w ~/.ssh/id_ed25519.pub
ssh-keygen -s ~/.ssh/lab_ca -h -I host-bocata -n bocata-jamon -V +52w /etc/ssh/ssh_host_ed25519_key.pub
ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub
```

```sshconfig
Host SRDSI
    HostName 192.168.56.110
    User user1
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
```

Permisos: `~/.ssh` a `700`, claves privadas a `600`, `authorized_keys` a `600`. Tras cambiar `sshd_config`, valida con `sudo sshd -t` antes de `systemctl reload ssh`.

[:octicons-arrow-right-24: Ver más — SSH y túneles](../tema2/comandos/ssh.md)

## GnuPG

```bash
# Llavero aislado de laboratorio
LABGPG=$(mktemp -d); chmod 700 "$LABGPG"; export GNUPGHOME="$LABGPG"

# Simétrico
gpg --symmetric --cipher-algo AES256 mensaje.txt
gpg --decrypt mensaje.txt.gpg

# Asimétrico: claves, cifrado y descifrado
gpg --batch --passphrase '' --quick-gen-key "Alice <alice@srdsi.lab>" default default never
gpg --list-keys --keyid-format long
gpg --fingerprint
gpg --recipient alice@srdsi.lab --encrypt mensaje.txt
gpg --decrypt mensaje.gpg

# Firmas
gpg --clearsign mensaje.txt
gpg --detach-sign -a mensaje.txt
gpg --sign mensaje.txt
gpg --verify mensaje.txt.asc
gpg --verify mensaje.txt.asc mensaje.txt

# Claves y estructura
gpg --armor --export alice@srdsi.lab > alice.pub
gpg --import alice.pub
gpg --export-secret-keys alice@srdsi.lab > alice.sec
gpg --list-packets mensaje.gpg
gpg --edit-key alice@srdsi.lab           # trust, sign, save
```

`--list-packets` describe la estructura (PKESK, SEIPD, comprimido, literal); **no** verifica firmas. Una clave `default` solo firma: añade una subclave `encr` si vas a cifrar.

[:octicons-arrow-right-24: Ver más — GnuPG](../tema1/comandos/gpg.md)
[:octicons-arrow-right-24: Ver más — PGP con GnuPG (Tema 2)](../tema2/comandos/pgp.md)

## Wireshark, dumpcap y tshark

```bash
dumpcap -D                                      # interfaces
dumpcap -i lo -w captura.pcapng                 # capturar loopback
dumpcap -i lo -f 'tcp port 4433' -w tls.pcapng  # filtro de captura (BPF)

tshark -r captura.pcapng                        # leer captura
tshark -r captura.pcapng -Y 'tls'               # filtro de visualización
tshark -r captura.pcapng -Y 'tls.alert_message' \
  -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc
tshark -r captura.pcapng -Y 'tls.handshake.type == 1' -T fields -e frame.number -e _ws.col.Info
tshark -r captura.pcapng -o tls.keylog_file:keys.log -Y 'tls' -T fields -e frame.number -e _ws.col.Info
tshark -r captura.pcapng -o tls.keylog_file:keys.log -q -z follow,tls,ascii,0
tshark -r captura.pcapng -Y 'tcp.stream eq 0' -V
```

En la GUI: `Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename`, y `Analyze → Follow → TLS Stream`. Sin keylog, TLS 1.3 muestra el certificado y las alertas como *Application Data*.

[:octicons-arrow-right-24: Ver más — Wireshark y capturas](../tema2/comandos/wireshark.md)

## GDB

```bash
gcc -g -O0 -Wall -o programa programa.c    # compilar con símbolos
gdb ./programa                             # iniciar el depurador
```

Dentro de GDB:

```text
list              # mostrar el código fuente
break main        # punto de ruptura en main
break fichero.c:42
run               # ejecutar (con argumentos: run arg1 arg2)
next              # siguiente línea, sin entrar en funciones
step              # siguiente línea, entrando en funciones
print variable    # evaluar una variable o expresión
bt                # backtrace de la pila
jump 42           # saltar a la línea 42
continue          # reanudar hasta el siguiente breakpoint
info locals       # variables locales
quit              # salir
```

Compila siempre con `-g`; `-O0` facilita seguir el código fuente. Para examinar un *core dump*: `gdb ./programa core`.

[:octicons-arrow-right-24: Ver más — Guía rápida de GDB (PDF)](../assets/pdf/gdb.pdf)

## Enlaces rápidos

- [Antes del examen](antes-del-examen.md)
- [Alertas TLS](alertas-tls.md)
- [Configuración OpenSSL](openssl-config.md)
- [Código y configuraciones](../recursos/codigo.md)
- [Certificados de laboratorio](../recursos/certificados.md)
- [Benchmarks](../recursos/benchmarks.md)
