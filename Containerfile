ARG FREEBSD_RELEASE

FROM ghcr.io/appjail-makejails/core:${FREEBSD_RELEASE}

ARG FLAVOUR
ARG NO_PKGCLEAN

LABEL org.opencontainers.image.title="NGINX" \
    org.opencontainers.image.description="Robust and small WWW server" \
    org.opencontainers.image.source="https://github.com/AppJail-makejails/nginx" \
    org.opencontainers.image.url="https://github.com/AppJail-makejails/nginx" \
    org.opencontainers.image.vendor="DtxdF" \
    org.opencontainers.image.authors="Jesús Daniel Colmenares Oviedo <dtxdf@disroot.org>"

RUN set -xe; \
    \
    pkg update; \
    pkg install -U nginx${FLAVOUR} gettext-runtime FreeBSD-utilities; \
    \
    if [ -z "${NO_PKGCLEAN}" ]; then \
        pkg clean -a; \
        rm -rf /var/cache/pkg/* /var/db/pkg/repos/*; \
    fi; \
    \
    mkdir -p \
        /entrypoint.d \
        /usr/local/etc/nginx/stream-conf.d \
        /usr/local/etc/nginx/conf.d \
        /usr/local/etc/nginx/sites-enabled \
        /usr/local/www/html; \
    chmod 555 /usr/local/www/html; \
    cp -a /usr/local/www/nginx-dist/index.html /usr/local/www/html

COPY nginx.conf /usr/local/etc/nginx/nginx.conf
COPY entrypoint/15-local-resolvers.envsh /entrypoint.d
COPY entrypoint/20-envsubst-on-templates.sh /entrypoint.d
COPY entrypoint/entrypoint.sh /entrypoint.sh

RUN chmod +x \
        /entrypoint.sh \
        /entrypoint.d/*.sh \
        /entrypoint.d/*.envsh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
