# Validación local — 8 de septiembre de 2026

La implementación quedó ejecutándose en Docker Compose en `http://localhost:8081`, con PostgreSQL y Rails saludables, Rails expuesto directamente en el puerto 8081 y el proyecto Agendario · Demo (tres anotaciones de ejemplo). Los proyectos creados por las pruebas fueron retirados.

## Comprobaciones realizadas

- Construcción real de la imagen de producción: Rails 8.1.3.1, React, TypeScript y Vite; lockfiles incluidos. JSON fijado a la serie 2.x por incompatibilidad comprobada de Rails 8.1 con la firma de `JSON.parse` de JSON 3.
- `./scripts/test.sh`: **11 pruebas, 67 comprobaciones, sin fallos ni errores**, usando PostgreSQL separado (`webnotator_test`). Incluye login/CSRF/logout, orígenes, revocación, contexto, idempotencia, aislamiento entre proyectos, filtros/paginación y adjuntos privados.
- Playwright/Chromium: **7 recorridos aprobados**, repetidos contra Rails directamente en 8081 después de retirar el proxy del Compose. Incluyen widget oculto sin invitación, demo en el mismo origen, integración desde un origen externo local, selección sin enviar formularios, envío con imagen, resolución y localización del elemento, panel móvil, selección táctil, exclusión de valores de campos/query strings y revocación de accesos existentes.
- Inspección visual del panel a 1440 px y 390 px, y del widget sobre la demo.
- Configuración `HTTPS=true` comprobada con una solicitud que simula el proxy externo: respuesta 200 y cookie `Secure`, sin necesidad de TLS dentro del contenedor.
- `./scripts/backup.sh`: backup generado y aplicación reiniciada; dump restaurado correctamente en una base temporal independiente, luego retirada.
- Sintaxis JavaScript, compilación TypeScript y `git diff --check` correctos.

## Límites de esta validación

Nginx y Certbot fueron retirados del proyecto por decisión de despliegue. El Compose final contiene app y PostgreSQL, con un único puerto publicado: 8081. El proxy HTTPS externo y sus certificados se administran por separado; no se validó esa infraestructura del VPS.

Las pruebas de navegador se ejecutaron en Chromium, incluyendo emulación táctil; no equivalen a una prueba en Safari/iPhone físicos. La beta real de Agendario no fue modificada: la integración se comprobó con la demo y un segundo servidor local en otro origen.
