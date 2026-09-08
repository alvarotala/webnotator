# Webnotator

Feedback de sitios web en beta: un widget instalable con un script y un panel privado para administrar proyectos y anotaciones.

Rails 8.1 + React/TypeScript + PostgreSQL 17. Docker Compose ejecuta únicamente la app y PostgreSQL. Rails publica HTTP directamente en el puerto **8081**; el proxy HTTPS se administra fuera de este proyecto. No requiere Redis, correo ni servicios externos.

## Probar en localhost

Requisitos: Docker con Compose y OpenSSL (incluido en macOS y normalmente en Linux).

```sh
./scripts/start.sh
```

Abrir **http://localhost:8081**. El administrador y su contraseña aleatoria están en `.env`, en `ADMIN_EMAIL` y `ADMIN_PASSWORD`. El archivo se genera con permisos privados y está excluido de Git. No hay contraseña universal ni registro público.

La primera ejecución crea el administrador y el proyecto **Agendario · Demo**, con tres anotaciones de ejemplo. En el panel:

1. Abrir **Invitar a revisar** y **Probar la invitación**.
2. Escribir un nombre y abrir el sitio de demostración.
3. Usar **Anotar** para seleccionar un elemento o comentar sobre toda la página.
4. Volver al panel y pulsar **Actualizar** para revisar el comentario, ver la captura y cambiar su estado.

La demo está en `/demo`; sin activar una invitación, el widget permanece oculto. La demo no crea citas reales.

```sh
docker compose logs -f app
docker compose stop
# Reiniciar sin reconstruir:
docker compose up -d --wait
# Después de cambiar código:
docker compose up -d --build --wait
```

Los cambios de `ADMIN_PASSWORD` en `.env` no sobrescriben una cuenta existente. Para aplicar un cambio de contraseña explícitamente:

```sh
docker compose up -d app
docker compose exec app bundle exec rails runner 'Admin.find_by!(email: ENV.fetch("ADMIN_EMAIL")).update!(password: ENV.fetch("ADMIN_PASSWORD"))'
```

## Integrar una beta

Crear un proyecto con sus **orígenes exactos**: por ejemplo `https://agendario.app` y `https://beta.agendario.app`. No incluir rutas ni `/` final. HTTP/HTTPS y puertos distintos son orígenes diferentes. El identificador público del proyecto está en el código de integración que genera el panel:

```html
<script defer src="https://webnotator.sadmonkey.app/widget.js" data-project="IDENTIFICADOR"></script>
```

Compartir la invitación del proyecto. El revisor escribe su nombre y abre el sitio. La invitación activa el widget en ese navegador, sin cookies de terceros ni una cuenta de cliente. Puede navegar por el sitio y seguir anotando.

El enlace es una credencial de acceso al proyecto: compartirlo solo con revisores. **Renovar invitación** invalida el enlace y los accesos activados anteriormente. El identificador público del script por sí solo no permite enviar ni leer feedback.

El script usa Shadow DOM para aislar el estilo del widget. Se debe incluir en todas las páginas revisables (o en el layout principal de una SPA). Si el sitio usa una CSP restrictiva, autorizar el origen de Webnotator en `script-src` y `connect-src`; sus estilos también deben estar permitidos por la política del sitio. El widget transmite el `nonce` del script a su hoja de estilos, pero usa posiciones dinámicas mediante estilos de elementos: validar la CSP real de la beta antes de distribuir la invitación.

### Qué guarda una anotación

- Comentario, tipo (`error`, `cambio`, `sugerencia`), autor y fecha.
- Estado: pendiente, en curso, resuelto o descartado.
- URL sin parámetros de consulta, título de página y dimensiones de pantalla.
- Selector CSS, etiqueta y hasta 160 caracteres de texto del elemento. No guarda HTML, valores de campos, cookies ni datos del almacenamiento del sitio.
- Una captura PNG/JPEG/WebP opcional, de hasta 5 MB. Se adjunta manualmente; no hay captura automática.

Los adjuntos se sirven únicamente a administradores autenticados. El panel permite filtrar por página, tipo, estado y texto; pagina los resultados de 30 en 30. Reintentar un envío con el mismo identificador no duplica la anotación.

### Límites de esta versión

- Un equipo interno con un panel compartido; sin roles por proyecto, comentarios entre participantes ni notificaciones por email.
- Los nombres de revisores son declarados por ellos, no identidades verificadas.
- No selecciona el contenido interno de iframes ni componentes con Shadow DOM propio. En esos casos se puede seleccionar el contenedor y adjuntar una captura.
- Los selectores pueden dejar de coincidir si cambia el DOM. Se comprueban también la etiqueta y el texto antes de resaltar; el contexto original permanece guardado aunque no se encuentre el elemento.
- Se eliminan los query strings para evitar guardar tokens. Por eso una pantalla cuya identidad depende exclusivamente de un parámetro puede necesitar que el cliente describa el contexto. Se conservan rutas de SPA del tipo `#/ruta`, sin su query string.
- Una captura y el texto visible seleccionado pueden contener información del cliente. Revisarlos antes de enviar.
- La limitación de intentos de login se mantiene en memoria de la app (un proceso Puma). Los límites de tráfico del widget se configuran en el proxy externo. Este despliegue está pensado para una única instancia interna.

## Desplegar detrás de tu proxy HTTPS

El Compose contiene solamente `app` y `postgres` y publica **8081 → 3000**. La base de datos queda en la red interna de Docker. No incluye Nginx, Certbot ni gestión de certificados.

Copiar el proyecto al VPS sin `.env`, datos locales ni `node_modules`, y generar la configuración:

```sh
./scripts/setup.sh
```

Editar `.env` conservando los secretos generados:

```dotenv
APP_URL=https://webnotator.sadmonkey.app
ALLOWED_HOSTS=localhost,127.0.0.1,webnotator.sadmonkey.app
HTTPS=true
ADMIN_EMAIL=tu-email@ejemplo.com
SEED_DEMO=false
```

Elegir una contraseña de al menos 12 caracteres en `ADMIN_PASSWORD` antes del primer arranque. Los seeds no cambian las contraseñas de cuentas existentes.

```sh
docker compose up -d --build --wait
```

En tu Nginx externo, dentro del servidor HTTPS de `webnotator.sadmonkey.app`, dirigir las solicitudes al puerto 8081. Por ejemplo, si Nginx corre en el mismo VPS fuera de Docker:

```nginx
location / {
    proxy_pass http://127.0.0.1:8081;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    client_max_body_size 6m;
}
```

Si ese Nginx corre en otro contenedor, usar en `proxy_pass` una dirección del host accesible desde él; su `127.0.0.1` corresponde al propio contenedor. Los certificados y la redirección de HTTP a HTTPS quedan en esa capa externa.

`HTTPS=true` indica a Rails que el acceso público usa HTTPS y activa cookies seguras, aunque el proxy se comunique con la app mediante HTTP. `APP_URL` es la dirección pública utilizada en las invitaciones. Para pruebas directas en localhost, mantener `HTTPS=false` y `APP_URL=http://localhost:8081`.

Para conservar la demo en el VPS, usar `SEED_DEMO=true` y configurar el origen HTTPS del proyecto demo. `/demo` está disponible cuando existe el proyecto con el nombre `Agendario · Demo`.

## Datos y backups

Volúmenes nombrados: `database` y `uploads` (prefijo `webnotator_`). No ejecutar `docker compose down -v` salvo que se quiera eliminar los datos.

```sh
./scripts/backup.sh
```

Genera `backups/FECHA/database.dump`, `uploads.tar.gz` y `env`. Pausa temporalmente la app para mantener consistencia entre datos y adjuntos, y la vuelve a iniciar al terminar. El backup incluye credenciales: guardarlo en un lugar privado fuera del VPS.

Restauración **sobre una instalación nueva o una base que se desea reemplazar**, con el mismo `.env` del backup:

```sh
# Después de copiar el .env del backup y construir la imagen:
docker compose up -d postgres
docker compose stop app
docker compose exec -T postgres pg_restore -U webnotator -d webnotator --clean --if-exists --no-owner < backups/FECHA/database.dump
docker compose run --rm -T --no-deps --entrypoint tar app -xzf - -C /app/storage < backups/FECHA/uploads.tar.gz
docker compose up -d --wait
```

Los archivos de adjuntos que no estén referenciados por la base restaurada no se sirven. La restauración no requiere acceso público al directorio `storage`.

## Desarrollo y pruebas

El build de producción compila React con Vite y copia sus archivos a `public`; Rails sirve panel, API y widget en el mismo origen. Los tests Ruby usan una base separada `webnotator_test` y archivos en `storage/test`.

```sh
# Asegurarse de haber construido la imagen después de modificar tests o código:
docker compose build app
./scripts/test.sh

cd frontend
npm ci
npm run build
npx playwright install chromium
npm run test:e2e
```

Las pruebas de navegador requieren el stack local levantado en `http://localhost:8081`, los datos de acceso en `.env` y el puerto local 9091 libre. Crean proyectos con prefijo `QA Webnotator` para probar un sitio en otro origen. No ejecutarlas contra producción. Cubren invitación, aislamiento del widget, selección sin enviar formularios, adjuntos privados, filtrado, resolución, localización y revocación. Para retirar solo sus datos de prueba:

```sh
docker compose exec app bundle exec rails runner 'Project.where("name LIKE ?", "QA Webnotator%").find_each { |p| p.annotations.find_each { |a| ScreenshotStore.delete(a.screenshot_key); a.destroy! }; p.destroy! }'
```

Durante desarrollo del panel puede ejecutarse `npm run dev` en `frontend` y usar Vite con su proxy a Rails. Para validar cookies y CSRF, preferir el stack completo en 8081; usar ese mismo origen para las pruebas de integración.

## Referencias

- [Seguridad de sesiones y CSRF en Rails](https://guides.rubyonrails.org/security.html)
