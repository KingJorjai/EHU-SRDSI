# Proyecto SRDSI #16 — Port Knocking y SPA (fwknop)

**Autores:** Jorge Arévalo y Jon González  
**Asignatura:** Seguridad, Rendimiento y Disponibilidad de Servicios e Infraestructuras (UPV/EHU)

Proyecto sobre **Port Knocking** y **Single Packet Authorization** con `fwknop`, con una demostración real en dos VM Debian 13.

**Presentación:** 10 minutos, sin demostración online.

## Estructura

```text
port-knocking/
├── informe/
│   ├── informe.md          # memoria
│   ├── informe.pdf         # memoria compilada
│   ├── img/                # capturas incluidas en la memoria
│   ├── iflatex/            # plantilla UPV/EHU
│   └── Makefile
├── presentacion/
│   ├── presentacion.md     # guion de diapositivas
│   ├── presentacion.pdf    # PDF de la presentación
│   ├── img/
│   └── Makefile
└── lab/
    ├── setup-server.sh     # configuración de VM1 (firewall, knockd, fwknopd)
    ├── knockd.conf         # secuencia 7000,8000,9000
    ├── access.conf         # claves SPA (laboratorio)
    ├── run-tests.sh        # pruebas completas desde el host
    ├── capturas/           # .pcapng y capturas de Wireshark
    └── resultados/         # salida real de las pruebas
```

## Reproducción

### 1. Servidor (VM1, 192.168.56.110)

```bash
sudo apt-get install iptables knockd fwknop-server
sudo bash lab/setup-server.sh
```

El script:

- configura `fwknopd` en modo UDP (puerto 62201);
- instala `knockd.conf` y `access.conf`;
- crea la cadena `PROTECTED` con `DROP` para `tcp/8080`;
- arranca un servidor HTTP de prueba en `8080`;
- habilita y reinicia `knockd` y `fwknop-server`.

### 2. Cliente (VM2, 192.168.56.111)

```bash
sudo apt-get install knockd fwknop-client
```

### 3. Pruebas

Desde el host, con las dos VM encendidas:

```bash
bash lab/run-tests.sh
```

Genera `lab/resultados/pruebas.txt` con los casos: sin knock, secuencia correcta, timeout, SPA correcta, HMAC incorrecta y replay.

## Evidencias

- `lab/capturas/knockd.pcapng`: secuencia `7000,8000,9000` y acceso HTTP.
- `lab/capturas/fwknop.pcapng`: un datagrama UDP 62201 y acceso HTTP.
- `lab/capturas/01-wireshark-knockd.png` y `02-wireshark-fwknop.png`.
- `lab/resultados/pruebas.txt`: salida real de las pruebas.

## Notas

- Las claves de `access.conf` son **de laboratorio**; no deben reutilizarse.
- El paquete Debian de `fwknop-server` 2.6.11 no incluye soporte de `libpcap`; `fwknopd` funciona en modo servidor UDP.
- Se protege HTTP en `8080` en lugar de SSH para no perder la sesión de administración; el procedimiento es idéntico para `tcp/22`.
- El enunciado indica la fecha de presentación **16-17/12/25**; conviene confirmar con el profesorado si se refiere a **2026**.

## Compilar

```bash
cd informe && make informe
cd ../presentacion && make presentacion
```
