# Certificados y claves de laboratorio

Inventario de los certificados publicados en `docs/assets/certs/`. Son **sintéticos**, se generaron para las prácticas y solo valen para el laboratorio. No los uses en ningún sistema real.

!!! danger "Solo laboratorio"
    Algunas claves privadas se publican sin passphrase. Cualquiera puede leerlas. No protegen nada real: son material didáctico.

## `lab-ssl`: dos CAs independientes

El laboratorio SSL usa una CA para el servidor y otra distinta para el cliente. No forman una cadena entre sí.

| Fichero | CN | Emisor | Validez (GMT) | Serial |
| --- | --- | --- | --- | --- |
| [`s-ca_cert.pem`](../assets/certs/lab-ssl/s-ca_cert.pem) | `CA_SERV-SRDSI` | él mismo (autofirmado) | 2026-10-19 → 2037-10-01 | `69A15E5ACC9A15D1CBFA5E7221AAC361880B3058` |
| [`c-ca_cert.pem`](../assets/certs/lab-ssl/c-ca_cert.pem) | `CA_CLI-SRDSI` | él mismo (autofirmado) | 2026-10-19 → 2037-10-01 | `65D3E2A35AEDB9C6A2B59C1EE8BBAC0B10DAEABE` |
| [`s_cert.pem`](../assets/certs/lab-ssl/s_cert.pem) | `SERV-SRDSI` | `CA_SERV-SRDSI` | 2026-10-19 → 2037-10-01 | `865EE37EE2F16ABE` |
| [`c_cert.pem`](../assets/certs/lab-ssl/c_cert.pem) | `CLI-SRDSI` | `CA_CLI-SRDSI` | 2026-10-19 → 2037-10-01 | `16B61DD2792713CF` |

Claves privadas asociadas:

| Fichero | Uso |
| --- | --- |
| [`s_key.pem`](../assets/certs/lab-ssl/s_key.pem) | Clave del servidor `SERV-SRDSI`. |
| [`c_key.pem`](../assets/certs/lab-ssl/c_key.pem) | Clave del cliente `CLI-SRDSI`; **no se usa** en la versión entregada. |

Detalles:

- `s_cert.pem` está firmado por `CA_SERV-SRDSI`; el cliente confía en `s-ca_cert.pem`.
- El cliente **no presenta certificado**: `cli-infouser` no carga `c_cert.pem`/`c_key.pem`, y `serv-infouser` no pide certificado de cliente.
- Sustituidos el 2026-10-19; caducan el **2037-10-01**.
- El escenario 03 del laboratorio consiste en usar `c-ca_cert.pem` en el cliente en lugar de `s-ca_cert.pem`; como no firma al servidor, aparece `unknown_ca` (48).

## `lab-certs`: raíz, subCA y extremos

Jerarquía `CA-SRDSI` → `SUBCA-SRDSI` → `server` / `client`. La raíz y la subCA son RSA; `serverpq` usa una clave post-cuántica.

| Fichero | CN | Emisor | Validez (GMT) | Clave / firma | Serial |
| --- | --- | --- | --- | --- | --- |
| [`ca-root.crt`](../assets/certs/lab-certs/ca-root.crt) | `CA-SRDSI` | él mismo (autofirmado) | 2026-10-17 22:58:34 → 2036-10-14 22:58:34 | RSA / SHA-256 | `87F923EF08E85E1D43D40971576CF882` |
| [`subca.crt`](../assets/certs/lab-certs/subca.crt) | `SUBCA-SRDSI` | `CA-SRDSI` | 2026-10-17 22:59:04 → 2036-10-14 22:59:04 | RSA / SHA-256 | `87F923EF08E85E1D43D40971576CF884` |
| [`server.crt`](../assets/certs/lab-certs/server.crt) | `www.srdsi.lab` | `SUBCA-SRDSI` | 2026-10-17 22:59:30 → 2036-10-14 22:59:30 | RSA / SHA-256 | `6EB2AFC887B6BC7163C554D225A45512` |
| [`client.crt`](../assets/certs/lab-certs/client.crt) | `client` | `SUBCA-SRDSI` | 2026-10-17 22:59:34 → 2036-10-14 22:59:34 | RSA / SHA-256 | `6EB2AFC887B6BC7163C554D225A45513` |
| [`serverpq.crt`](../assets/certs/lab-certs/serverpq.crt) | `www.srdsi.lab` | `SUBCA-SRDSI` | 2026-10-17 23:01:14 → 2036-10-14 23:01:14 | **ML-DSA-65** / SHA-256 con RSA | `6EB2AFC887B6BC7163C554D225A45514` |

Claves privadas (sin passphrase):

| Fichero | Uso |
| --- | --- |
| [`server.key`](../assets/certs/lab-certs/server.key) | Clave RSA del servidor `www.srdsi.lab`. |
| [`client.key`](../assets/certs/lab-certs/client.key) | Clave RSA del cliente `client`. |
| [`serverpq.key`](../assets/certs/lab-certs/serverpq.key) | Clave **ML-DSA-65** del servidor PQC. |

`ca-root.crt` y `subca.crt` no tienen clave privada en el repositorio: solo se publica la parte pública de la cadena.

## Inspeccionar y verificar

```bash
# Sujeto, emisor, fechas y serial
openssl x509 -in s_cert.pem -noout -subject -issuer -dates -serial

# Algoritmo de clave y de firma (útil para serverpq)
openssl x509 -in serverpq.crt -noout -text | \
  grep -E 'Public Key Algorithm|Signature Algorithm'

# Cadena de lab-certs: la raíz sola NO basta
openssl verify -CAfile ca-root.crt server.crt                      # falla
openssl verify -CAfile ca-root.crt -untrusted subca.crt server.crt # OK
cat ca-root.crt subca.crt > /tmp/ca-chain.pem
openssl verify -CAfile /tmp/ca-chain.pem server.crt client.crt     # OK
```

```console
server.crt: OK
client.crt: OK
```

## Gotchas

- **Claves sin passphrase**: `server.key`, `client.key` y `serverpq.key` se pueden leer directamente. No las cifres para el laboratorio.
- **`server.crt` está firmado por la subCA**, no por la raíz. `openssl verify -CAfile ca-root.crt server.crt` falla con `unable to get local issuer certificate`. Pasa la cadena (`-CAfile` con raíz + subCA, o `-untrusted subca.crt`) y, en TLS, `-cert_chain subca.crt`.
- **Sin SAN**: los certificados solo tienen `CN` (`www.srdsi.lab`, `client`). OpenSSL acepta el CN como respaldo, pero los navegadores y las CAs públicas exigen `subjectAltName`. No uses estos certificados fuera del laboratorio.
- **`server2` no existe**: el [`README`](../assets/certs/lab-certs/README) menciona `server2.crt`/`server2.key` para `www.srdsi2.lab`, pero no están en el repositorio. No cuentes con ellos.
- **Dos CAs en `lab-ssl`**: `CA_SERV-SRDSI` y `CA_CLI-SRDSI` son independientes. Mezclarlas produce `unknown_ca` (48).
- **`c_key.pem` no se usa**: el cliente del laboratorio SSL no presenta certificado; solo verifica al servidor.
- **Caducidad**: `lab-ssl` caduca en 2037 y `lab-certs` en 2036. Si el reloj de la VM está mal, aparecerá `certificate_expired` (45).
- **`serverpq`**: la clave pública es ML-DSA-65, pero el certificado lo firma la subCA con RSA (`sha256WithRSAEncryption`). Solo funciona con TLS 1.3. Su clave ocupa 5604 bytes y el certificado 14877 bytes, muy por encima de RSA/ECDSA.

## Enlaces

- [Código del laboratorio](codigo.md)
- [OpenSSL TLS/DTLS](../tema2/comandos/openssl-tls.md)
- [Ejercicios TLS y DTLS](../tema2/actividades/tls-dtls.md)
- [Laboratorio SSL: certificados](../tema2/lab-ssl/codigo.md)
- [Alertas TLS](../chuletas/alertas-tls.md)
