#!/bin/bash

# get variables from .env file
source .env

TLD_MAIN_DOMAIN_PTR=$(echo $MAIN_NETWORK_SUBNET | awk 'BEGIN{FS="."}{print $3"."$2"."$1}')
TLD_DOMAIN_PTR=$(echo $PROJECT_NETWORK_SUBNET | awk 'BEGIN{FS="."}{print $3"."$2"."$1}')
MAIL_IP_HOST_ID=$(echo $IP_MAIL | awk 'BEGIN{FS="."}{print $4}')

# creating volume directories
su -c "mkdir /mnt/share; \
mkdir /mnt/share/main/ldap; \
mkdir /mnt/share/main/db; \
mkdir /mnt/share/main/dns; \
mkdir /mnt/share/main/mail; \
chmod -R 777 /mnt/share/"

# launch docker containers
docker-compose up -d

#TODO REPLACE BY PUBLIC IPs!!!!

# download config file from git
git clone https://github.com/tomav/docker-mailserver.git
cp -R $HOME/docker-mailserver/config /mnt/share/mail/config
#edit config/dovecot.cf to authorize plaintext auth

#edit postfix file

# insert DNS records in the database
cat > records.sql << EOF
\c pdns
INSERT INTO domains (name, type) values ('${PROJECT_NAME}.iglu.lu', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (3,'${PROJECT_NAME}.iglu.lu','$IP_DNS admin.${PROJECT_NAME}.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (3,'${PROJECT_NAME}.iglu.lu','$IP_DNS','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (3,'mail.${PROJECT_NAME}.iglu.lu','$IP_MAIL','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (3,'webmail.${PROJECT_NAME}.iglu.lu','$IP_ROUNDCUBE','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (3,'${PROJECT_NAME}.iglu.lu','mail.${PROJECT_NAME}.iglu.lu','MX',120,25);
INSERT INTO domains (name, type) values ('$TLD_DOMAIN_PTR.in-addr.arpa', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (4,'$TLD_DOMAIN_PTR.in-addr.arpa','${PROJECT_NAME}.iglu.lu admin.${PROJECT_NAME}.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (4,'$TLD_DOMAIN_PTR.in-addr.arpa','${PROJECT_NAME}.iglu.lu','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (4,'$MAIL_IP_HOST_ID.$TLD_DOMAIN_PTR.in-addr.arpa','mail.${PROJECT_NAME}.iglu.lu','A',120,NULL);
EOF
docker cp records.sql dns-db:/tmp/
docker exec dns-db psql -f /tmp/records.sql pdns -U admin

# create groups and users for the project structure from script present inside container
cat > users.ldif << EOF

dn: cn=Gaetan Longree,ou=users,dc=iglu,dc=lu
cn: Gaetan Longree
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: PostfixBookMailAccount
mail: glongree@iglu.lu
mail: glongree@${PROJECT_NAME}.iglu.lu
gidNumber: 501
givenName: Gaetan
homeDirectory: /home/users/glongree
mailEnabled: TRUE
mailGidNumber: 601
mailHomeDirectory: /var/mail/iglu.lu/glongree
mailUidNumber: 1001
userPassword: {crypt}Tigrou007
sn: Longree
uidNumber: 1001
uid: glongree

EOF

cat > groups.ldif << EOF

# create the administrators group

dn: cn=${PROJECT_NAME}Administrators,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Administrators
description: ${PROJECT_NAME} administrators group
gidNumber: 650
memberUid: glongree

# create the users group

dn: cn=${PROJECT_NAME}Users,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Users
description: ${PROJECT_NAME} Users group
gidNumber: 651
memberUid: ipiccar

# create the Externals group

dn: cn=${PROJECT_NAME}Externals,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Externals
description: ${PROJECT_NAME} Externals group
gidNumber: 652
memberUid: jdoe

# create the Mails group

dn: cn=${PROJECT_NAME}Mails,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Mails
description: ${PROJECT_NAME} Mails group
gidNumber: 653
memberUid: jdoe
memberUid: ipiccar
memberUid: glongree

EOF

docker cp users.ldif openldap:/tmp/
docker cp groups.ldif openldap:/tmp/
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -v -D "cn=admin,dc=iglu,dc=lu" -f /tmp/users.ldif -w $LDAP_ADMIN_PASSWD
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -v -D "cn=admin,dc=iglu,dc=lu" -f /tmp/groups.ldif -w $LDAP_ADMIN_PASSWD

# create base users in LDAP



