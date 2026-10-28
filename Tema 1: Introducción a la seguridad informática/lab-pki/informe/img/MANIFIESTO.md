# Manifiesto de imágenes — Informe PKI Fase 1 (Tarea T2)

Extracción byte-exacta (sin recomprimir ni convertir) de `Pictures/` del ODT `PKI - Fase 1 - SRDSI.odt`. Verificado con comparación binaria contra el zip.

| Fichero nuevo | Fichero original en el ODT | Sección | Dimensiones | Descripción |
|---|---|---|---|---|
| `paso1-01.png` | `Pictures/100000000000030C00000366972AC216.png` | Paso 1 | 780x870 | Firma del certificado raíz autofirmado |
| `paso1-02.png` | `Pictures/1000000000000434000003B8BB2157C0.png` | Paso 1 | 1076x952 | Emisión del certificado de subCA |
| `paso2-01.png` | `Pictures/100000000000039F000002DCD28BDBB7.png` | Paso 2 | 927x732 | Generación de solicitud de usuario |
| `paso2-02.png` | `Pictures/10000000000003820000032980C11F2C.png` | Paso 2 | 898x809 | Emisión de certificado de usuario |
| `paso2-03.png` | `Pictures/100000000000032E0000026A7165C8BE.png` | Paso 2 | 814x618 | Confirmación de emisión y PKCS#12 |
| `paso2-04.png` | `Pictures/1000000000000397000001102710EE8C.png` | Paso 2 | 919x272 | Revocación por cese de operación |
| `paso3-01.png` | `Pictures/10000000000003870000018EC9360859.png` | Paso 3 | 903x398 | Generación de solicitud del OCSP |
| `paso3-02.png` | `Pictures/10000000000003950000028C7FC44C82.png` | Paso 3 | 917x652 | Emisión del certificado del OCSP |
| `paso3-03.png` | `Pictures/100000000000036E000000B80543D39E.png` | Paso 3 | 878x184 | Arranque del respondedor OCSP |
| `paso3-04.png` | `Pictures/100000000000039C000001851B481F61.png` | Paso 3 | 924x389 | Consulta OCSP con resultado good |
| `paso3-05.png` | `Pictures/1000000000000291000000AE02B64A8F.png` | Paso 3 | 657x174 | Verificación final del estado good |
| `web/mockup-01.png` | `Pictures/100000010000020E000002053B9DABF5.png` | WEB | 526x517 | Mockup dibujado del formulario web |

Nota: la imagen nº 12 (`100000010000020E000002053B9DABF5.png`, 526x517, 448 KB) **SÍ es el mockup web dibujado a mano**: título "Bocata de Jamón", campos Nombre/Apellidos/Contraseña/Correo/País/Organización/Provincia/Departamento y botón "Solicitar certificado", sobre fondo de bocadillo. Se guarda como `web/mockup-01.png`.
