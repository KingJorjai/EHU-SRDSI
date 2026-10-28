# Actividades: modelo de amenazas y CAPEC

[:material-file-pdf-box: Transparencias — Conceptos y amenazas (PDF)](../../assets/pdf/SRDSI_T1-1.pdf){ .md-button }

## Enunciado de la actividad

Durante el diseño de un servicio seguro se construye un **modelo de amenazas**: una lista de las vulnerabilidades y ataques posibles, una estimación de su riesgo y las contramedidas que se van a implantar. El primer paso es identificar las amenazas.

La actividad pide:

1. Escoger una **categoría** de servicio (C).
2. Seleccionar **cuatro patrones de ataque estándar** (S) de CAPEC que pertenezcan al menos a **dos metacategorías** distintas (M).
3. Preparar una presentación con qué consisten, sus relaciones, requisitos, consecuencias y prevención.
4. Buscar una noticia que recoja uno de esos ataques.

Referencia: [MITRE CAPEC — Common Attack Pattern Enumeration and Classification](https://capec.mitre.org/).

## Vocabulario CAPEC necesario

| Término | Qué es |
| --- | --- |
| **Categoría (C)** | Agrupación de patrones relacionados. En esta actividad se usa como «tipo de servicio»: por ejemplo, un portal web de reservas. |
| **Patrón de ataque estándar (S)** | Descripción de una técnica concreta, con requisitos, flujo de ejecución, consecuencias y mitigaciones. Es el nivel que se pide seleccionar. |
| **Metacategoría (M)** | Gran dominio de ataque de la vista *Domains of Attack*. Ejemplos: **Software**, **Social Engineering**, **Communications**, **Supply Chain**, **Hardware**, **Physical Security**. |
| **Relación** | Vínculos `ChildOf` / `ParentOf` / `CanFollow` / `CanPrecede` entre patrones. Sirven para encadenar ataques y explicar un incidente. |

!!! note "La notación C/S/M"
    En el enunciado, **C** es la categoría elegida, **S** cada patrón estándar y **M** cada metacategoría. Los cuatro patrones deben ser estándar y cubrir al menos dos metacategorías.

## Ejemplo resuelto: portal web de reservas

### Contexto

Servicio ficticio **ReservaLab**: portal web donde una persona se registra, consulta disponibilidad, reserva una sala y paga una señal. Activos principales:

- cuentas de usuario y sesiones;
- base de datos de reservas y datos personales;
- pasarela de pago;
- reputación de la marca y del dominio.

### Patrones seleccionados

Categoría: **servicio web de reservas**. Metacategorías usadas: **Software** y **Social Engineering**.

| ID | Nombre | Metacategoría | Requisitos | Consecuencias | Prevención |
| --- | --- | --- | --- | --- | --- |
| [CAPEC-66](https://capec.mitre.org/data/definitions/66.html) | SQL Injection | Software | Consultas SQL construidas con entrada del usuario y sin validación; base de datos accesible desde la aplicación. | Lectura y modificación de datos; ejecución de comandos no autorizados; escalada de privilegios; caída del servicio. | Validación de entrada, *consultas parametrizadas* o procedimientos almacenados, mínimos privilegios en la base de datos y páginas de error genéricas. |
| [CAPEC-63](https://capec.mitre.org/data/definitions/63.html) | Cross-Site Scripting (XSS) | Software | El navegador víctima ejecuta JavaScript; la aplicación refleja o almacena contenido suministrado por el atacante sin codificarlo. | Ejecución de código en el navegador de la víctima; robo de sesión o credenciales; modificación de la página; acciones en nombre del usuario. | Codificación de salida según el contexto, validación de entrada, CSP, cookies `HttpOnly`/`Secure`/`SameSite` y parcheo del navegador. |
| [CAPEC-62](https://capec.mitre.org/data/definitions/62.html) | Cross Site Request Forgery (CSRF) | Software | La sesión se autentica con una cookie que el navegador envía automáticamente; el atacante puede construir una petición válida y conseguir que la víctima la ejecute. | Acciones de cambio de estado con los privilegios de la víctima: reservas, pagos, cambio de contraseña o de correo. | Tokens anti-CSRF ligados a la sesión, cookies `SameSite`, comprobación de `Origin`/`Referer` y reautenticación en operaciones sensibles. |
| [CAPEC-98](https://capec.mitre.org/data/definitions/98.html) | Phishing | Social Engineering | Canal de contacto con la víctima (correo, SMS, red social); suplantación de una entidad legítima; llamada a la acción creíble; web o URL parecida. | Robo de credenciales o datos de pago; acceso a la cuenta; fraude; pérdida de confianza en la marca. | Formación de usuarios, MFA resistente a phishing (WebAuthn), filtrado de correo, verificación del dominio y no reutilizar contraseñas. |

### Relaciones entre los patrones

| Patrón | Relación principal | Lectura para el modelo de amenazas |
| --- | --- | --- |
| CAPEC-66 | `ChildOf` **CAPEC-248 Command Injection** | La inyección SQL es una forma concreta de inyectar comandos en un intérprete; si la base de datos permite ejecutar código del sistema, el impacto crece. |
| CAPEC-63 | `ChildOf` **CAPEC-242 Code Injection** | El XSS inyecta código que ejecuta el navegador; puede encadenarse con CSRF para enviar peticiones en nombre de la víctima. |
| CAPEC-62 | `ChildOf` **CAPEC-21 Exploitation of Trusted Identifiers** | El servidor confía en una cookie de sesión que el navegador adjunta automáticamente; el atacante «cabalga» esa confianza. |
| CAPEC-98 | `ChildOf` **CAPEC-151 Identity Spoofing** | El phishing es suplantación de identidad aplicada a la obtención de información; suele preceder al uso de credenciales robadas. |

Un encadenamiento típico en este servicio sería: **phishing** para obtener credenciales → acceso a la cuenta → **CSRF** o **XSS** para actuar sin que el usuario lo note → **SQL injection** si algún formulario interno no valida la entrada.

### Noticia de ejemplo

!!! example "Caso real: Heartland Payment Systems (2008)"
    **Titular:** «Three Men Indicted for Hacking into Five Corporate Entities, including Heartland, 7-Eleven, and Hannaford, With Over 130 Million Credit and Debit Card Numbers Stolen».

    **Qué pasó:** el Departamento de Justicia de EE. UU. documentó que Heartland Payment Systems sufrió un ataque de **SQL injection** en su red corporativa. El ataque permitió introducir malware y robar más de 130 millones de números de tarjetas. Albert Gonzalez fue condenado en 2010 a 20 años y un día de prisión por este y otros casos relacionados.

    **Relación con el modelo:** es un caso real de **CAPEC-66** con consecuencias de confidencialidad (lectura de datos), integridad (manipulación) y disponibilidad (compromiso de la red). Recuerda que la inyección no siempre se queda en la base de datos: puede servir de punto de entrada para desplegar *sniffers* y moverse lateralmente.

    **Fuentes:**
    - [DOJ — nota de prensa de la acusación (2009)](https://www.justice.gov/archive/usao/nj/Press/files/pdffiles/2009/gonz0817%20rel.pdf)
    - [DOJ — sentencia de Albert Gonzalez (2010)](https://www.justice.gov/archives/opa/pr/leader-hacking-ring-sentenced-massive-identity-thefts-payment-processor-and-us-retail)
    - [Federal Reserve Bank of Philadelphia — *Heartland Payment Systems: Lessons Learned from a Data Breach*](https://www.philadelphiafed.org/-/media/FRBP/Assets/Consumer-Finance/Discussion-Papers/D-2010-January-Heartland-Payment-Systems.pdf)

La noticia se incluye como **ejemplo documentado**, no como parte del servicio ficticio. Para la entrega se puede usar un caso real o una noticia verosímil, pero conviene etiquetarla claramente y citar la fuente.

## Guion de presentación

1. **Servicio y activos** (1 diapositiva): qué hace ReservaLab, qué datos maneja y quién lo usa.
2. **Categoría y metacategorías** (1): por qué se eligen Software y Social Engineering.
3. **Los cuatro patrones** (4, una por patrón): descripción, requisitos, consecuencias y prevención.
4. **Relaciones** (1): cómo se encadenan y qué patrón habilita a cuál.
5. **Noticia** (1): qué pasó, qué patrón se materializó y qué contramedida lo habría reducido.
6. **Riesgo y priorización** (1): probabilidad, impacto y orden de implantación de contramedidas.
7. **Conclusiones** (1): qué amenazas quedan fuera del alcance y qué se revisará en la siguiente iteración.

## Plantilla reutilizable

### Ficha por patrón

| Campo | Contenido |
| --- | --- |
| ID y nombre | `CAPEC-XXX`: nombre oficial |
| Metacategoría | Software / Social Engineering / Communications / Supply Chain / Hardware / Physical Security |
| Nivel | Estándar (S) |
| Descripción | Qué hace el atacante en 2–3 frases |
| Requisitos | Qué necesita para tener éxito (acceso, entrada no validada, sesión activa, etc.) |
| Relaciones | `ChildOf`, `CanFollow`, `CanPrecede`… |
| Consecuencias | Confidencialidad / integridad / disponibilidad / privilegios |
| Prevención | Contramedidas técnicas, organizativas y de detección |
| Ejemplo | Incidente real o noticia verosímil, con fuente |

### Checklist de la actividad

- [ ] He elegido una categoría de servicio concreta y he descrito sus activos.
- [ ] Los cuatro patrones son **estándar** y están verificados en CAPEC.
- [ ] Hay al menos **dos metacategorías** distintas.
- [ ] Para cada patrón indico requisitos, consecuencias y prevención.
- [ ] Explico al menos una **relación** entre patrones.
- [ ] La noticia está identificada como real o verosímil y tiene fuente.
- [ ] La presentación distingue amenaza, vulnerabilidad y riesgo.
- [ ] Las contramedidas están priorizadas según impacto y probabilidad.

## Enlaces

- [MITRE CAPEC](https://capec.mitre.org/)
- [CAPEC — Domains of Attack](https://capec.mitre.org/data/definitions/3000.html)
- [Conceptos y amenazas (teoría)](../teoria/conceptos.md)
- [Actividades de GnuPG](gnupg.md)
- [Transparencias T1-1](../../assets/pdf/SRDSI_T1-1.pdf)
