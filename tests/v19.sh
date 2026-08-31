#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
base=https://localhost
cookie=/tmp/tkl-faveo-cookie.$$
page=/tmp/tkl-faveo-page.$$
headers=/tmp/tkl-faveo-headers.$$

cleanup() {
    rm -f -- "$cookie" "$page" "$headers"
}
trap cleanup EXIT

csrf_token() {
    sed -n 's/.*name="_token" type="hidden" value="\([^"]*\)".*/\1/p' "$1" |
        head -n1
}

systemctl --quiet is-active apache2.service mariadb.service redis-server.service \
    supervisor.service postfix.service cron.service multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service redis-server.service \
    supervisor.service postfix.service cron.service
apache2ctl -t
apache2ctl -M 2>/dev/null | grep -q ' rewrite_module '
apache2ctl -M 2>/dev/null | grep -q ' ssl_module '
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-faveo-helpdesk-19\.0' /etc/turnkey_version
grep -Fq '[40faveo-helpdesk] successfully completed' /var/log/inithooks.log

installed_version=$(sed -n 's/^APP_VERSION=//p' \
    /var/www/faveo-helpdesk/storage/faveoconfig.ini)
test "$installed_version" = v2.0.3
php_version=$(php --version | head -n1)
[[ $php_version == 'PHP 8.4.'* ]]
for module in bcmath curl gd gmp intl ldap mbstring mysqli pdo_mysql redis soap xml zip; do
    php -m | grep -Fxiq "$module"
done

curl --insecure --fail --silent --show-error \
    --cookie-jar "$cookie" "$base/" >"$page"
token=$(csrf_token "$page")
test -n "$token"
curl --insecure --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode "_token=$token" \
    --data-urlencode 'email=admin@example.invalid' \
    --data-urlencode "password=$app_password" \
    --dump-header "$headers" --output "$page" "$base/login"
grep -q '^HTTP/.* 302' "$headers"
grep -Eqi '^Location: .*/dashboard' "$headers"
curl --insecure --fail --silent --show-error \
    --cookie "$cookie" "$base/dashboard" >"$page"
grep -Fq 'Dashboard' "$page"
grep -Fq 'Create ticket' "$page"

curl --insecure --fail --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" "$base/newticket" >"$page"
token=$(csrf_token "$page")
test -n "$token"
subject="TurnKey v19 acceptance ticket $$"
body="Faveo ticket persistence round trip $$"
before=$(mariadb --batch --skip-column-names faveo --execute \
    'SELECT COUNT(*) FROM tickets')
curl --insecure --silent --show-error \
    --cookie "$cookie" --cookie-jar "$cookie" \
    --data-urlencode "_token=$token" \
    --data-urlencode 'email=customer@example.invalid' \
    --data-urlencode 'first_name=Acceptance' \
    --data-urlencode 'last_name=Test' \
    --data-urlencode 'helptopic=1' \
    --data-urlencode 'sla=1' \
    --data-urlencode "subject=$subject" \
    --data-urlencode "body=$body" \
    --data-urlencode 'priority=2' \
    --dump-header "$headers" --output "$page" "$base/newticket/post"
grep -q '^HTTP/.* 302' "$headers"
after=$(mariadb --batch --skip-column-names faveo --execute \
    'SELECT COUNT(*) FROM tickets')
test "$after" -eq "$((before + 1))"
mariadb --batch --skip-column-names faveo --execute \
    "SELECT CONCAT(title, '|', body) FROM ticket_thread WHERE title='$subject' ORDER BY id DESC LIMIT 1" |
    grep -Fxq "$subject|$body"

redis-cli ping | grep -Fxq PONG
timeout 20 runuser -u www-data -- php /var/www/faveo-helpdesk/artisan \
    queue:work redis --once --no-interaction
supervisorctl status >"$page"
grep -q '^faveo-worker:faveo-worker_.*RUNNING' "$page"
grep -q '^faveo-recur:faveo-recur_.*RUNNING' "$page"
grep -q '^faveo-Reports:faveo-Reports_.*RUNNING' "$page"
! grep -Eq 'BACKOFF|FATAL|EXITED' "$page"
grep -Fxq '* * * * * www-data /usr/bin/php /var/www/faveo-helpdesk/artisan schedule:run > /dev/null 2>&1' \
    /etc/cron.d/faveo-helpdesk
runuser -u www-data -- php /var/www/faveo-helpdesk/artisan schedule:run \
    --no-interaction >/dev/null

dpkg-query -W adminer webmin-apache webmin-mysql webmin-phpini postfix \
    mariadb-server redis-server supervisor >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12322/ >/dev/null
ss -ltn | grep -Eq '127\.0\.0\.1:25[[:space:]]'

latest_tag=$(curl --fail --silent --show-error \
    https://api.github.com/repos/faveosuite/faveo-helpdesk/releases/latest |
    sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n1)
test -n "$latest_tag"
test "$latest_tag" = "$installed_version"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Official Faveo Helpdesk Community release $installed_version, archive SHA-256 8b42f15c164a2e7cdf87ab53ed00c3c806ac7efa96e201405886fe559af93252; PHP, MariaDB, Apache, Redis and extensions from Debian Trixie
installed_version=Faveo Helpdesk Community $installed_version; $php_version; mariadb-server $(dpkg-query -W -f='${Version}' mariadb-server)
runtime_checks=normal init; Apache TLS; firstboot administrator HTTPS login; authenticated ticket create through the real web form; direct MariaDB persistence; Redis queue worker; Supervisor workers and scheduler; Adminer, Webmin and local Postfix
updater_command=official GitHub latest-release query followed by the documented Faveo file update and turnkey-artisan database:sync
updater_result=official latest stable release endpoint returned $latest_tag, matching the installed release; no application files changed
updater_channel=https://github.com/faveosuite/faveo-helpdesk/releases and the official Faveo upgrade documentation
integrity_evidence=build verifies the pinned release archive SHA-256; APT accepted signed Trixie metadata; no Bookworm source remained
EOF
