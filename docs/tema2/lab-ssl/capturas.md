# Capturas y alertas TLS

Análisis de las tres capturas del laboratorio. El tráfico se tomó en la interfaz de *loopback* con `dumpcap -i lo`; el análisis textual se generó con `tshark`. Para la sintaxis de las herramientas y de los filtros, consulta [Wireshark y capturas](../comandos/wireshark.md).

| Escenario | Captura | Keylog | Análisis textual | Figura |
| --- | --- | --- | --- | --- |
| Handshake correcto | [01_ok.pcapng](../../assets/capturas/lab-ssl/01_ok.pcapng) | [01_ok.keylog](../../assets/capturas/lab-ssl/01_ok.keylog) | [01_ok.tshark.txt](../../assets/capturas/lab-ssl/01_ok.tshark.txt) | [01_ok.png](../../assets/capturas/lab-ssl/01_ok.png) |
| Certificado inexistente | [02_cert_inexistente.pcapng](../../assets/capturas/lab-ssl/02_cert_inexistente.pcapng) | — | [02_cert_inexistente.tshark.txt](../../assets/capturas/lab-ssl/02_cert_inexistente.tshark.txt) | [02_cert_inexistente.png](../../assets/capturas/lab-ssl/02_cert_inexistente.png) |
| CA desconocida | [03_ca_desconocida.pcapng](../../assets/capturas/lab-ssl/03_ca_desconocida.pcapng) | — | [03_ca_desconocida.tshark.txt](../../assets/capturas/lab-ssl/03_ca_desconocida.tshark.txt) | [03_ca_desconocida.png](../../assets/capturas/lab-ssl/03_ca_desconocida.png) |

Los tres escenarios usan el puerto 1064. En las capturas, el cliente ocupa un puerto efímero y el servidor el 1064.

## 1. Handshake correcto

El flujo TLS de `01_ok.pcapng`, una vez cargado `01_ok.keylog`, es:

```console
4   TLSv1    Client Hello
6   TLSv1.2  Server Hello, Certificate, Server Hello Done
8   TLSv1.2  Client Key Exchange, Change Cipher Spec, Finished
9   TLSv1.2  New Session Ticket, Change Cipher Spec, Finished
10  TLSv1.2  Application Data, Application Data, Alert (Close Notify)
11  TLSv1.2  Alert (Level: Warning, Description: Close Notify)
```

1. **Client Hello** (frame 4): el cliente anuncia TLS 1.2 y los cifrados fijados (`AES128-SHA256`, `AES256-CCM`, `AES256-GCM-SHA384`).
2. **Server Hello, Certificate, Server Hello Done** (frame 6): el servidor elige TLS 1.2 y uno de los cifrados, presenta su certificado (`SERV-SRDSI`, firmado por `CA_SERV-SRDSI`) y termina su parte del saludo.
3. **Client Key Exchange, Change Cipher Spec, Finished** (frame 8): el cliente envía el secreto de sesión cifrado con la clave pública RSA del servidor, cambia a cifrado y se autentica.
4. **New Session Ticket, Change Cipher Spec, Finished** (frame 9): el servidor confirma el cambio de cifrado y el handshake.
5. **Application Data** (frame 10): viaja la cabecera `OK:221` y el listado de `w`, ya cifrados.

El análisis textual marca `frame 10	6,221`: en el frame 10 hay un registro de 6 bytes (la cabecera) y otro de 221 bytes (el fichero). Con el *keylog* cargado, Wireshark descifra ambos.

![Handshake correcto. Con el keylog cargado se ve la capa TLS descifrada y, al elegir «Decrypted TLS» en el panel de bytes, el contenido en claro.](../../assets/capturas/lab-ssl/01_ok.png)

El contenido descifrado se puede volcar con *Follow → TLS Stream* o con `tshark -z follow,tls,ascii,0`:

```console
$ tshark -r 01_ok.pcapng -o tls.keylog_file:01_ok.keylog -q -z follow,tls,ascii,0
Filter: tls.stream eq 0
Node 0: 127.0.0.1:33526
Node 1: 127.0.0.1:1064
        6
OK:221
        221
 17:18:43 up 0 min,  1 user,  load average: 0,78, 0,19, 0,06
USUARIO  TTY      DESDE            LOGIN@   IDLE   JCPU   PCPU  WHAT
user1             192.168.56.1     17:18           0.00s  0.01s sshd-session: user1 [priv]
```

Se reconocen la cabecera del protocolo de aplicación (`OK:221`) y la salida de `w`. El tamaño puede variar entre ejecuciones porque depende de las sesiones abiertas en la VM.

## 2. Certificado inexistente: `handshake_failure` (40)

Al renombrar `certificados/s_cert.pem`, el servidor no dispone de certificado. El cliente solo ofrece cifrados con intercambio de clave RSA, que necesitan la clave pública del certificado del servidor, así que no hay ningún cifrado negociable. La captura muestra:

```console
4   TLSv1    Client Hello
6   TLSv1.2  Alert (Level: Fatal, Description: Handshake Failure)
```

- La alerta la genera el **servidor** en respuesta al `Client Hello`.
- Código 40, nivel fatal: el servidor cierra la conexión sin completar el handshake.
- En el servidor aparece `no shared cipher`; en el cliente, `ssl/tls alert handshake failure: SSL alert number 40`.
- No hay `Application Data` ni datos descifrados.

![Certificado inexistente; el servidor responde Handshake Failure (40).](../../assets/capturas/lab-ssl/02_cert_inexistente.png)

## 3. CA desconocida: `unknown_ca` (48)

Si el cliente confía en `certificados/c-ca_cert.pem` (`CA_CLI-SRDSI`) en lugar de en `s-ca_cert.pem` (`CA_SERV-SRDSI`), el servidor sí presenta su certificado, pero el cliente no puede construir una cadena de confianza hasta una CA conocida. La captura muestra:

```console
4   TLSv1    Client Hello
6   TLSv1.2  Server Hello, Certificate, Server Hello Done
8   TLSv1.2  Alert (Level: Fatal, Description: Unknown CA)
```

- La alerta la genera el **cliente**, después de recibir el `Certificate` del servidor.
- Código 48, nivel fatal: el cliente aborta porque la CA que firma el certificado no está en su almacén de confianza.
- El cliente registra `certificate verify failed`; el servidor recibe `tlsv1 alert unknown ca: SSL alert number 48`.
- Tampoco hay `Application Data`.

![CA desconocida; el cliente responde Unknown CA (48).](../../assets/capturas/lab-ssl/03_ca_desconocida.png)

La diferencia entre ambos errores es el punto en que se rompe el handshake:

| Situación | Frame de la alerta | Origen | Alerta |
| --- | --- | --- | --- |
| Certificado inexistente | 6, tras el `Client Hello` | Servidor | `handshake_failure` (40, fatal) |
| CA desconocida | 8, tras el `Certificate` | Cliente | `unknown_ca` (48, fatal) |

## 4. Reproducir el análisis con `tshark`

Los comandos siguientes se ejecutan **desde la raíz del repositorio**; `CAP` apunta a las capturas del sitio:

```bash
CAP=docs/assets/capturas/lab-ssl

# Listado TLS del escenario correcto, descifrado con el keylog
tshark -r "$CAP/01_ok.pcapng" \
  -o "tls.keylog_file:$CAP/01_ok.keylog" -Y tls

# Contenido descifrado del flujo TLS
tshark -r "$CAP/01_ok.pcapng" \
  -o "tls.keylog_file:$CAP/01_ok.keylog" \
  -q -z follow,tls,ascii,0

# Solo alertas
tshark -r "$CAP/01_ok.pcapng" -o "tls.keylog_file:$CAP/01_ok.keylog" \
  -Y tls.alert_message
tshark -r "$CAP/02_cert_inexistente.pcapng" -Y tls.alert_message
tshark -r "$CAP/03_ca_desconocida.pcapng" -Y tls.alert_message

# Datos de aplicación descifrados (content type 23)
tshark -r "$CAP/01_ok.pcapng" \
  -o "tls.keylog_file:$CAP/01_ok.keylog" \
  -Y "tls.record.content_type == 23" \
  -T fields -e frame.number -e tcp.len
```

Puntos clave:

- `-o tls.keylog_file:<fichero>` carga los secretos TLS sin pasar por la interfaz gráfica.
- `-Y tls` filtra los paquetes del protocolo TLS; `-Y tls.alert_message` deja solo las alertas.
- `follow,tls,ascii,0` reconstruye el flujo TLS descifrado en ASCII. El `0` es el número de flujo; se puede obtener con `-z follow,tls,ascii,0` o desde *Follow → TLS Stream*.
- Sin el *keylog* correcto, los registros de aplicación aparecen como `Application Data` cifrado y no se puede leer la salida de `w`.

En Wireshark, el equivalente es *Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log filename* y, después, seleccionar un registro de *Application Data* y elegir **Decrypted TLS** en el panel de bytes. El descifrado solo funciona porque el cliente fija TLS 1.2.
