# RECAPTURA — Guion para re-ejecutar el laboratorio en la VM y verificar capturas (Tarea T3)

Estado de la VM detectado el 2026-10-10 (solo lectura, sin arrancar):

- `VBoxManage` existe: `/usr/bin/VBoxManage`.
- VM registrada: `"SRDSI_Debian13" {574fa4d5-7569-48cd-909c-bbbd69df6780}`.
- Estado: `powered off` (desde 2026-10-02). Disco `SRDSI_Debian13.vdi` 6,4 GB en `~/Documents/SRDSI/SRDSI_Debian13/`.
- Snapshots: la VM **no tiene snapshots**, pero `VBoxManage snapshot` está soportado (carpeta `Snapshots/` configurada). Ver §5 (solo documentado, no ejecutado).

No se ha iniciado ni modificado nada.

## (a) Arranque y terminal fondo blanco

1. Arrancar (elige una):
   ```bash
   VBoxManage startvm "SRDSI_Debian13" --type gui
   # o abrir VirtualBox y pulsar Iniciar en SRDSI_Debian13
   ```
2. Entrar como `user1` (su contraseña de login, no es la de la PKI).
3. Comprobar prompt personalizado:
   ```bash
   whoami; hostname; echo "$PS1"
   # esperado: user1@bocata-jamon:~$
   ```
   Si el prompt no es ese, restaurarlo para que las capturas coincidan (p. ej. `PS1='\u@\h:\w\$ '` y hostname `bocata-jamon`, dominio `bocata-jamon.srdsi.lab`).
4. Terminal fondo blanco (exigido por el enunciado): en GNOME Terminal → Preferencias del perfil → Colores → fondo `#FFFFFF`, texto `#000000`; o paleta clara. Desactivar transparencia. Maximizar ventana antes de capturar para que el tamaño sea comparable a las originales.
5. Verificar scripts y PKI heredada:
   ```bash
   ls ~/PKI_root ~/PKI_root/PKI_sub ~/PKI_scripts/
   ls ~/PKI_scripts/   # gen_solicitud.sh  emitir_cert.sh  revocar_cert.sh
   openssl version     # >= 1.1.1 (gen_solicitud.sh usa -addext)
   ```

## (b) Guion numerado listo para pegar (valores del ODT)

Contraseñas del laboratorio (ver §(e), no reutilizar fuera):

| Clave | Valor ODT | Dónde se pide |
|---|---|---|
| `P_ROOT` | `user1Root_CA` | clave privada de la CA raíz + firma `ca -selfsign` |
| `P_SUB` | `user1Sub_CA` | clave privada de la subCA + firma `emitir_cert.sh` (`CA_PASS`) |
| `P_PACO` | `Contraseña segura1234_` | clave de Paco (`KEY_PASS`) y su `.p12` (`P12_PASS`, por defecto = `KEY_PASS`) |
| `P_OCSP` | `user1Sub_CA_ocsp` | clave del respondedor OCSP (`KEY_PASS`) |

### Paso 1 — CA raíz + subCA (cubre `paso1-01`, `paso1-02`)

```bash
# 1. Estructura
mkdir -p ~/PKI_root/{private,DB,certs,solicitudes,certs.p12,PKI_sub/{private,DB,certs,certs.p12}}
chmod 700 ~/PKI_root/private ~/PKI_root/PKI_sub/private
touch ~/PKI_root/DB/index.txt ~/PKI_root/PKI_sub/DB/index.txt

# 2. Series (4 ficheros rand -hex 16; nombres según ODT: serie_emitidos/revocados x2 niveles)
openssl rand -hex 16 > ~/PKI_root/DB/serial
openssl rand -hex 16 > ~/PKI_root/DB/crlnumber
openssl rand -hex 16 > ~/PKI_root/PKI_sub/DB/serial
openssl rand -hex 16 > ~/PKI_root/PKI_sub/DB/crlnumber

# 3. Configs (copiar las del ODT a ~/PKI_root/ y ~/PKI_root/PKI_sub/ca-sub_openssl.cnf)
#    cp ... (misma ruta que en el ODT)

# 4. Clave + CSR raíz (contraseña → P_ROOT = user1Root_CA)
openssl req -new -newkey rsa:3072 -keyout ~/PKI_root/private/ca-root.key -out ~/PKI_root/solicitudes/ca-root.csr -config ~/PKI_root/ca-root_openssl.cnf
#    subject del ODT (C=ES, O="Bocata de Jamon", CN raíz según ODT)

# 5. Autofirma raíz → PASO1-01 (contraseña → P_ROOT)
openssl ca -selfsign -batch -config ~/PKI_root/ca-root_openssl.cnf -extensions ca_ext -in ~/PKI_root/solicitudes/ca-root.csr -out ~/PKI_root/certs/ca-root.crt
mv ~/PKI_root/certs/01.pem ~/PKI_root/certs/ca-root.crt 2>/dev/null || true
openssl crl -in ~/PKI_root/certs/ca-root.crt 2>/dev/null; openssl ca -gencrl -config ~/PKI_root/ca-root_openssl.cnf -out ~/PKI_root/certs/ca-root.crl

# 6. Clave + CSR subCA (contraseña → P_SUB = user1Sub_CA)
openssl req -new -newkey rsa:3072 -keyout ~/PKI_root/PKI_sub/private/ca-sub.key -out ~/PKI_root/PKI_sub/solicitudes/ca-sub.csr -config ~/PKI_root/PKI_sub/ca-sub_openssl.cnf

# 7. Firma subCA → PASO1-02 (contraseña → P_ROOT)
openssl ca -batch -config ~/PKI_root/ca-root_openssl.cnf -extensions subca_ext -in ~/PKI_root/PKI_sub/solicitudes/ca-sub.csr -out ~/PKI_root/PKI_sub/certs/ca-sub.crt
```

### Paso 2 — Usuario Paco (cubre `paso2-01` … `paso2-04`)

```bash
# 8. Solicitud Paco → PASO2-01 (contraseña → P_PACO = "Contraseña segura1234_")
KEY_PASS='Contraseña segura1234_' ~/PKI_scripts/gen_solicitud.sh -t usuario -n "Paco Antonio Gutierrez" -e paco@bocata-jamon.srdsi.lab -C ES -O "Bocata de Jamon" -o ~/PKI_root/PKI_sub/solicitudes
# genera: clave-privada-Paco_Antonio_Gutierrez.key + solicitud-Paco_Antonio_Gutierrez.csr

# 9. Emisión user_ext → PASO2-02 + PASO2-03 (contraseña CA → P_SUB = user1Sub_CA)
CA_PASS='user1Sub_CA' ~/PKI_scripts/emitir_cert.sh ~/PKI_root/PKI_sub/solicitudes/solicitud-Paco_Antonio_Gutierrez.csr user_ext
# genera .crt + .p12 (P12_PASS por defecto = KEY_PASS = P_PACO)

# 10. Revocación → PASO2-04 + regenerar CRL
~/PKI_scripts/revocar_cert.sh ~/PKI_root/PKI_sub/certs/*Paco*.crt cessationOfOperation
openssl ca -gencrl -config ~/PKI_root/PKI_sub/ca-sub_openssl.cnf -out ~/PKI_root/PKI_sub/certs/ca-sub.crl
```

### Paso 3 — OCSP (cubre `paso3-01` … `paso3-05`)

```bash
# 11. /etc/hosts: ocsp → 127.10.0.1
echo "127.10.0.1  ocsp ocsp.bocata-jamon.srdsi.lab" | sudo tee -a /etc/hosts

# 12. Solicitud servicio OCSP → PASO3-01 (contraseña → P_OCSP = user1Sub_CA_ocsp)
mkdir -p ~/PKI_root/PKI_sub/ocsp
KEY_PASS='user1Sub_CA_ocsp' ~/PKI_scripts/gen_solicitud.sh -t servicio -n "ocsp" -d ocsp.bocata-jamon.srdsi.lab -e ocsp@bocata-jamon.srdsi.lab -C ES -S GP -L Donostia -O "Bocata de Jamon" -U PKI -o ~/PKI_root/PKI_sub/ocsp
# OJO: -d/-e/-C/-S/-L/-O/-U con los valores exactos del ODT; la política de la subCA exige C y O iguales a los de la CA.

# 13. Emisión ocsp_ext → PASO3-02 (contraseña CA → P_SUB)
CA_PASS='user1Sub_CA' ~/PKI_scripts/emitir_cert.sh ~/PKI_root/PKI_sub/ocsp/solicitud-ocsp.csr ocsp_ext

# 14. Mover clave a private/ + chmod 600
mv ~/PKI_root/PKI_sub/ocsp/clave-privada-ocsp.key ~/PKI_root/PKI_sub/private/
chmod 600 ~/PKI_root/PKI_sub/private/clave-privada-ocsp.key

# 15. Arrancar respondedor → PASO3-03 (puerto 4747)
openssl ocsp -port 4747 -index ~/PKI_root/PKI_sub/DB/index.txt -CA ~/PKI_root/PKI_sub/certs/ca-sub.crt -rsigner ~/PKI_root/PKI_sub/certs/ocsp.crt -ndays 7 &
# (segunda terminal para lo siguiente)

# 16. Cadena + consulta → PASO3-04
cat ~/PKI_root/PKI_sub/certs/ocsp.crt ~/PKI_root/PKI_sub/certs/ca-sub.crt > /tmp/chain.crt
openssl ocsp -issuer ~/PKI_root/PKI_sub/certs/ca-sub.crt -cert ~/PKI_root/PKI_sub/certs/ocsp.crt -url http://127.10.0.1:4747 -CAfile /tmp/chain.crt -resp_text
# esperado: ocsp.crt: good

# 17. Verificación final → PASO3-05 (repetir la consulta del punto 16 tras recargar/CRL)
```

Si algún DN exacto de CA difiere, copiarlo literal del ODT antes de pegar: lo crítico es que C=`ES` y O=`Bocata de Jamon` coincidan con la política de la subCA, y que los `-n/-d/-e` sean los de arriba.

## (c) Checklist captura-por-captura (`informe/img/pasoX-NN.png`)

Qué debe verse igual en cada recaptura:

- [ ] `paso1-01.png` (firma raíz autofirmada): prompt `user1@bocata-jamon:~$`, comando `openssl ca -selfsign … -extensions ca_ext`, salida `Using configuration… / Check that the request matches the signature / Certificate is to be certified until …`, `1 out of 1 certificate requests certified, commit? [y/n] y`, fichero `ca-root.crt` creado.
- [ ] `paso1-02.png` (emisión subCA): mismo prompt, comando `openssl ca -batch … -extensions subca_ext`, subject de la subCA visible, `ca-sub.crt` creado.
- [ ] `paso2-01.png` (solicitud usuario): `gen_solicitud.sh -t usuario -e paco@… -n "Paco Antonio Gutierrez" -C ES -O "Bocata de Jamon"`, salida con `clave-privada-Paco_Antonio_Gutierrez.key` + `solicitud-Paco_Antonio_Gutierrez.csr`, subject `CN=Paco Antonio Gutierrez`.
- [ ] `paso2-02.png` (emisión usuario): `emitir_cert.sh …solicitud-Paco_Antonio_Gutierrez.csr user_ext`, subject Paco, serial y fichero `.crt`.
- [ ] `paso2-03.png` (confirmación + PKCS#12): `1 out of 1 … commit? y`, `.p12` generado junto al `.crt`.
- [ ] `paso2-04.png` (revocación): `revocar_cert.sh … cessationOfOperation`, `Revoking Certificate …`, `Data Base Updated`, + `openssl ca -gencrl` posterior.
- [ ] `paso3-01.png` (solicitud OCSP): `gen_solicitud.sh -t servicio -d ocsp… -e ocsp@… -C ES -S GP -L Donostia -O … -U PKI`, subject `CN=ocsp`, SAN `DNS:ocsp…`.
- [ ] `paso3-02.png` (emisión OCSP): `emitir_cert.sh … ocsp_ext`, `ocsp.crt` creado.
- [ ] `paso3-03.png` (arranque respondedor): `openssl ocsp -port 4747 …`, `Waiting for OCSP client connections…` en puerto 4747.
- [ ] `paso3-04.png` (consulta OCSP): `openssl ocsp -CAfile … -resp_text`, `OCSP Response Status: successful`, `Cert Status: good`, `This Update/Next Update`.
- [ ] `paso3-05.png` (verificación final): segunda consulta con `…: good` claramente visible.
- [ ] Global: fondo blanco, prompt `user1@bocata-jamon`, mismos nombres de fichero, `openssl version` ≥ 1.1.1 si se muestra.

## (d) Exportar las recapturas a `informe/img/recaptura/`

1. En la VM, captura con la herramienta del SO huésped (p. ej. `gnome-screenshot -w` por ventana, o Mayús+ImprPant) con fondo blanco ya configurado.
2. Formato: **PNG sin recomprimir ni convertir** (igual que las originales del ODT).
3. Nombres (espejo 1:1 + OCSP ya incluido en paso3):
   ```
   informe/img/recaptura/paso1-01.png
   informe/img/recaptura/paso1-02.png
   informe/img/recaptura/paso2-01.png
   informe/img/recaptura/paso2-02.png
   informe/img/recaptura/paso2-03.png
   informe/img/recaptura/paso2-04.png
   informe/img/recaptura/paso3-01.png
   informe/img/recaptura/paso3-02.png
   informe/img/recaptura/paso3-03.png
   informe/img/recaptura/paso3-04.png
   informe/img/recaptura/paso3-05.png
   ```
4. Copiar al host: carpeta compartida, `scp`, o arrastrar desde VirtualBox Guest Additions a `/home/jorjai/Documents/SRDSI/Lab PKI/informe/img/recaptura/`.
5. No tocar `informe/img/pasoX-NN.png` (originales de Jon): las nuevas van solo en `recaptura/`.

## §5 Snapshot previo (solo documentado — NO ejecutado)

```bash
VBoxManage snapshot "SRDSI_Debian13" take "pre-recaptura-$(date +%F)" --description "Antes de re-ejecutar el lab PKI Fase 1 (T3)"
VBoxManage snapshot "SRDSI_Debian13" list
# Restaurar si algo sale mal:
# VBoxManage controlvm "SRDSI_Debian13" poweroff
# VBoxManage snapshot "SRDSI_Debian13" restore "pre-recaptura-<fecha>"
```

Recomendado porque el laboratorio muta `index.txt`/`serial`/`crlnumber` y emite certificados: con snapshot se puede repetir la recaptura desde estado limpio.

## (e) Nota de seguridad

Las contraseñas de este guion (`user1Root_CA`, `user1Sub_CA`, `Contraseña segura1234_`, `user1Sub_CA_ocsp`) son las del laboratorio docente, extraídas del ODT. **No reutilizarlas fuera del lab** (ni como contraseña real ni en otros servicios). Pasarlas siempre por variables de entorno (`KEY_PASS`, `CA_PASS`, `P12_PASS`), nunca con `-p` (queda visible en `ps`/historial). Las claves y `.p12` quedan con modo 600 (`umask 077` de los scripts): no cambiarles permisos ni copiarlas fuera de la VM salvo al `.p12` de Paco para su entrega.
