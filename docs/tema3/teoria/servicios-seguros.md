# Servicios seguros

Un servidor presta servicios a usuarios internos y externos, almacena o procesa información sensible y es un objetivo habitual: accesos no autorizados, denegación de servicio y exfiltración de datos. Asegurarlo no es instalar un producto, sino planificar controles durante todo su ciclo de vida.

[:material-file-pdf-box: Transparencias — 3.1 Servicios seguros (PDF)](../../assets/pdf/SRDSI_T3-1-2.pdf#page=4){ .md-button }

## Qué se protege

Los servicios más comunes son web, DNS, correo, bases de datos, gestión de ficheros y *backups*, gestión de usuarios y de infraestructura. Todos comparten la misma superficie de ataque: el sistema operativo, los servicios de red y las cuentas con privilegios.

| Nivel | Controles |
| --- | --- |
| **Físico** | Ubicación en un entorno controlado, protección frente a condiciones ambientales y control de acceso físico. |
| **Firmware y arranque** | BIOS/UEFI y *boot loader* asegurados, contraseña de arranque, arranque firmado. |
| **Sistema operativo** | Parámetros del *kernel* (por ejemplo `/etc/sysctl.conf`), cuentas, permisos, servicios mínimos. |
| **Software adicional** | Antimalware, IDS basado en *host*, cortafuegos local. |
| **Registro y detección** | *Logs* suficientes para detectar, analizar y prevenir incidentes. |

## Endurecer el servidor

Las recomendaciones de la transparencia siguen la línea de **NIST SP 800-123** (*Guide to General Server Security*):

- Mantener una **configuración segura**: parches y actualizaciones, pruebas periódicas, política de recuperación ante desastres.
- **Copias de seguridad** de datos y del sistema, con cifrado de discos internos y externos.
- **Minimizar el software**: cada paquete extra es una vulnerabilidad potencial. Evita compiladores en producción y protocolos inseguros (FTP, Telnet, rlogin).
- **Acotar los accesos**: solo interfaces, usuarios y permisos necesarios; aislar procesos expuestos con virtualización, contenedores, *jails* o *sandboxing*.
- **Un servicio de red por sistema** (físico o virtual) y entornos de desarrollo, pruebas y producción separados.
- **Comunicaciones seguras**, autenticación multifactor y contraseñas gestionadas.
- **Sin acceso remoto para administración**; separación de roles y mínimo privilegio.
- Directorios principales en **particiones separadas** y redundancia para la disponibilidad.
- **Sin GUI**: menos superficie y menos consumo.

!!! warning "El servidor no es solo el servicio"
    Un fallo en el sistema operativo compromete todos los servicios que aloja. Por eso el endurecimiento del *host* y el del servicio (por ejemplo, Apache) se hacen en capas distintas.

## Herramientas de hardening

Existen distribuciones y paquetes orientados a que el administrador mejore la seguridad del sistema. Tras la configuración inicial, automatizan la instalación de herramientas, el análisis de seguridad y la eliminación o marcado de servicios peligrosos.

| Herramienta | Función |
| --- | --- |
| **Grsecurity** | Parches de seguridad para el *kernel* Linux. |
| **Harden** | Conjunto de herramientas de endurecimiento. |
| **Lynis** | Auditoría de seguridad y *hardening* de Linux/Unix. |
| **CSF** (*ConfigServer Security & Firewall*) | Cortafuegos y detección de intrusiones. |
| **Hardenize** | Análisis *online* de configuración y certificados. |
| **debsecan** | Auditoría de vulnerabilidades (CVE) en Debian. |
| **CIS Benchmark** | Guías y *scripts* de configuración segura por producto. |
| **Tenable CIS scripts** | Comprobaciones automatizadas de los *benchmarks* CIS. |

Distribuciones orientadas a seguridad: Subgraph OS, BlackArch, LPS-Public, Kodachi, Alpine Linux, Kali Linux.

La actividad asociada es [Lynis](../actividades/lynis.md): instala la herramienta, audita la VM Debian e interpreta los avisos rojos.
