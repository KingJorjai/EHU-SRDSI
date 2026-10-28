# Benchmarks

Resultados de rendimiento de las actividades de criptografía. Los logs originales están publicados en [`docs/assets/benchmarks/`](../assets/benchmarks/benchmark_ascon.txt) y la explicación completa, en [Criptografía y Ascon](../tema1/actividades/criptografia.md).

!!! note "Cómo leer los números"
    Un **ciclo por byte** más bajo es mejor. Los **MB/s** más altos son mejores. No compares medidas de máquinas, compiladores o tamaños distintos: fija máquina, flags, tamaño y repeticiones.

## `benchmark_ascon.txt`: ciclos por byte

Implementación de referencia `ascon-c` v1.2, variantes `opt32` y `lowsize`, ejecutada en la VM del laboratorio:

| Binario | 1 B | 8 B | 16 B | 32 B | 64 B | 1536 B | 2048 B |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `asconaead128_opt32` | 220 | 26 | 19 | 11 | 7,9 | 4,8 | 4,7 |
| `asconaead128_opt32_lowsize` | 247 | 31 | 20 | 13 | 8,8 | 5,8 | 5,0 |
| `asconhash256_opt32` | 444 | 71 | 40 | 29 | 22,5 | 15,4 | 19,1 |
| `asconhash256_opt32_lowsize` | 523 | 70 | 49 | 33 | 24,1 | 19,2 | 14,0 |

Los valores son los **mínimos** de cada distribución; el log incluye también la mediana y las 16 repeticiones por tamaño.

Lectura:

- **Mensajes de 1 byte**: domina el coste fijo de inicialización (220–523 ciclos/byte). Medir *throughput* con 1 byte no tiene sentido.
- **A partir de 1 KiB**: el AEAD se estabiliza en **4,7–5,0 ciclos/byte**; el hash, en **14–19 ciclos/byte**. El hash procesa a una tasa menor y usa más rondas en la fase intermedia.
- **`opt32` frente a `lowsize`**: `lowsize` reduce el tamaño de código a cambio de algo más de coste. En AEAD a 2048 B la diferencia es pequeña (4,7 frente a 5,0, ~6 %); en hash los valores son ruidosos.
- **Variabilidad**: a 1536/2048 B hay dispersión entre repeticiones (el hash `opt32` pasa de 15,4 a 19,1). Para comparar implementaciones, fija tamaño, compilador, flags y repeticiones.

[Log completo: `benchmark_ascon.txt`](../assets/benchmarks/benchmark_ascon.txt)

## Comparativa del informe Ascon (MB/s)

El informe comparó Ascon con AES-GCM, ChaCha20-Poly1305 y SHA-256 en la misma máquina (Debian 13, OpenSSL 3.5.7, Intel i7-1360P a ~2,6 GHz):

| Algoritmo | Tipo | 64 B (MB/s) | 1024 B (MB/s) |
| --- | --- | ---: | ---: |
| Ascon-AEAD128 | AEAD | 329 | 553 |
| AES-128-GCM | AEAD | 178 | 1.716 |
| ChaCha20-Poly1305 | AEAD | 343 | 1.246 |
| Ascon-Hash256 | Hash | 116 | 186 |
| SHA-256 | Hash | 217 | 841 |

Lectura:

- **Mensajes cortos (64 B)**: Ascon-AEAD128 (329 MB/s) está muy cerca de ChaCha20-Poly1305 (343 MB/s) y supera a AES-128-GCM (178 MB/s). En mensajes pequeños pesa mucho la preparación de clave y estado; Ascon tiene poca sobrecarga.
- **Bloques grandes (1 KiB)**: AES-GCM escala con **AES-NI** y supera claramente a Ascon; ChaCha20-Poly1305 también. En un servidor con aceleración hardware, AES-GCM es la opción natural.
- **Hash**: Ascon-Hash256 es más lento que SHA-256 en esta máquina; su ventaja no es la velocidad bruta, sino el tamaño de código y el consumo en dispositivos sin aceleración.
- **Tamaño de código**: el informe destaca que Ascon es ~**1,4× más compacto** que ChaCha20-Poly1305 y ~**3,3× más compacto** que AES-128-GCM en ARM. En IoT, la memoria flash y la energía importan más que los MB/s.

## `benchmark_all.txt`: libgcrypt

Salida de `libgcrypt` 1.11.0. La primera parte mide hashes, HMAC, CMAC, GMAC, Poly1305 y cifrados simétricos; los tiempos son de **0–30 ms** y muchos quedan en `0ms`, así que sirven para comprobar que las primitivas existen y funcionan, **no** para una comparación fina. Para un informe serio, aumenta el tamaño de los datos y repite las medidas.

### Clave pública (`generate` / `100*priv` / `100*public`)

| Algoritmo | generate | 100 operaciones privadas | 100 operaciones públicas |
| --- | ---: | ---: | ---: |
| RSA 1024 bit | 10 ms | 70 ms | 0 ms |
| RSA 2048 bit | 80 ms | 300 ms | 0 ms |
| RSA 3072 bit | 140 ms | 800 ms | 0 ms |
| RSA 4096 bit | 1.150 ms | 1.730 ms | 10 ms |
| ELG 1024 bit | — | 410 ms | 180 ms |
| ELG 2048 bit | — | 2.050 ms | 1.070 ms |
| ELG 3072 bit | — | 5.520 ms | 2.510 ms |
| DSA 1024/160 | — | 10 ms | 20 ms |
| DSA 2048/224 | — | 60 ms | 70 ms |
| DSA 3072/256 | — | 110 ms | 160 ms |
| ECDSA 192 bit | 0 ms | 30 ms | 40 ms |
| ECDSA 224 bit | 0 ms | 40 ms | 50 ms |
| ECDSA 256 bit | 0 ms | 50 ms | 60 ms |
| ECDSA 384 bit | 0 ms | 100 ms | 110 ms |
| ECDSA 521 bit | 0 ms | 220 ms | 230 ms |
| EdDSA Ed25519 | 0 ms | 20 ms | 40 ms |
| EdDSA Ed448 | 0 ms | 90 ms | 180 ms |
| GOST 256 bit | 0 ms | 60 ms | 70 ms |
| GOST 512 bit | 10 ms | 350 ms | 410 ms |

Interpretación:

- **RSA**: la generación y las operaciones privadas son caras y crecen rápido con el tamaño (RSA 4096: 1.150 ms para generar y 1.730 ms para 100 privadas). La operación pública es barata (exponente pequeño).
- **ElGamal**: mucho más lento que RSA en privadas y públicas; no es una opción práctica para TLS.
- **DSA**: privadas y públicas del mismo orden, mucho más rápidas que RSA/ElGamal a tamaños equivalentes.
- **ECDSA**: curvas pequeñas muy rápidas (256 bit: 50/60 ms); el coste crece con el tamaño de la curva.
- **EdDSA**: Ed25519 es la opción más equilibrada (20/40 ms) y Ed448 sube a 90/180 ms.
- **GOST**: GOST 512 es notablemente más lento que Ed25519/ECDSA-256.

[Log completo: `benchmark_all.txt`](../assets/benchmarks/benchmark_all.txt)

## Reproducir las medidas

### `openssl speed`

```bash
openssl speed -evp aes-128-gcm
openssl speed -evp chacha20-poly1305
openssl speed -evp sha256

# Misma duración y misma máquina para comparar
openssl speed -seconds 5 -evp aes-128-gcm
```

`-evp` selecciona la primitiva por nombre; `-seconds N` fija la duración de cada prueba.

### libgcrypt

```bash
sudo apt update
sudo apt install build-essential dpkg-dev libgpg-error-dev
mkdir -p ~/gcrypt-test && cd ~/gcrypt-test
apt source libgcrypt20
cd libgcrypt20-*/
./configure
make
cd tests
make benchmark
./benchmark
```

El binario `benchmark` recorre hashes, MAC, cifrados y clave pública. Compara siempre con la misma versión de libgcrypt y la misma máquina.

### ascon-c

El código de Ascon **no está en el repositorio**: se compiló en la VM (`~/gcrypt-test/ascon-c/build`). Los binarios del log se ejecutan desde `build/`:

```bash
cd ~/gcrypt-test/ascon-c/build
./getcycles_crypto_aead_asconaead128_opt32
./getcycles_crypto_aead_asconaead128_opt32_lowsize
./getcycles_crypto_hash_asconhash256_opt32
./getcycles_crypto_hash_asconhash256_opt32_lowsize
```

Cada ejecución imprime la distribución de ciclos para varios tamaños y la tabla de ciclos por byte.

## Conclusión

Ascon no sustituye a AES en un servidor con AES-NI: cubre el hueco de dispositivos con poca memoria, poca energía o sin aceleración hardware, y es competitivo en mensajes cortos. La elección depende del entorno, no solo de los ciclos por byte.

## Enlaces

- [Actividad de criptografía: Ascon](../tema1/actividades/criptografia.md)
- [Criptografía (teoría)](../tema1/teoria/criptografia.md)
- [Hashes e integridad](../tema1/comandos/hash.md)
- [`benchmark_ascon.txt`](../assets/benchmarks/benchmark_ascon.txt)
- [`benchmark_all.txt`](../assets/benchmarks/benchmark_all.txt)
