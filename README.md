# nginx

NGINX is a high performance edge web server with the lowest memory footprint and the key features to build modern and efficient web infrastructure.

NGINX functionality includes HTTP server, HTTP and mail reverse proxy, caching, load balancing, compression, request throttling, connection multiplexing and reuse, SSL offload and HTTP media streaming.

wikipedia.org/wiki/Nginx

![nginx logo](https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Nginx_logo.svg/120px-Nginx_logo.svg.png)

## How to use this Makejail

### Hosting some simple static content

Create a `Makejail` in your project directory.

```
INCLUDE options/network.makejail
INCLUDE gh+AppJail-makejails/nginx

COPY usr

SERVICE nginx reload
```

Where `options/network.makejail` are the options that suit your environment, for example:

```
ARG ext_if
ARG ruleset
ARG iface=nginx

OPTION bridge=iface:${ext_if} ${iface}
OPTION dhcp=sb_${iface}
OPTION mount_devfs
OPTION devfs_ruleset=${ruleset}
```

The tree structure of the `usr/` directory is as follows:

```
# tree -pug usr/
[drwxr-xr-x root     wheel   ]  usr/
└── [drwxr-xr-x root     wheel   ]  local
    ├── [drwxr-xr-x root     wheel   ]  etc
    │   └── [drwxr-xr-x root     wheel   ]  nginx
    │       └── [-rw-r--r-- root     wheel   ]  nginx.conf
    └── [drwxr-xr-x root     wheel   ]  www
        └── [dr-xr-xr-x root     wheel   ]  html
            └── [-rw-r--r-- root     wheel   ]  index.html

5 directories, 2 files
```

Where `nginx.conf` is your custom configuration file, for example:

```
events {
        worker_connections 1024;
}

http {
        include mime.types;
        default_type application/octet-stream;

        server {
                listen 80;
                server_name $hostname "";
                root /usr/local/www/html;
                index index.html index.htm;

                location / {
                        try_files $uri $uri/ =404;
                }
        }
}
```

Open a shell and run `appjail makejail`:

```sh
appjail makejail -j nginx -- --ruleset 10 --ext_if jext
```

### Exposing external port

When you use network options that use a variant of NAT, you can expose ports:

**options/network.makejail**:

```
ARG network?
ARG interface=nginx
# external
ARG eport=80
# internal
ARG iport=80

OPTION virtualnet=${network}?:${interface} default
OPTION nat
OPTION expose=${eport}:${iport}
```

```sh
appjail makejail -j nginx -- --eport 8080
# or use a network explicitly
appjail makejail -j nginx -- --network development --eport 8080
```

### Using a host's directory

Instead of copying an entire directory, you can mount a host's directory.

```
INCLUDE options/network.makejail
INCLUDE gh+AppJail-makejails/nginx

ARG wwwdir=/usr/local/www/html

COPY nginx.conf /usr/local/etc/nginx/nginx.conf

CMD --local mkdir -p "${wwwdir}"
CMD mkdir -p /usr/local/www/html
MOUNT "${wwwdir}" /usr/local/www/html

SERVICE nginx reload
```

```sh
appjail makejail -j nginx -- --network development
```

### PHP support

Since there is a [Makejail](https://github.com/AppJail-makejails/php) for PHP, you can combine PHP and NGINX with a custom configuration to get a web server with PHP support.

```
INCLUDE options/network.makejail
INCLUDE gh+AppJail-makejails/nginx
INCLUDE gh+AppJail-makejails/php

COPY --verbose usr

SERVICE php-fpm reload
SERVICE nginx reload
```

The tree structure of the `usr/` directory is as follows:

```
# tree -pug usr
[drwxr-xr-x root     wheel   ]  usr
└── [drwxr-xr-x root     wheel   ]  local
    ├── [drwxr-xr-x root     wheel   ]  etc
    │   ├── [drwxr-xr-x root     wheel   ]  nginx
    │   │   └── [-rw-r--r-- root     wheel   ]  nginx.conf
    │   └── [drwxr-xr-x root     wheel   ]  php-fpm.d
    │       └── [-rw-r--r-- root     wheel   ]  www.conf
    └── [drwxr-xr-x root     wheel   ]  www
        └── [drwxr-xr-x root     wheel   ]  php
            └── [-rw-r--r-- root     wheel   ]  index.php

6 directories, 3 files
```

Where `nginx.conf` is your custom configuration file for NGINX, for example:

```
events {
        worker_connections 1024;
}

http {
        include       mime.types;
        default_type  application/octet-stream;

        upstream php {
                server unix:/var/run/php-fpm.sock;
        }

        server {
                listen 80;
                server_name $hostname "";
                root /usr/local/www/php;
                index index.php;

                client_max_body_size 8M;

                location / {
                        try_files $uri $uri/ =404;
                }

                location ~ \.php$ {
                        include fastcgi_params;
                        fastcgi_intercept_errors on;
                        fastcgi_pass php;
                        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                }
        }
}
```

`www.conf` is your custom configuration file for php-fpm, for example:

```
[www]
user = www
group = www
listen = /var/run/php-fpm.sock
listen.owner = www;
listen.group = www;
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

`index.php` is your index file, for example:

```php
<?php echo "Hello, world!\n"; ?>
```

Open a shell and run `appjail makejail`:

```sh
appjail makejail -j nginx -- --network web
```

### Arguments

* `nginx_tag` (default: `latest`): see [#tags](#tags).

## How to build the Image

Make any changes you want to your image.

```
INCLUDE options/network.makejail
INCLUDE gh+AppJail-makejails/nginx --file build.makejail

SYSRC nginx_enable=YES
SERVICE nginx start
```

Build the jail:

```sh
appjail makejail -j nginx
```

Remove unportable or unnecessary files and directories and export the jail:

```sh
appjail stop nginx
appjail cmd local nginx sh -c "rm -f var/log/*"
appjail cmd local nginx sh -c "rm -f var/log/nginx/*"
appjail cmd local nginx vi etc/rc.conf
appjail image export nginx
```

## Tags

| Tag      | Arch     | Version        |
| -------- | -------- | -------------- |
| `latest` | `amd64`  | `13.2-RELEASE` |
| `13.1`   | `amd64`  | `13.1-RELEASE` |
