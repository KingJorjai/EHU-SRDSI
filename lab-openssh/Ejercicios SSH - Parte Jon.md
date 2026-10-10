ssh1: la version configurada
ssh2: la version instalada de 0
Principales diferencias (en orden de aparicion al usar la opcion -v):
    - Al inicio la ssh1 lee la configuración en /etc/ssh/ssh_config, /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf y aplica la configuracion
    - ssh2 suelta un par de veces un error de fopen al intentar abrir .ssh/known_hosts
    - ssh1 comprueba que "localhost" es un host conocido y que se corresponde con la key ED25519
    - ssh2 en ese mismo punto busca los ficheros que contienen firmas de hosts en el sistema y al no encontrarlo determina que no se puede comprobar la autenticidad del host.
    - ssh2 avisa al usuario que no se conoce la key y pregunta a ver si quiere continuar.
    - ssh2 avisa que el soporte de SELinux esta deshabilitado
    - ssh2 suelta un warning de que se ha añadido permanentemente el host "localhost" a la lista de known hosts
    - ssh1 avisa de que no hay ninguna key del servidor nueva o revocada y carga variables de entorno (COLORTERM y LANG)
    - ssh2 en ese punto avisa que ha aprendido nuevas hostkeys y que las ha guardado


Al intentar conectarse, como ya no tenemos guardadas las claves del host, ssh avisa que no se puede determinar la autenticidad del host muestra la clave ED25519 y pregunta si queremos continuar. Al decir que si guarda la clave.