# HA Ingress Frame

A Home Assistant add-on that shows internal websites from your homelab as tabs in the Home Assistant sidebar, including when you are away from home.

A regular webpage dashboard or `panel_iframe` loads the page in your **browser**. From outside your network the browser cannot reach internal sites, so the frame stays empty. HA Ingress Frame turns this around: a reverse proxy (nginx) runs **as an add-on inside your home network** and is reachable only through Home Assistant Ingress. Your browser talks to Home Assistant only, and the proxy fetches the sites internally. The sites themselves do not need to be reachable from the internet, and no additional port is opened. Only users who are signed in to Home Assistant have access.

```
Browser ──HTTPS──▶ Home Assistant (Ingress) ──▶ add-on (nginx) ──HTTPS──▶ internal sites
```

## Requirements

- Home Assistant OS or Supervised (add-ons must be available)
- The add-on must be able to resolve and reach your internal hostnames
- Sites with a valid certificate (or `verify_ssl: false`)

## Installation

1. In Home Assistant open **Settings → Add-ons → Add-on Store → ⋮ → Repositories** and add `https://github.com/MajorMaxdom/ha-ingress-frame`.
2. Install **HA Ingress Frame**, fill in the configuration (see below) and start it.
3. "Homelab" appears in the sidebar.

To install locally instead, copy the `ha-frame/` folder to `/addons/ha-frame` on the Home Assistant host, click "Check for updates" in the Add-on Store and install it.

## Configuration

```yaml
sites:
  - name: wiki
    title: Wiki
    url: https://wiki.example.lan
    verify_ssl: true
  - name: monitoring
    title: CheckMK
    url: https://check.example.lan
    path: site/
  - name: spa
    title: My SPA
    url: https://spa.example.lan
    strip_prefix: true
```

| Option | Required | Description |
|---|---|---|
| `name` | yes | Short name, only `a-z 0-9 _ -`. Becomes part of the proxy URL. |
| `title` | yes | Label of the tab. |
| `url` | yes | Base URL of the site, **without a path**. |
| `path` | no | Start path when the tab opens (e.g. `servers`). |
| `verify_ssl` | no | Set `false` for self-signed certificates. Default: verify. |
| `strip_prefix` | no | For single-page apps with a client-side router that otherwise show "Page not found" (see below). |
| `cookie_root` | no | Do not rewrite the cookie path. For `__Host-` cookies, which require `Path=/`. |
| `basic_auth` | no | `user:password`, added as a Basic Auth header to every request. |

After changing the configuration, restart the add-on and reload Home Assistant with Ctrl+F5.

## How it works

The Ingress path of Home Assistant is dynamic, while most sites expect to be served from `/`. The add-on combines several measures:

- nginx forwards `/s/<name>/` to the site, sets `Host`, `Origin` and `Referer` to the site's own address (CSRF/origin checks), removes `X-Frame-Options`, `Content-Security-Policy` and `Link` preload headers, and rewrites redirects and cookie paths.
- `sub_filter` rewrites absolute paths in HTML/CSS to the ingress path.
- `shim.js` is injected into every page. It patches `fetch`, `XMLHttpRequest`, `EventSource` and `WebSocket` so that absolute paths end up under the prefix, and it separates `localStorage`/`sessionStorage` per site. Otherwise all sites share the Home Assistant origin and keys such as `theme` collide.
- A service worker (`sw.js`) redirects remaining requests for absolute paths.
- The iframe uses `sandbox` so that pages cannot break out of the frame (frame busting).

## Known limitations

- **One sidebar entry.** An add-on has a single sidebar entry; the sites are tabs inside it.
- **`strip_prefix`:** the site's router then sees only the path without the prefix. A hard reload (F5) inside the tab reloads without the prefix and shows an error. Switch to another tab and back, or reload Home Assistant.
- **Next.js apps** (e.g. Jellyseerr/Seerr) do not hydrate behind the proxy and do not work.
- Apps without sub-path support need to be tested individually. It has worked with, among others, Vaultwarden, Radarr/Sonarr, CheckMK, AdGuard Home, TrueNAS, SolidTime, Paperless-ngx, Wiki.js, Selkies and Nexterm.

## Security

- nginx only accepts requests from the Supervisor (`172.30.32.2`), not from the rest of the network.
- `basic_auth` is stored in plain text in the add-on configuration. Anyone who can see the Home Assistant settings can see the password. Use a dedicated account.
- The access log is disabled so that no paths or parameters are logged.
- The proxy removes the framing protection of the sites (`X-Frame-Options`, CSP). This is intentional. Only use the add-on with sites you trust.

## License

MIT, see [LICENSE](LICENSE).
