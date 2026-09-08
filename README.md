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
2. Agregá los sitios autorizados, por ejemplo `https://agendario.app`. Incluí el protocolo y, si corresponde, el puerto; omití rutas y la barra final.
3. En **Invitar a revisar**, copiá el script y pegalo en el `<head>` del sitio.
4. Compartí el enlace de invitación con tu cliente.
5. El cliente escribe su nombre, abre el sitio y usa el botón **Anotar**.

Puede seleccionar un elemento o comentar sobre toda la página, elegir entre error, cambio o sugerencia y adjuntar una captura de hasta 5 MB.

Las anotaciones aparecen en el panel con su página, autor y contexto. Podés filtrarlas, cambiar su estado y abrir la página para localizar el elemento señalado.

La invitación activa el widget en el navegador del cliente. **Renovar invitación** desactiva los enlaces y accesos anteriores.

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
