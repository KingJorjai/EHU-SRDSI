# Actividad DNS con BIND

Práctica de servidor de nombres sobre Debian: servidor caché, zona autorizada directa e inversa, servidor secundario, transferencias de zona con TSIG, DNSSEC y delegación segura.

[:material-file-pdf-box: Enunciado de la actividad (PDF)](../../assets/pdf/lab-dns-actividad.pdf){ .md-button }

!!! warning "Requiere la VM"
    La instalación de BIND, las zonas y las capturas se hacen en la VM Debian (`user1`). Los pasos que dependen de ella están marcados como **VM**. La actividad completa usa dos VM para el servidor secundario.

## Material

- Paquetes: `bind9`, `bind9-utils` y `bind9-dnsutils`.
- Dominio de ejemplo: `srdsi.lab`; servidor `dns1.srdsi.lab`.
- La red de la UPV/EHU **no permite consultas a servidores DNS externos**; por eso el laboratorio usa reenviadores y pruebas locales.

## 1. Servidor caché

**VM**. Instala y arranca el servicio:

```bash
sudo apt-get install bind9 bind9-utils bind9-dnsutils
sudo systemctl restart bind9
```

Configura el nombre del servidor:

```bash
sudo hostnamectl set-hostname dns1
hostname --fqdn          # dns1.srdsi.lab
```

En `/etc/resolv.conf`, apunta el equipo a sí mismo y protégelo:

```text
search srdsi.lab
nameserver 127.0.0.1
```

```bash
sudo chattr +i /etc/resolv.conf
```

Herramientas de control y diagnóstico:

```bash
sudo rndc status
sudo rndc dumpdb -cache      # vuelca la caché en /var/cache/bind/named_dump.db
sudo rndc flush              # vacía la caché
sudo systemctl status named
dig [@dirIP_servidor] nombre [tipoRR]
```

## 2. Zona autorizada `srdsi.lab`

**VM**. Declara las zonas en `/etc/bind/named.conf.local`:

```bind
zone "srdsi.lab" {
    type primary;
    file "/etc/bind/db.srdsi.lab";
};

zone "0.16.172.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.0.16.172";
};
```

Zona directa `/etc/bind/db.srdsi.lab`:

```bind
$ORIGIN srdsi.lab.
$TTL 2h
@   IN  SOA dns1.srdsi.lab. admin.srdsi.lab. (
        20240401 ; Serial
        604800   ; Refresh
        86400    ; Retry
        2419200  ; Expire
        604800 ) ; Negative Cache TTL
;
srdsi.lab. IN NS    dns1.srdsi.lab.
dns1       IN A     172.16.0.136
host1      IN A     172.16.0.138
www        IN CNAME host1
```

Zona inversa `/etc/bind/db.0.16.172`:

```bind
$TTL 604800
@   IN SOA dns1.srdsi.lab. admin.srdsi.lab. (
        20240401 ; Serial
        604800   ; Refresh
        86400    ; Retry
        2419200  ; Expire
        604800 ) ; Negative Cache TTL
;
@   IN NS  dns1.srdsi.lab.
136 IN PTR dns1.srdsi.lab.
138 IN PTR host1.srdsi.lab.
```

Comprueba y recarga:

```bash
sudo named-checkconf /etc/bind/named.conf
sudo named-checkzone srdsi.lab /etc/bind/db.srdsi.lab
sudo named-checkzone 0.16.172.in-addr.arpa /etc/bind/db.0.16.172
sudo systemctl restart bind9
sudo rndc status
dig @dirIP_dns1 dns1.srdsi.lab
dig @localhost -x 172.16.0.136
```

## 3. Servidor secundario

**VM (dos máquinas)**. En `dns2` declara las zonas como secundarias:

```bind
zone "srdsi.lab" {
    type secondary;
    file "/var/cache/bind/db.srdsi.lab";
    masterfile-format text;
    primaries { dirIP_dns1; };
};

zone "0.16.172.in-addr.arpa" {
    type secondary;
    file "/var/cache/bind/db.0.16.172";
    masterfile-format text;
    primaries { dirIP_dns1; };
};
```

Restringe las transferencias en `/etc/bind/named.conf.options`:

```bind
allow-transfer { none; };
```

En el primario, autoriza y notifica al secundario dentro de cada zona:

```bind
allow-transfer { dirIP_dns2; };
also-notify { dirIP_dns2; };
```

Comprueba la transferencia y añade el nuevo NS a la zona:

```bash
dig @dirIP_dns1 srdsi.lab axfr
dig @dirIP_dns2 srdsi.lab axfr
sudo rndc reload
sudo rndc notify srdsi.lab
```

Para Wireshark, filtra por `ip.addr == dirIP_dns2`.

## 4. TSIG

**VM**. Genera la clave compartida en el primario:

```bash
sudo sh -c 'tsig-keygen dns1-dns2_tsigkey > Kdns1-dns2_tsigkey'
sudo chmod 640 Kdns1-dns2_tsigkey
```

Inclúyela en `/etc/bind/named.conf`:

```bind
include "/etc/bind/Kdns1-dns2_tsigkey";
```

Y úsala en la zona del primario:

```bind
allow-transfer { key dns1-dns2_tsigkey; };
```

En el secundario, distribuye el mismo fichero y declara el servidor maestro con la clave:

```bind
server dirIP_dns1 {
    keys { dns1-dns2_tsigkey; };
};
```

```bind
masters { dirIP_dns1 key dns1-dns2_tsigkey; };
```

Prueba la transferencia con y sin la clave:

```bash
sudo dig @dirIP_dns1 srdsi.lab axfr
sudo dig @dirIP_dns1 srdsi.lab axfr -k Kdns1-dns2_tsigkey_only
```

Ambas máquinas deben tener la hora sincronizada (NTP o `date --set`).

## 5. DNSSEC

**VM**. Genera las claves KSK y ZSK:

```bash
sudo dnssec-keygen -a RSASHA256 -b 1024 -f KSK -n ZONE srdsi.lab.
sudo dnssec-keygen -a RSASHA256 -b 1024 -n ZONE srdsi.lab.
```

Incluye los `.key` en la zona, actualiza el serial y fírmala:

```bash
sudo dnssec-signzone -t -o srdsi.lab. db.srdsi.lab [ZSK-file]
```

Apunta la zona al fichero firmado en `named.conf.local`:

```bind
zone "srdsi.lab" {
    type primary;
    file "/etc/bind/db.srdsi.lab.signed";
};
```

Comprueba los registros DNSSEC y la cadena de confianza:

```bash
dig @localhost srdsi.lab. DNSKEY +dnssec +multi
dig @localhost srdsi.lab. RRSIG +dnssec
dig @localhost srdsi.lab. NSEC +dnssec
delv @localhost -a /etc/bind/trustanchor.key +root=srdsi.lab srdsi.lab NS
```

Cada cambio de zona obliga a volver a firmarla (no a regenerar claves):

```bash
sudo dnssec-signzone -o srdsi.lab. -f db.srdsi.lab.signed.new db.srdsi.lab.signed
```

También se puede publicar un registro **TLSA** para DANE:

```bash
sudo apt-get install ldnsutils
ldns-dane create -a 172.16.0.138 www.srdsi.lab 443
ldns-dane verify www.srdsi.lab
drill @nameserver -S srdsi.lab
```

## 6. Delegación segura

**VM**. Crea una subzona (por ejemplo `subGX.srdsiGX.lab`) en el servidor o en el secundario, fírmala y añade a la zona padre los registros `NS`, `A` y `DS`:

```bind
subGX IN NS dns1.srdsiGX.lab.
subGX IN A  172.16.0.136
```

Vuelve a firmar la zona padre. Para validar la cadena (`flag ad`), consulta desde un servidor **no autorizado** para el dominio.

## 7. NSEC3

**VM**. Firma la zona inversa y comprueba que aparecen los registros de respuesta negativa:

```bash
dig @localhost 0.16.172.in-addr.arpa NSEC3 +dnssec
dig @localhost 0.16.172.in-addr.arpa NSEC3PARAM +dnssec
```

## 8. Resultados en la VM

Ejecutado en `bocata-jamon` (BIND 9.20.30) con `bocata-jamon2` como secundario:

| Prueba | Resultado |
| --- | --- |
| `named-checkzone` | `loaded serial 2026112301`, `OK` |
| Zona directa | `dns1` → `172.16.0.136`; `www` → `CNAME host1` |
| Zona inversa | `136.0.16.172.in-addr.arpa` → `PTR dns1.srdsi.lab` |
| DNSSEC | `DNSKEY` (KSK/ZSK), `RRSIG` y `NSEC` |
| Secundario | `dns2` (`192.168.56.111`) resuelve y transfiere la zona |
| TSIG | AXFR sin clave falla; con `-k` funciona |
| NSEC3 | `NSEC3PARAM` y `NSEC3` en la respuesta negativa |

![Consultas DNS en Wireshark](../../assets/capturas/lab-dns/01-wireshark-dns.png)

![AXFR con TSIG entre dns1 y dns2](../../assets/capturas/lab-dns/02-wireshark-axfr-tsig.png)

Resultados completos y scripts:

- [`dig.txt`](../../assets/resultados/dns/dig.txt) y [`secundario-tsig.txt`](../../assets/resultados/dns/secundario-tsig.txt)
- [`setup-dns.sh`](../../assets/scripts/dns/setup-dns.sh), [`setup-tsig-primary.sh`](../../assets/scripts/dns/setup-tsig-primary.sh), [`setup-tsig-secondary.sh`](../../assets/scripts/dns/setup-tsig-secondary.sh) y [`setup-nsec3.sh`](../../assets/scripts/dns/setup-nsec3.sh)

!!! note "Pendiente"
    La delegación segura (§6) no se ha ejecutado; el resto de bloques sí.

## Entrega

Resolución de los ejercicios con capturas de pantalla, ejemplos de configuración, pruebas de consultas a los NS y análisis de resultados. Adjunta un comprimido del directorio `/etc/bind` e indica el tiempo empleado.

## Teoría relacionada

- [Seguridad en DNS](../teoria/dns.md): resolución, *cache poisoning*, DNSSEC y *split horizon*.
