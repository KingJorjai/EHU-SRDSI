# Actividad MACsec

Práctica de **MACsec (IEEE 802.1AE)** con dos máquinas virtuales Debian 13 conectadas por una red L2 de VirtualBox. El objetivo es proteger el enlace, verificar la conectividad y comparar el tráfico con cifrado activado y desactivado.

[:material-file-pdf-box: Enunciado y comandos (PDF)](../../assets/pdf/lab-macsec-comandos.pdf){ .md-button }
[:material-file-pdf-box: Informe completo (PDF)](../../assets/pdf/informe-macsec.pdf){ .md-button }

!!! warning "Requiere dos VM"
    La actividad necesita dos máquinas con una interfaz L2 común. En este repositorio se usaron `MV1` (`bocata-jamon`) y `MV2` (`bocata-jamon2`) sobre la NAT Network `macsecnet`. Los pasos que dependen de la VM están marcados como **VM**.

## Topología

| VM | `enp0s8` host-only | `enp0s9` NAT Network | MACsec |
| --- | --- | --- | --- |
| MV1 | 192.168.56.110/24 | 10.0.3.11/24 | `macsec0` 1.1.1.1/24 |
| MV2 | 192.168.56.111/24 | 10.0.3.12/24 | `macsec1` 1.1.1.2/24 |

La host-only se usa para administrar las VM desde el anfitrión. La NAT Network `macsecnet` (10.0.3.0/24) es la red L2 por la que viajan las tramas MACsec. La VM2 se clonó de la VM1: hubo que regenerar sus MAC y cambiar su IP host-only para evitar conflictos.

![Topología MACsec](../../assets/img/lab-macsec/topologia.png)

## Preparar las interfaces

En ambas VM (**VM**):

```bash
sudo ip link set enp0s9 up
sudo ip addr add 10.0.3.11/24 dev enp0s9   # MV1
sudo ip addr add 10.0.3.12/24 dev enp0s9   # MV2
```

Comprueba que se ven antes de MACsec:

```bash
ping -c 3 10.0.3.12   # desde MV1
ping -c 3 10.0.3.11   # desde MV2
```

## Crear las interfaces MACsec

Carga el módulo y mira la sintaxis:

```bash
sudo modprobe macsec
lsmod | grep macsec
ip macsec help
```

### MV1

```bash
sudo ip link add link enp0s9 macsec0 type macsec encrypt on
sudo ip macsec add macsec0 tx sa 0 pn 100 on key 01 11111111111111111111111111111111
sudo ip macsec add macsec0 rx address 08:00:27:d1:03:ae port 1
sudo ip macsec add macsec0 rx address 08:00:27:d1:03:ae port 1 \
  sa 0 pn 100 on key 02 22222222222222222222222222222222
sudo ip link set dev macsec0 up
sudo ip addr add 1.1.1.1/24 dev macsec0
```

### MV2

```bash
sudo ip link add link enp0s9 macsec1 type macsec encrypt on
sudo ip macsec add macsec1 tx sa 0 pn 100 on key 02 22222222222222222222222222222222
sudo ip macsec add macsec1 rx address 08:00:27:17:ce:47 port 1
sudo ip macsec add macsec1 rx address 08:00:27:17:ce:47 port 1 \
  sa 0 pn 100 on key 01 11111111111111111111111111111111
sudo ip link set dev macsec1 up
sudo ip addr add 1.1.1.2/24 dev macsec1
```

!!! note "Claves y direcciones"
    `01` y `02` son identificadores de clave; la clave completa es la cadena hexadecimal de 32 caracteres. Cada extremo usa `01` para transmitir y `02` para recibir, y el otro extremo lo inverso. La MAC del otro extremo es la de su `enp0s9`.

## Verificar

```bash
ip macsec show
ping -c 4 1.1.1.2   # desde MV1
ping -c 4 1.1.1.1   # desde MV2
```

![Estado de MACsec en MV1](../../assets/img/lab-macsec/ip-macsec-mv1.png)

![Estado de MACsec en MV2](../../assets/img/lab-macsec/ip-macsec-mv2.png)

`ip macsec show` muestra el cifrado (`GCM-AES-128`), el ICV, el SCI de transmisión/recepción, el PN y el estado de la SA. La clave no se imprime completa: solo se ve el ID seguido de ceros. `offload: off` indica cifrado software.

## Capturar el tráfico

Con `dumpcap` en MV1 (**VM**):

```bash
sudo dumpcap -i enp0s9 -w macsec-on.pcapng -a duration:6
```

Mientras captura, haz `ping` por `macsec0`. Analiza en el anfitrión:

```bash
tshark -r macsec-on.pcapng -T fields \
  -e frame.number -e eth.src -e eth.dst -e eth.type -e _ws.col.Protocol -e _ws.col.Info
```

Resultado esperado: EtherType `0x88e5`, protocolo `MACSEC`, cabecera **802.1AE Security tag** e **ICV**. Con `encrypt on`, el payload aparece como `Data` (cifrado) y Wireshark marca las tramas como `[UNVERIFIED]` porque no tiene la SAK.

![Wireshark con MACsec y cifrado activo](../../assets/img/lab-macsec/wireshark-macsec-on.png)

## Comparar con `encrypt off`

En ambas VM:

```bash
sudo ip link set macsec0 type macsec encrypt off   # MV1
sudo ip link set macsec1 type macsec encrypt off   # MV2
```

Repite el `ping` y la captura. Ahora Wireshark puede leer el paquete interior: verás `ICMP`/`ICMPv6` dentro de la trama MACsec. La integridad y la autenticación siguen activas, pero **la confidencialidad desaparece**.

![Wireshark con MACsec y cifrado desactivado](../../assets/img/lab-macsec/wireshark-macsec-off.png)

| Prueba | `encrypt on` | `encrypt off` |
| --- | --- | --- |
| EtherType | `0x88e5` | `0x88e5` |
| Cabecera MACsec | Sí | Sí |
| Payload visible | No (`Data`) | Sí (ICMP/ICMPv6) |
| Confidencialidad | Sí | No |
| Integridad/autenticación | Sí | Sí |

## Problemas típicos

- **Misma MAC/IP en la VM clonada**: regenera las MAC y cambia la IP host-only de la VM2; si no, las dos VM chocan.
- **Usar `enp0s3`**: en este entorno es la NAT (10.0.2.15) y no conecta las dos VM. Usa la interfaz de la red L2 (`enp0s9` en la NAT Network o la Internal Network).
- **NAT Network y EtherType no IP**: en esta prueba funcionó; si tu versión de VirtualBox no reenvía `0x88e5`, cambia el adaptador a **Internal Network**.
- **`tcpdump` no instalado**: `dumpcap` viene con Wireshark; analiza el `.pcapng` con `tshark`.
- **Wireshark `[UNVERIFIED]`**: es normal sin la SAK; para verificar/descifrar haría falta MKA o configurar la clave en el disector.
- **`ip macsec show` no muestra la clave**: solo el ID y ceros; es lo esperado.

## Evidencia

- [Captura con cifrado activo](../../assets/capturas/lab-macsec/macsec-on.pcapng)
- [Captura con cifrado desactivado](../../assets/capturas/lab-macsec/macsec-off.pcapng)
- [Salida de `ip macsec show` en MV1](../../assets/capturas/lab-macsec/ip-macsec-show-mv1.txt)
- [Salida de `ip macsec show` en MV2](../../assets/capturas/lab-macsec/ip-macsec-show-mv2.txt)
- [Análisis `tshark` con cifrado](../../assets/capturas/lab-macsec/tshark-macsec-on.txt)
- [Análisis `tshark` sin cifrado](../../assets/capturas/lab-macsec/tshark-macsec-off.txt)

## Relacionado

- [Teoría: seguridad en el nivel de enlace](../teoria/nivel-enlace.md)
- [Protocolos seguros por niveles](../teoria/protocolos-por-niveles.md)
- [Comandos de Wireshark](../comandos/wireshark.md)
