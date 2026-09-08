/* Webnotator embed — standalone, no dependencies. */
(() => {
  'use strict';
  const script = document.currentScript;
  const project = script && script.dataset.project;
  if (!project || document.querySelector('[data-webnotator-root]')) return;
  const base = new URL(script.src).origin;
  const key = `webnotator:${project}`;
  let access;
  try { access = JSON.parse(localStorage.getItem(key) || 'null'); } catch (_) { access = null; }
  let locateId;
  const marker = '~webnotator=';
  const markerAt = location.hash.indexOf(marker);
  if (markerAt >= 0) {
    const raw = location.hash.slice(markerAt + marker.length);
    const cleanHash = location.hash.slice(0, markerAt);
    history.replaceState(history.state, '', location.pathname + location.search + (cleanHash === '#' ? '' : cleanHash));
    try {
      const payload = JSON.parse(decodeURIComponent(escape(atob(decodeURIComponent(raw)))));
      if (typeof payload.token === 'string' && /^[\w-]{40,60}$/.test(payload.token)) {
        access = { token: payload.token, name: typeof payload.name === 'string' ? payload.name.slice(0, 80) : (access?.name || '') };
        locateId = Number.isSafeInteger(payload.note) ? payload.note : undefined;
        persist();
      }
    } catch (_) { /* Ignore malformed activation fragments. */ }
  }
  if (!access?.token) return;
  function persist() { try { localStorage.setItem(key, JSON.stringify(access)); } catch (_) { /* Storage may be disabled; current-tab access still works. */ } }
  function forget() { try { localStorage.removeItem(key); } catch (_) {} }
  async function request(path, options = {}) {
    const response = await fetch(`${base}/api/widget/${encodeURIComponent(project)}/${path}`, { ...options, credentials: 'omit', headers: { Authorization: `Bearer ${access.token}`, ...options.headers } });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      if (response.status === 401) forget();
      throw new Error(result.error || (response.status === 429 ? 'Recibimos muchas solicitudes. Esperá un minuto e intentá de nuevo.' : 'No pudimos enviar la anotación. Intentá de nuevo.'));
    }
    return result;
  }
  request('context').then(boot).catch(error => {
    console.info('[Webnotator]', error.message);
    if (markerAt >= 0) boot({ name: 'Webnotator', error: error.message });
  });
  function boot(context) {
    if (!document.body) {
      document.addEventListener('DOMContentLoaded', () => boot(context), { once: true });
      return;
    }
    if (document.querySelector('[data-webnotator-root]')) return;
    const host = document.createElement('div');
    host.dataset.webnotatorRoot = '';
    // Inline styles here and inside the shadow root keep the host site's CSS out.
    host.style.cssText = 'all:initial!important;position:fixed!important;inset:auto 20px 20px auto!important;z-index:2147483647!important;display:block!important;';
    document.body.append(host);
    const shadow = host.attachShadow({ mode: 'open' });
    const style = document.createElement('style');
    if (script.nonce) style.nonce = script.nonce;
    style.textContent = `
      :host{all:initial;font-family:system-ui,-apple-system,sans-serif;font-size:14px;color:#33283e;line-height:1.5;color-scheme:light}
      .surface{font-family:system-ui,-apple-system,sans-serif;font-size:14px;color:#33283e;line-height:1.5}*{box-sizing:border-box}button,input,textarea,select{font:inherit}button{cursor:pointer;border:0;border-radius:8px;padding:10px 13px;display:inline-flex;align-items:center;justify-content:center;gap:7px;background:#f3eff9;color:#735393;font-weight:600}button:hover{filter:brightness(.96)}button:disabled{opacity:.6;cursor:wait}button:focus-visible,input:focus-visible,textarea:focus-visible,select:focus-visible{outline:3px solid #b5a1e8;outline-offset:2px}.launch{background:#7657df;color:white;border:1px solid #a58ae8;box-shadow:0 5px 25px #36234e35;border-radius:30px;height:48px;padding:0 19px;float:right;font-size:13px}.launch svg{width:18px;height:18px}.panel{background:white;border:1px solid #e0d7eb;border-radius:15px;box-shadow:0 12px 60px #25113535;width:350px;max-width:calc(100vw - 32px);max-height:calc(100dvh - 96px);overflow:auto;margin-bottom:12px;padding:21px;clear:both}.hidden{display:none!important}.head{display:flex;align-items:center;justify-content:space-between;margin-bottom:15px}.brand{font-size:16px;font-weight:700;letter-spacing:-.6px}.brand span{color:#9871de}.close{padding:2px 8px;background:none;font-size:22px;color:#a78ab7}.eyebrow{font-size:10px;letter-spacing:1.1px;color:#aa91b9;font-weight:700;text-transform:uppercase;margin-bottom:6px}h2{font-size:19px;line-height:1.3;letter-spacing:-.5px;margin:0 0 8px}p{color:#98859f;font-size:12px;margin:0 0 17px;line-height:1.7}.actions{display:grid;gap:9px}.primary{background:#7657df;color:white}.option{justify-content:flex-start;background:#f7f3fc;border:1px solid #e6dcf0;padding:14px;gap:12px;text-align:left;font-size:13px}.option span small{display:block;font-weight:400;color:#ab96b6;font-size:11px;margin-top:3px}.option svg{width:20px;height:20px;color:#9c79cc}.foot{display:flex;justify-content:space-between;margin-top:17px}.link{padding:0;background:none;color:#a58db3;font-size:10px;font-weight:400}.context{background:#f6f1fb;border-left:3px solid #a789d2;padding:10px 12px;border-radius:4px;font-size:11px;margin:15px 0;color:#9980ac;overflow-wrap:anywhere}.context strong{display:block;color:#785b92;font-size:12px;margin-bottom:3px}label{display:block;font-size:12px;color:#7f658e;font-weight:600;margin:13px 0 5px}input,textarea,select{width:100%;background:white;color:#55415f;border:1px solid #ded3e7;border-radius:7px;padding:9px;font-size:13px}textarea{resize:vertical;min-height:100px}input[type=file]{font-size:11px;padding:8px}.row{display:flex;gap:10px}.row>div{flex:1;min-width:0}.help{font-size:10px;color:#ae99b8;margin:5px 0 15px}.submit{width:100%;margin-top:15px}.error{color:#a6434c;background:#fff0f1;border-radius:6px;padding:10px;font-size:12px;margin:12px 0;white-space:pre-wrap}.success{padding:20px 0;text-align:center}.success-mark{font-size:30px;color:#8f6cb9;background:#f0e8fb;border-radius:50%;height:55px;width:55px;margin:0 auto 15px;display:grid;place-items:center}.target{position:fixed;pointer-events:none!important;border:2px solid #9564e5;background:#a472ef18;border-radius:3px;box-shadow:0 0 0 1px #fff8;z-index:2147483645}.target-label{position:absolute;bottom:100%;left:-2px;font-size:11px;background:#9564e5;color:white;padding:2px 6px;border-radius:4px 4px 0 0;white-space:nowrap}.select-banner{position:fixed;top:16px;left:50%;transform:translateX(-50%);display:flex;align-items:center;gap:15px;background:#352641;color:white;padding:11px 17px;border-radius:11px;box-shadow:0 4px 20px #28123033;width:max-content;max-width:calc(100vw - 30px);font-size:12px}.select-banner button{font-size:11px;padding:5px 8px;background:#5d4271;color:white}.notice{position:fixed;bottom:85px;right:20px;max-width:350px;padding:14px 18px;border:1px solid #e6dcf0;border-radius:10px;background:white;box-shadow:0 5px 30px #25113525;font-size:13px;color:#7d5a91}@media(max-width:450px){.panel{width:calc(100vw - 32px)}.launch{height:45px}.select-banner{font-size:11px;gap:7px}.panel{padding:18px}}
    `;
    shadow.append(style);
    const box = document.createElement('div');
    box.className = 'surface';
    box.innerHTML = `<div class="panel hidden" role="dialog" aria-label="Webnotator"><div class="head"><span class="brand">webnotator<span>.</span></span><button class="close" aria-label="Cerrar">×</button></div><div class="content"></div></div><button class="launch" aria-label="Abrir Webnotator" aria-expanded="false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M4 4h16v12H10l-6 5V4z"/><path d="M8 8h8M8 12h5"/></svg> Anotar</button><div class="target hidden"><span class="target-label"></span></div><div class="select-banner hidden"><span>Seleccioná un elemento de la página</span><button class="cancel">Cancelar · Esc</button></div><div class="notice hidden" role="status"></div>`;
    shadow.append(box);
    const panel = shadow.querySelector('.panel'); const content = shadow.querySelector('.content'); const launch = shadow.querySelector('.launch'); const border = shadow.querySelector('.target'); const banner = shadow.querySelector('.select-banner'); const notice = shadow.querySelector('.notice');
    let selecting = false, hovered = null, chosen = null, draft = {body: '', kind: 'change', name: access.name || '', file: null}, requestId = null, sending = false, noticeTimer;
    const escapeHtml = value => String(value || '').replace(/[&<>"']/g, c => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
    const cursorIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="m4 3 16 9-8 2-3 7-5-18z"/></svg>';
    function open() { panel.classList.remove('hidden'); launch.setAttribute('aria-expanded', 'true'); }
    function close() { if (sending) return; captureDraft(); stopSelection(); panel.classList.add('hidden'); launch.setAttribute('aria-expanded', 'false'); launch.focus(); }
    function toast(message) { notice.textContent = message; notice.classList.remove('hidden'); clearTimeout(noticeTimer); noticeTimer = setTimeout(() => notice.classList.add('hidden'), 6000); }
    function home() {
      chosen = null; requestId = null;
      content.innerHTML = `<div class="eyebrow">${escapeHtml(context.name)}</div><h2>¿Qué podemos mejorar?</h2><p>Señalá algo en la página o contanos una idea general.</p><div class="actions"><button class="option choose">${cursorIcon}<span>Seleccionar un elemento<small>Un título, un botón, un campo…</small></span></button><button class="option page"><span style="font-size:21px">⊞</span><span>Anotar sobre esta página<small>Una idea o un problema de funcionamiento</small></span></button></div><div class="foot"><span class="link">${escapeHtml(access.name || 'Revisión del sitio')}</span><button class="link deactivate">Desactivar en este navegador</button></div>`;
      content.querySelector('.choose').onclick = startSelection;
      content.querySelector('.page').onclick = () => {chosen = null; composer();};
      content.querySelector('.deactivate').onclick = () => { forget(); stopSelection(); document.removeEventListener('keydown', onKey, true); host.remove(); };
    }
    function captureDraft() {
      const form = content.querySelector('form');
      if (form) draft = { body: form.elements.body.value, kind: form.elements.kind.value, name: form.elements.author_name.value, file: form.elements.screenshot.files[0] || draft.file };
    }
    function composer() {
      open();
      content.innerHTML = `<h2>Dejá tu anotación</h2><div class="context"><strong>${chosen ? `&lt;${escapeHtml(chosen.tag)}&gt;` : 'Página completa'}</strong>${escapeHtml(chosen ? chosen.text || chosen.selector : document.title)}</div><form><div class="row"><div><label for="wn-name">Tu nombre</label><input id="wn-name" name="author_name" required maxlength="80" autocomplete="name" value="${escapeHtml(draft.name)}"></div><div><label for="wn-kind">Tipo</label><select id="wn-kind" name="kind"><option value="change">Cambio</option><option value="bug">Error</option><option value="suggestion">Sugerencia</option></select></div></div><label for="wn-body">¿Qué te gustaría cambiar?</label><textarea id="wn-body" name="body" required maxlength="10000" placeholder="Por ejemplo: este campo debería permitir buscar escribiendo…">${escapeHtml(draft.body)}</textarea><label for="wn-file">Adjuntar captura (opcional)</label><input id="wn-file" type="file" name="screenshot" accept="image/png,image/jpeg,image/webp"><div class="help file-help">PNG, JPEG o WebP · Hasta 5 MB${draft.file ? ` · Conservada: ${escapeHtml(draft.file.name)}` : ''}</div><div class="error hidden" role="alert"></div><button class="primary submit" type="submit">Enviar anotación ↗</button></form><div class="foot"><button class="link back">← Volver</button><button class="link change-element">Cambiar elemento</button></div>`;
      const form = content.querySelector('form'); form.elements.kind.value = draft.kind;
      form.onsubmit = send;
      form.elements.screenshot.onchange = () => { draft.file = form.elements.screenshot.files[0] || null; content.querySelector('.file-help').textContent = 'PNG, JPEG o WebP · Hasta 5 MB'; };
      content.querySelector('.back').onclick = () => { captureDraft(); home(); };
      content.querySelector('.change-element').onclick = () => { captureDraft(); startSelection(); };
      form.elements[draft.name ? 'body' : 'author_name'].focus();
    }
    function pageUrl() {
      const url = new URL(location.href); url.search = '';
      // Keep hash-router paths, but not tokens or arbitrary fragments.
      url.hash = url.hash.startsWith('#/') ? url.hash.split('?')[0] : '';
      return url.href;
    }
    async function send(event) {
      event.preventDefault(); if (sending) return;
      captureDraft(); const form = event.currentTarget; const error = form.querySelector('.error'); error.classList.add('hidden');
      if (!draft.body.trim() || !draft.name.trim()) { error.textContent = 'Completá tu nombre y el comentario.'; error.classList.remove('hidden'); return; }
      if (draft.file && draft.file.size > 5 * 1024 * 1024) { error.textContent = 'La captura debe pesar como máximo 5 MB.'; error.classList.remove('hidden'); return; }
      const data = new FormData();
      requestId ||= (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`);
      Object.entries({author_name: draft.name.trim(), body: draft.body.trim(), kind: draft.kind, page_url: pageUrl(), page_title: document.title.slice(0, 200), client_id: requestId, element: JSON.stringify(chosen || {}), viewport: JSON.stringify({width: innerWidth, height: innerHeight})}).forEach(([k,v]) => data.set(k,v));
      if (draft.file) data.set('screenshot', draft.file);
      sending = true;
      const button = form.querySelector('.submit'); button.disabled = true; button.textContent = 'Enviando…';
      try {
        await request('annotations', {method: 'POST', body: data});
        access.name = draft.name.trim(); persist(); draft = {body: '', kind: 'change', name: access.name, file: null}; requestId = null;
        content.innerHTML = '<div class="success"><div class="success-mark">✓</div><h2>¡Anotación enviada!</h2><p>Tu comentario ya está en el panel del proyecto. Gracias por ayudar a mejorarlo.</p><button class="primary again">Seguir revisando</button></div>';
        content.querySelector('.again').onclick = () => {home(); close();};
        content.querySelector('.again').focus();
      } catch (e) { error.textContent = e.message || 'No hay conexión. Tu comentario sigue acá; intentá de nuevo.'; error.classList.remove('hidden'); button.disabled = false; button.textContent = 'Reintentar envío ↗'; }
      finally {sending = false;}
    }
    function selectorFor(element) {
      const parts = []; let node = element;
      while (node && node.nodeType === 1) {
        if (node.id && document.querySelectorAll(`#${CSS.escape(node.id)}`).length === 1) { parts.unshift(`#${CSS.escape(node.id)}`); break; }
        let part = node.localName;
        if (node.parentElement) {
          const same = [...node.parentElement.children].filter(s => s.localName === node.localName);
          if (same.length > 1) part += `:nth-of-type(${same.indexOf(node) + 1})`;
        }
        parts.unshift(part); node = node.parentElement;
      }
      return parts.join(' > ').slice(0, 2500);
    }
    function elementText(element) {
      // Never collect field values, HTML, or password input content.
      if (/^(INPUT|TEXTAREA)$/.test(element.tagName)) return (element.getAttribute('aria-label') || element.getAttribute('placeholder') || element.getAttribute('name') || '').slice(0, 160);
      const clone = element.cloneNode(true);
      clone.querySelectorAll('input,textarea,script,style,[contenteditable]').forEach(node => node.remove());
      if (element.isContentEditable) return '';
      return (clone.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 160);
    }
    function move(event) {
      if (event.composedPath().includes(host)) return;
      const element = event.target;
      if (!(element instanceof Element) || element === document.documentElement) return;
      hovered = element; draw(element);
    }
    function draw(element) {
      const rect = element.getBoundingClientRect();
      border.style.left = `${rect.left}px`; border.style.top = `${rect.top}px`; border.style.width = `${rect.width}px`; border.style.height = `${rect.height}px`;
      border.classList.remove('hidden'); border.querySelector('span').textContent = `<${element.localName}>`;
    }
    function block(event) {
      if (event.composedPath().includes(host)) return;
      event.preventDefault(); event.stopImmediatePropagation();
    }
    function pick(event) {
      if (event.composedPath().includes(host)) return;
      block(event);
      const element = event.target;
      if (!(element instanceof Element)) return;
      chosen = {selector: selectorFor(element), tag: element.localName, text: elementText(element)};
      stopSelection(); composer();
    }
    function reposition() { if (hovered && selecting) draw(hovered); }
    function startSelection() {
      captureDraft(); panel.classList.add('hidden'); banner.classList.remove('hidden'); launch.classList.add('hidden'); selecting = true;
      document.addEventListener('pointermove', move, true);
      ['pointerdown', 'mousedown', 'submit', 'contextmenu'].forEach(type => document.addEventListener(type, block, {capture: true, passive: false}));
      document.addEventListener('click', pick, true);
      window.addEventListener('scroll', reposition, true); window.addEventListener('resize', reposition);
    }
    function stopSelection() {
      selecting = false; hovered = null;
      border.classList.add('hidden'); banner.classList.add('hidden'); launch.classList.remove('hidden');
      document.removeEventListener('pointermove', move, true);
      ['pointerdown', 'mousedown', 'submit', 'contextmenu'].forEach(type => document.removeEventListener(type, block, true));
      document.removeEventListener('click', pick, true);
      window.removeEventListener('scroll', reposition, true); window.removeEventListener('resize', reposition);
    }
    function onKey(event) {
      if (event.key === 'Escape') { if (selecting) {event.preventDefault(); event.stopImmediatePropagation(); stopSelection(); open(); home();} else if (!panel.classList.contains('hidden')) close(); }
      if (selecting && event.key === 'Enter' && !event.composedPath().includes(host)) {
        const target = hovered || document.activeElement;
        if (target instanceof Element) {event.preventDefault(); event.stopImmediatePropagation(); chosen = {selector: selectorFor(target), tag: target.localName, text: elementText(target)}; stopSelection(); composer();}
      }
    }
    launch.onclick = () => { if (!panel.classList.contains('hidden')) close(); else {open(); if (!content.children.length) home();} };
    shadow.querySelector('.close').onclick = close;
    shadow.querySelector('.cancel').onclick = () => {stopSelection(); open(); home();};
    document.addEventListener('keydown', onKey, true);
    if (context.error) {open(); home(); toast(context.error);}
    if (locateId) {
      request(`annotations/${locateId}`).then(note => {
        if (!note.element?.selector) { toast('Esta anotación corresponde a la página completa.'); return; }
        let attempts = 0;
        const find = () => {
          let element; try { element = document.querySelector(note.element.selector); } catch (_) {}
          // Do not silently highlight a different element after a DOM change.
          const matches = element && (!note.element.tag || element.localName === note.element.tag) && (!note.element.text || elementText(element) === note.element.text);
          if (!matches && attempts++ < 12) { setTimeout(find, 350); return; }
          if (!matches) {toast('El elemento ya no se encuentra en esta página. El contexto original sigue guardado en el panel.'); return;}
          element.scrollIntoView({block: 'center', behavior: 'instant'}); draw(element); toast('Este es el elemento de la anotación.'); setTimeout(() => border.classList.add('hidden'), 6000);
        };
        find();
      }).catch(e => toast(e.message));
    }
  }
})();
