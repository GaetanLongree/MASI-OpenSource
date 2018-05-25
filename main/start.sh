#!/bin/bash

echo "#####################################################"
echo ""
echo " Getting variables..."
echo ""
echo "#####################################################"

# get variables from .env file
PUBLIC_IP=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
echo "PUBLIC_IP=$PUBLIC_IP" >> .env

source .env

TLD_DOMAIN_PTR=$(echo $PUBLIC_IP | awk 'BEGIN{FS="."}{print $3"."$2"."$1}')
MAIL_IP_HOST_ID=$(echo $PUBLIC_IP | awk 'BEGIN{FS="."}{print $4}')

# creating volume directories
su -c "mkdir /mnt/share; chmod -R 777 /mnt/share/"

echo "#####################################################"
echo ""
echo " Launching containers, hang on to your shorts!..."
echo ""
echo "#####################################################"

# launch docker containers
docker-compose up -d

echo "#####################################################"
echo ""
echo " Waiting for services to be ready..."
echo ""
echo "#####################################################"

sleep 30s

echo "#####################################################"
echo ""
echo " Creating DNS records..."
echo ""
echo "#####################################################"

# insert DNS records in the database
cat > records.sql << EOF
\c pdns
INSERT INTO domains (name, type) values ('iglu.lu', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'iglu.lu','$PUBLIC_IP admin.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'iglu.lu','$PUBLIC_IP','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'mail.iglu.lu','$PUBLIC_IP','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'webmail.iglu.lu','$PUBLIC_IP','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (1,'iglu.lu','mail.iglu.lu','MX',120,25);
INSERT INTO domains (name, type) values ('$TLD_DOMAIN_PTR.in-addr.arpa', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$TLD_DOMAIN_PTR.in-addr.arpa','iglu.lu admin.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$TLD_DOMAIN_PTR.in-addr.arpa','iglu.lu','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$MAIL_IP_HOST_ID.$TLD_DOMAIN_PTR.in-addr.arpa','mail.iglu.lu','A',120,NULL);
EOF
docker cp records.sql dns-db:/tmp/
docker exec dns-db psql -f /tmp/records.sql pdns -U admin

echo "#####################################################"
echo ""
echo " Creating LDAP schema and inserting users..."
echo ""
echo "#####################################################"

# create OU structure from script present inside container
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -D "cn=admin,dc=iglu,dc=lu" -f /default-structure.ldif -w $LDAP_ADMIN_PASSWD

NEXT_UID=1000
declare -i NEXT_UID

INPUT=users.csv

while IFS=, read -r name surname username group
do
if [ ! "$name" == "name" ]; then

if [ $group = "administrators" ]; then
    $GID=600
elif [ $group = "users" ]; then
    $GID=601
elif [ $group = "externals" ]; then
    $GID=602
fi

cat > users.ldif << EOF

dn: cn=${name} ${surname},ou=users,dc=iglu,dc=lu
cn: ${name} ${surname}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: PostfixBookMailAccount
mail: ${username}@iglu.lu
gidNumber: ${GID}
givenName: ${name}
homeDirectory: /home/users/${username}
mailEnabled: TRUE
mailGidNumber: ${GID}
mailHomeDirectory: /var/mail/iglu.lu/${username}
mailUidNumber: ${NEXT_UID}
userPassword: {SSHA}doO0M2OTqtqFCeAbnMvfdeQhO4yCws7U
sn: ${surname}
uidNumber: ${NEXT_UID}
uid: ${username}

EOF

docker cp users.ldif openldap:/tmp/
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -v -D "cn=admin,dc=iglu,dc=lu" -f /tmp/users.ldif -w $LDAP_ADMIN_PASSWD

NEXT_UID=$NEXT_UID+1

fi
done < $INPUT

echo "#############################################################################"
echo ""
echo "Main services launched"
echo ""
echo "# Services available:"
echo "## phpLDAPadmin: https://${PUBLIC_IP}:${LDAP_ADMIN_PORT}/"
echo "## PgAdmin: http://${PUBLIC_IP}:${PGADMIN_PORT}/"
echo "## RoundCube: http://${PUBLIC_IP}:${ROUNDCUBE_PORT}/"
echo ""
echo "# Credentials"
echo "Default LDAP user password: Tigrou007"
echo ""
echo "phpLDAPadmin"
echo "Username: cn=admin,dc=iglu,dc=lu"
echo "Password: ${LDAP_ADMIN_PASSWD}"
echo ""
echo "PgAdmin"
echo "Username: ${PGADMIN_ADMIN_USER}"
echo "Password: ${PGADMIN_ADMIN_PASSWD}"
echo ""
echo "Database connection"
echo "Databse IP: ${IP_DNS_DB}"
echo "Username: ${DNS_DB_ADMIN_USER}"
echo "Password: ${DNS_ADMIN_PASSWD}"
echo ""
echo " ! Note: the mail server takes a while to initialize !"
echo "          wait a couple of minutes before trying to connect" 
echo "Roundcube login"
echo "Username: <username>@iglu.lu"
echo "Password: Tigrou007"
echo ""
echo "#############################################################################"