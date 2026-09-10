import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { createServer, Server } from 'node:http';
import path from 'node:path';
test.describe.configure({mode: 'serial'});

const env = Object.fromEntries(readFileSync(path.resolve(process.cwd(), '../.env'), 'utf8').split('\n').filter(line => line && !line.startsWith('#')).map(line => { const at = line.indexOf('='); return [line.slice(0, at), line.slice(at + 1)]; }));
const origin = 'http://localhost:9091';
const appUrl = env.APP_URL || 'http://localhost:8081';
let server: Server;
let project: any;
let adminRequest: any;
let csrf: string;
let savedNote: number;
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aGNcAAAAASUVORK5CYII=', 'base64');

test.beforeAll(async ({ playwright }) => {
  adminRequest = await playwright.request.newContext({baseURL: appUrl});
  let session = await (await adminRequest.get('/api/session')).json();
  const login = await adminRequest.post('/api/session', {headers: {'X-CSRF-Token': session.csrf_token}, data: {email: env.ADMIN_EMAIL, password: env.ADMIN_PASSWORD}});
  expect(login.ok()).toBeTruthy();
  csrf = (await login.json()).csrf_token;
  const response = await adminRequest.post('/api/projects', {headers: {'X-CSRF-Token': csrf}, data: {project: {name: `QA Webnotator ${Date.now()}`, origins: [origin]}}});
  expect(response.status()).toBe(201);
  project = await response.json();
  server = createServer((_req, res) => {
    if (_req.url === '/switch-site') {
      res.writeHead(302, {Location: 'http://calle11.webnotator.localhost:9091/agenda'});
      res.end();
      return;
    }
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end(`<!doctype html><html lang="es"><head><title>Sitio de prueba del cliente</title><script defer src="${appUrl}/widget.js" data-project="${project.public_key}"></script><style>body{font:18px system-ui;padding:50px}button,select,input{padding:15px;margin:15px}</style></head><body><div id="root"><h1 id="title">Reservá tu próxima cita</h1><form id="booking"><label for="service">Servicio</label><select id="service"><option>Masaje relajante</option><option>Corte de pelo</option></select><input id="private" placeholder="Tu teléfono" value="PRIVATE_FIELD_VALUE"/><button id="save" type="submit">Guardar cita</button></form><div id="results"></div></div><script>window.activationCount=0;document.querySelector('form').addEventListener('submit',e=>{e.preventDefault();window.activationCount++;document.querySelector('#results').textContent='Se guardó';});</script></body></html>`);
  });
  await new Promise<void>(resolve => server.listen(9091, '127.0.0.1', resolve));
});
test.afterAll(async () => { await new Promise<void>(resolve => server?.close(() => resolve())); await adminRequest?.dispose(); });

async function activate(page: any) {
  await page.goto(project.invitation_url);
  await page.getByLabel('¿Cómo te llamás?').fill('María QA');
  await page.getByRole('button', {name: 'Abrir sitio y anotar'}).click();
  await expect(page.getByRole('button', {name: 'Abrir Webnotator'})).toBeVisible();
  await expect(page.locator('body > [data-webnotator-root]')).toHaveCount(1);
  await expect(page).toHaveURL(`${origin}/`);
}
async function loginPanel(page: any) {
  await page.goto(appUrl);
  await page.getByLabel('Email', {exact: true}).fill(env.ADMIN_EMAIL);
  await page.getByLabel('Contraseña').fill(env.ADMIN_PASSWORD);
  await page.getByRole('button', {name: 'Entrar al panel'}).click();
  await page.getByRole('button', {name: new RegExp(project.name)}).click();
}

test('widget stays hidden without invitation', async ({page}) => {
  await page.goto(origin);
  await page.waitForLoadState('networkidle');
  await expect(page.locator('[data-webnotator-root]')).toHaveCount(0);
});

for (const touch of [false, true]) {
  test(`launcher can be hidden until reload on ${touch ? 'mobile' : 'desktop'}`, async ({browser}, testInfo) => {
    const context = await browser.newContext({viewport: touch ? {width: 390, height: 844} : {width: 1440, height: 1000}, hasTouch: touch, isMobile: touch});
    const page = await context.newPage();
    try {
      await activate(page);
      const launch = page.getByRole('button', {name: 'Abrir Webnotator'});
      const hide = page.getByRole('button', {name: 'Ocultar Anotar hasta recargar'});
      const accessBefore = await page.evaluate(key => localStorage.getItem(key), `webnotator:${project.public_key}`);
      const bounds = await launch.boundingBox();
      expect(bounds).toBeTruthy();
      await page.evaluate(rect => {
        const button = document.createElement('button');
        button.textContent = 'Página siguiente del cliente';
        button.style.cssText = `position:fixed;left:${rect!.x}px;top:${rect!.y}px;width:${rect!.width}px;height:${rect!.height}px;margin:0;padding:0;z-index:1000`;
        button.onclick = () => { button.textContent = 'Página 2 del cliente'; history.pushState({}, '', '/pagina-2'); };
        document.body.append(button);
      }, bounds);
      expect(await page.evaluate(rect => document.elementFromPoint(rect!.x + rect!.width / 2, rect!.y + rect!.height / 2)?.hasAttribute('data-webnotator-root'), bounds)).toBe(true);
      await page.screenshot({path: testInfo.outputPath('launcher.png')});
      if (touch) await hide.tap(); else { await hide.focus(); await page.keyboard.press('Enter'); }
      await expect(launch).toBeHidden();
      await expect(hide).toBeHidden();
      const pagination = page.getByRole('button', {name: 'Página siguiente del cliente'});
      if (touch) await pagination.tap(); else await pagination.click();
      await expect(page.getByRole('button', {name: 'Página 2 del cliente'})).toBeVisible();
      await expect(launch).toBeHidden();
      expect(await page.evaluate(key => localStorage.getItem(key), `webnotator:${project.public_key}`)).toBe(accessBefore);
      await page.reload();
      await expect(launch).toBeVisible();
      await expect(hide).toBeVisible();
      await launch.click();
      await page.getByRole('button', {name: 'Anotar sobre esta página'}).click();
      await expect(page.getByLabel('Tu nombre')).toHaveValue('María QA');
      await hide.click();
      await expect(page.getByRole('dialog', {name: 'Webnotator'})).toBeHidden();
      await expect(launch).toBeHidden();
    } finally { await context.close(); }
  });
}

test('bundled demo activates the widget on the same origin', async ({page}) => {
  const projects = await (await adminRequest.get('/api/projects')).json();
  const demo = projects.find((item: any) => item.name === 'Agendario · Demo');
  expect(demo).toBeTruthy();
  await page.goto(demo.invitation_url);
  await page.getByLabel('¿Cómo te llamás?').fill('Revisor Demo');
  await page.getByRole('button', {name: 'Abrir sitio y anotar'}).click();
  await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
  await page.getByRole('button', {name: 'Seleccionar un elemento'}).click();
  await page.locator('h1').click();
  await expect(page.getByRole('heading', {name: 'Dejá tu anotación'})).toBeVisible();
  await expect(page.getByRole('dialog', {name: 'Webnotator'}).getByLabel('Tu nombre')).toHaveValue('Revisor Demo');
  await expect(page.locator('[data-webnotator-root]').locator('.surface')).toHaveCSS('font-family', /system-ui/);
});

test('widget stays outside the application root when page content changes', async ({page}) => {
  await activate(page);
  await expect(page.locator('#root [data-webnotator-root]')).toHaveCount(0);
  await page.locator('#root').evaluate(root => {
    const title = document.createElement('h1');
    title.id = 'new-title';
    title.textContent = 'Clientes';
    root.replaceChildren(title);
    history.pushState({}, '', '/clientes');
  });
  await expect(page.locator('body > [data-webnotator-root]')).toHaveCount(1);
  await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
  await page.getByRole('button', {name: 'Seleccionar un elemento'}).click();
  await page.locator('#new-title').click();
  await expect(page.getByRole('heading', {name: 'Dejá tu anotación'})).toBeVisible();
  await expect(page.getByRole('dialog', {name: 'Webnotator'})).toContainText('Clientes');
});

test('cross-origin invitation, DOM selection, attachment, dashboard and locating', async ({page, context}) => {
  const errors: string[] = []; page.on('pageerror', e => errors.push(e.message));
  await activate(page);
  await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
  await page.getByRole('button', {name: 'Seleccionar un elemento'}).click();
  await page.locator('#title').click();
  await page.getByLabel('¿Qué te gustaría cambiar?').fill('Cambiar este título por “Tu próxima pausa empieza acá”.');
  await page.getByLabel('Adjuntar captura (opcional)').setInputFiles({name: 'captura.png', mimeType: 'image/png', buffer: png});
  await page.getByRole('button', {name: 'Enviar anotación'}).click();
  await expect(page.getByText('¡Anotación enviada!')).toBeVisible();
  await page.reload();
  await expect(page.getByRole('button', {name: 'Abrir Webnotator'})).toBeVisible();
  const list = await (await adminRequest.get(`/api/projects/${project.id}/annotations`)).json();
  savedNote = list.items[0].id;
  expect(list.items[0].element.selector).toBe('#title');
  expect(list.items[0].author_name).toBe('María QA');
  expect(list.items[0].screenshot_url).toBeTruthy();
  expect(JSON.stringify(list)).not.toContain('PRIVATE_FIELD_VALUE');
  const panel = await context.newPage();
  await loginPanel(panel);
  await panel.getByRole('button', {name: /Cambiar este título/}).click();
  await expect(panel.getByRole('img', {name: 'Captura adjunta a la anotación'})).toBeVisible();
  await panel.getByLabel('Estado de la anotación').selectOption('resolved');
  await expect(panel.getByRole('status')).toContainText('Estado actualizado');
  const popupPromise = panel.waitForEvent('popup');
  await panel.getByRole('button', {name: 'Abrir y localizar elemento'}).click();
  const popup = await popupPromise;
  await expect(popup.getByText('Este es el elemento de la anotación.')).toBeVisible();
  await expect(popup.locator('[data-webnotator-root]').locator('.target')).toBeVisible();
  expect(errors).toEqual([]);
  await popup.close(); await panel.close();
});

test('selection prevents form actions, sanitizes page URL and supports page feedback', async ({page}) => {
  await activate(page);
  await page.goto(`${origin}/?token=TOP_SECRET`);
  await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
  await page.getByRole('button', {name: 'Seleccionar un elemento'}).click();
  await page.locator('#save').click();
  expect(await page.evaluate(() => (window as any).activationCount)).toBe(0);
  await page.getByLabel('¿Qué te gustaría cambiar?').fill('Guardar debería pedir confirmación.');
  await page.getByRole('button', {name: 'Enviar anotación'}).click();
  await expect(page.getByText('¡Anotación enviada!')).toBeVisible();
  await page.getByRole('button', {name: 'Seguir revisando'}).click();
  await page.locator('#save').click();
  expect(await page.evaluate(() => (window as any).activationCount)).toBe(1);
  await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
  await page.getByRole('button', {name: 'Anotar sobre esta página'}).click();
  await page.getByLabel('Tipo', {exact: true}).selectOption('bug');
  await page.getByLabel('¿Qué te gustaría cambiar?').fill('La lógica de horarios debería actualizarse.');
  await page.getByRole('button', {name: 'Enviar anotación'}).click();
  await expect(page.getByText('¡Anotación enviada!')).toBeVisible();
  const list = await (await adminRequest.get(`/api/projects/${project.id}/annotations`)).json();
  expect(list.items[0].element).toEqual({});
  expect(list.items[0].kind).toBe('bug');
  expect(JSON.stringify(list)).not.toContain('TOP_SECRET');
});

test('mobile project creation, filters, logout, invalid login', async ({page}) => {
  await page.setViewportSize({width: 390, height: 844});
  await loginPanel(page);
  await page.getByLabel('Filtrar por estado').selectOption('resolved');
  await expect(page.getByRole('button', {name: /Cambiar este título/})).toBeVisible();
  await page.getByLabel('Buscar anotaciones').fill('no existe esta frase');
  await expect(page.getByText('No hay coincidencias')).toBeVisible();
  await page.getByLabel('Buscar anotaciones').fill('');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.setViewportSize({width: 1440, height: 1000});
  await page.getByRole('button', {name: 'Nuevo proyecto', exact: true}).click();
  await page.getByLabel('Nombre del proyecto').fill('QA Webnotator UI');
  await page.getByLabel('Sitios autorizados').fill('agendario.app');
  await page.getByRole('dialog').getByRole('button', {name: 'Crear proyecto', exact: true}).click();
  await expect(page.getByRole('heading', {name: 'QA Webnotator UI'})).toBeVisible();
  await page.getByRole('button', {name: 'Cerrar sesión'}).click();
  await expect(page.getByRole('heading', {name: 'Volvé a tus proyectos'})).toBeVisible();
  await page.getByLabel('Email', {exact: true}).fill(env.ADMIN_EMAIL);
  await page.getByLabel('Contraseña').fill('wrong-password');
  await page.getByRole('button', {name: 'Entrar al panel'}).click();
  await expect(page.getByRole('alert')).toContainText('Email o contraseña incorrectos');
});

test('export page has independent filters and downloads matching notes', async ({page}, testInfo) => {
  await loginPanel(page);
  await page.setViewportSize({width: 390, height: 844});
  await page.getByLabel('Buscar anotaciones').fill('sin coincidencias para exportar');
  await expect(page.getByText('No hay coincidencias')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({path: testInfo.outputPath('export-mobile.png'), fullPage: true});
  await page.getByRole('button', {name: 'Exportar CSV'}).click();
  await expect(page).toHaveURL(`${appUrl}/projects/${project.id}/export`);
  await expect(page.getByRole('heading', {name: 'Exportar anotaciones'})).toBeVisible();
  await expect(page.getByText('3 anotaciones para exportar', {exact: true})).toBeVisible();
  await expect(page.getByLabel('Ignorada', {exact: true})).not.toBeChecked();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({path: testInfo.outputPath('export-mobile.png'), fullPage: true});
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', {name: 'Descargar CSV', exact: true}).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe(`webnotator-${project.id}-anotaciones.csv`);
  const file = testInfo.outputPath('anotaciones.csv');
  await download.saveAs(file);
  const csv = readFileSync(file, 'utf8');
  expect(csv).toContain('Cambiar este título por “Tu próxima pausa empieza acá”.');
  expect(csv).toContain('Guardar debería pedir confirmación.');
  expect(csv).toContain('La lógica de horarios debería actualizarse.');
  expect(csv).toContain('"Resuelto"');
  expect(csv).toContain('"Pendiente"');
  expect(csv).toContain('/screenshot');
  await page.getByLabel('Pendiente', {exact: true}).uncheck();
  await page.getByLabel('En curso', {exact: true}).uncheck();
  await page.getByLabel('Autor', {exact: true}).selectOption('María QA');
  const today = new Date().toISOString().slice(0, 10);
  await page.getByLabel('Desde (fecha de creación, UTC)').fill(today);
  await page.getByLabel('Hasta (inclusive, UTC)').fill(today);
  await expect(page.getByText('1 anotación para exportar', {exact: true})).toBeVisible();
  const filteredDownload = page.waitForEvent('download');
  await page.getByRole('button', {name: 'Descargar CSV', exact: true}).click();
  const filteredFile = testInfo.outputPath('filtradas.csv');
  await (await filteredDownload).saveAs(filteredFile);
  const filteredCsv = readFileSync(filteredFile, 'utf8');
  expect(filteredCsv).toContain('Cambiar este título');
  expect(filteredCsv).not.toContain('Guardar debería');
  expect(filteredCsv).not.toContain('La lógica');
  await page.getByLabel('Resuelto', {exact: true}).uncheck();
  await expect(page.getByRole('alert')).toContainText('Elegí al menos un estado');
  await expect(page.getByRole('button', {name: 'Descargar CSV', exact: true})).toBeDisabled();
  await page.getByRole('button', {name: 'Restablecer filtros'}).click();
  await page.getByLabel('Buscar texto').fill('no existe este texto');
  await expect(page.getByText('0 anotaciones para exportar', {exact: true})).toBeVisible();
  await expect(page.getByRole('button', {name: 'Descargar CSV', exact: true})).toBeDisabled();
  await page.goBack();
  await expect(page.getByText('No hay coincidencias')).toBeVisible();
  await page.goForward();
  await expect(page.getByRole('heading', {name: 'Exportar anotaciones'})).toBeVisible();
  await page.reload();
  await expect(page.getByRole('heading', {name: 'Exportar anotaciones'})).toBeVisible();
  await page.setViewportSize({width: 1440, height: 1000});
  await page.screenshot({path: testInfo.outputPath('export-desktop.png'), fullPage: true});
  await page.getByRole('button', {name: 'Volver a anotaciones'}).click();
  await expect(page.getByLabel('Filtrar por estado')).toBeVisible();
});

test('bulk actions hide ignored notes and allow restoring them explicitly', async ({page}, testInfo) => {
  await loginPanel(page);
  await page.getByLabel('Filtrar por estado').selectOption('pending');
  await expect(page.getByRole('button', {name: /Guardar debería/})).toBeVisible();
  const selectAll = page.getByLabel('Seleccionar todas las anotaciones de esta página');
  await selectAll.check();
  await expect(page.getByText('2 seleccionadas', {exact: true})).toBeVisible();
  await page.getByLabel('Filtrar por tipo').selectOption('bug');
  await expect(page.getByText('2 seleccionadas', {exact: true})).toHaveCount(0);
  await expect(page.getByRole('button', {name: /La lógica/})).toBeVisible();
  await expect(selectAll).not.toBeChecked();
  await page.getByLabel('Filtrar por tipo').selectOption('');
  await expect(page.getByRole('button', {name: /Guardar debería/})).toBeVisible();
  const boxes = page.getByRole('checkbox', {name: /^Seleccionar anotación #/});
  await boxes.first().check();
  expect(await selectAll.evaluate((el: HTMLInputElement) => el.indeterminate)).toBe(true);
  await expect(page.getByLabel('Detalle de anotación')).toHaveCount(0);
  await selectAll.check();
  await page.getByLabel('Estado para las seleccionadas').selectOption('discarded');
  await page.setViewportSize({width: 390, height: 844});
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({path: testInfo.outputPath('bulk-mobile.png'), fullPage: true});
  await page.getByRole('button', {name: 'Aplicar', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('2 anotaciones actualizadas');
  await expect(page.getByRole('button', {name: /Guardar debería/})).toHaveCount(0);
  await page.getByLabel('Filtrar por estado').selectOption('');
  await expect(page.getByRole('button', {name: /Cambiar este título/})).toBeVisible();
  await expect(page.getByRole('button', {name: /Guardar debería/})).toHaveCount(0);
  await page.getByRole('button', {name: 'Exportar CSV'}).click();
  await expect(page.getByText('1 anotación para exportar', {exact: true})).toBeVisible();
  await page.getByLabel('Ignorada', {exact: true}).check();
  await expect(page.getByText('3 anotaciones para exportar', {exact: true})).toBeVisible();
  await page.getByRole('button', {name: 'Volver a anotaciones'}).click();
  await page.getByLabel('Filtrar por estado').selectOption('discarded');
  await expect(page.getByRole('button', {name: /Guardar debería/})).toBeVisible();
  await expect(boxes).toHaveCount(2);
  await selectAll.check();
  await page.getByLabel('Estado para las seleccionadas').selectOption('pending');
  await page.getByRole('button', {name: 'Aplicar', exact: true}).click();
  await expect(page.getByText('No hay coincidencias')).toBeVisible();
  await page.getByLabel('Filtrar por estado').selectOption('');
  await expect(page.getByRole('button', {name: /Guardar debería/})).toBeVisible();
});

test('one invitation follows redirects across authorized subdomains and remains revocable', async ({page, context}) => {
  const update = await adminRequest.patch(`/api/projects/${project.id}`, {headers: {'X-CSRF-Token': csrf}, data: {project: {origins: ['webnotator.localhost', origin]}}});
  expect(update.ok()).toBeTruthy();
  try {
    await page.goto('http://calle11.webnotator.localhost:9091/agenda');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('[data-webnotator-root]')).toHaveCount(0);
    await page.goto(project.invitation_url);
    await page.getByLabel('¿Cómo te llamás?').fill('Revisor del dominio');
    await page.getByLabel('Página para empezar').fill('http://evilwebnotator.localhost:9091');
    await page.getByRole('button', {name: 'Abrir sitio y anotar'}).click();
    await expect(page.getByRole('alert')).toContainText('La dirección debe pertenecer');
    await page.getByLabel('Página para empezar').fill('http://admin.webnotator.localhost:9091/plataforma');
    await page.getByRole('button', {name: 'Abrir sitio y anotar'}).click();
    await expect(page.getByRole('button', {name: 'Abrir Webnotator'})).toBeVisible();
    const cookies = await context.cookies();
    expect(cookies.find(cookie => cookie.name === `webnotator_${project.public_key}`)?.domain).toBe('.webnotator.localhost');
    await page.goto('http://admin.webnotator.localhost:9091/switch-site');
    await expect(page).toHaveURL('http://calle11.webnotator.localhost:9091/agenda');
    for (const host of ['calle11.webnotator.localhost', 'webnotator.localhost', 'preview.admin.webnotator.localhost']) {
      await page.goto(`http://${host}:9091/agenda`);
      await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
      await page.getByRole('button', {name: 'Anotar sobre esta página'}).click();
      await expect(page.getByLabel('Tu nombre')).toHaveValue('Revisor del dominio');
      await page.getByLabel('¿Qué te gustaría cambiar?').fill(`Feedback desde ${host}`);
      await page.getByRole('button', {name: 'Enviar anotación'}).click();
      await expect(page.getByText('¡Anotación enviada!')).toBeVisible();
    }
    await page.goto('http://evilwebnotator.localhost:9091');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('[data-webnotator-root]')).toHaveCount(0);
    const rotated = await adminRequest.post(`/api/projects/${project.id}/rotate_invitation`, {headers: {'X-CSRF-Token': csrf}});
    expect(rotated.ok()).toBeTruthy();
    project = await rotated.json();
    for (const host of ['admin.webnotator.localhost', 'calle11.webnotator.localhost']) {
      await page.goto(`http://${host}:9091/agenda`);
      await page.waitForLoadState('networkidle');
      await expect(page.locator('[data-webnotator-root]')).toHaveCount(0);
    }
  } finally {
    const restored = await adminRequest.patch(`/api/projects/${project.id}`, {headers: {'X-CSRF-Token': csrf}, data: {project: {origins: [origin]}}});
    expect(restored.ok()).toBeTruthy();
  }
});

test('existing local activation migrates to the configured domain and deactivation clears it', async ({page}) => {
  const update = await adminRequest.patch(`/api/projects/${project.id}`, {headers: {'X-CSRF-Token': csrf}, data: {project: {origins: ['webnotator.localhost', origin]}}});
  expect(update.ok()).toBeTruthy();
  try {
    await page.goto('http://admin.webnotator.localhost:9091/plataforma');
    await page.evaluate(({key, token}) => localStorage.setItem(key, JSON.stringify({token, name: 'Revisor existente'})), {key: `webnotator:${project.public_key}`, token: project.invitation_url.split('/').pop()});
    await page.reload();
    await expect(page.getByRole('button', {name: 'Abrir Webnotator'})).toBeVisible();
    expect(await page.evaluate(key => localStorage.getItem(key), `webnotator:${project.public_key}`)).toBeNull();
    await page.goto('http://admin.webnotator.localhost:9091/switch-site');
    await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
    await expect(page.getByRole('dialog', {name: 'Webnotator'})).toContainText('Revisor existente');
    await page.getByRole('button', {name: 'Desactivar en este navegador'}).click();
    await page.goto('http://admin.webnotator.localhost:9091/plataforma');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('[data-webnotator-root]')).toHaveCount(0);
  } finally {
    const restored = await adminRequest.patch(`/api/projects/${project.id}`, {headers: {'X-CSRF-Token': csrf}, data: {project: {origins: [origin]}}});
    expect(restored.ok()).toBeTruthy();
  }
});

test('touch selection works and never copies an input value', async ({browser}) => {
  const context = await browser.newContext({viewport: {width: 390, height: 844}, hasTouch: true, isMobile: true});
  const page = await context.newPage();
  await activate(page);
  await page.getByRole('button', {name: 'Abrir Webnotator'}).tap();
  await page.getByRole('button', {name: 'Seleccionar un elemento'}).tap();
  await page.locator('#private').tap();
  await expect(page.getByRole('heading', {name: 'Dejá tu anotación'})).toBeVisible();
  await page.getByLabel('¿Qué te gustaría cambiar?').fill('Validar el formato del teléfono.');
  await page.getByRole('button', {name: 'Enviar anotación'}).tap();
  await expect(page.getByText('¡Anotación enviada!')).toBeVisible();
  const list = await (await adminRequest.get(`/api/projects/${project.id}/annotations`)).json();
  expect(list.items[0].element.text).toBe('Tu teléfono');
  expect(JSON.stringify(list)).not.toContain('PRIVATE_FIELD_VALUE');
  await context.close();
});

test('revoking invitation blocks a previously activated browser', async ({page}) => {
  await activate(page);
  const rotated = await adminRequest.post(`/api/projects/${project.id}/rotate_invitation`, {headers: {'X-CSRF-Token': csrf}});
  expect(rotated.ok()).toBeTruthy();
  await page.getByRole('button', {name: 'Abrir Webnotator'}).click();
  await page.getByRole('button', {name: 'Anotar sobre esta página'}).click();
  await page.getByLabel('¿Qué te gustaría cambiar?').fill('No debería aceptarse');
  await page.getByRole('button', {name: 'Enviar anotación'}).click();
  await expect(page.getByRole('alert')).toContainText('La invitación venció');
  await expect(page.getByLabel('¿Qué te gustaría cambiar?')).toHaveValue('No debería aceptarse');
  await page.reload();
  await page.waitForLoadState('networkidle');
  await expect(page.locator('[data-webnotator-root]')).toHaveCount(0);
});
