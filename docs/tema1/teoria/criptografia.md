# Criptografía

La criptografía aporta las primitivas con las que se construyen los servicios de seguridad: cifrado, integridad, autenticación y firma. Esta página resume las definiciones, la clasificación de los sistemas criptográficos y las construcciones que aparecen en el bloque 1.2 del Tema 1.

[:material-file-pdf-box: Transparencias — Introducción a la criptografía (PDF)](../../assets/pdf/SRDSI_T1-2.pdf){ .md-button }

## Definiciones ([p. 6](../../assets/pdf/SRDSI_T1-2.pdf#page=6))

| Término | Qué estudia |
| --- | --- |
| **Criptografía** | Técnicas para cifrar la información. |
| **Criptoanálisis** | Técnicas para romper el cifrado. |
| **Criptología** | Estudio conjunto de criptografía y criptoanálisis. |
| **Esteganografía** | Ocultar la existencia del mensaje, camuflándolo entre información de relleno. Su análisis es la estegoanálisis. |

Un **sistema criptográfico** transforma un texto claro en un criptograma mediante un algoritmo y una clave. Si la clave de cifrado y la de descifrado son la misma, la criptografía es **simétrica**; si son distintas, **asimétrica**.

## Principios

- **Principio de Kerckhoff (1883)**: todos los algoritmos deben ser públicos; solo las claves son secretas.
- Un esquema es **computacionalmente seguro** si romperlo cuesta más que el valor de la información o tarda más que su vida útil.
- Vías de ataque: debilidades matemáticas, fuerza bruta, análisis del criptograma e ingeniería social.

## Clasificación de los sistemas criptográficos ([p. 14](../../assets/pdf/SRDSI_T1-2.pdf#page=14))

| Criterio | Tipos |
| --- | --- |
| **Número de claves** | Simétrico (clave única, secreta, compartida o convencional) y asimétrico (clave pública). |
| **Tipo de operación** | Sustitución, transposición y funciones matemáticas. |
| **Procesado del texto claro** | Cifrado por bloques y cifrado de flujo. |
| **Proceso** | Reversible (cifrado) e irreversible (hash). |

## Sustitución y transposición

- **Sustitución**: se cambia cada símbolo por otro. Incluye cifrados **monoalfabéticos** (César), **polialfabéticos** (Vigenère) y **homofónicos** (el alfabeto de salida tiene más símbolos y son equiprobables).
- **Transposición**: se reordenan los símbolos del mensaje sin cambiarlos. Ejemplos clásicos: escítala de Esparta y transposición por columnas.

## Cifrado de flujo y cifrado por bloques

| Aspecto | Flujo (*stream*) | Bloques |
| --- | --- | --- |
| Unidad | Bit o byte | Bloque de longitud fija (64, 128, 192 bits…) |
| Idea | XOR del mensaje con un flujo pseudoaleatorio | Transformación del bloque con la clave |
| Relleno | No necesita | Necesita *padding* si el mensaje no es múltiplo |
| Sincronización | Síncrono o autosincronizante | Por bloques encadenados o independientes |
| Ejemplos | RC4, SEAL, ChaCha20 (RFC 7539) | AES, Twofish, Camellia, Blowfish, DES, 3DES, IDEA |

## Modos de operación ([p. 26](../../assets/pdf/SRDSI_T1-2.pdf#page=26))

| Modo | Características |
| --- | --- |
| **ECB** (*Electronic Codebook*) | Cada bloque se cifra por separado. Es determinista: bloques iguales producen criptogramas iguales y se filtran patrones. No usa IV. |
| **CBC** (*Cipher Block Chaining*) | Cada bloque se XOR con el criptograma anterior; el primero usa un IV. Requiere relleno y el cifrado es serial. |
| **CTR** (*Counter*) | Cifra un contador con nonce y hace XOR con el mensaje. Se comporta como un cifrado de flujo, permite paralelismo y no necesita relleno; el nonce no debe repetirse. |

Otros modos citados: CFB (*Cipher FeedBack*) y OFB (*Output Feedback*). ECB, CBC y CTR proporcionan **solo confidencialidad**.

## Criptografía simétrica y asimétrica

| | Simétrica | Asimétrica |
| --- | --- | --- |
| **Claves** | Una clave compartida para cifrar y descifrar | Par pública/privada: lo que cifra una lo descifra la otra |
| **Número de claves** | \(n(n-1)/2\) | \(2n\) |
| **Fortaleza** | Secreto y longitud de la clave | Dificultad de calcular la inversa de una función matemática |
| **Ventajas** | Rápida y eficiente | Resuelve el intercambio de claves y permite firma digital |
| **Desventajas** | Hay que distribuir la clave y el número de claves crece | Autenticación de la clave pública, proceso más lento y criptograma mayor |
| **Usos** | Confidencialidad, integridad y autenticación del mensaje | Intercambio de claves y firma digital |
| **Ejemplos** | AES, SEAL, DES, 3DES, RC5 | RSA, ElGamal, DSA, ECC |

La criptografía asimétrica depende de funciones matemáticas difíciles de invertir, pero está amenazada por la computación cuántica (algoritmo de Shor). De ahí el interés por la **criptografía post-cuántica** (NIST, RFC 9958).

## Funciones hash o MDC ([p. 40](../../assets/pdf/SRDSI_T1-2.pdf#page=40))

Una **función resumen** (*hash*) toma datos de tamaño arbitrario y devuelve un resumen de tamaño fijo. Debe ser fácil y rápida de calcular y difundir los bits de entrada.

- **Resistencia a preimagen**: dado \(h\), es inviable encontrar \(m\) con \(h = H(m)\).
- **Resistencia débil a colisiones**: dado \(m_0\), es difícil encontrar otro \(m\) con \(H(m_0) = H(m)\).
- **Resistencia fuerte a colisiones**: es inviable encontrar dos mensajes cualesquiera con el mismo resumen.

Algoritmos habituales: MD5, SHA-1, SHA-2 (SHA-224/256/384/512), SHA-3 y RIPEMD-160. La construcción **Merkle-Damgård** encadena bloques mediante una función de compresión; sufre el ataque de **extensión de longitud**. Alternativas: *sponge functions*, *wide-pipe* y HAIFA.

Usos: comprobar integridad, almacenar contraseñas (`/etc/shadow`), construir MAC, derivar claves (KDF) y reducir el coste de las firmas digitales.

## MAC ([p. 45](../../assets/pdf/SRDSI_T1-2.pdf#page=45))

Un **Message Authentication Code** es un hash con clave simétrica compartida:

\[
MAC = H_{K_{sim}}(M)
\]

Proporciona **autenticación del origen e integridad**, pero no confidencialidad ni no repudio; por tanto, **no es una firma digital**. Enfoques:

- **HMAC** (RFC 2104), estándar de facto en TLS e IPsec.
- **CMAC** (RFC 4493) y **GMAC** (RFC 4543), basados en cifrado por bloques.
- **UMAC** (RFC 4418), basado en *universal hashing*.

## Cifrado autenticado (AE) y AEAD ([p. 48](../../assets/pdf/SRDSI_T1-2.pdf#page=48))

Los modos **AE** (*Authenticated Encryption*) garantizan a la vez confidencialidad y autenticación. Estrategias de composición:

| Estrategia | Orden | Ejemplos |
| --- | --- | --- |
| **Hash-then-Encrypt** | Resumen y después cifrado | WEP |
| **MAC-then-Encrypt** | MAC y después cifrado | SSL/TLS |
| **Encrypt-then-MAC** | Cifrado y después MAC | IPsec, extensión TLS |
| **Encrypt\&MAC** | Cifrado y MAC independientes | SSH |
| **Integración** | Modo único | OCB (RFC 7253) |

**AEAD** (*Authenticated Encryption with Additional Data*) autentica también datos que no se cifran: direcciones IP, puertos, identificadores de sesión, versión y cabeceras del protocolo. Esquemas: **AES-GCM** (RFC 5288, NIST SP 800-38D), AES-CCM y ChaCha20/Poly1305 (RFC 8439). AES-GCM usa un contador y una función de hash de Galois para producir la etiqueta de autenticación.

## Ideas clave para el examen

- Kerckhoff: la seguridad reside en la clave, no en el secreto del algoritmo.
- Simétrica: rápida, pero con problema de distribución y \(n(n-1)/2\) claves.
- Asimétrica: resuelve distribución y firma, pero es lenta y exige validar la clave pública.
- ECB filtra patrones; CBC encadena con IV; CTR funciona como flujo y exige nonce único.
- Un hash no tiene clave; un MAC sí, pero no da no repudio.
- AEAD = confidencialidad + integridad + autenticación, con datos adicionales autenticados.
- La criptografía de clave pública es la más expuesta al futuro cuántico.

## Actividades relacionadas

- [Criptografía y benchmarks: Ascon](../actividades/criptografia.md)
- [Benchmarks de algoritmos](../../recursos/benchmarks.md)
- [GnuPG: cifrado, hashes y firmas](../actividades/gnupg.md)
- [Transparencias completas del bloque](../../assets/pdf/SRDSI_T1-2.pdf)
