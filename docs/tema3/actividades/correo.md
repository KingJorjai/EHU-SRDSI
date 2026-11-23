# Actividad de correo (SMTP y POP3)

Práctica de protocolos de correo: sesión manual con `telnet`, comprobación de *open relay* y extensiones ESMTP, conexión segura con STARTTLS/POP3S y análisis del tráfico con Wireshark.

[:material-file-pdf-box: Enunciado de la actividad (PDF)](../../assets/pdf/actividad-correo.pdf){ .md-button }

!!! warning "Requiere la VM"
    La actividad se ejecuta desde la VM Debian (`user1`). Los pasos que dependen de ella están marcados como **VM**. Las capturas de SMTP sí están incluidas. POP3 no está disponible en `mailin.ehu.es` (110/995), ni siquiera por la VPN; IMAP sí (143/993) y está en la [actividad IMAPv4](imap.md).

## 1. SMTP manual con `telnet`

**VM**. Obtén los servidores de correo del dominio y conecta al puerto 25:

```bash
dig nombre-dominio MX
telnet smtp.ehu.es 25
```

Comandos básicos:

```text
EHLO nombre
MAIL FROM: emisor@ejemplo.com
RCPT TO: receptor@ejemplo.com
DATA
Asunto: prueba

Hola.
.
QUIT
```

Respuestas habituales:

| Código | Significado |
| --- | --- |
| `220` | Servicio preparado. |
| `221` | Servicio cerrando el canal. |
| `250` | Solicitud completada con éxito. |
| `251` | Usuario no local; se reenviará. |
| `354` | Introduce el texto; termina con `.` en una línea. |
| `421` | Servicio no disponible. |

## 2. POP3 manual con `telnet`

**VM**.

```bash
telnet mailin.ehu.es 110
```

```text
USER usuario
PASS contraseña
LIST
RETR 1
DELE 1
QUIT
```

Respuestas: `+OK` (éxito) y `-ERR` (error).

## 3. Comprobar seguridad del servidor SMTP

**VM**.

1. **Open relay**: intenta enviar correo a un dominio externo sin autenticarte. Un servidor seguro debe rechazarlo.
2. **Extensiones ESMTP**: empieza con `EHLO` y revisa la lista (`STARTTLS`, `AUTH`, `SIZE`, `8BITMIME`…).
3. **Conexión segura con STARTTLS**:

```bash
openssl s_client -starttls smtp -crlf -connect smtp.ehu.es:25 \
  -keylogfile mailkeylog.log
```

El `-keylogfile` permite descifrar el tráfico en Wireshark si hiciera falta.

4. **Cabeceras**: revisa los campos `Received`, `Return-Path`, `Authentication-Results` y las trazas de SMTP.

## 4. Comprobar seguridad del servidor POP3

**VM**.

```bash
# POP3S: TLS implícito
openssl s_client -connect mailin.ehu.es:pop3s

# POP3 + STLS: STARTTLS en el puerto 110
openssl s_client -starttls pop3 -crlf -connect mailin.ehu.es:110
```

Comprueba qué mecanismos de autenticación anuncia el servidor y si acepta `USER`/`PASS` solo tras TLS.

## 5. Capturas con Wireshark

**VM**. Captura el tráfico mientras repites las sesiones:

```bash
sudo dumpcap -i any -f "tcp port 25 or tcp port 110 or tcp port 465 or tcp port 995" -w correo.pcapng
```

Diferencias que debes observar:

- **SMTP/POP3 en claro**: usuario, contraseña y contenido del mensaje son legibles.
- **STARTTLS**: el saludo y los comandos iniciales van en claro; tras el `OK` empieza TLS.
- **SMTPS/POP3S**: TLS desde el primer byte; solo se ven metadatos TCP y tráfico cifrado.

## 6. Resultados en la VM

Ejecutado desde `bocata-jamon`:

| Prueba | Resultado |
| --- | --- |
| SMTP 25 | `220 smtp-1 ESMTP Postfix`; `EHLO` anuncia `PIPELINING`, `SIZE`, `VRFY`, `ETRN`, `STARTTLS`, `8BITMIME`, `DSN` y `CHUNKING` |
| STARTTLS SMTP | `220 2.0.0 Ready to start TLS`; TLS 1.3 con `TLS_AES_256_GCM_SHA384`; certificado `CN=*.ehu.eus`; `Verification: OK` |
| POP3 110/995 | **No disponible** en `mailin.ehu.es` ni desde la VPN; 143/993 sí responden |

![SMTP: saludo y EHLO en claro](../../assets/capturas/lab-correo/01-wireshark-smtp.png)

![SMTP: STARTTLS y handshake TLS 1.3](../../assets/capturas/lab-correo/02-wireshark-smtp-starttls.png)

- [Salida SMTP](../../assets/resultados/correo/smtp.txt)
- [Salida STARTTLS](../../assets/resultados/correo/smtp-starttls.txt)
- [Prueba POP3 por VPN](../../assets/resultados/correo/pop3-vpn.txt)
- Script: [`probe_smtp.py`](../../assets/codigo/lab-correo/probe_smtp.py)

!!! note "POP3"
    Probado también con la VPN de la UPV/EHU (`tun0`): `mailin.ehu.es` e `ikasle.ehu.eus` no responden en 110 ni 995, mientras que 143/993 sí. El servidor solo publica IMAP; el guion de POP3 queda documentado, pero no ejecutado.

## Teoría relacionada

- [Correo electrónico](../teoria/correo.md): SMTP, POP3, IMAP, autenticación y SPF/DKIM/DMARC.
- [Actividad IMAPv4](imap.md): extensiones de seguridad y capturas de IMAPS/STARTTLS.
