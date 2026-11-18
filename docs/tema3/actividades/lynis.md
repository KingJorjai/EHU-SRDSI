# Actividad Lynis: auditoría y hardening

**Lynis** es una herramienta *open source* de auditoría de seguridad, análisis de vulnerabilidades y *hardening* para Linux, macOS y BSD. No cambia el sistema por sí sola: inspecciona la configuración, asigna un índice de endurecimiento y propone acciones.

[:material-file-pdf-box: Enunciado de la actividad (PDF)](../../assets/pdf/lab-lynis.pdf){ .md-button }

!!! warning "Requiere la VM"
    La auditoría completa se ejecuta en la VM Debian. Aquí se documentan los comandos, cómo interpretar los avisos y la diferencia entre ejecutarla como root o como usuario; la ejecución y sus hallazgos concretos quedan marcados como **VM**.

## Instalación

### Opción A: descarga directa (sin instalar)

```bash
sudo apt-get install wget
wget https://downloads.cisofy.com/lynis/lynis-3.1.7.tar.gz
sha256sum lynis-3.1.7.tar.gz          # compara con el valor publicado por CISOfy
tar -xvf lynis-3.1.7.tar.gz
cd lynis
```

### Opción B: repositorio de Debian

```bash
sudo apt-get install lynis
sudo lynis audit system --auditor "Ana"
```

La versión empaquetada puede ser anterior a la 3.1.7. Si el enunciado pide una versión concreta, usa la descarga directa.

!!! warning "`lynis -c` ya no funciona en 3.1.7"
    El enunciado propone `lynis -c --auditor "Ana"`. En Lynis 3.1.7 ese atajo está obsoleto y el programa termina con `This option (-c) is deprecated. Use: lynis audit system [options]`. Usa `lynis audit system --auditor "Ana"`.

## Comandos

| Comando | Qué hace |
| --- | --- |
| `sudo ./lynis audit system --auditor "Ana"` | Auditoría completa del sistema; etiqueta el informe con el auditor. |
| `sudo ./lynis --tests USB-1000` | Ejecuta solo la prueba indicada (USB-1000: almacenamiento USB deshabilitado). |
| `sudo ./lynis --pentest` | Modo no privilegiado, pensado para pruebas de penetración. |
| `./lynis -c --auditor "Ana"` | Atajo de versiones anteriores; en 3.1.7 aborta con `This option (-c) is deprecated`. |
| `./lynis` | Pantalla de ayuda y versión. |
| `./lynis show help`, `show tests`, `show categories` | Ayuda, catálogo de pruebas y categorías (`security`, `performance`, `privacy`). |
| `ls ./include` | Implementación de las pruebas y perfiles. |
| `lynis show version` | Versión instalada. |

Hay *plugins* de la comunidad que amplían la recogida de información; la versión comercial añade más.

### Dónde quedan los resultados

- Resumen en pantalla, con `Hardening index` de 0 a 100.
- Detalle en `/var/log/lynis.log`.
- Hallazgos estructurados en `/var/log/lynis-report.dat`:

```bash
sudo grep '^warning\[\]='    /var/log/lynis-report.dat
sudo grep '^suggestion\[\]=' /var/log/lynis-report.dat | head
sudo grep '^hardening_index=' /var/log/lynis-report.dat
sudo grep -i 'lynis' /var/log/lynis.log | tail
```

Sin privilegios, Lynis no puede escribir en `/var/log` y guarda los ficheros en el directorio de trabajo o en `$HOME` (`lynis.log`, `lynis-report.dat`). En ese caso, busca ahí.

## Prueba 1: ejecutar en la VM

**VM**:

```bash
cd ~/lynis
sudo ./lynis audit system --auditor "Ana" --quick
```

`--quick` evita pausas y acelera la auditoría; para la entrega conviene ejecutarla sin `--quick` la primera vez. Guarda la salida completa:

```bash
sudo ./lynis audit system --auditor "Ana" 2>&1 | tee ~/lynis-auditoria.txt
```

## Prueba 2: interpretar los avisos rojos

Lynis clasifica los hallazgos como **warning** (rojo), **suggestion** (amarillo), **notice** y **info**. Un aviso rojo no siempre es una vulnerabilidad explotable: indica una configuración que debilita el sistema o que impide verificarlo.

| Aviso típico | Qué significa | Cómo se corrige |
| --- | --- | --- |
| Cortafuegos sin reglas o deshabilitado (`FIRE-4512`, `FIRE-4540`, `FIRE-4586`) | El *host* no filtra tráfico ni registra bloqueos. | Instalar y configurar `nftables`/`iptables` o `ufw`; activar el registro. |
| Sin sistema de detección de intrusiones | No hay IDS/IPS basado en *host*. | Valorar `auditd`, AIDE o un HIDS; al menos, activar auditoría. |
| `auditd` ausente o sin reglas (`ACCT-9628`) | No se registran eventos de seguridad. | `apt install auditd`, definir reglas y revisar `/var/log/audit/`. |
| Opciones de SSH débiles (`SSH-7408`) | Por ejemplo, `PermitRootLogin yes` o `PasswordAuthentication yes`. | `PermitRootLogin no`, claves en lugar de contraseñas, `AllowUsers`/`AllowGroups`. |
| Permisos de `sudo`/`shadow`/`group` incorrectos (`AUTH-9216`, `AUTH-9252`) | Un usuario podría elevar privilegios o leer hashes. | `chmod`/`chown` según la política; `visudo` para revisar. |
| Método de *hash* de contraseñas débil (`AUTH-9229`) | Hashes antiguos (DES/MD5) o sin *salt* suficiente. | Migrar a SHA-512 o `yescrypt` (`ENCRYPT_METHOD` en `/etc/login.defs`). |
| Contraseñas sin caducidad (`AUTH-9288`) | Cuentas con contraseña perpetua. | `chage -M`, política en `/etc/login.defs`. |
| Usuarios con UID 0 (`AUTH-9204`) | Varias cuentas con privilegios de root. | Eliminar o cambiar el UID; una sola cuenta de root. |
| Cifrado de disco/swap ausente (`CRYP-7930`, `CRYP-7931`) | Datos recuperables si se roba el disco o la swap. | LUKS para disco y swap cifrada. |
| Almacenamiento USB habilitado (`USB-1000`) | Un atacante físico puede montar un dispositivo. | Deshabilitar `usb-storage` en el *kernel* o por política. |
| Parámetros del *kernel* inseguros (`KRNL-6000`) | `sysctl` sin endurecer (redirecciones ICMP, ASLR, `rp_filter`…). | Ajustar `/etc/sysctl.conf` y aplicar con `sysctl -p`. |
| Sin particiones separadas (`FILE-*`) | Un llenado de `/` o `/var` tumba el sistema. | Separar `/var`, `/tmp`, `/home` y aplicar cuotas. |
| Software vulnerable o sin actualizar | Paquetes con CVE conocidos. | `apt update && apt upgrade`; revisar `debsecan`. |
| Compiladores o servicios innecesarios | Aumentan la superficie de ataque. | Desinstalar lo que no se use; un servicio por sistema. |

Para localizar el test exacto de cada aviso, Lynis incluye el identificador en el resumen (`SSH-7408`, `FIRE-4512`…) y en el informe. Búscalo en el catálogo:

```bash
./lynis show tests | grep -i ssh
grep -A2 "SSH-7408" /var/log/lynis.log
```

!!! note "No hay resultados inventados"
    Los avisos concretos dependen del estado de la VM (paquetes, servicios, particiones y usuarios). La tabla anterior permite interpretarlos, pero la auditoría real debe ejecutarse y capturarse en la VM.

### Índice de endurecimiento

El `Hardening index` resume el estado en una cifra. Sirve para **comparar antes y después** de aplicar correcciones, no como certificación. Anota el valor inicial y el final:

```bash
sudo grep '^hardening_index=' /var/log/lynis-report.dat
```

## Prueba 3: root frente a usuario normal

Lynis funciona sin privilegios, pero **omite las pruebas que necesitan leer ficheros protegidos o consultar el estado del sistema**. En la ejecución local de comprobación (esta máquina, sin root, versión 3.1.7) la propia herramienta listó:

```text
Skipped tests due to non-privileged mode:
  BOOT-5108 - Check Syslinux as bootloader
  BOOT-5109 - Check rEFInd as bootloader
  BOOT-5116 - Check if system is booted in UEFI mode
  AUTH-9216 - Check group and shadow group files
  AUTH-9229 - Check password hashing methods
  AUTH-9252 - Check ownership and permissions for sudo configuration files
  AUTH-9288 - Checking for expired passwords
  FILE-6368 - Checking ACL support on root file system
  FIRE-4540 - Check for empty nftables configuration
  FIRE-4586 - Check firewall logging
  CRYP-7930 - Determine if system uses LUKS block device encryption
  CRYP-7931 - Determine if system uses encrypted swap
```

| Como root | Como usuario |
| --- | --- |
| Lee `/etc/shadow`, reglas de cortafuegos, parámetros del *kernel*, ACL y estado de los discos. | No puede leer ficheros protegidos ni consultar parte del estado del sistema. |
| Ejecuta el conjunto completo de pruebas. | Omite pruebas y algunas las marca como no concluyentes. |
| Escribe en `/var/log/lynis.log` y `/var/log/lynis-report.dat`. | Guarda los informes en su directorio de trabajo o `$HOME`. |
| El `Hardening index` es completo y comparable entre ejecuciones. | El índice es parcial: **no se puede comparar** con el de root. |
| Puede auditar servicios de otros usuarios y el arranque. | El modo `--pentest` está pensado precisamente para esta limitación. |

Conclusión: para la entrega se ejecuta con `sudo`; el modo usuario sirve para una primera pasada rápida o cuando no hay privilegios, asumiendo que el resultado está incompleto.

## Entregables

- [ ] Versión de Lynis y método de instalación utilizados.
- [ ] Salida completa de la auditoría en la VM (`lynis-auditoria.txt` o captura).
- [ ] Lista de avisos rojos con su identificador, interpretación y medida correctiva.
- [ ] Índice de endurecimiento inicial (y final, si se aplican correcciones).
- [ ] Comparación razonada entre ejecución como root y como usuario.

## Comprobado en local

```console
$ ./lynis show version
3.1.7

$ ./lynis show tests | grep USB-1000
USB-1000   Linux      Check if USB storage is disabled (security)

$ ./lynis show categories
performance
privacy
security

$ ./lynis -c --auditor "Prueba" --quick --no-log
This option (-c) is deprecated.
Use: lynis audit system [options]
```

La auditoría completa **no** se ha ejecutado sobre la VM desde este entorno; la ejecución local sin privilegios solo se ha usado para verificar los comandos y la lista de pruebas omitidas.
