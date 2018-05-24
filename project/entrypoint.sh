#!/bin/bash
if [ -z "$(ls -A /var/www/html)" ]; then
  cp -R /tmp/html/* /var/www/html
fi

if [ ! -f /etc/smbldap-tools/smbldap_bind.conf ]; then
cat > /etc/smbldap-tools/smbldap_bind.conf << EOF
slaveDN="cn=admin,dc=iglu,dc=lu"
slavePw="Tigrou007"
masterDN="cn=admin,dc=iglu,dc=lu"
masterPw="Tigrou007"
EOF
fi

set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- apache2-foreground "$@"
fi

exec "$@"