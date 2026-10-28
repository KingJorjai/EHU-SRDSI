# Actividad: criptografía ligera y Ascon

[:material-file-pdf-box: Enunciado de la actividad (PDF)](../../assets/pdf/actividad-criptografia.pdf){ .md-button }
[:material-file-pdf-box: Informe Ascon (PDF)](../../assets/pdf/actividad-ascon.pdf){ .md-button }

La actividad de T1 pide un informe breve sobre un algoritmo criptográfico y un análisis de rendimiento comparativo. Esta página resuelve el caso de **Ascon**, el ganador del proceso de criptografía ligera del NIST, y enlaza los *benchmarks* del repositorio.

## 1. Resumen del informe: qué es Ascon

Ascon es una **familia de algoritmos simétricos** diseñada para dispositivos con recursos limitados (IoT, sensores, tarjetas, wearables). Unifica en un mismo diseño:

- **AEAD** (*Authenticated Encryption with Associated Data*): cifra y autentica a la vez, con datos asociados que se autentican pero no se cifran.
- **Hash y XOF** (*Extendable Output Function*): funciones de resumen y salida de longitud variable.

Fue presentada en 2014 y seleccionada por el NIST en febrero de 2023 como base de la criptografía ligera. El estándar se publicó como **NIST SP 800-232** en agosto de 2025.

### 1.1 La permutación Ascon-p

El estado interno tiene **320 bits**, organizados como una matriz de **5 palabras de 64 bits**. Cada ronda aplica tres capas:

1. **Constante de ronda**: XOR con una constante distinta en cada ronda, para romper simetrías.
2. **Capa no lineal**: una S-box de 5 bits (χ₅) aplicada en paralelo a las 64 columnas. Es la única operación no lineal y la responsable de la resistencia frente a criptoanálisis.
3. **Difusión lineal**: desplazamientos circulares y XOR sobre cada palabra de 64 bits, para propagar los cambios por todo el estado.

El número de rondas depende de la fase: **12 rondas** en inicialización y finalización, y **6 u 8** en el procesamiento intermedio.

### 1.2 Modos de operación

| Modo | Uso | Idea |
| --- | --- | --- |
| **Esponja** (*sponge*) | Hash y XOF | Se «absorben» los datos en el estado y se «escurre» la salida. |
| **Dúplex** (*duplex*) | AEAD | Combina absorción y expulsión para procesar datos asociados, texto claro, texto cifrado y etiqueta de autenticación. |

### 1.3 Variantes

El informe recoge cuatro variantes principales:

| Variante | Tipo | Tasa (r) | Rondas (a, b) | Uso |
| --- | --- | ---: | ---: | --- |
| Ascon-128 | AEAD | 64 bits | (12, 6) | Cifrado autenticado con clave de 128 bits |
| Ascon-128a | AEAD | 128 bits | (12, 8) | Cifrado autenticado de alto rendimiento |
| Ascon-Hash | Hash | 64 bits | (12, 12) | Hash de 256 bits |
| Ascon-Xof | XOF | 64 bits | (12, 12) | Salida extensible de longitud variable |

La nomenclatura del estándar NIST y la de la implementación de referencia no siempre coincide letra a letra. En los *benchmarks* de este repositorio aparecen los binarios `asconaead128` y `asconhash256`; se etiquetan tal cual para no confundir variantes.

### 1.4 Seguridad

- Los mejores ataques conocidos contra la inicialización reducen las rondas a **7 o menos**; el diseño usa 12, así que mantiene margen.
- El diseño **no usa tablas de búsqueda** y la S-box es de bajo grado, lo que facilita contramedidas de **canal lateral** como el enmascaramiento (*masking*).
- La seguridad depende de la variante, la tasa y el número de rondas; no se debe reducir rondas «para ir más rápido» en producción.

### 1.5 Aplicaciones

- dispositivos médicos (implantes, monitores);
- RFID y tarjetas inteligentes;
- wearables;
- redes de sensores IoT industriales y domóticas;
- integración en protocolos como COSE (CBOR Object Signing and Encryption) para el ecosistema IoT.

## 2. Análisis de rendimiento

### 2.1 Resultados del informe (MB/s)

El informe comparó Ascon con AES-GCM, ChaCha20-Poly1305 y SHA-256 en la misma máquina (Debian 13, OpenSSL 3.5.7, Intel i7-1360P a ~2,6 GHz):

| Algoritmo | Tipo | 64 B (MB/s) | 1024 B (MB/s) |
| --- | --- | ---: | ---: |
| Ascon-AEAD128 | AEAD | 329 | 553 |
| AES-128-GCM | AEAD | 178 | 1.716 |
| ChaCha20-Poly1305 | AEAD | 343 | 1.246 |
| Ascon-Hash256 | Hash | 116 | 186 |
| SHA-256 | Hash | 217 | 841 |

Lectura:

- **Mensajes cortos (64 B):** Ascon-AEAD128 (329 MB/s) está muy cerca de ChaCha20-Poly1305 (343 MB/s) y supera a AES-128-GCM (178 MB/s). En mensajes pequeños pesa mucho la preparación de la clave y del estado; Ascon tiene poca sobrecarga.
- **Bloques grandes (1 KB):** AES-GCM escala gracias a **AES-NI** y supera claramente a Ascon. ChaCha20-Poly1305 también supera a Ascon. En un servidor con aceleración hardware, AES-GCM es la opción natural.
- **Hash:** Ascon-Hash256 es más lento que SHA-256 en esta máquina, pero su ventaja no es la velocidad bruta, sino el tamaño de código y el consumo en dispositivos sin aceleración.
- **Tamaño de código:** el informe destaca que Ascon es aproximadamente **1,4× más compacto** que ChaCha20-Poly1305 y **3,3× más compacto** que AES-128-GCM en ARM. En IoT, la memoria flash y la energía importan más que los MB/s.

### 2.2 Resultados de `ascon-c` (ciclos/byte)

El log [benchmark_ascon.txt](../../assets/benchmarks/benchmark_ascon.txt) recoge la implementación de referencia `ascon-c` v1.2 (`opt32` y `lowsize`) midiendo **ciclos por byte**. Cuanto menor, mejor:

| Binario | 1 B | 8 B | 16 B | 32 B | 64 B | 1536 B | 2048 B |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `asconaead128_opt32` | 220 | 26 | 19 | 11 | 7,9 | 4,8 | 4,7 |
| `asconaead128_opt32_lowsize` | 247 | 31 | 20 | 13 | 8,8 | 5,8 | 5,0 |
| `asconhash256_opt32` | 444 | 71 | 40 | 29 | 22,5 | 15,4 | 19,1 |
| `asconhash256_opt32_lowsize` | 523 | 70 | 49 | 33 | 24,1 | 19,2 | 14,0 |

Interpretación:

- **Mensajes de 1 byte**: el coste fijo de inicialización domina (220–523 ciclos/byte). No tiene sentido medir throughput con mensajes tan pequeños.
- **A partir de 1 KiB**: el AEAD se estabiliza alrededor de **4,7–5,0 ciclos/byte**; el hash, en **14–19 ciclos/byte**. El hash es más lento porque procesa a una tasa menor y usa más rondas en la fase intermedia.
- **`opt32` frente a `lowsize`**: la variante *lowsize* reduce el tamaño de código a cambio de algo más de coste. En AEAD, a 2048 B, la diferencia es pequeña (4,7 frente a 5,0 ciclos/byte, ~6 %); en hash los valores son más ruidosos y no permiten concluir una diferencia estable.
- Los valores de 1536 B y 2048 B muestran variabilidad entre repeticiones (por ejemplo, el hash `opt32` pasa de 15,4 a 19,1 ciclos/byte). Para comparar implementaciones hay que fijar tamaño, compilador, flags y número de repeticiones.

### 2.3 Comparativa global

| Criterio | Ascon | AES-GCM | ChaCha20-Poly1305 | SHA-256 |
| --- | --- | --- | --- | --- |
| Tipo | AEAD + hash/XOF | AEAD | AEAD | Hash |
| Aceleración hardware | No habitual | AES-NI en x86, extensiones ARM | NEON/vectorización | SHA extensions |
| Mensajes cortos | Muy competitivo | Peor sin AES-NI | Muy competitivo | — |
| Bloques grandes | Correcto, pero inferior | Excelente con AES-NI | Muy bueno en software | Excelente |
| Huella de código | Muy pequeña | Mayor | Media | Media |
| Consumo/energía | Diseñado para bajo consumo | Depende de la plataforma | Bueno en software | — |
| Uso típico | IoT, sensores, RFID | Servidores, TLS con AES-NI | Software sin AES-NI, móviles | Integridad y firmas |

La conclusión no es «Ascon es más rápido que AES»: es «Ascon ofrece una seguridad moderna con muy poca memoria y energía, y resulta competitivo en mensajes cortos o en dispositivos sin aceleración». En un servidor con AES-NI, AES-GCM sigue siendo la elección lógica.

## 3. Comandos del anexo

### 3.1 `openssl speed`

```bash
openssl speed -evp aes-128-gcm
openssl speed -evp chacha20-poly1305
openssl speed -evp sha256
```

`openssl speed` mide el rendimiento de una primitiva concreta. Para que la comparación sea justa, usa la misma máquina, el mismo número de segundos y la misma versión de OpenSSL. La opción `-evp` selecciona el algoritmo por nombre; `-seconds N` ajusta la duración.

### 3.2 Compilar libgcrypt para los benchmarks

El anexo del enunciado indica:

```bash
sudo apt update
sudo apt install build-essential dpkg-dev libgpg-error-dev
mkdir ~/gcrypt-test && cd ~/gcrypt-test
apt source libgcrypt20
cd libgcrypt20-*/
./configure
make
cd tests
make benchmark
./benchmark
```

El log [benchmark_all.txt](../../assets/benchmarks/benchmark_all.txt) recoge la salida de `libgcrypt` 1.11.0. Los tiempos son de **0–30 ms** y muchos valores quedan en `0ms`, así que ese log sirve para comprobar que las primitivas existen y funcionan, no para hacer una comparación fina. Para un informe serio, aumenta el tamaño de los datos y repite las medidas.

### 3.3 Ascon-c

El informe usó `ascon-c` v1.2 con la implementación `opt32`. Los binarios del log se ejecutan desde el directorio `build/`:

```console
user1@demo:~/gcrypt-test/ascon-c/build$ ./getcycles_crypto_aead_asconaead128_opt32
user1@demo:~/gcrypt-test/ascon-c/build$ ./getcycles_crypto_hash_asconhash256_opt32
```

Cada ejecución imprime la distribución de ciclos para varios tamaños de mensaje y la tabla de ciclos por byte. Es la fuente de la tabla de la sección 2.2.

## 4. Conclusión: cuándo conviene Ascon

Ascon conviene cuando:

- el dispositivo tiene **poca memoria, poca energía o poco espacio de código**;
- no hay aceleración hardware para AES;
- los mensajes son **cortos** o el coste fijo importa;
- se necesita **AEAD y hash** con una sola familia de algoritmos y una implementación compacta;
- el despliegue es IoT, RFID, wearables, sensores o comunicaciones industriales.

No es la primera opción cuando:

- hay AES-NI o aceleración equivalente y se prioriza **throughput** en bloques grandes (mejor AES-GCM);
- se necesita compatibilidad amplia con infraestructura TLS existente (AES-GCM y ChaCha20-Poly1305 están desplegados);
- se requiere un ecosistema maduro de bibliotecas y certificaciones; Ascon es joven, aunque ya es estándar NIST.

En resumen: **Ascon no sustituye a AES en el servidor; cubre el hueco de los dispositivos que no pueden pagar el coste de AES**. La elección depende del entorno, no solo de los ciclos por byte.

## Enlaces

- [Benchmark de Ascon](../../assets/benchmarks/benchmark_ascon.txt)
- [Benchmark de libgcrypt](../../assets/benchmarks/benchmark_all.txt)
- [Recursos: benchmarks](../../recursos/benchmarks.md)
- [Criptografía (teoría)](../teoria/criptografia.md)
- [Hashes e integridad](../comandos/hash.md)
- [Actividad de criptografía (PDF)](../../assets/pdf/actividad-criptografia.pdf)
- [Informe Ascon (PDF)](../../assets/pdf/actividad-ascon.pdf)
- [Ascon — especificación](https://ascon.isec.tugraz.at/specification.html)
