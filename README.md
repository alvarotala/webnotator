# Webnotator

Una herramienta para recibir feedback de sitios web. El cliente selecciona un elemento de la página, escribe una anotación y la envía. Desde el panel podés revisar los comentarios, ver capturas y marcar los cambios como pendientes, en curso, resueltos o descartados.

Construido con Rails, React y PostgreSQL. Se instala con Docker Compose y expone la aplicación en el puerto **8081**.

## Instalación

Necesitás Docker con Compose y OpenSSL. Ejecutá los comandos desde la carpeta del proyecto.

**1. Generar la configuración**

```sh
./scripts/setup.sh
```

**2. Editar `.env` antes del primer arranque**

```sh
nano .env
```

Revisá `ADMIN_EMAIL` y `ADMIN_PASSWORD`: serán tus datos de acceso al panel. La contraseña debe tener al menos 12 caracteres. Podés conservar la contraseña aleatoria generada, al igual que `POSTGRES_PASSWORD` y `SECRET_KEY_BASE`.

Para usarlo en tu computadora, dejá:

```dotenv
APP_URL=http://localhost:8081
HTTPS=false
SEED_DEMO=true
```

Para usarlo con un dominio público HTTPS:

```dotenv
APP_URL=https://webnotator.sadmonkey.app
ALLOWED_HOSTS=localhost,127.0.0.1,webnotator.sadmonkey.app
HTTPS=true
SEED_DEMO=false
```

`APP_URL` debe ser la dirección desde la que se accede a Webnotator. El acceso público HTTPS debe apuntar al puerto **8081**, conservando el dominio en la cabecera `Host`.

**3. Iniciar**

```sh
./scripts/start.sh
```

Abrí [localhost:8081](http://localhost:8081) o tu dominio e ingresá con los datos de `.env`.

La cuenta de administrador se crea durante la instalación. Cambiar su contraseña en `.env` después del primer arranque no modifica la cuenta existente.

## Usar Webnotator

1. Creá un proyecto en el panel.
2. En **Sitios autorizados**, escribí el dominio principal, por ejemplo `agendario.app`. Esto autoriza todas sus páginas y subdominios (`admin.agendario.app`, `calle11.agendario.app`, etc.). No hace falta agregarlos por separado. Escribí un dominio por línea, sin `https://` ni rutas.
3. En **Invitar a revisar**, copiá el script y pegalo en el `<head>` del sitio.
4. Compartí el enlace de invitación con tu cliente.
5. El cliente escribe su nombre, abre el sitio y usa el botón **Anotar**.

Puede seleccionar un elemento o comentar sobre toda la página, elegir entre error, cambio o sugerencia y adjuntar una captura de hasta 5 MB.

Las anotaciones aparecen en el panel con su página, autor y contexto. Podés filtrarlas, cambiar su estado y abrir la página para localizar el elemento señalado.

El botón **Exportar CSV** abre una pantalla interna para elegir estados, autor, rango de fechas de creación (UTC, ambos días incluidos), tipo, página y texto. Muestra cuántas anotaciones coinciden y descarga todas esas coincidencias, sin límite de paginación. Sus filtros son independientes de los de la lista. Incluye el comentario completo, autor, fechas, página, contexto del elemento y enlaces a las capturas. Las capturas se consultan con sesión iniciada en Webnotator.

En la lista podés seleccionar anotaciones individualmente o todas las de la página actual y aplicar un cambio de estado en lote. La selección se limpia al cambiar de proyecto, filtros o página. Las ignoradas se conservan, pero quedan fuera de la vista y del total por defecto; se consultan con el filtro **Ignorada** y se pueden restaurar cambiando su estado. Para incluirlas en el CSV hay que seleccionarlas expresamente.

La invitación activa el widget en el navegador del cliente. **Renovar invitación** desactiva los enlaces y accesos anteriores.

La **×** junto a **Anotar** oculta temporalmente el widget para dejar libres los controles de la página. Al recargar vuelve a aparecer con la misma invitación y nombre; no desactiva el acceso.

Si configurás un dominio como `agendario.app`, la activación se comparte entre sus subdominios en ese navegador. Podés abrir la invitación en `admin.agendario.app` y continuar en `calle11.agendario.app` sin activarla de nuevo. El navegador debe permitir cookies del sitio. Las configuraciones con una URL exacta conservan la activación por sitio.

Un dominio sin protocolo permite HTTP y HTTPS en cualquier puerto. Una URL completa restringe el acceso al protocolo, dominio y puerto indicados. Las URLs ya guardadas mantienen ese acceso específico; podés reemplazarlas por el dominio principal desde **Configurar → Sitios autorizados**.

## Actualizar en el servidor

Desde la carpeta del proyecto, cuando los cambios estén publicados en el repositorio:

```sh
git pull --ff-only
docker compose up -d --build --wait
docker compose ps
```

La actualización conserva `.env`, la base de datos y los adjuntos. Las migraciones se ejecutan automáticamente al iniciar. No hace falta reinstalar ni borrar volúmenes.

Para compartir una activación existente entre subdominios, después de actualizar recargá una vez la página donde ya funcionaba el widget. Por ejemplo, recargá `admin.agendario.app/plataforma` antes de continuar a `calle11.agendario.app`.

## Probar la demo

Con `SEED_DEMO=true`, se crea el proyecto **Agendario · Demo** con una página de prueba y tres anotaciones de ejemplo.

Abrí **Invitar a revisar → Probar la invitación** para recorrer el flujo completo.

## Comandos útiles

```sh
# Ver el estado
docker compose ps

# Ver los logs
docker compose logs -f app

# Detener
docker compose stop

# Volver a iniciar
docker compose up -d --wait

# Aplicar cambios de código o configuración
docker compose up -d --build --wait

# Crear un backup
./scripts/backup.sh
```

Los datos y adjuntos se conservan en volúmenes de Docker. Los backups se guardan en `backups/` e incluyen la configuración de acceso; guardalos en un lugar privado.
