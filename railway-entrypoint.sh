#!/bin/bash
# Railway entrypoint for Open Web Analytics: the config written from the service
# variables, the database installed on first boot with the admin password from
# OWA_ADMIN_PASSWORD (the web installer is never reachable) and upgraded when the image
# brings a new release, OWA's scheduler every minute in the background.
set -euo pipefail

# Railway flattens the image layers, which brings back the mpm_event links the PHP
# image deleted: "AH00534: More than one MPM loaded". mod_php needs prefork only.
rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.*
# Prefork's default of 150 processes would outgrow a small plan.
printf '<IfModule mpm_prefork_module>\n\tMaxRequestWorkers %s\n</IfModule>\n' \
  "${OWA_APACHE_WORKERS:-20}" > /etc/apache2/conf-enabled/zz-workers.conf

: "${OWA_URL:?OWA_URL is not set: the site address, https://<your domain>}"
: "${DB_HOST:?DB_HOST is not set}" "${DB_PASSWORD:?DB_PASSWORD is not set}"
: "${OWA_SECRET:?OWA_SECRET is not set}"
export DB_NAME=${DB_NAME:-owa} DB_USER=${DB_USER:-root} DB_PORT=${DB_PORT:-3306}
# The four keys and salts are derived from one secret, so they never change between
# deploys (sessions and password-reset links would break if they did).
php -r '
$secret = getenv("OWA_SECRET");
$c = ["OWA_DB_TYPE" => "mysql", "OWA_DB_NAME" => getenv("DB_NAME"), "OWA_DB_HOST" => getenv("DB_HOST"),
  "OWA_DB_USER" => getenv("DB_USER"), "OWA_DB_PORT" => getenv("DB_PORT"), "OWA_DB_PASSWORD" => getenv("DB_PASSWORD"),
  "OWA_PUBLIC_URL" => rtrim(getenv("OWA_URL"), "/") . "/"];
foreach (["OWA_NONCE_KEY", "OWA_NONCE_SALT", "OWA_AUTH_KEY", "OWA_AUTH_SALT"] as $k) $c[$k] = hash_hmac("sha256", $k, $secret);
$s = "<?php\n// Written by the Railway entrypoint on every start; set the service variables instead.\n";
foreach ($c as $k => $v) $s .= "define(\"$k\", " . var_export($v, true) . ");\n";
file_put_contents("owa-config.php", $s);'
chown root:www-data owa-config.php && chmod 640 owa-config.php

trap 'kill $(jobs -p) 2>/dev/null; wait; exit 0' TERM INT

# On a fresh deploy MariaDB may still be initializing.
q() { MYSQL_PWD=$DB_PASSWORD mariadb --skip-ssl-verify-server-cert -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -N -B "$DB_NAME" -e "$1"; }
for i in $(seq 90); do
  q 'select 1' >/dev/null 2>&1 && break
  [ "$i" = 90 ] && { echo "railway: database not reachable after 3 minutes"; exit 1; }
  sleep 2
done

owa() { setpriv --reuid=www-data --regid=www-data --init-groups php cli.php "$@"; }
# The railway_install marker is written last, so tables without it are an install cut
# short (a redeploy during the first boot): no data yet, so clear them and start over.
if [ "$(q "select count(*) from information_schema.tables where table_schema = database() and table_name = 'railway_install'")" = 0 ]; then
  tables=$(q "select group_concat(concat('\`', table_name, '\`')) from information_schema.tables where table_schema = database()")
  if [ "$tables" != NULL ]; then
    echo "railway: an earlier install did not finish; clearing it and starting over"
    q "set foreign_key_checks = 0; drop table $tables"
  fi
  : "${OWA_ADMIN_PASSWORD:?OWA_ADMIN_PASSWORD is not set}"
  echo "railway: first boot, installing Open Web Analytics $OWA_VERSION"
  site=${OWA_SITE_URL:-https://example.com}
  owa cmd=install user_id=admin email_address="${OWA_ADMIN_EMAIL:-admin@example.com}" \
    domain="$site" description="Added on first boot" site_family=""
  owa cmd=change-password user=admin password="$OWA_ADMIN_PASSWORD"
  q "create table railway_install (installed_at datetime not null)"
  q "insert into railway_install values (now())"
else
  # Applies any schema updates a new release brings; nothing to do otherwise.
  owa cmd=update
fi

apache2-foreground &
echo "railway: Open Web Analytics $OWA_VERSION is up at $OWA_URL (login: admin)"

# OWA's scheduler: one tick a minute, each job decides how often it really runs.
while sleep 60; do owa cmd=schedule-run >/dev/null 2>&1 || echo "railway: schedule-run failed"; done &

wait -n
exit 1
