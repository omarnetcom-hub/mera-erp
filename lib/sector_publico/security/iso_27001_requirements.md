# Requisitos ISO 27001 y Política de Gobierno Digital MinTIC

## ISO 27001 - Seguridad de la Información

### Contexto
MerkaERP Sector Público debe cumplir con los requisitos de seguridad de la información según la norma ISO 27001:2013 para ser habilitado en entidades del Estado colombiano.

### Controles Críticos (Anexo A)

#### A.9 Control de Acceso
- **A.9.1 Control de acceso a los activos de la organización**
  - Implementación de autenticación multifactor (MFA) para usuarios con roles sensibles
  - Gestión de contraseñas con políticas de complejidad y rotación
  - Bloqueo automático después de N intentos fallidos (configurable, mínimo 3)

- **A.9.2 Gestión de acceso de usuario**
  - Proceso formal de registro y revocación de accesos
  - Revisión periódica de permisos (mínimo semestral)
  - Segregación de funciones implementada en código (no solo configuración)

- **A.9.3 Responsabilidades de usuario**
  - Acuerdo de confidencialidad firmado por cada usuario
  - Capacitación obligatoria en seguridad de la información

- **A.9.4 Control de acceso al sistema**
  - Control de sesión con timeout configurable (máximo 30 minutos de inactividad)
  - Restricción de acceso por horario y ubicación (IP whitelist)

#### A.12 Seguridad de las Operaciones
- **A.12.2 Gestión de vulnerabilidades**
  - Escaneo automatizado de vulnerabilidades mensual
  - Parcheo de seguridad dentro de 30 días de publicación

- **A.12.3 Copias de seguridad**
  - Backups diarios con retención mínima de 90 días
  - Backups mensuales con retención de 7 años
  - Prueba de restauración trimestral
  - Encriptación de backups en reposo y en tránsito

- **A.12.4 Registro de eventos y protección de la información registrada**
  - Logs inmutables (append-only) con hash encadenado
  - Retención diferenciada por tipo de evento (5, 10 o 50 años)
  - Protección contra manipulación de logs
  - Monitoreo en tiempo real de eventos de seguridad

- **A.12.6 Gestión de vulnerabilidades técnicas**
  - Encriptación de datos sensibles en reposo (AES-256)
  - Encriptación de datos en tránsito (TLS 1.3)
  - Enmascaramiento de datos en logs (contraseñas, datos personales)

#### A.14 Adquisición, Desarrollo y Mantenimiento de Sistemas
- **A.14.1 Requisitos de seguridad de los sistemas**
  - Análisis de amenazas y vulnerabilidades en cada fase de desarrollo
  - Validación de entradas (input validation) en todos los puntos
  - Principio de privilegio mínimo

- **A.14.2 Seguridad en los procesos de desarrollo**
  - Code review obligatorio antes de despliegue
  - Análisis estático de código (SAST) en cada commit
  - Testing de seguridad automatizado (DAST) en cada release

- **A.14.3 Datos de prueba**
  - Uso exclusivo de datos anonimizados para pruebas
  - Prohibición de datos reales de ciudadanos en ambientes de desarrollo

#### A.18 Cumplimiento
- **A.18.1 Cumplimiento de requisitos legales**
  - Ley 1581 de 2012 (Habeas Data)
  - Ley 1712 de 2014 (Transparencia)
  - Decreto 1074 de 2015 (Gobierno Digital)
  - Resolución 533 de 2015 CGN (NICSP)

- **A.18.2 Revisión de políticas de seguridad**
  - Revisión anual de políticas de seguridad
  - Auditoría externa bianual (certificación ISO 27001)

## Política de Gobierno Digital MinTIC

### Requisitos de Habilitación

#### 1. Interoperabilidad
- **API REST** documentada con OpenAPI/Swagger
- **Formato de intercambio**: JSON estándar
- **Estándares de datos**: XML/JSON según lineamientos MinTIC
- **Integración con**: CHIP, SIA, SIIF, SECOP II, RUT

#### 2. Accesibilidad
- **WCAG 2.1** Nivel AA (mínimo)
- Soporte para lectores de pantalla (JAWS, NVDA)
- Contraste mínimo de 4.5:1 para texto
- Navegación por teclado completa
- Texto alternativo para todas las imágenes

#### 3. Seguridad
- **TLS 1.3** obligatorio para todas las conexiones
- **HSTS** habilitado
- **CSP** (Content Security Policy) configurado
- **X-Frame-Options** DENY
- **X-Content-Type-Options** nosniff
- **Referrer-Policy** strict-origin-when-cross-origin

#### 4. Disponibilidad
- **SLA mínimo**: 99.5% mensual
- **Tiempo de recuperación**: máximo 4 horas
- **Punto de recuperación**: máximo 1 hora de datos perdidos
- **Redundancia geográfica** para datos críticos

#### 5. Protección de Datos Personales (Ley 1581/2012)
- **Política de privacidad** visible y accesible
- **Consentimiento explícito** para tratamiento de datos
- **Derechos ARCO** (Acceso, Rectificación, Cancelación, Oposición)
- **Registro de tratamiento** de datos personales
- **Encargado de datos** designado y registrado

#### 6. Transparencia (Ley 1712/2014)
- **Portal de transparencia** con información proactiva
- **Datos abiertos** en formatos reutilizables (CSV, JSON)
- **Licencia de datos**: Creative Commons BY 4.0
- **Actualización mínima**: mensual

#### 7. Archivo de Gestión Documental
- **Estándar NOG-001** de Archivo General de la Nación
- **Metadatos obligatorios** según NOG-001
- **Tablas de retención documental (TRD)** implementadas
- **Digitalización** con estándares ISO/IEC 27001

## Plan de Implementación

### Fase 1: Diagnóstico (4 semanas)
- Evaluación de brechas vs ISO 27001
- Evaluación de brechas vs MinTIC Gobierno Digital
- Matriz de riesgos inicial

### Fase 2: Implementación de Controles (12 semanas)
- Configuración de MFA
- Implementación de logging inmutable
- Encriptación de datos sensibles
- Configuración de backups y retención
- Documentación de políticas

### Fase 3: Certificación (8 semanas)
- Auditoría interna
- Corrección de no conformidades
- Auditoría externa (entidad certificadora)
- Certificación ISO 27001

### Fase 4: Habilitación MinTIC (4 semanas)
- Registro en el portal de Gobierno Digital
- Evaluación de interoperabilidad
- Evaluación de accesibilidad
- Habilitación oficial

## Métricas de Cumplimiento

### Seguridad
- Tiempo medio de detección de incidentes (MTTD): < 24 horas
- Tiempo medio de respuesta (MTTR): < 72 horas
- Porcentaje de vulnerabilidades críticas parcheadas en 30 días: 100%

### Disponibilidad
- Uptime mensual: > 99.5%
- Tiempo máximo de indisponibilidad planeada: 4 horas/mes
- Tiempo máximo de indisponibilidad no planeada: 1 hora/año

### Calidad
- Cobertura de pruebas de seguridad: > 80%
- Porcentaje de código con review: 100%
- Porcentaje de vulnerabilidades críticas en producción: 0%

## Responsabilidades

### Oficial de Seguridad de la Información (ISO)
- Responsable de la política de seguridad
- Gestión de riesgos
- Coordinación de auditorías

### Oficial de Protección de Datos (Habeas Data)
- Responsable de cumplimiento Ley 1581
- Gestión de solicitudes ARCO
- Registro de tratamiento de datos

### Oficial de Gobierno Digital
- Responsable de cumplimiento MinTIC
- Interoperabilidad con sistemas del Estado
- Portal de transparencia

## Referencias Normativas

- ISO/IEC 27001:2013 - Sistemas de Gestión de Seguridad de la Información
- Ley 1581 de 2012 - Habeas Data
- Ley 1712 de 2014 - Transparencia y Acceso a la Información Pública
- Decreto 1074 de 2015 - Decreto Único Reglamentario del Sector TIC
- Resolución 533 de 2015 CGN - NICSP
- Decreto 1081 de 2015 - Decreto Único Reglamentario del Sector Hacienda
- Estándar NOG-001 - Archivo General de la Nación
- WCAG 2.1 - Accesibilidad Web
