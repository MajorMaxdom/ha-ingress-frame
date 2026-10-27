#!/usr/bin/with-contenv bashio
# Renders the nginx config and the start page from the add-on options.
set -euo pipefail

CONF=/etc/nginx/nginx.conf
WWW=/var/www/ha-frame
mkdir -p "${WWW}" /run/nginx

count=$(bashio::config 'sites|length')
locations=""
json="["

for ((i = 0; i < count; i++)); do
  name=$(bashio::config "sites[${i}].name")
  title=$(bashio::config "sites[${i}].title")
  url=$(bashio::config "sites[${i}].url")
  url="${url%/}"
  verify=$(bashio::config "sites[${i}].verify_ssl" || true)
  [ "${verify}" = "false" ] && verify_line="proxy_ssl_verify off;" || verify_line="proxy_ssl_verify on;"

  path=$(bashio::config "sites[${i}].path" || true)
  [ "${path}" = "null" ] && path=""
  path="${path#/}"
  # __Host- cookies require Path=/, so the path must not be rewritten
  cookie_line="proxy_cookie_path / \"\$http_x_ingress_path/s/${name}/\";"
  [ "$(bashio::config "sites[${i}].cookie_root" || true)" = "true" ] && cookie_line=""
  strip=0
  [ "$(bashio::config "sites[${i}].strip_prefix" || true)" = "true" ] && strip=1
  auth=$(bashio::config "sites[${i}].basic_auth" || true)
  auth_line=""
  if [ -n "${auth}" ] && [ "${auth}" != "null" ]; then
    b64=$(printf '%s' "${auth}" | base64 | tr -d '\n')
    auth_line="proxy_set_header Authorization \"Basic ${b64}\"; proxy_hide_header WWW-Authenticate;"
  fi

  host=$(echo "${url}" | sed -E 's#^[a-z]+://([^/:]+).*#\1#')
  origin=$(echo "${url}" | sed -E 's#^([a-z]+://[^/]+).*#\1#')
  json+="{\"name\":\"${name}\",\"title\":\"${title}\",\"path\":\"${path}\"},"

  locations+="
    location /s/${name}/ {
      proxy_pass ${url}/;
      proxy_http_version 1.1;
      proxy_set_header Host ${host};
      proxy_set_header X-Forwarded-Proto https;
      # CSRF/Origin checks of the sites expect their own address
      proxy_set_header Origin ${origin};
      proxy_set_header Referer \"${origin}/\";
      set \$site_prefix /s/${name};
      proxy_hide_header X-Inertia-Location;
      add_header X-Inertia-Location \$inertia_loc always;
      proxy_set_header X-Forwarded-For \$remote_addr;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      proxy_set_header Accept-Encoding \"\";
      proxy_ssl_server_name on;
      proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
      proxy_ssl_verify_depth 5;
      ${verify_line}
      proxy_read_timeout 1h;
      ${cookie_line}
      proxy_redirect \"~^https?://${host}(?::[0-9]+)?(/.*)?\" \"\$http_x_ingress_path/s/${name}\$1\";
      proxy_redirect / \$http_x_ingress_path/s/${name}/;
      ${auth_line}

      proxy_hide_header X-Frame-Options;
      proxy_hide_header Content-Security-Policy;
      # Preload headers (Vite/Laravel) point to the absolute site URL and bypass the proxy
      proxy_hide_header Link;

      # Rewrite absolute paths to the ingress prefix
      sub_filter_once off;
      sub_filter_types text/css;
      sub_filter 'https:\\\\/\\\\/${host}' 'https://\$http_host\$http_x_ingress_path/s/${name}';
      sub_filter 'https://${host}/' '\$http_x_ingress_path/s/${name}/';
      sub_filter 'http://${host}/' '\$http_x_ingress_path/s/${name}/';
      sub_filter '<head>' '<head><script src=\"\$http_x_ingress_path/_shim.js\" data-prefix=\"\$http_x_ingress_path/s/${name}\" data-strip=\"${strip}\"></script>';
      sub_filter 'url(/' 'url(\$http_x_ingress_path/s/${name}/';
      sub_filter 'href=\"/' 'href=\"\$http_x_ingress_path/s/${name}/';
      sub_filter 'src=\"/' 'src=\"\$http_x_ingress_path/s/${name}/';
      sub_filter 'action=\"/' 'action=\"\$http_x_ingress_path/s/${name}/';
    }
"
done

json="${json%,}]"
cp /shim.js "${WWW}/_shim.js"
cp /sw.js "${WWW}/_sw.js"
sed "s#/\*SITES\*/\[\]#${json}#" /index.html.tpl > "${WWW}/index.html"

cat > "${CONF}" <<EOF
daemon off;
error_log /dev/stderr warn;
pid /run/nginx/nginx.pid;
events { worker_connections 256; }
http {
  include /etc/nginx/mime.types;
  access_log off;
  map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }
  map \$upstream_http_x_inertia_location \$inertia_loc {
    default "";
    "~^https?://[^/]+(?<ipath>/.*)\$" "\$http_x_ingress_path\$site_prefix\$ipath";
    "~^(?<rpath>/.*)\$" "\$http_x_ingress_path\$site_prefix\$rpath";
  }

  server {
    listen 8099;
    absolute_redirect off;
    allow 172.30.32.2;
    deny all;

    root ${WWW};
    location = / { index index.html; add_header Cache-Control "no-store"; }
    location = /_shim.js { add_header Cache-Control no-cache; }
    location = /_sw.js { add_header Cache-Control no-cache; }
${locations}
  }
}
EOF

bashio::log.info "Starting nginx with ${count} site(s)"
exec nginx -c "${CONF}"
