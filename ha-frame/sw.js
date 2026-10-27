// Redirects requests from embedded sites that point to absolute paths ("/assets/x.js")
// to the ingress prefix. The site is determined via the client ID.
var scopeUrl = new URL(self.registration.scope);
var origin = scopeUrl.origin;
var prefix = scopeUrl.pathname.replace(/\/$/, '');
var siteRe = new RegExp('^' + prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '/s/([^/]+)/');
var CACHE = 'ha-frame-clients';

function key(id) { return new Request('https://client.invalid/' + id); }

async function remember(id, site) {
  if (!id) return;
  var c = await caches.open(CACHE);
  await c.put(key(id), new Response(site));
}

async function recall(id) {
  if (!id) return null;
  var c = await caches.open(CACHE);
  var r = await c.match(key(id));
  return r ? r.text() : null;
}

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

self.addEventListener('fetch', function (e) {
  var u = new URL(e.request.url);
  if (u.origin !== origin) return;

  if (u.pathname === prefix || u.pathname.indexOf(prefix + '/') === 0) {
    var m = siteRe.exec(u.pathname);
    if (m && e.request.mode === 'navigate') {
      e.waitUntil(Promise.all([remember(e.resultingClientId, m[1]), remember(e.clientId, m[1])]));
    }
    return;
  }
  if (e.request.mode === 'navigate') return;
  e.respondWith(rewrite(e.request, u, e.clientId));
});

async function rewrite(request, u, clientId) {
  var site = await recall(clientId);
  if (!site && request.referrer) {
    try {
      var m = siteRe.exec(new URL(request.referrer).pathname);
      if (m) site = m[1];
    } catch (err) {}
  }
  if (!site) return fetch(request);
  var init = { method: request.method, headers: request.headers, credentials: 'include', redirect: 'follow' };
  if (request.method !== 'GET' && request.method !== 'HEAD') init.body = await request.blob();
  return fetch(origin + prefix + '/s/' + site + u.pathname + u.search, init);
}
