ARG BUILD_FROM=ghcr.io/home-assistant/base:latest
FROM $BUILD_FROM

RUN apk add --no-cache nginx ca-certificates

COPY run.sh /run.sh
COPY index.html.tpl /index.html.tpl
COPY shim.js /shim.js
COPY sw.js /sw.js
RUN chmod a+x /run.sh

CMD ["/run.sh"]
