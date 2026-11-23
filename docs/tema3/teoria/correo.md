# Correo electrónico

El correo es uno de los servicios más atacados: spam, *phishing*, suplantación y robo de credenciales. Esta página resume la arquitectura SMTP/POP3/IMAP, los mecanismos de autenticación y las defensas que se aplican hoy.

[:material-file-pdf-box: Transparencias — 3.4 Correo (PDF)](../../assets/pdf/SRDSI_T3-4.pdf){ .md-button }

## Arquitectura

| Elemento | Función |
| --- | --- |
| **MUA** | Cliente de correo (Thunderbird, webmail). |
| **MSA** | Servidor de envío autenticado (submission, 587). |
| **MTA** | Transporta el correo entre dominios (SMTP, 25). |
| **MDA** | Entrega en el buzón del usuario. |
| **MRA** | Acceso al buzón (POP3/IMAP). |

Un mensaje viaja del MUA al MSA, de ahí al MTA del dominio y, por SMTP, al MTA destino, que lo entrega con el MDA. El usuario lo lee por **POP3** o **IMAP** ([transparencias, pág. 7](../../assets/pdf/SRDSI_T3-4.pdf#page=7)).

## Protocolos y puertos

| Protocolo | Puerto | Cifrado |
| --- | --- | --- |
| SMTP | 25 | STARTTLS (entre MTA). |
| Submission | 587 | STARTTLS obligatorio. |
| SMTPS | 465 | TLS implícito. |
| POP3 | 110 | STARTTLS (`STLS`). |
| POP3S | 995 | TLS implícito. |
| IMAP | 143 | STARTTLS. |
| IMAPS | 993 | TLS implícito. |

**POP3** descarga y habitualmente borra del servidor ([pág. 23](../../assets/pdf/SRDSI_T3-4.pdf#page=23)); **IMAP** mantiene el buzón en el servidor y sincroniza carpetas y estados ([pág. 7](../../assets/pdf/SRDSI_T3-4.pdf#page=7)). Para uso multidispositivo se prefiere IMAP.

## SMTP

SMTP es texto y por defecto no autentica al emisor. Comandos básicos:

```text
EHLO cliente
MAIL FROM: emisor@ejemplo.com
RCPT TO: receptor@ejemplo.com
DATA
...mensaje...
.
QUIT
```

Códigos habituales: `220` preparado, `250` OK, `354` envía el cuerpo, `421` no disponible, `5xx` error permanente.

**ESMTP** añade extensiones con `EHLO`: `STARTTLS`, `AUTH`, `SIZE`, `8BITMIME`, `PIPELINING`…

Un **open relay** acepta enviar correo a cualquier destino sin autenticar; es la base de gran parte del spam. Debe rechazarse.

## Seguridad en tránsito

- **TLS**: STARTTLS en 25/587/110/143 o TLS implícito en 465/995/993. Validar siempre el certificado y el nombre ([págs. 21 y 26](../../assets/pdf/SRDSI_T3-4.pdf#page=21)).
- **SMTP AUTH**: autenticación del usuario que envía. `PLAIN`/`LOGIN` solo sobre TLS; mejor `SCRAM-SHA-256` u OAuth.
- **MTA-STS** (RFC 8461): política publicada por HTTPS que obliga a TLS entre MTA ([pág. 36](../../assets/pdf/SRDSI_T3-4.pdf#page=36)).
- **DANE/TLSA**: vincula el certificado del servidor de correo a un registro DNS firmado con DNSSEC.
- **Certificados**: cadena válida, fechas, SAN del servidor y renovación automática.

```bash
openssl s_client -starttls smtp -crlf -connect smtp.ehu.es:25
openssl s_client -connect mailin.ehu.es:pop3s
openssl s_client -starttls pop3 -crlf -connect mailin.ehu.es:110
```

## Autenticación del dominio

| Mecanismo | Qué hace |
| --- | --- |
| **SPF** (RFC 7208) | Lista de IP/servidores autorizados a enviar por el dominio (registro `TXT`). |
| **DKIM** (RFC 6376) | Firma criptográfica del mensaje; el receptor valida con la clave publicada en DNS. |
| **DMARC** (RFC 7489) | Política sobre SPF/DKIM, alineación del dominio y reportes. |
| **ARC** (RFC 8617) | Conserva la autenticación a través de reenviadores. |
| **BIMI** | Publica la marca (logo) para remitentes autenticados. |

El detalle de SPF, DKIM y DMARC está en las [transparencias, págs. 43-53](../../assets/pdf/SRDSI_T3-4.pdf#page=43).

SPF, DKIM y DMARC se publican en **DNS**; sin DNSSEC, un atacante que controle el DNS podría alterarlos.

## Amenazas

- **Spoofing** del remitente y *phishing*.
- **Open relay** y abuso del servidor.
- **Robo de credenciales** por fuerza bruta o *credential stuffing*.
- **Inyección de cabeceras** y adjuntos maliciosos.
- **Spam y campañas masivas**; **troyanos** y *ransomware* por adjuntos.
- **Interceptación** si no hay TLS o si el cliente no valida el certificado.

## Buenas prácticas

1. TLS obligatorio en todos los puertos y versiones modernas (TLS 1.2/1.3).
2. Deshabilitar `PLAIN`/`LOGIN` sin TLS y exigir autenticación para enviar.
3. Publicar SPF, DKIM y DMARC, y revisar los reportes.
4. Limitar tamaño, adjuntos y ritmo de envío; filtros antispam y antimalware.
5. MFA en el webmail y en el acceso al buzón.
6. Registrar y monitorizar conexiones, rebotes y autenticaciones fallidas.
7. Cifrado extremo a extremo con **S/MIME** o **PGP** cuando se requiera confidencialidad.

## Relación con otras prácticas

- [Actividad de correo](../actividades/correo.md): SMTP y POP3 con `telnet`, *open relay* y STARTTLS.
- [Actividad IMAPv4](../actividades/imap.md): extensiones de seguridad y capturas de IMAPS/STARTTLS.
- [Seguridad en DNS](dns.md): `MX`, SPF, DKIM, DMARC y DNSSEC.
- [PGP y S/MIME](../../tema2/teoria/pgp-smime.md): cifrado y firma de extremo a extremo.
