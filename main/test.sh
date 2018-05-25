#!/bin/bash

# get variables from .env file
#$DNS_IP=$(grep "IP_DNS=" .env | sed 's/IP_DNS=//')
#$MAIL_IP=$(grep "IP_MAIL=" .env | sed 's/IP_MAIL=//')
#$WEBMAIL_IP=$(grep "IP_ROUNDCUBE" .env | sed 's/IP_ROUNDCUBE//')
#$DNS_DB_NAME=$(grep "IP_ROUNDCUBE" .env | sed 's/IP_ROUNDCUBE//')
#$MAIN_NETWORK_SUBNET=$(grep "MAIN_NETWORK_SUBNET=" .env | sed 's/MAIN_NETWORK_SUBNET=//' | sed 's/\/24//')
source .env

TLD_DOMAIN_PTR=$(echo $MAIN_NETWORK_SUBNET | awk 'BEGIN{FS="."}{print $3"."$2"."$1}')
MAIL_IP_HOST_ID=$(echo $IP_MAIL | awk 'BEGIN{FS="."}{print $4}')


# insert DNS records in the database
cat > records.sql << EOF
\c pdns
INSERT INTO domains (name, type) values ('iglu.lu', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'iglu.lu','$IP_DNS admin.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'iglu.lu','$IP_DNS','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'mail.iglu.lu','$IP_MAIL','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'webmail.iglu.lu','$IP_ROUNDCUBE','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'iglu.lu','mail.iglu.lu','MX',120,25);
INSERT INTO domains (name, type) values ('$TLD_DOMAIN_PTR.in-addr.arpa', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$TLD_DOMAIN_PTR.in-addr.arpa','iglu.lu admin.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$TLD_DOMAIN_PTR.in-addr.arpa','iglu.lu','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$MAIL_IP_HOST_ID.$TLD_DOMAIN_PTR.in-addr.arpa','mail.iglu.lu','A',120,NULL);
EOF
docker cp records.sql dns-db:/tmp/
docker exec dns-db psql -f /tmp/records.sql pdns -U admin

# create OU structure from script present inside container
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -D "cn=admin,dc=iglu,dc=lu" -f /default-structure.ldif -w $LDAP_ADMIN_PASSWD

cat > users.ldif << EOF

dn: cn=John Doe,ou=users,dc=iglu,dc=lu
cn: John Doe
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: PostfixBookMailAccount
mail: jdoe@iglu.lu
gidNumber: 501
givenName: John
homeDirectory: /home/users/jdoe
mailEnabled: TRUE
mailGidNumber: 601
mailHomeDirectory: /var/mail/iglu.lu/jdoe
mailUidNumber: 1003
userPassword: {SSHA}U37xQpXgHLXluP6lGFWr0PZrn/7Jy2+a
sn: Doe
uidNumber: 1003
uid: jdoe

EOF

docker cp users.ldif openldap:/tmp/
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -v -D "cn=admin,dc=iglu,dc=lu" -f /tmp/users.ldif -w $LDAP_ADMIN_PASSWD

# create base users in LDAP


