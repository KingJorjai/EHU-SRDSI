# VM y entorno de trabajo

Guía práctica para poner en marcha la máquina virtual del laboratorio y personalizar el entorno.

[:material-file-pdf-box: Anexo de laboratorios y máquina virtual (PDF)](../assets/pdf/anexo-laboratorios.pdf){ .md-button }
[:material-file-pdf-box: Personalizar entorno de trabajo (PDF)](../assets/pdf/personalizar-entorno.pdf){ .md-button }

## La máquina virtual

Las prácticas se realizan en una máquina virtual gestionada con **VirtualBox** sobre **Debian 13** (stable), con escritorio LXDE.

| Elemento | Valor de laboratorio |
| -------- | -------------------- |
| Carpeta de la imagen | `SRDSI_Debian13` (≈ 1,5 GB) |
| Sistema | Debian 13, monoprocesador, 4 GB RAM, disco SCSI de 30 GB |
| Nombre del sistema | `demo` (a personalizar) |
| Usuario | `user1` / contraseña `user1` |
| Administrador | `root` / contraseña `root` |

!!! danger "Credenciales de laboratorio"
    `user1`/`user1` y `root`/`root` son credenciales **de laboratorio**. No las reutilices en ningún sistema real ni expongas la VM a una red no confiable.

La imagen se abre con VirtualBox haciendo doble clic en el fichero `.vbox` o añadiéndola desde el gestor de máquinas virtuales.

## Arranque y apagado

- **Arrancar**: doble clic en el `.vbox` o desde el gestor de VirtualBox.
- **Volver al anfitrión**: en sistemas sin entorno gráfico, `Ctrl+Der` (configurable) devuelve teclado y ratón al host.
- **Apagar**: usa el botón *Apagar* de la propia máquina virtual o `poweroff` con privilegios:

```bash title="Apagado ordenado"
sudo poweroff
```

!!! warning "No apagues desde el menú de VirtualBox"
    Suspender o apagar desde el menú de VirtualBox puede dejar el sistema en un estado inconsistente. Usa el apagado ordenado del invitado.

## Transferir archivos

### Con `scp`

El comando `scp` copia ficheros entre el anfitrión y la VM de forma segura. Sustituye `IPaddress` por la IP de la máquina virtual.

```bash title="scp"
# Del host a la VM (directorio HOME de user1)
scp file1 user1@IPaddress:.

# De la VM al host (directorio actual)
scp user1@IPaddress:file2 .

# Copiar un directorio completo
scp -r directorio user1@IPaddress:.
```

### Carpetas compartidas

1. En VirtualBox: **Dispositivos → Carpetas Compartidas**, indica la *Ruta a la carpeta* y marca **Automontar** y **Hacer permanente**.
2. En la VM, añade tu usuario al grupo `vboxsf` para tener permisos de acceso:

```bash title="Permisos de carpeta compartida"
sudo usermod -aG vboxsf $(whoami)
```

Cierra y vuelve a abrir la sesión de usuario para que el cambio tenga efecto. La carpeta aparece en `/media/sf_<nombre>`.

!!! tip "Arrastrar y soltar"
    VirtualBox permite arrastrar y soltar entre invitado y anfitrión, pero su rendimiento no es óptimo. Se recomienda mantenerlo deshabilitado y usar `scp` o carpetas compartidas.

## Red NAT `SRDSINet`

Para que varias VM se comuniquen entre sí deben estar conectadas a la misma red.

1. En VirtualBox: **Archivo → Herramientas → Administrador de red → Redes NAT**.
2. Añade una red y configúrala (por ejemplo, `SRDSINet`). El anexo propone ajustar el identificador de grupo; la personalización pide el rango `172.16.99.0/24` para el grupo 99.
3. En la configuración de red de cada VM, en **Adaptador 1** selecciona **Red NAT** y asígnale la red creada.

## Clonar una VM

Para crear una nueva máquina a partir de la existente (por ejemplo, `servidor` a partir de `demo`):

1. En el administrador de VirtualBox, **clona** la máquina:
   - Nombre de la nueva máquina: `servidor`.
   - Política de dirección MAC: **Generar nuevas #MACs para todas las NICs**.
   - Tipo de clonación: **completa**.
2. Arranca el clon y actualiza su nombre en `/etc/hostname` y `/etc/hosts`:

```bash title="Renombrar el clon"
sudo nano /etc/hostname   # sustituye demo por servidor
sudo nano /etc/hosts      # sustituye demo por servidor
```

## Personalizar el entorno

Es **requisito** que el nombre de la máquina, el dominio, el usuario y los nombres de los servicios incluyan el nombre del grupo (por ejemplo `G99`) y del alumno (por ejemplo `alumnoG99`). Las capturas y resultados de las entregas deben mostrar estos valores personalizados.

### Cambiar el nombre de la máquina

```bash title="hostnamectl"
sudo hostnamectl set-hostname demoG99
```

Actualiza después la resolución del nombre en `/etc/hosts`:

```text title="/etc/hosts"
127.0.1.1 demo.srdsi.lab demo
127.0.1.1 demoG99.srdsiG99.lab demoG99
```

### Crear un usuario nuevo

```bash title="adduser"
sudo adduser alumnoG99
```

Concede permisos de administración editando `/etc/sudoers` con `visudo`:

```bash title="visudo"
sudo visudo
```

```text title="/etc/sudoers"
alumnoG99   ALL=(ALL:ALL) ALL
```

### Direcciones localhost distintas

Asigna una dirección localhost distinta a cada sitio web o servidor para discriminar el origen y destino de los paquetes en las capturas de Wireshark:

```text title="/etc/hosts"
127.0.0.1   localhost
127.0.1.1   demog99.srdsig99.lab   demog99
127.0.0.1   www.srdsig99.lab
127.0.0.2   ocsp.srdsig99.lab
127.0.0.3   ...
```

### Grupos `wireshark` y `vboxsf`

Permite al usuario usar Wireshark y acceder a las carpetas compartidas:

```bash title="Grupos del usuario"
sudo usermod -aG wireshark alumnoG99
sudo usermod -aG vboxsf    alumnoG99
```

Cierra y abre la sesión para aplicar los cambios de grupo.

## Comprobación rápida

```bash title="Verificar el entorno"
hostnamectl                 # nombre del sistema
id                          # usuario y grupos (wireshark, vboxsf)
getent hosts demoG99        # resolución en /etc/hosts
ip -brief address           # direcciones de red (172.16.99.0/24)
```

!!! tip "Antes de cada entrega"
    Revisa que el prompt, el hostname y las capturas muestran el nombre personalizado del grupo y del alumno.
