# Antes del examen

Checklist de última hora. Marca lo que ya hayas comprobado y repasa los errores típicos antes de empezar.

## 1. VM y entorno

- [ ] La VM arranca y responde por SSH: `ssh user1@<ip>`.
- [ ] El prompt y el hostname muestran el nombre personalizado del grupo/alumno: `hostnamectl`.
- [ ] El usuario está en los grupos `wireshark` y `vboxsf`: `id` o `getent group wireshark vboxsf`.
- [ ] La carpeta compartida aparece en `/media/sf_<nombre>` y se puede leer.
- [ ] Los puertos que vas a usar están libres: `ss -tlnp` y `ss -ulnp`.
- [ ] Para capturar sin `sudo`: `getcap "$(command -v dumpcap)"` muestra `cap_net_admin,cap_net_raw`.
- [ ] Sabes dónde está el repositorio y citas entre comillas las rutas con espacios y `:`.

```bash
hostnamectl
id
getent group wireshark vboxsf
ip -brief address
ss -tlnp
ss -ulnp
getcap "$(command -v dumpcap)"
```

Puertos habituales del laboratorio:

| Puerto | Protocolo | Uso |
| --- | --- | --- |
| `22` | TCP | SSH |
| `23` | TCP | Telnet (solo demostración) |
| `1064` | TCP | `serv-infouser` / `cli-infouser` |
| `4433` | TCP | `openssl s_server` TLS |
| `4434` | UDP | `openssl s_server` DTLS |
| `4747` | TCP | Respondedor OCSP |
| `8000` | TCP | `python3 -m http.server` para el bundle offline |

[:octicons-arrow-right-24: Ver más — VM y entorno](../guia/vm-entorno.md)

## 2. PKI

- [ ] Existen `index.txt`, el fichero de serie, el de número de CRL, el certificado de la CA y su clave privada.
- [ ] La clave privada está en un directorio `700` y el fichero de configuración apunta a las rutas correctas (`home`, `database`, `serial`, `crlnumber`, `certificate`, `private_key`, `new_certs_dir`).
- [ ] Las contraseñas se pasan por entorno: `KEY_PASS`, `CA_PASS`, `P12_PASS`, no con `-p`.
- [ ] Tras revocar, has regenerado la CRL: `openssl ca -gencrl ...`.
- [ ] El respondedor OCSP usa un certificado con `extendedKeyUsage=OCSPSigning` (`ocsp_ext`).
- [ ] La cadena se verifica con la raíz como ancla y la subCA como `-untrusted`, o con la cadena completa en `-CAfile`.
- [ ] La política exige `C` y `O` iguales a los de la CA; los usuarios también necesitan `-e`.

```bash
openssl x509 -in certificado.crt -noout -subject -issuer -dates -serial
openssl verify -CAfile ca-root.crt -untrusted subca.crt certificado.crt
openssl ca -status <serial> -config ca-sub_openssl.cnf </dev/null
openssl crl -in crl.pem -noout -text
openssl ocsp -issuer subca.crt -cert certificado.crt \
  -url http://ocsp.bocata-jamon.srdsi.lab:4747 -CAfile cadena.crt -resp_text
```

!!! danger "Revocar no publica la CRL"
    `openssl ca -revoke` solo marca el certificado en `index.txt`. Si no ejecutas `openssl ca -gencrl`, la CRL publicada sigue diciendo que es válido. El OCSP refleja el cambio en cuanto lee `index.txt`.

[:octicons-arrow-right-24: Ver más — OpenSSL y PKI](../tema1/comandos/openssl.md)
[:octicons-arrow-right-24: Ver más — Scripts PKI](../tema1/lab-pki/scripts.md)
[:octicons-arrow-right-24: Ver más — Configuración OpenSSL](openssl-config.md)

## 3. TLS y DTLS

- [ ] Sabes que `server.crt` y `client.crt` están firmados por la **subCA**, no por la raíz.
- [ ] La cadena se construye con raíz + subCA: `cat ca-root.crt subca.crt > /tmp/ca-chain.pem`.
- [ ] En el servidor envías el intermedio con `-cert_chain subca.crt`; con solo `-cert server.crt` el cliente falla con `unable to get local issuer certificate`.
- [ ] Para mTLS: servidor con `-Verify 1 -CAfile ...` y cliente con `-cert client.crt -key client.key`.
- [ ] Para descifrar en Wireshark fijas **TLS 1.2** y generas el keylog de esa misma sesión (`-keylogfile` o `SSL_CTX_set_keylog_callback`).
- [ ] Recuerdas que `-verify` (cliente) y `-Verify` (servidor) son distintos y sensibles a mayúsculas.
- [ ] DTLS no admite `-www`; usa `-quiet` y envía datos por la entrada estándar.
- [ ] 0-RTT necesita una sesión/ticket previo y `-early_data`; en OpenSSL 4 el cliente exige un fichero.
- [ ] PQC: `serverpq.crt` tiene clave ML-DSA-65 y solo funciona con TLS 1.3.

```bash
cat ca-root.crt subca.crt > /tmp/ca-chain.pem
openssl verify -CAfile /tmp/ca-chain.pem server.crt client.crt
openssl x509 -in server.crt -noout -subject -issuer -dates
openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
  -CAfile /tmp/ca-chain.pem -keylogfile /tmp/keys.log -brief
```

!!! warning "El keylog no es universal"
    Un keylog de TLS 1.2 no descifra una captura TLS 1.3, ni al revés. Carga el fichero generado por la sesión que quieres analizar.

[:octicons-arrow-right-24: Ver más — OpenSSL TLS/DTLS](../tema2/comandos/openssl-tls.md)
[:octicons-arrow-right-24: Ver más — Alertas TLS](alertas-tls.md)
[:octicons-arrow-right-24: Ver más — Wireshark](../tema2/comandos/wireshark.md)

## 4. SSH

- [ ] `~/.ssh` está en `700`; la clave privada, en `600`; `authorized_keys`, en `600`.
- [ ] Si cambió la host key (reinstalación de la VM), borras la entrada con `ssh-keygen -R host` **después** de comprobar la huella.
- [ ] `ssh -v` muestra qué método de autenticación se acepta y qué clave se ofrece.
- [ ] Los túneles `-L`, `-R` y `-D` se comprueban con `ss -tlnp` en el extremo correspondiente.
- [ ] El agente está activo y la clave cargada: `ssh-add -l`.
- [ ] Si hay multiplexación, `ssh -O check SRDSI` confirma el maestro; `ssh -O exit` lo cierra.
- [ ] En certificados SSH, los *principals* (`-n`) coinciden con el usuario o el nombre del host.
- [ ] Antes de recargar `sshd`: `sudo sshd -t` y deja una sesión abierta.

```bash
ls -ld ~/.ssh; ls -l ~/.ssh
ssh -v user1@localhost
ssh-keygen -F host
ssh-keygen -R host
eval "$(ssh-agent -s)" && ssh-add -l
ss -tlnp | grep -E ':22|:12000|:1080'
```

[:octicons-arrow-right-24: Ver más — SSH y túneles](../tema2/comandos/ssh.md)

## 5. GnuPG

- [ ] Usas un `GNUPGHOME` temporal o sabes qué llavero estás tocando (`gpg --version` muestra el `Home`).
- [ ] La clave tiene una subclave de cifrado `[E]`; una clave solo de firma no sirve para `--encrypt`.
- [ ] La confianza de una clave importada es `[unknown]` hasta que la firmas o ajustas `trust`; para pruebas: `--trust-model always`.
- [ ] La passphrase no está en el historial; en scripts usa `--batch --pinentry-mode loopback` o el agente.
- [ ] `--list-packets` solo describe la estructura; para comprobar una firma usa `--verify`.
- [ ] Recuerdas que el certificado de revocación se guarda *offline* y que revocar es irreversible.

```bash
gpg --version
gpg --list-keys --keyid-format long
gpg --list-secret-keys
gpg --fingerprint
gpg --verify mensaje.txt.asc
gpg --list-packets mensaje.gpg
```

[:octicons-arrow-right-24: Ver más — GnuPG](../tema1/comandos/gpg.md)
[:octicons-arrow-right-24: Ver más — PGP con GnuPG](../tema2/comandos/pgp.md)

## 6. Errores típicos y diagnóstico

| Síntoma | Causa probable | Cómo diagnosticarlo / arreglarlo |
| --- | --- | --- |
| `Permission denied (publickey)` | Clave no instalada, usuario incorrecto o permisos abiertos. | `ssh -vv`, revisa `authorized_keys` y `ls -ld ~/.ssh`. |
| `UNPROTECTED PRIVATE KEY FILE` | Clave privada legible por otros. | `chmod 600 ~/.ssh/id_ed25519`. |
| `Host key verification failed` | Host key cambiada o entrada obsoleta. | Comprueba la huella y `ssh-keygen -R host`. |
| `Connection refused` | Servicio parado o puerto/firewall incorrecto. | `systemctl status ssh`, `ss -tlnp`, firewall. |
| `unable to get local issuer certificate` | Falta la subCA en el almacén de confianza. | `-CAfile /tmp/ca-chain.pem` o `-cert_chain subca.crt`. |
| `alert handshake failure` (40) | El servidor exige certificado de cliente y no lo hay, o no hay cifrados comunes. | Añade `-cert client.crt -key client.key`; revisa `-cipher`/`-tls1_2`. |
| `alert unknown ca` (48) | El cliente no confía en la CA del servidor. | Usa la CA correcta (`s-ca_cert.pem`, no `c-ca_cert.pem`). |
| `alert protocol version` (70) | Cliente y servidor forzados a versiones distintas. | Deja negociar o usa la misma versión en ambos extremos. |
| `no shared cipher` | Cifrado o versión incompatibles. | Revisa `-tls1_2`/`-tls1_3` y `-cipher`/`-ciphersuites`. |
| `address already in use` | Otro proceso ocupa el puerto. | `ss -tlnp \| grep 4433` y elige otro puerto. |
| Wireshark no descifra | Keylog de otra sesión, versión TLS distinta o cargado después de abrir. | Usa el keylog de esa captura, la misma versión TLS y recarga. |
| `dumpcap: Permission denied` | Usuario fuera del grupo `wireshark`. | `usermod -aG wireshark`, re-login, `getcap`. |
| `gpg: No secret key` | El mensaje no es para esa clave o falta la privada. | `gpg --list-packets` y `gpg --list-secret-keys`. |
| `gpg: BAD signature` | Datos modificados o fichero equivocado. | Verifica el par firma/datos correcto. |
| `TXT_DB error number 2` | Ya existe una entrada con ese `subject`. | `unique_subject=no` o revisa `index.txt`. |
| `The mandatory countryName field was missing` | La CSR no lleva `C`/`O` que exige la política. | Añade `-C ES -O "Bocata de Jamon"` al generar la CSR. |

!!! tip "Regla general"
    Ante un fallo de TLS, mira primero la **alerta** (`tls.alert_message.desc`) y la **cadena** (`openssl verify`). Ante un fallo de SSH, mira `ssh -vv` y los permisos. Ante un fallo de PKI, mira `index.txt` y la configuración (`openssl ca -config ...`).

## Enlaces

- [Chuleta de comandos](comandos.md)
- [Alertas TLS](alertas-tls.md)
- [Configuración OpenSSL](openssl-config.md)
- [Certificados de laboratorio](../recursos/certificados.md)
- [Descargas y bundle offline](../recursos/descargas.md)
