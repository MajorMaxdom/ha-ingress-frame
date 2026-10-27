<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Homelab</title>
<style>
  html, body { margin: 0; height: 100%; font-family: system-ui, sans-serif; }
  body { display: flex; flex-direction: column; background: #fff; color: #111; }
  nav { display: flex; gap: 4px; padding: 6px 8px; background: #f2f2f2; overflow-x: auto; }
  nav button { border: 0; border-radius: 6px; padding: 8px 14px; background: transparent; color: inherit; font: inherit; cursor: pointer; white-space: nowrap; }
  nav button.active { background: #03a9f4; color: #fff; }
  iframe { flex: 1; border: 0; width: 100%; }
  @media (prefers-color-scheme: dark) {
    body { background: #111; color: #eee; }
    nav { background: #1c1c1c; }
  }
</style>
</head>
<body>
<nav id="tabs"></nav>
<iframe id="frame" title="Homelab"
  sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-popups-to-escape-sandbox allow-modals allow-downloads allow-pointer-lock allow-presentation"
  allow="fullscreen; clipboard-read; clipboard-write; autoplay"></iframe>
<script>
  // Relative URLs: the ingress prefix is dynamic.
  var sites = /*SITES*/[];
  var tabs = document.getElementById('tabs');
  var frame = document.getElementById('frame');
  function open(i) {
    frame.src = 's/' + sites[i].name + '/' + (sites[i].path || '');
    Array.prototype.forEach.call(tabs.children, function (b, j) { b.classList.toggle('active', i === j); });
    try { localStorage.setItem('ha-frame-tab', String(i)); } catch (e) {}
  }
  sites.forEach(function (s, i) {
    var b = document.createElement('button');
    b.textContent = s.title;
    b.onclick = function () { open(i); };
    tabs.appendChild(b);
  });
  var start = 0;
  try { start = Math.min(+localStorage.getItem('ha-frame-tab') || 0, sites.length - 1); } catch (e) {}
  // Activate the service worker first so the embedded site starts already controlled.
  var ready = 'serviceWorker' in navigator
    ? navigator.serviceWorker.register('_sw.js', { scope: './' })
        .then(function () { return navigator.serviceWorker.ready; })
        .then(function (reg) { return reg.active && navigator.serviceWorker.controller ? null : new Promise(function (r) { setTimeout(r, 300); }); })
        .catch(function () {})
    : Promise.resolve();
  if (sites.length) ready.then(function () { open(start); });
</script>
</body>
</html>
