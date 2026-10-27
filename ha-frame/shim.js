// Runs before the embedded app. Lets SPAs that expect to live at "/" work
// behind the ingress prefix.
(function () {
  var prefix = document.currentScript.getAttribute('data-prefix');

  // Let the router see the path without the prefix.
  // Only for SPAs with a client-side router (data-strip="1"); otherwise relative links/forms
  // would be resolved against the HA origin.
  var p = location.pathname;
  if (document.currentScript.getAttribute('data-strip') === '1' && p.indexOf(prefix) === 0) {
    history.replaceState(history.state, '', (p.slice(prefix.length) || '/') + location.search + location.hash);
  }

  // All sites share the HA origin. Separate web storage per site, otherwise keys such as
  // "theme" overwrite each other (and HA's own).
  (function () {
    var ns = 'ha-frame:' + prefix.replace(/.*\//, '') + ':';
    function wrap(name) {
      var real;
      try { real = window[name]; real.length; } catch (e) { return; }
      var api = {
        getItem: function (k) { return real.getItem(ns + k); },
        setItem: function (k, v) { real.setItem(ns + k, v); },
        removeItem: function (k) { real.removeItem(ns + k); },
        clear: function () {
          Object.keys(real).filter(function (k) { return k.indexOf(ns) === 0; })
            .forEach(function (k) { real.removeItem(k); });
        },
        key: function (i) {
          var keys = Object.keys(real).filter(function (k) { return k.indexOf(ns) === 0; });
          return i < keys.length ? keys[i].slice(ns.length) : null;
        }
      };
      var proxy = new Proxy(api, {
        get: function (t, p) {
          if (p === 'length') return Object.keys(real).filter(function (k) { return k.indexOf(ns) === 0; }).length;
          if (p in t) return t[p];
          return typeof p === 'string' ? real.getItem(ns + p) ?? undefined : undefined;
        },
        set: function (t, p, v) { real.setItem(ns + String(p), v); return true; },
        deleteProperty: function (t, p) { real.removeItem(ns + String(p)); return true; },
        has: function (t, p) { return p in t || real.getItem(ns + String(p)) !== null; },
        ownKeys: function () {
          return Object.keys(real).filter(function (k) { return k.indexOf(ns) === 0; })
            .map(function (k) { return k.slice(ns.length); });
        },
        getOwnPropertyDescriptor: function (t, p) {
          var v = real.getItem(ns + String(p));
          return v === null ? undefined : { value: v, writable: true, enumerable: true, configurable: true };
        }
      });
      try { Object.defineProperty(window, name, { configurable: true, get: function () { return proxy; } }); } catch (e) {}
    }
    wrap('localStorage');
    wrap('sessionStorage');
  })();

  // Rewrite absolute paths and same-origin URLs to the prefix.
  function fix(u) {
    if (u instanceof URL) u = u.href;
    if (typeof u !== 'string') return u;
    var m = /^(?:[a-z]+:\/\/([^\/]+))?(\/(?!\/)[\s\S]*)$/i.exec(u);
    if (!m || (m[1] && m[1] !== location.host)) return u;
    if (m[2] === prefix || m[2].indexOf(prefix + '/') === 0) return u;
    return u.slice(0, u.length - m[2].length) + prefix + m[2];
  }

  var nativeFetch = window.fetch;
  window.fetch = function (input, init) {
    if (typeof input === 'string' || input instanceof URL) {
      input = fix(input);
    } else if (input && input.url) {
      var u = fix(input.url);
      if (u !== input.url) {
        // Rebuild the Request object; read the body explicitly (Firefox would lose it otherwise).
        var req = input;
        var self = this;
        var hasBody = req.method !== 'GET' && req.method !== 'HEAD';
        return (hasBody ? req.clone().arrayBuffer() : Promise.resolve(undefined)).then(function (body) {
          return nativeFetch.call(self, u, Object.assign({
            method: req.method,
            headers: req.headers,
            credentials: req.credentials,
            redirect: req.redirect,
            signal: req.signal
          }, body === undefined ? {} : { body: body }, init || {}));
        });
      }
    }
    return nativeFetch.call(this, input, init);
  };

  var nativeOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    arguments[1] = fix(String(url));
    return nativeOpen.apply(this, arguments);
  };

  ['EventSource', 'WebSocket'].forEach(function (name) {
    var Native = window[name];
    if (!Native) return;
    var Wrapped = function (url, arg) {
      return arg === undefined ? new Native(fix(String(url))) : new Native(fix(String(url)), arg);
    };
    Wrapped.prototype = Native.prototype;
    ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'].forEach(function (k) {
      if (k in Native) Wrapped[k] = Native[k];
    });
    window[name] = Wrapped;
  });
})();
