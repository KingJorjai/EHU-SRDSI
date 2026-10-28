# Gestión de claves y PKI

El cifrado solo es tan fuerte como la gestión de sus claves. Este bloque cubre el ciclo de vida, el establecimiento y distribución de claves, los modelos de confianza y la infraestructura de clave pública (PKI) que sostiene certificados, revocación y validación.

[:material-file-pdf-box: Transparencias — Gestión de claves (PDF)](../../assets/pdf/SRDSI_T1-4.pdf){ .md-button }

## El problema de la distribución

- **Simétrica**: hay que establecer una clave compartida entre las partes.
- **Asimétrica**: hay que validar que una clave pública pertenece a su titular.

Soluciones: entrega en persona, **establecimiento de claves** (*key establishment*) y **distribución mediante un tercero de confianza** (*Trusted Third Party*). Para claves simétricas se usa un **KDC**; para asimétricas, un **certificado digital + PKI**. Modelos de confianza: distribuida (*web of trust*) o centralizada (Internet X.509 PKI). El ciclo de vida completo se recoge en NIST SP 800-57.

## Establecimiento de claves simétricas

| Mecanismo | Idea |
| --- | --- |
| **Key Transport** | Una parte genera la clave de sesión y la envía cifrada con la clave pública de la otra. |
| **Key Agreement / KEM** | Ambas partes contribuyen y obtienen la misma clave de sesión. |

En el acuerdo de clave, Alice y Bob generan sendos secretos parciales \(C_1\) y \(C_2\); la clave de sesión se obtiene combinándolos. NIST SP 800-227 recoge recomendaciones de KEM.

## Diffie-Hellman y ataque de intermediario ([p. 12](../../assets/pdf/SRDSI_T1-4.pdf#page=12))

Diffie-Hellman **no autenticado** (RFC 2631):

1. Alice y Bob conocen \(N\) y \(G\).
2. Alice elige \(a\) y envía \(I_A = G^a \bmod N\).
3. Bob elige \(b\) y envía \(I_B = G^b \bmod N\).
4. Ambos calculan \(K = I_B^a = I_A^b = G^{ab} \bmod N\).

El protocolo es vulnerable a **MiM**: Trudy establece una clave \(K_{AT}\) con Alice y otra \(K_{TB}\) con Bob, y descifra y reenvía el tráfico. La solución es autenticar el intercambio.

## Station-to-Station

**STS** añade autenticación a Diffie-Hellman mediante firmas sobre los valores intercambiados. Cada parte firma su valor público y el del otro, de modo que un intermediario no puede sustituirlos sin invalidar la firma. Otros protocolos basados en DH autenticado: STS-MAC, MQV, IKEv2, Oakley, SKEME y SIGMA.

## KDC y Kerberos ([p. 15](../../assets/pdf/SRDSI_T1-4.pdf#page=15))

Un **KDC** (*Key Distribution Center*) es un servidor de confianza que comparte una clave simétrica predistribuida con cada entidad y crea claves de sesión para las conexiones. Se usa típicamente en redes locales.

**Kerberos v5** (RFC 4120) incluye:

- **Authentication Server (AS)**: autentica al usuario.
- **Ticket-Granting Server (TGS)**: autoriza el acceso a los recursos y emite tickets.
- **Servidor final**: presta el servicio solicitado.

Desventajas: punto único de fallo, base de datos de claves, escala limitada (decenas de miles de usuarios), necesidad de canal seguro en la puesta en marcha y disponibilidad permanente.

## PKI y modelos de confianza ([p. 22](../../assets/pdf/SRDSI_T1-4.pdf#page=22))

Una **PKI** es el conjunto de hardware, software, personas, políticas y procedimientos para crear, gestionar, almacenar, distribuir y revocar certificados de clave pública en red.

| Modelo | Relación | Ventajas | Inconvenientes |
| --- | --- | --- | --- |
| **Jerárquico** | CAs subordinadas a una raíz; confianza en la raíz | Escalable, camino determinista y corto, certificados pequeños | Si se compromete la raíz, cae toda la PKI; acuerdo político difícil |
| **Malla** (*mesh*) | Relación *peer to peer* entre CAs | Fácil añadir CAs; una CA comprometida no arrastra el resto | Camino complejo y no determinista; certificados más largos |

## Web of trust y PGP

En PGP/GnuPG el modelo es **distribuido**: cada usuario decide en quién confía y puede firmar claves públicas de otros, actuando como una CA. Distingue dos niveles:

- **Validez de la clave**: la firma valida esa clave concreta.
- **Confianza en el propietario** (*trust*): se confía en las claves firmadas por esa persona, con distintos niveles.

Un certificado PGP lo emite el propietario y lo firma él mismo (*self-signature*). Las claves se guardan en *keyrings* público y privado. Una clave nueva se valida si está firmada por una clave de plena confianza o por tres de confianza marginal, y si el camino hasta nuestra clave tiene cinco pasos o menos (valores configurables). Desventajas: comunidad reducida, sin validez legal y confianza subjetiva.

Distribución PGP: **key servers** (tradicionales como Hockeypuck y modernos como Hagrid, protocolo HKP/HKPS en TCP 11371), **Web Key Directory (WKD)** por HTTPS a partir del correo y **OpenPGP CA** para gestión local.

## Certificados X.509, CSR y roles ([p. 40](../../assets/pdf/SRDSI_T1-4.pdf#page=40))

Un **certificado digital** asocia una clave pública y otros datos con la identidad de su propietario, firmado por una CA:

\[
Cert_A = [Pub_A, ID_A, Priv_{CA}(Pub_A, ID_A)]
\]

El formato X.509 v3 (RFC 5280) incluye clave pública, nombre del titular (CN y Subject Alternative Name), firma del emisor, fechas de validez, nombre de la CA, versión y extensiones. Una **CSR** (RFC 2986, formato PKCS#10) no es un certificado: es una solicitud firmada con la clave privada del solicitante que contiene su clave pública e identidad.

| Rol | Función |
| --- | --- |
| **CA** | Emite y revoca certificados; publica su certificado y sus CRL. |
| **RA** | Registra usuarios, verifica datos y autoriza la asociación clave-identidad; no emite. |
| **VA** | Informa en línea del estado de un certificado. |
| **Repositorio** | Almacena certificados y CRL. |

La **CPS** (RFC 7382) declara las prácticas de certificación. Una CA raíz emite un certificado autofirmado y suele permanecer *offline*. Los certificados de CA subordinada o servidor se solicitan a la CA; los personales pueden entregarse como PKCS#12 (`.p12`/`.pfx`) o generarse en un dispositivo seguro (smartcard, DNIe).

## Revocación y validación ([p. 51](../../assets/pdf/SRDSI_T1-4.pdf#page=51))

| Mecanismo | Descripción |
| --- | --- |
| **CRL** (RFC 5280) | Lista firmada por la CA con los certificados revocados no caducados. |
| **OCSP** (RFC 6960) | Consulta en línea del estado de un certificado. |
| **OCSP Stapling** (RFC 6066) | El servidor obtiene la respuesta OCSP y la adjunta al certificado. |
| **OCSP Must-Staple** (RFC 7633) | Extensión que obliga al servidor a incluir la respuesta; si no, el cliente rechaza la conexión. |

Los certificados de vida corta (7 días o menos) hacen innecesaria la revocación según las normativas. En segundo plano, navegadores como Firefox usan CRLite u OneCRL y Chrome usa CRLSets para comprobar revocaciones localmente.

La **validación** comprueba: dominio (SAN frente a CN), camino de certificación (construcción y validación), periodo de validez, extensiones críticas, uso de la clave (*key usage*), longitud del camino y estado de revocación (CRL u OCSP). El camino va desde una CA de confianza hasta el certificado presentado (RFC 4158).

## Ideas clave para el examen

- Simétrica: distribuir una clave compartida; asimétrica: validar una clave pública.
- Diffie-Hellman sin autenticar es vulnerable a MiM; STS añade firmas.
- KDC centraliza claves simétricas; Kerberos usa AS, TGS y servidor final.
- PKI jerárquica: camino corto y determinista, pero la raíz es un punto crítico.
- Web of trust: confianza distribuida, dos niveles (validez de clave y trust del propietario).
- La CSR solicita certificación; no es un certificado.
- CRL es offline; OCSP es online; stapling y must-staple acercan la respuesta al servidor.
- Validar un certificado es más que comprobar fechas: cadena, extensiones, uso y revocación.

## Actividades relacionadas

- [Laboratorio PKI](../lab-pki/index.md)
- [Estudio de una CA](../actividades/estudio-ca.md)
- [Gestión de claves con GnuPG](../actividades/gnupg.md)
- [Comandos OpenSSL para PKI](../comandos/openssl.md)
- [Transparencias completas del bloque](../../assets/pdf/SRDSI_T1-4.pdf)
