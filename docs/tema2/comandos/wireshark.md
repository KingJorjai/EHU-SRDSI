# Wireshark, dumpcap y tshark

`dumpcap` captura, Wireshark analiza con interfaz gráfica y `tshark` hace el mismo análisis en línea de comandos. En el laboratorio SSL se usan para ver el handshake TLS, localizar alertas y descifrar el tráfico con el *keylog* del cliente.

[:material-file-pdf-box: Transparencias — TLS, DTLS y QUIC (PDF)](../../assets/pdf/SRDSI_T2-3.pdf){ .md-button }

!!! note "Versiones y permisos"
    Comprobado con **Wireshark/tshark/dumpcap 4.7.4** en el host. `dumpcap` tiene capacidades `cap_net_admin,cap_net_raw` y el usuario pertenece al grupo `wireshark`, así que captura sin `sudo`. En la VM del laboratorio también están instalados `dumpcap`, `tshark` y `wireshark`; los comandos de captura en `lo` se ejecutan allí.

## Permisos para capturar

Comprobar el grupo y las capacidades:

```bash
id
getent group wireshark
getcap "$(command -v dumpcap)"
ls -l /usr/bin/dumpcap
```

```console
uid=1000(jorjai) gid=1000(jorjai) groups=...,150(wireshark),...
/usr/bin/dumpcap cap_dac_override,cap_net_admin,cap_net_raw=eip
-rwxr-xr-- 1 root wireshark ... /usr/bin/dumpcap
```

Si tu usuario no está en el grupo:

```bash
sudo usermod -aG wireshark "$USER"
newgrp wireshark        # o cierra sesión y vuelve a entrar
```

Alternativa en Debian/Ubuntu al instalar Wireshark:

```bash
sudo dpkg-reconfigure wireshark-common   # responder "Sí"
```

Capturar con `sudo` funciona, pero crea ficheros propiedad de root y mezcla privilegios; es preferible el grupo `wireshark`. No ejecutes Wireshark completo como root.

## Capturar con `dumpcap`

Listar interfaces y capturar en loopback:

```bash
dumpcap -D
dumpcap -i lo -w captura.pcapng
```

Parar con `Ctrl-C`. Al terminar, `dumpcap` muestra el recuento de paquetes capturados y descartados. Opciones útiles:

```bash
dumpcap -i lo -w captura.pcapng -a duration:30
dumpcap -i lo -w captura.pcapng -c 500
dumpcap -i lo -w captura.pcapng -f 'tcp port 1064'
dumpcap -i any -w captura.pcapng
```

- `-i lo` captura el tráfico de loopback (cliente y servidor en la misma máquina).
- `-a duration:30` limita la captura a 30 segundos; también existe `-a filesize:`, `-a files:`.
- `-c 500` se detiene tras 500 paquetes.
- `-f` es un **filtro de captura** (sintaxis BPF), distinto de los filtros de visualización de Wireshark.
- `-i any` captura en todas las interfaces en Linux; puede duplicar paquetes y no siempre conserva el enlace.

Para el laboratorio SSL, el orden habitual es: arrancar `dumpcap` en una terminal, ejecutar cliente y servidor en otras, y parar con `Ctrl-C`.

## `tshark` básico

```bash
tshark -D                                  # interfaces
tshark -i lo                               # captura en vivo
tshark -r captura.pcapng                   # lee un fichero
tshark -r captura.pcapng -c 10             # primeras 10 tramas
tshark -r captura.pcapng -Y 'tls'          # filtro de visualización
tshark -r captura.pcapng -V -Y 'frame.number == 6'
tshark -r captura.pcapng -T fields -e frame.number -e _ws.col.Info
```

- `-r` lee un `.pcap`/`.pcapng`; `-i` captura en vivo.
- `-Y` aplica un filtro de visualización (el mismo lenguaje que Wireshark).
- `-f` aplica un filtro de captura (BPF) solo al capturar.
- `-V` muestra el árbol de protocolos completo de cada paquete.
- `-T fields -e campo` extrae campos concretos; es ideal para tablas.
- `-q` reduce la salida y se combina con `-z` para estadísticas.

Listar campos TLS disponibles:

```bash
tshark -G fields | awk -F'\t' '$3 ~ /^tls\./' | head -30
```

## Filtros útiles

| Filtro | Efecto |
| --- | --- |
| `tls` | Todo el tráfico TLS/SSL reconocido. |
| `tls.alert_message` | Mensajes de alerta TLS. |
| `tls.alert_message.desc == 40` | `handshake_failure`. |
| `tls.alert_message.desc == 48` | `unknown_ca`. |
| `tls.handshake.type == 1` | `ClientHello`. |
| `tls.handshake.type == 2` | `ServerHello`. |
| `tls.handshake.type == 11` | `Certificate`. |
| `tls.handshake.type == 16` | `ClientKeyExchange`. |
| `tcp.port == 1064` | Puerto de la aplicación `cli-infouser`/`serv-infouser`. |
| `tcp.stream eq 0` | Primer flujo TCP de la captura. |
| `ip.addr == 127.0.0.1` | Tráfico de loopback. |
| `udp.port == 4434` | DTLS en un puerto concreto. |

Ejemplos:

```bash
tshark -r captura.pcapng -Y 'tls.alert_message' \
  -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc

tshark -r captura.pcapng -Y 'tls.handshake.type == 1 || tls.handshake.type == 2' \
  -T fields -e frame.number -e _ws.col.Info

tshark -r captura.pcapng -Y 'tcp.port == 1064' \
  -T fields -e frame.number -e tcp.srcport -e tcp.dstport -e _ws.col.Info
```

En las capturas del repositorio:

```console
$ tshark -r capturas/02_cert_inexistente.pcapng -Y 'tls.alert_message' \
    -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc
6	2	40

$ tshark -r capturas/03_ca_desconocida.pcapng -Y 'tls.alert_message' \
    -T fields -e frame.number -e tls.alert_message.level -e tls.alert_message.desc
8	2	48
```

`level=2` es **fatal**; `desc=40` es `handshake_failure` y `desc=48` es `unknown_ca`.

## Descifrado TLS con keylog

### En Wireshark (GUI)

1. Genera el keylog al ejecutar el cliente:

   ```bash
   openssl s_client -connect 127.0.0.1:4433 -tls1_2 \
     -CAfile /tmp/ca-chain.pem -keylogfile /tmp/keys.log
   ```

   En el laboratorio SSL, el cliente C ya escribe `keylog-ssl.log` mediante `SSL_CTX_set_keylog_callback`.

2. Abre la captura en Wireshark.
3. `Edit → Preferences → Protocols → TLS`.
4. En **(Pre)-Master-Secret log filename**, selecciona `/tmp/keys.log` o `capturas/01_ok.keylog`.
5. Acepta y vuelve a cargar la captura si es necesario.

Con el keylog cargado, las tramas `Application Data` se descifran y aparece la pestaña **Decrypted TLS** en el panel de bytes.

### Con `tshark`

```bash
tshark -r capturas/01_ok.pcapng \
  -o tls.keylog_file:capturas/01_ok.keylog \
  -Y 'tls' -T fields -e frame.number -e _ws.col.Info
```

```console
4	Client Hello
6	Server Hello, Certificate, Server Hello Done
8	Client Key Exchange, Change Cipher Spec, Encrypted Handshake Message
9	New Session Ticket, Change Cipher Spec, Encrypted Handshake Message
10	Application Data, Application Data, Encrypted Alert
11	Encrypted Alert
```

Seguir el flujo TLS descifrado:

```bash
tshark -r capturas/01_ok.pcapng \
  -o tls.keylog_file:capturas/01_ok.keylog \
  -q -z follow,tls,ascii,0
```

```console
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

Se reconocen la cabecera de la aplicación (`OK:<tamaño>`) y la salida de `w`. El descifrado funciona porque el cliente fija **TLS 1.2** y exporta el secreto maestro; las capturas del laboratorio son TLS 1.2.

!!! warning "TLS 1.3"
    Wireshark también descifra TLS 1.3 con keylog, pero el laboratorio fija TLS 1.2 (`SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION)`) para que el material sea reproducible. El keylog de TLS 1.3 contiene secretos distintos y no sirve para una captura TLS 1.2, ni al revés.

### `SSLKEYLOGFILE` para navegadores

Muchos programas respetan la variable de entorno:

```bash
export SSLKEYLOGFILE="$HOME/sslkeys.log"
```

Al reiniciar el navegador desde esa shell, escribe los secretos en el fichero. No dejes esa variable activa en un entorno real: cualquiera que lea el fichero puede descifrar tus sesiones.

## `Follow → TLS Stream`

En Wireshark:

1. Selecciona una trama TLS.
2. `Analyze → Follow → TLS Stream` (o clic derecho → `Follow → TLS Stream`).
3. Elige la dirección y el formato (`ASCII`, `Raw`, `Hex Dump`).

En `tshark`, el equivalente es `-z follow,tls,ascii,0` o `-z follow,tls,raw,0`. El último número es el índice del flujo (`tls.stream`), no el número de paquete.

Si Wireshark muestra el protocolo como `PUSH` o no reconoce TLS:

- Clic derecho en la trama → `Decode As...` → `Transport` → `TLS`.
- O `Analyze → Decode As` y añade una regla para el puerto (por ejemplo, 1064).

Esto es habitual cuando se usa un puerto no estándar o cuando la captura empieza a mitad de conexión.

## Columnas útiles

En Wireshark, clic derecho en una columna → `Column Preferences`:

| Columna | Campo | Para qué |
| --- | --- | --- |
| `No.` | `frame.number` | Referencia de trama. |
| `Time` | `frame.time_relative` | Cronología del handshake. |
| `Source` / `Destination` | `ip.src` / `ip.dst` | Sentido del tráfico. |
| `Protocol` | `_ws.col.Protocol` | TLS, TCP, DTLS. |
| `Info` | `_ws.col.Info` | Resumen del mensaje. |
| `TLS Alert` | `tls.alert_message.desc` | Código de alerta (40, 48…). |
| `TLS Stream` | `tls.stream` | Flujo al que pertenece. |

Añadir una columna con `tls.alert_message.desc` permite localizar de un vistazo la alerta fatal. En `tshark`, el equivalente es `-e tls.alert_message.desc`.

## Alertas del laboratorio SSL

| Escenario | Origen | Alerta | Trama (captura del repo) |
| --- | --- | --- | --- |
| Handshake correcto | — | Ninguna | `01_ok.pcapng` |
| Certificado inexistente | servidor | `handshake_failure` (40, fatal) | `02_cert_inexistente.pcapng`, trama 6 |
| CA desconocida | cliente | `unknown_ca` (48, fatal) | `03_ca_desconocida.pcapng`, trama 8 |

Por qué ocurre:

- **Certificado inexistente**: el servidor no carga `s_cert.pem`; con los cifrados fijados por el cliente (intercambio RSA) no puede negociar y responde `handshake_failure` al `ClientHello`. El servidor registra `no shared cipher`.
- **CA desconocida**: el cliente confía en `c-ca_cert.pem` en vez de `s-ca_cert.pem`. El handshake llega al `Certificate` del servidor, pero el cliente no puede construir la cadena y envía `unknown_ca`. El cliente registra `certificate verify failed`.

## MACsec (802.1AE)

MACsec no es TLS: se analiza en el nivel de enlace. En Wireshark aparece como **MACSEC**, con EtherType `0x88e5`.

| Qué buscar | Campo / filtro | Nota |
| --- | --- | --- |
| Tramas MACsec | `eth.type == 0x88e5` o `macsec` | Protocolo `MACSEC` |
| SecTAG | `macsec.TCI`, `macsec.AN`, `macsec.SL` | Cabecera 802.1AE |
| Cifrado | `macsec.TCI.E == 1` | Bit E |
| Texto cambiado | `macsec.TCI.C == 1` | Bit C |
| SCI | `macsec.SCI` | MAC + puerto |
| PN | `macsec.PN` | Packet number |
| ICV | `macsec.ICV` | 16 bytes |
| EtherType interior | `macsec.etype` | Solo con `encrypt off` |
| Verificación | `macsec.verify_info.verified == 0` | `False` sin SAK |
| ARP | `arp` | Red no protegida o interior con `encrypt off` |
| MKA/EAPOL | `eapol` | Vacío con claves manuales |

Columnas útiles: `macsec.SCI`, `macsec.PN`, `macsec.TCI.E`, `macsec.AN` y `macsec.ICV`.

Valores observados en el laboratorio:

- `encrypt on`: TCI `0x0b` (`SC,E,C`), payload `Data`, ICV distinto en cada trama.
- `encrypt off`: TCI `0x08` (`SC`), Wireshark ve `ICMP`/`ICMPv6` y `macsec.etype`.
- `macsec.verify_info.verified = False` porque Wireshark no tiene la SAK; no significa que MACsec falle.
- No hay MKA/EAPOL si se usan claves manuales; la preferencia `macsec.mka` solo sirve si hay SAK distribuidas por MKA.

Para verlo con capturas reales: [Actividad MACsec](../actividades/macsec.md).

## Capturas GUI sin abrir ventanas (VM)

El script `ws_shot.sh` del laboratorio usa un display virtual dentro de la VM (`Xvfb :99`, `openbox`, `scrot`) para hacer capturas de Wireshark sin abrir ninguna ventana en el host. No es necesario para el análisis con `tshark`, pero permite generar las figuras del informe de forma reproducible.

## Problemas frecuentes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `dumpcap: Permission denied` | Usuario fuera del grupo `wireshark` o sin capacidades. | `usermod -aG wireshark`, re-login, `getcap`. |
| `No interfaces found` | `dumpcap` sin permisos o contenedor sin `NET_RAW`. | Ejecuta en la VM o revisa capacidades. |
| El tráfico no se descifra | Keylog de otra sesión, TLS 1.3 vs 1.2 o clave incorrecta. | Usa el keylog de esa captura y la misma versión TLS. |
| `Follow` no muestra texto | Flujo equivocado o tráfico no descifrado. | Prueba otro `tls.stream` y carga el keylog. |
| El protocolo aparece como `PUSH` | Puerto no estándar. | `Decode As → Transport → TLS`. |
| Captura vacía en `lo` | Cliente/servidor usan otra interfaz o no hubo tráfico. | Comprueba `-i lo` y que el puerto sea el correcto. |

## Enlaces

- [OpenSSL TLS/DTLS](openssl-tls.md)
- [TLS, DTLS y QUIC (teoría)](../teoria/tls-dtls.md)
- [SSH y túneles](ssh.md)
- [Actividad MACsec](../actividades/macsec.md)
- [Nivel de enlace (teoría)](../teoria/nivel-enlace.md)
- [Transparencias — TLS, DTLS y QUIC](../../assets/pdf/SRDSI_T2-3.pdf)
- [Transparencias — Nivel de enlace](../../assets/pdf/SRDSI_T2-5.pdf)
