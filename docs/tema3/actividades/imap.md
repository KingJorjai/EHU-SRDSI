# Actividad IMAPv4

Informe sobre las mejoras de seguridad de IMAPv4: extensiones, mecanismos de autenticación y establecimiento de conexiones seguras, con capturas reales de Wireshark contra el servidor de la UPV/EHU.

[:material-file-pdf-box: Informe completo (PDF)](../../assets/pdf/informe-imap.pdf){ .md-button }

!!! note "Entorno"
    Las capturas se hicieron en la VM Debian (`user1`, `10.0.2.15`) con Wireshark y `dumpcap` contra `ikasle.ehu.eus`, puertos 143 y 993. No se enviaron credenciales reales.

## Extensiones y autenticación

IMAP4rev1 (RFC 3501) no incluía cifrado ni autenticación fuerte. Las mejoras se apoyan en **SASL** y **TLS**:

| Elemento | Función |
| --- | --- |
| `STARTTLS` | Pasa de texto claro a TLS en el puerto 143. |
| `LOGINDISABLED` | El servidor rechaza `LOGIN` mientras no haya TLS. |
| `SASL-IR` | Envía la respuesta inicial SASL en el mismo comando. |
| `AUTHENTICATE` / `AUTH=` | Negocia mecanismos SASL: `PLAIN`, `CRAM-MD5`, `SCRAM-SHA-256`, OAuth… |
| IMAP4rev2 (RFC 9051) | Recomienda TLS 1.2+ y penaliza la autenticación en claro. |

## Modos de conexión

| Modo | Puerto | Cuándo se cifra |
| --- | --- | --- |
| IMAPS (TLS implícito) | 993 | Desde el primer byte. |
| IMAP + STARTTLS | 143 | Tras el saludo y el comando `STARTTLS`. |

## Capturas

**IMAPS (993)**: TLS 1.3 desde el inicio, con SNI y certificado `*.ehu.eus`.

![IMAPS contra ikasle.ehu.eus](../../assets/img/lab-imap/01-imaps-993.png)

**IMAP en claro (143)**: el servidor anuncia `LOGINDISABLED` y responde `NO [PRIVACYREQUIRED]` al intentar `LOGIN`.

![IMAP en claro con LOGINDISABLED](../../assets/img/lab-imap/02-143-claro.png)

**STARTTLS (143)**: primero el saludo y `CAPABILITY` en claro; después el handshake TLS 1.3.

![STARTTLS contra ikasle.ehu.eus](../../assets/img/lab-imap/03-starttls.png)

## Conclusiones

- **IMAPS (993)** evita cualquier tramo en claro.
- **STARTTLS (143)** cifra tras el saludo, pero el tramo inicial es manipulable: hay que exigir TLS y validar el certificado.
- **LOGINDISABLED** bloquea la autenticación insegura, pero no sustituye al cifrado.
- La autenticación debe combinar **TLS + SASL** y no confiar en el `CAPABILITY` previo a TLS.

## Teoría relacionada

- [Correo electrónico](../teoria/correo.md): SMTP, POP3, IMAP y SPF/DKIM/DMARC.
- [Actividad de correo](correo.md): SMTP y POP3 con `telnet`.
