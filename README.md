# nginx

Nginx (pronounced "engine-x") is an open source reverse proxy server for HTTP, HTTPS, SMTP, POP3, and IMAP protocols, as well as a load balancer, HTTP cache, and a web server (origin server). The nginx project started with a strong focus on high concurrency, high performance and low memory usage. It is licensed under the 2-clause BSD-like license and it runs on Linux, BSD variants, Mac OS X, Solaris, AIX, HP-UX, as well as on other *nix flavors. It also has a proof of concept port for Microsoft Windows.

wikipedia.org/wiki/Nginx

<img src="https://raw.githubusercontent.com/docker-library/docs/01c12653951b2fe592c1f93a13b4e289ada0e3a1/nginx/logo.png" width="30%" height="auto" alt="nginx logo">

## How to use this Makejail

### Hosting some simple static content

```console
$ appjail oci run -Pd \
    -o overwrite=force \
    -o virtualnet=":<random> default" \
    -o nat \
    -o fstab="/some/content /usr/local/www/html nullfs ro" \
    ghcr.io/appjail-makejails/nginx:15.1 nginx
```

Alternatively, a simple `Containerfile` can be used to generate a new image that includes the necessary content (which is a much cleaner solution than the `nullfs(4)` mount above):

```dockerfile
FROM ghcr.io/appjail-makejails/nginx:15.1
COPY static-html-directory/ /usr/local/www/html
```

Place this file in the same directory as your directory of content ("static-html-directory"), then run these commands to build and start your container:

```console
$ buildah build --network=host -t some-content-nginx .
$ appjail oci run -Pd \
    -o overwrite=force \
    -o virtualnet=":<random> default" \
    -o nat \
    localhost/some-content-nginx some-nginx
```

#### Exposing external port

```console
$ appjail oci run -Pd \
    -o overwrite=force \
    -o virtualnet=":<random> default" \
    -o nat \
    -o expose="8080:80" \
    localhost/some-content-nginx some-nginx
...
[00:00:22] [ info  ] [some-nginx] Detached: pid:94952, log:jails/some-nginx/container/2026-07-02.log
$ appjail jail list -j some-nginx
STATUS  NAME        ALT_NAME  TYPE   VERSION       PORTS           NETWORK_IP4
UP      some-nginx  -         thick  15.1-RELEASE  8080 -> 80/tcp  10.0.0.8
```

Then you can hit `http://10.0.0.8:8080` (or `http://some-nginx:8080` if you've configured [DNS in AppJail](https://appjail.readthedocs.io/en/latest/networking/DNS/)) or `http://host-ip:8080` in your browser (and from an external host).

### Customize configuration

You can mount your configuration file, or build a new image with it.

If you wish to adapt the default configuration, use something like the following to get it from a running nginx container:

```console
$ appjail oci run \
    -o overwrite=force \
    -o ephemeral \
    -o alias \
    -o ip4_disable \
    -o ip6_disable \
    ghcr.io/appjail-makejails/nginx:15.1 nginx \
    cat /dev/null
$ appjail oci exec nginx cat /usr/local/etc/nginx/nginx.conf > /host/path/nginx.conf
```
And then edit `/host/path/nginx.conf` in your host file system.

For information on the syntax of the nginx configuration files, see [the official documentation](http://nginx.org/en/docs/) (specifically the [Beginner's Guide](http://nginx.org/en/docs/beginners_guide.html#conf_structure)).

#### Mount your configuration file

```console
$ appjail oci run -Pd \
    -o overwrite=force \
    -o virtualnet=":<random> default" \
    -o nat \
    -o fstab="/host/path/nginx.conf usr/local/etc/nginx/nginx.conf nullfs ro" \
    ghcr.io/appjail-makejails/nginx:15.1 nginx
```

#### Build a new image with your configuration file

```dockerfile
FROM ghcr.io/appjail-makejails/nginx:15.1
COPY nginx.conf /usr/local/etc/nginx/nginx.conf
```

If you add a custom `CMD` in the `Containerfile`, be sure to include `-g daemon off;` in the `CMD` in order for nginx to stay in the foreground, so that AppJail can track the process properly (otherwise your container will stop immediately after starting)!

Then build the image with `buildah build --network=host -t custom-nginx .` and run it as follows:

```console
$ appjail oci run -Pd \
    -o overwrite=force \
    -o virtualnet=":<random> default" \
    -o nat \
    localhost/custom-nginx my-custom-nginx-container
```

#### Using environment variables in nginx configuration

Out-of-the-box, nginx doesn't support environment variables inside most configuration blocks. But this image has a function, which will extract environment variables before nginx starts.

Here is an example using `appjail-director.yml`:

**appjail-director.yml**:

```yaml
options:
  - virtualnet: ':<random> default'
  - nat:
services:
  web:
    options:
      - container: 'boot args:--pull'
      - expose: '8080:80'
    volumes:
      - templates: '/usr/local/etc/nginx/templates'
    oci:
      environment:
        - NGINX_HOST: 'foobar.com'
        - NGINX_PORT: '80'
volumes:
  templates:
    device: 'templates'
    type: nullfs
    options: ro
```

**Makejail**:

```
ARG tag=15.1

OPTION overwrite=force
OPTION from=ghcr.io/appjail-makejails/nginx:${tag}
```

**.env**:

```
DIRECTOR_PROJECT=nginx
```

By default, this function reads template files in `/usr/local/etc/nginx/templates/*.template` and outputs the result of executing `envsubst` to `/usr/local/etc/nginx/conf.d`.

So if you place `templates/default.conf.template` file, which contains variable references like this:

```nginx
listen       ${NGINX_PORT};
```

outputs to `/usr/local/etc/nginx/conf.d/default.conf` like this:

```nginx
listen       80;
```

### Entrypoint quiet logs

There is a verbose entrypoint that provides information on what's happening during container startup. You can silence this output by setting environment variable `NGINX_ENTRYPOINT_QUIET_LOGS`:

```console
appjail oci run -Pd \
    -o overwrite=force \
    -o virtualnet=":<random> default" \
    -o nat \
    -e NGINX_ENTRYPOINT_QUIET_LOGS=1 \
    ghcr.io/appjail-makejails/nginx:15.1 nginx
```

### Arguments (stage: build)

* `nginx_from` (default: `ghcr.io/appjail-makejails/nginx`): Location of OCI image. See also [OCI Configuration](#oci-configuration).
* `nginx_tag` (default: `latest`): OCI image tag. See also [OCI Configuration](#oci-configuration).

### Environment (OCI image)

* `PGID` (default: `1000`): Equivalent to `PUID` but for the Process Group ID.
* `PUID` (default: `1000`): Process User ID for the container's main process, allowing you to match the owner of files written to mounted host volumes to your host system's user. Writable volumes are changed based on this environment variable.
### Environment (stage: build)

* `NGINX_ENTRYPOINT_LOCAL_RESOLVERS` (optional): If set, the `NGINX_LOCAL_RESOLVERS` environment variable will contain the name servers extracted from the jail's `/etc/resolv.conf` file, so that templates can configure the [resolver](https://nginx.org/en/docs/http/ngx_http_core_module.html#resolver).
* `NGINX_ENTRYPOINT_QUIET_LOGS` (optional): Silence verbose output in entrypoint.
* `NGINX_ENVSUBST_OUTPUT_DIR` (default: `/usr/local/etc/nginx/conf.d`): A directory where the result of executing envsubst is output. The output filename is the template filename with the suffix removed (`/usr/local/etc/nginx/templates/default.conf.template` will be output with the filename `/usr/local/etc/nginx/conf.d/default.conf`).
* `NGINX_ENVSUBST_STREAM_OUTPUT_DIR` (default: `/usr/local/etc/nginx/stream-conf.d`): Equivalent to `NGINX_ENVSUBST_OUTPUT_DIR` but for the [stream](https://nginx.org/en/docs/stream/ngx_stream_core_module.html) block.
* `NGINX_ENVSUBST_STREAM_TEMPLATE_SUFFIX` (default: `.stream-template`): Equivalent to `NGINX_ENVSUBST_TEMPLATE_SUFFIX` but for the [stream](https://nginx.org/en/docs/stream/ngx_stream_core_module.html) block.
* `NGINX_ENVSUBST_TEMPLATE_DIR` (default: `/usr/local/etc/nginx/templates`): A directory which contains template files. When this directory doesn't exist, this function will do nothing about template processing.
* `NGINX_ENVSUBST_TEMPLATE_SUFFIX` (default: `.template`): A suffix of template files. This function only processes the files whose name ends with this suffix.


## OCI Configuration

```yaml
build:
  variants:
    - tag: 15.1
      containerfile: Containerfile
      aliases: ["latest"]
      default: true
      args:
        FREEBSD_RELEASE: "15.1"
        NO_PKGCLEAN: "1"
      cache_dirs: ["pkgcache0:/var/cache/pkg"]
    - tag: 15.1-devel
      containerfile: Containerfile
      args:
        FREEBSD_RELEASE: "15.1"
        FLAVOUR: '-devel'
        NO_PKGCLEAN: "1"
      cache_dirs: ["pkgcache0:/var/cache/pkg"]
    - tag: 15.1-full
      containerfile: Containerfile
      args:
        FREEBSD_RELEASE: "15.1"
        FLAVOUR: '-full'
        NO_PKGCLEAN: "1"
      cache_dirs: ["pkgcache0:/var/cache/pkg"]
```

## Notes

1. The ideas present in the Docker image of NGINX are taken into account for users who are familiar with it.
