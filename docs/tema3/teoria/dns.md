# Seguridad en DNS

El **DNS** (*Domain Name System*) traduce nombres a direcciones IP y es infraestructura crítica: si se compromete, se compromete todo lo que depende de él (web, correo, TLS). Esta página resume su funcionamiento, los ataques habituales y las defensas, con BIND9 como servidor de referencia.

[:material-file-pdf-box: Transparencias — 3.3 DNS (PDF)](../../assets/pdf/SRDSI_T3-3.pdf){ .md-button }

## Funcionamiento

El espacio de nombres es una jerarquía: raíz, TLD (`.es`, `.com`), dominio y subdominios. Cada zona tiene servidores **autoritativos** que publican sus registros ([transparencias, pág. 6](../../assets/pdf/SRDSI_T3-3.pdf#page=6)).

| Tipo | Uso |
| --- | --- |
| `A` / `AAAA` | Dirección IPv4 / IPv6. |
| `CNAME` | Alias de otro nombre. |
| `MX` | Servidor de correo del dominio. |
| `NS` | Servidores autoritativos de la zona. |
| `SOA` | Autoridad y parámetros de la zona. |
| `TXT` | Texto libre (SPF, DKIM, DMARC, verificaciones). |
| `PTR` | Resolución inversa. |
| `SRV` | Servicio, puerto y destino. |
| `DS` / `DNSKEY` / `RRSIG` | Cadena de confianza DNSSEC. |

Un **resolver** consulta de forma recursiva y cachea las respuestas; el cliente pregunta a su resolver configurado en `/etc/resolv.conf`. DNS usa el puerto **53** (UDP para consultas cortas, TCP para transferencias y respuestas grandes), **853** para DNS over TLS (DoT) y **443** para DNS over HTTPS (DoH).

## BIND9

Instalación y control:

```bash
sudo apt-get install bind9 bind9-utils bind9-dnsutils
sudo systemctl restart bind9
sudo rndc status
sudo rndc reload
sudo rndc flush
```

Ficheros principales:

| Ruta | Contenido |
| --- | --- |
| `/etc/bind/named.conf` | Configuración principal e `include`. |
| `/etc/bind/named.conf.options` | Opciones globales (recursión, reenviadores, `allow-transfer`). |
| `/etc/bind/named.conf.local` | Declaración de zonas. |
| `/etc/bind/db.*` | Ficheros de zona. |
| `/var/cache/bind/` | Caché y copias de zonas secundarias. |

Una zona se declara así:

```bind
zone "srdsi.lab" {
    type primary;
    file "/etc/bind/db.srdsi.lab";
};
```

Y se valida antes de recargar:

```bash
sudo named-checkconf /etc/bind/named.conf
sudo named-checkzone srdsi.lab /etc/bind/db.srdsi.lab
```

## Amenazas

- **Cache poisoning**: inyectar respuestas falsas en la caché del resolver. El ataque de Kaminsky forzó el uso de puertos de origen aleatorios y DNSSEC.
- **Cache snooping**: consultar la caché de un resolver abierto para saber qué nombres visita una víctima.
- **Spoofing / pharming**: suplantar la respuesta o modificar el resolver del cliente. La mitigación pasa por el puerto de origen aleatorio, el `TXID` y las comprobaciones de la RFC 5452.
- **Transferencias no autorizadas**: un `AXFR` abierto entrega toda la zona.
- **Amplificación y reflexión**: consultas con respuesta grande (`ANY`, DNSSEC) usadas para DDoS.
- **Túneles DNS**: exfiltración de datos o *command & control* camuflado en consultas.
- **Registros maliciosos**: `MX`/`TXT` falsos, subdominios abandonados (*subdomain takeover*).
- **Hijacking del registrador**: cambio de `NS` sin tocar el servidor.

## Defensas

1. **Restringir la recursión** a la red local y separar resolutores de autoritativos ([pág. 17](../../assets/pdf/SRDSI_T3-3.pdf#page=17)).
2. **Limitar transferencias** con `allow-transfer` y autenticarlas con **TSIG** ([pág. 27](../../assets/pdf/SRDSI_T3-3.pdf#page=27)).
3. **DNSSEC**: firmar la zona (KSK/ZSK), publicar `DNSKEY`/`RRSIG` y encadenar con `DS` en la zona padre. `NSEC`/`NSEC3` protegen las respuestas negativas ([pág. 26](../../assets/pdf/SRDSI_T3-3.pdf#page=26)).
4. **Views / split horizon**: respuestas distintas para redes internas y externas ([pág. 18](../../assets/pdf/SRDSI_T3-3.pdf#page=18)).
5. **Rate limiting** (RRL) y límites de tamaño para mitigar amplificación; **anycast** reparte la carga y acorta la distancia al resolver ([pág. 20](../../assets/pdf/SRDSI_T3-3.pdf#page=20)).
6. **Registro y monitorización**: consultas anómalas, fallos de validación, cambios de zona.
7. **DoT/DoH** para proteger la consulta en tránsito, y **DANE/TLSA** para vincular certificados.
8. **Actualizaciones** de BIND y del sistema; revisar CVE y configuraciones por defecto.

## Comandos útiles

```bash
dig @servidor nombre tipo
dig +dnssec nombre DNSKEY
dig @servidor zona AXFR
dig +short MX dominio
dig -x 172.16.0.136
delv @localhost -a trustanchor.key +root=ejemplo.lab ejemplo.lab NS
drill @servidor -S zona
sudo rndc dumpdb -cache
sudo rndc notify zona
```

!!! warning "Red de la UPV/EHU"
    La red de la UPV/EHU no permite consultas a servidores DNS externos; en el laboratorio se usan reenviadores y pruebas locales.

## Relación con otras prácticas

- [Actividad DNS con BIND](../actividades/dns.md): servidor caché, zonas, secundario, TSIG, DNSSEC y delegación.
- [Correo electrónico](correo.md): los registros `MX`, `SPF`, `DKIM` y `DMARC` viven en DNS.
