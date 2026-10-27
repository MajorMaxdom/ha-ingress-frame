# HA Ingress Frame

Shows internal websites as tabs in the Home Assistant sidebar through a reverse proxy running in the add-on. Your browser talks to Home Assistant only; the sites do not need to be reachable from outside.

## Configuration

One entry per site under `sites`:

| Option | Required | Description |
|---|---|---|
| `name` | yes | Short name, only `a-z 0-9 _ -` |
| `title` | yes | Label of the tab |
| `url` | yes | Base URL **without a path** |
| `path` | no | Start path of the tab |
| `verify_ssl` | no | `false` for self-signed certificates |
| `strip_prefix` | no | For single-page apps that otherwise show "Page not found" |
| `cookie_root` | no | Do not rewrite the cookie path (`__Host-` cookies) |
| `basic_auth` | no | `user:password` for Basic Auth |

After changes, restart the add-on and reload Home Assistant with Ctrl+F5.
