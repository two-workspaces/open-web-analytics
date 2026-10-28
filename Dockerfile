# Open Web Analytics on PHP 8.3 and Apache. Configured from Railway variables,
# installed and upgraded from the command line on boot (the web installer is never
# used), with OWA's scheduler running every minute.
FROM php:8.3-apache-trixie

RUN set -eux; \
	docker-php-ext-install -j"$(nproc)" mysqli pdo_mysql; \
	apt-get update; \
	apt-get install -y --no-install-recommends mariadb-client; \
	rm -rf /var/lib/apt/lists/*

# The packaged release carries its PHP dependencies and built assets. The code stays
# root-owned; only owa-data/ (caches, logs) is the web server's. The database is all
# the state there is.
# upgrade: github Open-Web-Analytics/Open-Web-Analytics
ARG OWA_VERSION=1.14.2
RUN set -eux; \
	curl -fsSL "https://github.com/Open-Web-Analytics/Open-Web-Analytics/releases/download/${OWA_VERSION}/owa_${OWA_VERSION}_packaged.tar" \
		| tar -x -C /var/www/html --no-same-owner; \
	chmod 755 /var/www/html; chown -R www-data: /var/www/html/owa-data
ENV OWA_VERSION=${OWA_VERSION}

RUN { cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini; \
	printf '%s\n' 'memory_limit = 256M' 'max_execution_time = 300' 'expose_php = Off' \
		> /usr/local/etc/php/conf.d/owa.ini; }

# Apache on Railway's $PORT, IPv6 and IPv4. Errors go to stdout: Railway paints all of
# stderr red, including Apache's startup notices. The visitor's address comes from
# Railway's X-Real-IP; OWA would otherwise trust the first public address in
# X-Forwarded-For, which any visitor can make up.
ENV PORT=8080
RUN set -eux; \
	printf 'Listen [::]:${PORT}\nListen 0.0.0.0:${PORT}\n' > /etc/apache2/ports.conf; \
	ln -sfT /dev/stdout /var/log/apache2/error.log; \
	sed -i 's/^ServerTokens OS/ServerTokens Prod/; s/^ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf; \
	printf '%s\n' 'RemoteIPHeader X-Real-IP' 'RemoteIPInternalProxy 100.64.0.0/10' > /etc/apache2/conf-available/remoteip.conf; \
	a2enmod remoteip rewrite headers >/dev/null; a2enconf remoteip >/dev/null
COPY owa.conf /etc/apache2/sites-available/000-default.conf
RUN mkdir -p /usr/local/share/owa && echo ok > /usr/local/share/owa/healthz
COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh
WORKDIR /var/www/html
ENTRYPOINT ["/railway-entrypoint.sh"]
STOPSIGNAL SIGTERM
