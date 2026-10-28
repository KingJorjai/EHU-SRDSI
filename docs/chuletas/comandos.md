# Chuleta de comandos

Índice rápido por tarea. Cada entrada enlaza a la página con sintaxis, ejemplos y errores típicos.

## Entorno y VM

```bash
ssh user1@<ip>                         # acceso a la VM
scp fichero user1@<ip>:.               # copiar al HOME remoto
scp -r user1@<ip>:directorio .         # copiar un directorio
sudo usermod -aG vboxsf $(whoami)      # acceso a carpeta compartida
sudo usermod -aG wireshark $(whoami)   # capturar sin sudo
```

## PKI con OpenSSL

```bash
openssl req -new -newkey rsa:3072 -keyout ca.key -out ca.csr -config ca.cnf
openssl ca -selfsign -in ca.csr -out ca.crt -config ca.cnf -extensions ca_ext
openssl ca -gencrl -config ca.cnf -out ca.crl
openssl ca -in solicitud.csr -out certificado.crt -config ca.cnf -extensions server_ext
openssl ca -revoke certificado.crt -crl_reason keyCompromise -config ca.cnf
openssl x509 -in certificado.crt -noout -text
openssl verify -CAfile cadena.crt certificado.crt
openssl ocsp -port 4747 -index index.txt -CA subca.crt -rsigner ocsp.crt -rkey ocsp.key
openssl pkcs12 -export -out usuario.p12 -in usuario.crt -inkey usuario.key
```

## TLS y DTLS

```bash
openssl s_server -accept 4433 -cert server.crt -key server.key -tls1_2
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -keylogfile keylog.txt
openssl s_client -connect 127.0.0.1:4433 -dtls1_2
```

## SSH

```bash
ssh -v user@host
ssh-keygen -t ed25519
ssh-copy-id user@host
ssh -L 12000:hostdestino:443 user@host
ssh -R 8080:localhost:80 user@host
ssh -D 1080 user@host
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

## GnuPG

```bash
gpg --version
gpg --symmetric --cipher-algo AES256 fichero
gpg --recipient usuario --encrypt fichero
gpg --decrypt fichero.gpg
gpg --clearsign fichero
gpg --detach-sign -a fichero
gpg --list-packets fichero.gpg
gpg -a --export claveID > publica.asc
gpg --import publica.asc
```

## Wireshark y capturas

```bash
sudo dumpcap -i lo -w captura.pcapng
tshark -r captura.pcapng
tshark -r captura.pcapng -o tls.keylog_file:keylog.txt -Y tls
tshark -r captura.pcapng -o tls.keylog_file:keylog.txt -q -z follow,tls,ascii,0
```

!!! warning "Pendiente"
    Esta página se irá completando con los comandos exactos y enlaces a cada apartado durante la construcción del sitio.
