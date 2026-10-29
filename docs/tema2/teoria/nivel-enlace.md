# Seguridad en el nivel de enlace

El nivel de enlace transmite tramas entre dos entidades conectadas directamente por un medio (un enlace punto a punto o una LAN). Protegerlo implica autenticar el acceso, preservar la integridad y, opcionalmente, cifrar el payload de la trama.

[:material-file-pdf-box: Transparencias — Nivel de enlace (PDF)](../../assets/pdf/SRDSI_T2-5.pdf#page=4){ .md-button }

## Amenazas en la LAN

| Amenaza | Qué hace |
| --- | --- |
| **MAC spoofing** | Suplantar la MAC de otro equipo. |
| **MAC flooding** | Saturar la tabla CAM del switch para que empiece a inundar tráfico. |
| **Sniffing pasivo/activo** | Escuchar tráfico ajeno, a veces con acceso no autorizado al medio. |
| **ARP poisoning / flooding** | Envenenar o saturar la caché ARP para interceptar o denegar tráfico. |
| **DHCP starvation** | Agotar el pool DHCP con solicitudes falsas. |
| **VLAN hopping** | Saltar de una VLAN a otra mediante etiquetado o trunking mal configurado. |
| **STP attacks** | Manipular el Spanning Tree para convertirse en raíz o provocar bucles. |
| **DoSPort stealing** | Denegar servicio o robar un puerto. |

## PPP: autenticación y cifrado

**PPP** (RFC 1661) encapsula datagramas multiprotocolo en enlaces punto a punto. No autentica por sí mismo, pero ofrece métodos para hacerlo:

- **PAP** (RFC 1334): usuario y contraseña en claro; el autenticador responde si acepta o no.
- **CHAP** (RFC 1994): desafío-respuesta con un secreto compartido; no envía la contraseña.
- **EAP** (RFC 3748): transporte genérico para métodos de autenticación (EAP-MD5, EAP-TLS, EAP-PSK, EAP-IKEv2…).
- **ECP** (RFC 1968): negociación del cifrado después de la autenticación.

## IEEE 802.1X y EAP

**802.1X** (*Port-Based Network Access Control*) autentica el acceso a la red basándose en puertos:

- **Supplicant**: el equipo que quiere entrar.
- **Authenticator**: el switch o punto de acceso, que bloquea el puerto hasta que se autentique.
- **Servidor AAA**: RADIUS o Diameter, que decide si autoriza.

EAP se encapsula en **EAPOL** sobre Ethernet o Wi-Fi. El authenticator transporta los mensajes EAP entre supplicant y servidor AAA; no necesita entender el método. **EAP-TLS** (RFC 5216) usa certificados en ambos extremos y es uno de los métodos más fuertes.

## MACsec (IEEE 802.1AE)

**MACsec** protege las tramas Ethernet entre equipos autorizados de una LAN/MAN:

- Servicios: **integridad**, **autenticación del origen** y **confidencialidad opcional**.
- Protege también ARP/NDP, DHCP, STP y VLAN, porque actúa sobre la trama completa.
- Usa un formato de trama propio con EtherType **0x88e5**, cabecera **SecTAG** e **ICV**.
- Cifrados: **GCM-AES-128** y **GCM-AES-256**.

| Concepto | Significado |
| --- | --- |
| **CA** (*Connectivity Association*) | Grupo de nodos MACsec de la misma LAN/WAN. |
| **SA** (*Secure Association*) | Asociación segura entre dos nodos; tiene su clave y su PN. |
| **SCI** | Identificador del canal seguro (MAC + puerto). |
| **SAK** | Clave de la asociación de seguridad. |
| **MKA** | *MACsec Key Agreement* (802.1X-REV): descubre la CA, negocia las SA y distribuye claves. |
| **KeySec** (802.1af) | Autenticación y marco de distribución de claves. |

MACsec **no incluye** por sí solo la gestión de claves ni la creación de asociaciones: eso lo aporta MKA/802.1X. En el laboratorio se usan claves manuales para ver el funcionamiento, pero en producción lo normal es MKA.

!!! note "MACsec no es extremo a extremo"
    En una LAN, MACsec cifra el tramo entre dispositivos de red; los switches descifran, procesan y vuelven a cifrar. Un monitor conectado a un puerto *span* del switch puede ver el tráfico. Para protección extremo a extremo hacen falta TLS, IPsec u otras capas.

En una WAN se puede usar MACsec en enlaces de alta velocidad entre routers y IPsec para el acceso a Internet.

## WLAN: WEP, WPA, WPA2 y WPA3

| Esquema | Cifrado/integridad | Autenticación | Estado |
| --- | --- | --- | --- |
| **WEP** | RC4 + CRC-32 (ICV) | Clave compartida (WEP Shared Key) o abierta | Roto; no usar. |
| **WPA** | TKIP (RC4 + MIC) | 802.1X/EAP o PSK; handshake EAPOL de 4 vías | Obsoleto; TKIP está deprecado. |
| **WPA2** | CCMP (AES-CCMP) | 802.1X/EAP o PSK; 802.11i | Seguro si se configura bien; usa AES. |
| **WPA3** | AES-CCMP/GCMP, SAE | SAE (PSK) o 802.1X; protección de tramas de gestión | Recomendado; añade *forward secrecy* y resistencia a ataques de diccionario. |

La actividad de T2-5 pide comparar estos algoritmos; la tabla anterior es la respuesta resumida.

## Ataques de enlace y mitigaciones

- **Port security** en switches: ata un puerto a una o varias MAC; frena MAC flooding y repetición.
- **ARP estático**: evita envenenamiento ARP, pero complica DHCP y movilidad.
- **IDS**: analiza el tráfico; una mala configuración genera falsos positivos.
- **VLAN**: segmenta y limita el alcance de los ataques; mal configurada permite VLAN hopping.
- **MACsec**: autentica y cifra la trama, y protege ARP/NDP, DHCP, STP y VLAN.
- **802.1X/EAP**: controla quién entra en el puerto antes de dar acceso.

## Ideas clave para el examen

- PAP envía credenciales en claro; CHAP usa desafío-respuesta; EAP transporta métodos.
- 802.1X tiene supplicant, authenticator y servidor AAA (RADIUS/Diameter).
- MACsec = 802.1AE: integridad, autenticación y cifrado opcional de tramas; EtherType `0x88e5`.
- MACsec necesita MKA/802.1X para gestionar claves; no es extremo a extremo.
- WEP está roto; WPA/TKIP obsoleto; WPA2 con CCMP es el mínimo razonable; WPA3/SAE es el recomendado.
- Port security, ARP estático, IDS, VLAN y MACsec mitigan ataques de enlace.

## Páginas relacionadas

- [Actividad MACsec](../actividades/macsec.md)
- [Protocolos seguros por niveles](protocolos-por-niveles.md)
- [Transparencias T2-5 (PDF)](../../assets/pdf/SRDSI_T2-5.pdf)
