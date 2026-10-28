# Alertas TLS

Una **alerta TLS** es un mensaje del protocolo que indica un cierre ordenado o un error. Wireshark la expone en el campo `tls.alert_message`; `tshark` permite filtrarla y extraer su nivel y su código.

## Cómo leer una alerta

| Campo | Significado |
| --- | --- |
| `tls.alert_message.level` | `1` = *warning* (aviso, la conexión puede continuar); `2` = *fatal* (la conexión se cierra). |
| `tls.alert_message.desc` | Código numérico de la alerta (40, 48, 70…). |
| `tls.alert_message` | Campo paraguas: sirve para filtrar cualquier alerta. |

```bash
# Todas las alertas, con nivel y código
tshark -r captura.pcapng -Y 'tls.alert_message' \
  -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc

# Solo las fatales
tshark -r captura.pcapng -Y 'tls.alert_message.level == 2'

# Un código concreto
tshark -r captura.pcapng -Y 'tls.alert_message.desc == 40'
```

```console
$ tshark -r capturas/02_cert_inexistente.pcapng -Y 'tls.alert_message' \
    -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc
6	2	40

$ tshark -r capturas/03_ca_desconocida.pcapng -Y 'tls.alert_message' \
    -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc
8	2	48
```

En la GUI, añade una columna con `tls.alert_message.desc` para localizar la alerta de un vistazo. En **TLS 1.3** la alerta viaja cifrada: sin el keylog solo se ve como *Application Data*; con el keylog, Wireshark la muestra como `Alert (Level: ..., Description: ...)`.

## Tabla de alertas

| Código | Nombre | Nivel | Causa habitual | Ejemplo en el laboratorio |
| ---: | --- | --- | --- | --- |
| 0 | `close_notify` | warning | Cierre ordenado de la conexión. | Cierre normal de `s_server`/`s_client` y de `cli-infouser`. |
| 10 | `unexpected_message` | fatal | Mensaje fuera de orden o inesperado en el handshake. | Estado TLS corrupto o `s_client` mal encadenado. |
| 20 | `bad_record_mac` | fatal | El MAC/autenticación del registro no cuadra. | Clave de sesión o keylog incorrecto al descifrar. |
| 22 | `record_overflow` | fatal | Registro mayor que el máximo permitido. | Implementación o proxy que fragmenta mal. |
| 30 | `decompression_failure` | fatal | Fallo al descomprimir (compresión TLS obsoleta). | Configuración antigua con compresión activada. |
| 40 | `handshake_failure` | fatal | No hay parámetros comunes: cifrados, versión o certificado de cliente ausente. | `02_cert_inexistente.pcapng`: el servidor no carga `s_cert.pem` y con RSA no negocia → `no shared cipher`. También al exigir cliente con `-Verify` y no presentarlo. |
| 42 | `bad_certificate` | fatal | El certificado está mal formado o su firma no verifica. | Certificado manipulado o pareja cert/clave incoherente; no aparece en las capturas del repo. |
| 43 | `unsupported_certificate` | fatal | Tipo de certificado no soportado por el receptor. | Certificado con algoritmo o formato no aceptado. |
| 44 | `certificate_revoked` | fatal | El certificado figura revocado en la CRL/OCSP. | Revocar en la subCA, regenerar la CRL y volver a conectar. |
| 45 | `certificate_expired` | fatal | Certificado fuera de su periodo de validez. | Reloj de la VM desajustado o certificado caducado. |
| 46 | `certificate_unknown` | fatal | Error de validación no clasificado (cadena, propósito, etc.). | CA correcta pero extensión `extendedKeyUsage` inadecuada. |
| 47 | `illegal_parameter` | fatal | Un campo del handshake es ilegal o incoherente. | Extensión mal formada o parámetro fuera de rango. |
| 48 | `unknown_ca` | fatal | El receptor no puede construir la cadena hasta una CA de confianza. | `03_ca_desconocida.pcapng`: el cliente confía en `c-ca_cert.pem` en vez de `s-ca_cert.pem` y responde `certificate verify failed`. |
| 49 | `access_denied` | fatal | Política de acceso deniega la conexión. | Servidor con lista blanca o autenticación externa. |
| 50 | `decode_error` | fatal | No se puede decodificar un mensaje. | Handshake truncado o bytes corruptos. |
| 51 | `decrypt_error` | fatal | Falla la verificación criptográfica del handshake. | Firma de `CertificateVerify` inválida o clave incorrecta. |
| 60 | `export_restriction` | fatal | Restricción de exportación (cifrados débiles históricos). | Configuraciones antiguas; no se usa en el laboratorio. |
| 70 | `protocol_version` | fatal | No hay versión TLS común. | Servidor `-tls1_2` y cliente `-tls1_3` (o al revés): el servidor responde 70. |
| 71 | `insufficient_security` | fatal | Los parámetros no alcanzan la seguridad mínima exigida. | Servidor que exige cifrados fuertes y cliente que solo ofrece débiles. |
| 80 | `internal_error` | fatal | Error interno del receptor, ajeno al protocolo. | Servidor sin clave privada válida, sin memoria o fallo al cargar el certificado. |
| 90 | `user_canceled` | warning | El usuario canceló el handshake. | `Ctrl-C` durante una conexión interactiva. |
| 100 | `no_renegotiation` | warning | El receptor no acepta renegociación. | Cliente que intenta renegociar con un servidor que la prohíbe. |
| 109 | `missing_extension` | fatal | Falta una extensión obligatoria. | TLS 1.3 sin `supported_versions` o sin `key_share`. |
| 110 | `unsupported_extension` | fatal | Extensión no permitida en ese mensaje. | Extensión enviada en el mensaje equivocado. |
| 112 | `unrecognized_name` | warning | El SNI no coincide con ningún nombre del servidor. | Navegador que pide `www.srdsi2.lab` contra un servidor que solo conoce `www.srdsi.lab`; no es un fallo criptográfico. |
| 113 | `bad_certificate_status_response` | fatal | Respuesta OCSP inválida o no verificable. | Respondedor OCSP con certificado incorrecto o respuesta manipulada. |
| 115 | `unknown_psk_identity` | fatal | El servidor no reconoce la identidad PSK. | Resumption/0-RTT con un ticket de otro servidor o caducado. |
| 116 | `certificate_required` | fatal | El servidor exige certificado de cliente (TLS 1.3). | Equivalente moderno del 40 cuando el cliente no presenta certificado. |
| 120 | `no_application_protocol` | fatal | ALPN sin protocolo común. | `s_server -alpn h2` y cliente que solo ofrece `http/1.1`. |

## Diagnóstico rápido

| Alerta | Primera comprobación | Comando útil |
| --- | --- | --- |
| 40 `handshake_failure` | ¿El servidor tiene certificado y clave? ¿Exige cliente? ¿Hay cifrados comunes? | `openssl x509`, `ss -tlnp`, `s_client -cert/-key` |
| 42 `bad_certificate` | ¿Certificado y clave se corresponden? ¿Está manipulado? | `openssl verify`, `openssl x509 -text` |
| 44/45 `certificate_revoked` / `expired` | CRL regenerada, fechas y reloj del sistema | `openssl crl -text`, `date -u`, `openssl x509 -dates` |
| 48 `unknown_ca` | ¿Es la CA correcta? ¿Se envía el intermedio? | `openssl verify -CAfile ... -untrusted subca.crt`, `-cert_chain` |
| 70 `protocol_version` | Versiones forzadas en cada extremo | `-tls1_2` / `-tls1_3` en servidor y cliente |
| 80 `internal_error` | Ficheros de certificado/clave y logs del servidor | `ls -l`, `openssl rsa -check`, salida de `s_server` |
| 112 `unrecognized_name` | SNI frente a los nombres del servidor | `s_client -servername ...`, `-tlsextdebug` |
| 116 `certificate_required` | Certificado de cliente en TLS 1.3 | `s_client -cert client.crt -key client.key` |
| 120 `no_application_protocol` | Listas ALPN de ambos extremos | `-alpn` en `s_server` y `s_client` |

!!! note "Alertas y versiones"
    En TLS 1.2 los mensajes de alerta suelen verse en claro; en TLS 1.3 van cifrados y necesitan el keylog. El código y el nivel son los mismos, pero sin descifrar solo verás `Application Data`. La excepción práctica es el `protocol_version` inicial, que puede aparecer antes de que se establezca el cifrado.

## Cómo reproducir las alertas del laboratorio

```bash
# 40 handshake_failure: servidor sin certificado válido / sin cifrados comunes
# (escenario 02 del lab-ssl; el servidor registra "no shared cipher")

# 48 unknown_ca: el cliente confía en la CA equivocada
# (escenario 03: se usa c-ca_cert.pem en lugar de s-ca_cert.pem)

# 70 protocol_version: versiones incompatibles
openssl s_server -accept 4433 -cert server.crt -key server.key -cert_chain subca.crt -tls1_2 -quiet -naccept 1
openssl s_client -connect 127.0.0.1:4433 -tls1_3 -CAfile /tmp/ca-chain.pem -brief

# 120 no_application_protocol: ALPN sin coincidencia
openssl s_server -accept 4433 -cert server.crt -key server.key -cert_chain subca.crt -tls1_2 -alpn h2 -www -naccept 1
openssl s_client -connect 127.0.0.1:4433 -tls1_2 -CAfile /tmp/ca-chain.pem -alpn http/1.1
```

## Enlaces

- [Wireshark y capturas](../tema2/comandos/wireshark.md)
- [Capturas y alertas del laboratorio SSL](../tema2/lab-ssl/capturas.md)
- [OpenSSL TLS/DTLS](../tema2/comandos/openssl-tls.md)
- [Ejercicios TLS y DTLS](../tema2/actividades/tls-dtls.md)
- [Antes del examen](antes-del-examen.md)
