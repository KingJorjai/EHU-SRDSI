# Actividad: estudio de una CA — GlobalSign

[:material-file-pdf-box: Estudio original de GlobalSign (PDF)](../../assets/pdf/actividad-estudio-ca.pdf){ .md-button }

La actividad de T1-4 (p. 67) pide elegir una autoridad de certificación y estudiar cómo emite certificados para una entidad. Esta página resuelve el caso de **GlobalSign** y convierte el cuestionario en una checklist reutilizable para estudiar cualquier CA.

## 1. Tipos de certificados y usos

GlobalSign emite certificados para servicios TLS, firma de documentos, firma de código, correo y firma cualificada. Los niveles de validación SSL/TLS son:

| Tipo | Qué valida | Uso típico | Documentación |
| --- | --- | --- | --- |
| **DV** (*Domain Validation*) | Solo la propiedad del dominio | Blogs, sitios pequeños, pruebas | Ninguna documentación de empresa; validación por correo, DNS o fichero en el servidor |
| **OV** (*Organization Validation*) | Dominio + existencia legal de la organización | Webs corporativas | Documento de constitución, licencia comercial o carta de contable/abogado |
| **EV** (*Extended Validation*) | Dominio + organización + verificación exhaustiva | Bancos, comercio electrónico, datos sensibles | La misma que OV más verificación de identidad y autorización del representante legal |
| **Wildcard** | Un dominio y sus subdominios (`*.ejemplo.com`) | Empresas con muchos subdominios | Según el nivel (DV/OV/EV) del certificado base |

Otros productos:

- **Firma de documentos (AATL)**: firmar y sellar documentos en Adobe Acrobat, Microsoft Office, etc.
- **Firma de código** (*Code Signing*): autenticar software y aplicaciones.
- **S/MIME**: cifrar y firmar correo electrónico; GlobalSign lo llama *PersonalSign* o certificados de empresa/departamento.
- **Certificados cualificados (eIDAS)**: firma electrónica cualificada con el nivel de garantía más alto del reglamento europeo.

!!! note "Wildcard no es un nivel de validación"
    Wildcard describe el **alcance** del nombre (`*.ejemplo.com`), no la profundidad de validación. Un wildcard puede ser DV, OV o EV. Además, un wildcard solo cubre **un** nivel de subdominio (`a.ejemplo.com`), no `a.b.ejemplo.com`, salvo que el producto lo permita expresamente.

## 2. Pasos para obtener un certificado

1. **Realizar el pedido**: en la tienda de GlobalSign o, si ya se es cliente, en el *GlobalSign Certificate Center* (GCC).
2. **Seleccionar el producto** y el periodo de validez.
3. **Generar la CSR** (*Certificate Signing Request*) en el servidor. La CSR contiene la clave pública y los datos de identidad; la clave privada **no se envía**.
4. **Completar la validación**: GlobalSign comprueba el dominio y, en OV/EV, la organización y el representante.
5. **Descargar el certificado**: se recibe un enlace por correo o se descarga desde el panel; después se instala junto con la cadena intermedia.

Flujo técnico resumido:

```text
servidor: genera clave privada + CSR
        └── envía CSR a la CA
CA: valida dominio/organización
        └── emite certificado firmado
servidor: instala certificado + cadena + clave privada
```

La CA **no genera ni recibe la clave privada** del servidor en el flujo normal. Si un proveedor la pide, es una señal de alarma. La clave privada debe generarse en el servidor y protegerse con permisos restrictivos o un HSM.

## 3. Documentación necesaria

| Producto | Documentación |
| --- | --- |
| **DV** | No se pide documentación de la empresa. Se valida el control del dominio por correo a una dirección administrativa, DNS (registro TXT/CNAME) o un fichero HTTP bien conocido. |
| **OV** | Prueba de existencia legal: certificado de constitución, licencia comercial, carta de un contable o abogado, etc. |
| **EV** | La documentación de OV más verificación de la identidad y autorización del representante legal. |
| **Cualificado (eIDAS)** | Declaración personal firmada, documento de identidad con fotografía (pasaporte, DNI), dos documentos secundarios (uno financiero y otro no financiero) con nombre y dirección, y verificación por un tercero de confianza (notario, abogado, etc.). |

En OV/EV también se comprueba que el solicitante esté autorizado a solicitar el certificado en nombre de la organización. El número de teléfono y el dominio deben ser verificables y coherentes con los registros públicos.

## 4. Verificación de identidad del solicitante

GlobalSign documenta varios métodos:

- **Verificación por vídeo**: un agente se conecta por videollamada, revisa el documento de identidad y confirma que el solicitante es el titular.
- **Verificación por terceros**: notarios, abogados u otros profesionales legales cualificados realizan la comprobación.
- **Verificación telefónica**: llamada de desafío/respuesta a un número obtenido de una fuente fiable.
- **Verificación documental**: copia legible de un documento oficial (pasaporte, permiso de conducir, etc.).

Para EV y certificados cualificados, la verificación es más profunda: no basta con que la empresa exista; hay que demostrar que la persona que solicita el certificado puede actuar en su nombre.

## 5. Precio y periodo de validez

Precios de lista orientativos de GlobalSign (un año, según el informe; pueden variar por promoción, país y periodo):

| Producto | Precio aproximado |
| --- | ---: |
| TLS/SSL DV | 249 USD/año |
| TLS/SSL OV | 349 USD/año |
| TLS/SSL EV | 599 USD/año |
| S/MIME PersonalSign 1 | desde 59 USD/año |
| S/MIME PersonalSign 2 | desde 79 USD/año |
| S/MIME empresa | desde 104 USD/año |
| S/MIME departamento | desde 349 USD/año |
| Firma de código OV | desde 529 USD/año |
| Firma de código EV | desde 669 USD/año |
| Firma de documentos | desde 458 USD/año |

**Periodo de validez:** GlobalSign ofrece 6 meses o 1 año (este último como dos certificados de 6 meses). La tendencia del sector es limitar la vida de los certificados TLS; no conviene planificar una validez muy larga sin automatizar la renovación.

!!! warning "Precios y fechas"
    Los precios son una referencia del informe y cambian. Para un estudio real, consulta la tienda y la fecha de consulta, e indica la moneda y los impuestos.

## 6. Revocación: CRL, OCSP y stapling

- **CRL** (*Certificate Revocation List*): GlobalSign publica listas de revocación. Para certificados de usuario final, la actualización es al menos cada **24 horas** (en algunos casos, como máximo cada 7 días). Para certificados de CA, al menos cada **3 o 6 meses**, o en **24 horas** si se revoca un certificado de CA.
- **OCSP** (*Online Certificate Status Protocol*): respondedor para consultar el estado en tiempo real. La URL del respondedor aparece en la extensión **AIA** (*Authority Information Access*) del certificado.
- **OCSP Stapling**: el servidor web adjunta una respuesta OCSP firmada durante el *handshake* TLS. Mejora el rendimiento y la privacidad porque el cliente no consulta directamente a la CA.
- **OCSP Must-Staple**: el informe no confirma que GlobalSign admita explícitamente esta extensión. Sí soporta y recomienda **OCSP Stapling**. Must-Staple obliga al servidor a presentar una respuesta OCSP; si no lo hace, la conexión falla.
- **Certificados de corta vida** (*short-lived*): no son el modelo principal de GlobalSign en el informe; la validez habitual es de 6 meses o 1 año. La automatización (ACME) es la alternativa práctica para reducir la ventana de exposición.

## 7. CPS y certificado raíz

- **CPS** (*Certification Practice Statement*): GlobalSign publica políticas, prácticas, auditorías e informes de cumplimiento en su repositorio público: [GlobalSign Repository](https://www.globalsign.com/de-de/repository).
- **Certificado raíz**: la lista de raíces y sus huellas está en [GlobalSign Root Certificates](https://support.globalsign.com/ca-certificates/root-certificates/globalsign-root-certificates). Es importante comprobar qué raíz firma la cadena que se instala y si está en el almacén de confianza del sistema/navegador.
- **Cadena**: el servidor debe enviar el certificado del servidor y los intermedios necesarios; el cliente confía en la raíz. Una cadena incompleta provoca errores aunque el certificado sea válido.

## 8. Checklist reutilizable para estudiar cualquier CA

Copia esta lista y respóndela para la CA elegida. Sirve tanto para GlobalSign como para FNMT, Izenpe, Let's Encrypt, DigiCert, etc.

### Tipos de certificados

- [ ] ¿Qué tipos emite? (DV, OV, EV, wildcard, multidominio, S/MIME, código, documentos, cualificados)
- [ ] ¿Qué uso tiene cada tipo?
- [ ] ¿He seleccionado un tipo concreto para el estudio?
- [ ] ¿Qué alcance tiene (un dominio, varios, subdominios, persona, organización)?
- [ ] ¿Qué algoritmos y tamaños de clave admite? (RSA, ECDSA, Ed25519; 2048/3072/4096)

### Proceso y documentación

- [ ] ¿Qué pasos hay que realizar para solicitar el certificado?
- [ ] ¿Quién genera la clave privada y la CSR?
- [ ] ¿Qué documentación hay que presentar?
- [ ] ¿Se exige prueba de existencia legal de la organización?
- [ ] ¿Se verifica la autorización del representante legal?
- [ ] ¿Cómo se valida el control del dominio? (correo, DNS, HTTP, documento)
- [ ] ¿Cómo se entrega el certificado y la cadena?
- [ ] ¿Se entrega alguna clave privada? (no debería)

### Identidad

- [ ] ¿Cómo se verifica la identidad del solicitante? (vídeo, teléfono, documentos, terceros)
- [ ] ¿Se usa un tercero de confianza? ¿Cuál?
- [ ] ¿Qué evidencia queda del proceso?
- [ ] ¿Qué ocurre si la identidad no se puede verificar?

### Precio y validez

- [ ] ¿Cuánto cuesta el certificado? (moneda, impuestos, periodo)
- [ ] ¿Qué periodo de validez ofrece?
- [ ] ¿Hay descuentos por varios años?
- [ ] ¿Incluye soporte, reemisión o garantía?
- [ ] ¿Qué coste tiene la renovación y la revocación?

### Revocación y estado

- [ ] ¿Cada cuánto emite CRL?
- [ ] ¿Usa OCSP? ¿Dónde está la URL en el certificado (AIA)?
- [ ] ¿Admite OCSP Stapling?
- [ ] ¿Admite OCSP Must-Staple?
- [ ] ¿Ofrece certificados de corta vida o automatización (ACME)?
- [ ] ¿Qué latencia hay entre revocación y publicación?

### CPS, raíz y confianza

- [ ] ¿Tiene CPS público? ¿Dónde?
- [ ] ¿Publica auditorías (WebTrust, ETSI, ISO 27001)?
- [ ] ¿Dónde está su certificado raíz? ¿Cuál es la huella?
- [ ] ¿La raíz está en los almacenes de confianza habituales?
- [ ] ¿Qué cadena hay que instalar?
- [ ] ¿Qué política de privacidad y retención aplica?

### Extras útiles

- [ ] ¿Ofrece certificados comodín o multidominio? ¿Cómo se combinan?
- [ ] ¿Soporta CAA? ¿Qué registros recomienda?
- [ ] ¿Ofrece CT (*Certificate Transparency*)? ¿Se puede consultar el certificado emitido?
- [ ] ¿Tiene API o integración con ACME?
- [ ] ¿Qué SLA de emisión y soporte ofrece?
- [ ] ¿Qué pasa si la CA cesa la actividad o revoca su raíz?

## 9. Plantilla de respuesta

| Apartado | Respuesta para GlobalSign |
| --- | --- |
| CA elegida | GlobalSign |
| Tipo seleccionado | TLS/SSL OV (o el que se quiera estudiar) |
| Uso | Web corporativa con datos de clientes |
| Pasos | Pedido → producto → CSR → validación → descarga |
| Documentación | Existencia legal + autorización del representante |
| Verificación de identidad | Vídeo, terceros, teléfono, documentos |
| Precio orientativo | 349 USD/año (OV, referencia) |
| Validez | 6 meses o 1 año |
| Entrega | Descarga del certificado y cadena; la clave privada se queda en el servidor |
| CRL/OCSP | CRL periódica + OCSP en tiempo real; stapling recomendado |
| CPS/raíz | Repositorio público y página de raíces |

## Enlaces

- [Estudio original de GlobalSign (PDF)](../../assets/pdf/actividad-estudio-ca.pdf)
- [GlobalSign — tienda](https://shop.globalsign.com/es)
- [GlobalSign — repositorio de políticas y auditorías](https://www.globalsign.com/de-de/repository)
- [GlobalSign — certificados raíz](https://support.globalsign.com/ca-certificates/root-certificates/globalsign-root-certificates)
- [GlobalSign — OCSP stapling](https://support.globalsign.com/ssl/ocsp-stapling/ocsp-stapling)
- [Gestión de claves y PKI (teoría)](../teoria/gestion-claves.md)
- [OpenSSL y PKI (comandos)](../comandos/openssl.md)
