#!/bin/bash

echo "#####################################################"
echo ""
echo " Getting variables..."
echo ""
echo "#####################################################"

NEW_IP_ADD=$1

if [ "$1" = "" ]; then
    echo "Please provide a new free IP address in CIDR (10.10.10.10/24) as argument"
    exit 1
fi

# create new subif and get IP

#get default device
DEFAULT_DEV=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.onlink.*//")
#get next available subif
NEXT_SUBIF=$(cat /etc/network/interfaces | grep "iface ens192:" | cut -f 2 -d " " | sed -e 's/ens192://')
if [ "$NEXT_SUBIF" = "" ]; then
    NEXT_SUBIF=0
else 
    declare -i NEXT_SUBIF
    NEXT_SUBIF=$NEXT_SUBIF+1
fi

# determine subnet mask
if [ "$(echo $NEW_IP_ADD | awk -F "\/" '{print $2}')" = "24" ]; then
    MASK=255.255.255.0
elif  [ "$(echo $NEW_IP_ADD | awk -F "\/" '{print $2}')" = "16" ]; then
    MASK=255.255.0.0
elif  [ "$(echo $NEW_IP_ADD | awk -F "\/" '{print $2}')" = "8" ]; then
    MASK=255.0.0.0
fi

IFS=. read -r io1 io2 io3 io4 <<< $(echo $NEW_IP_ADD | sed 's/\/[0-9][0-9]$//')
su -c "cat >> /etc/network/interfaces << EOF

auto ${DEFAULT_DEV}:${NEXT_SUBIF}
allow-hotplug ${DEFAULT_DEV}:${NEXT_SUBIF}
iface ${DEFAULT_DEV}:${NEXT_SUBIF} inet static
    address ${io1}.${io2}.${io3}.${io4}
    netmask ${MASK}
EOF"
su -c "ip address add $NEW_IP_ADD dev ${DEFAULT_DEV}:${NEXT_SUBIF}"

echo "PUBLIC_IP=${io1}.${io2}.${io3}.${io4}" >> .env

# get variables from .env file
source .env

TLD_DOMAIN_PTR=$(echo $PUBLIC_IP | awk 'BEGIN{FS="."}{print $3"."$2"."$1}')
MAIL_IP_HOST_ID=$(echo $PUBLIC_IP | awk 'BEGIN{FS="."}{print $4}')

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

# get max ID on records table
NEXT_ID=$(docker exec dns-db psql -d pdns -t -c "SELECT MAX(id) FROM domains" -U admin)
declare -i NEXT_ID
NEXT_ID=$NEXT_ID+1

# insert DNS records in the database
cat > records.sql << EOF
\c pdns
INSERT INTO domains (name, type) values ('${PROJECT_NAME}.iglu.lu', 'NATIVE');
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'${PROJECT_NAME}.iglu.lu','$IP_DNS admin.${PROJECT_NAME}.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'${PROJECT_NAME}.iglu.lu','$IP_DNS','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'mail.${PROJECT_NAME}.iglu.lu','${PUBLIC_IP}','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'webmail.${PROJECT_NAME}.iglu.lu','${PUBLIC_IP}','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'gitlab.${PROJECT_NAME}.iglu.lu','${PUBLIC_IP}','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'cms.${PROJECT_NAME}.iglu.lu','${PUBLIC_IP}','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'www.${PROJECT_NAME}.iglu.lu','${PUBLIC_IP}','A',120,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (${NEXT_ID},'${PROJECT_NAME}.iglu.lu','mail.${PROJECT_NAME}.iglu.lu','MX',120,25);
EOF

NEXT_ID=$NEXT_ID+1

cat >> records.sql << EOF
--INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$TLD_DOMAIN_PTR.in-addr.arpa','${PROJECT_NAME}.iglu.lu admin.${PROJECT_NAME}.iglu.lu 1 10380 3600 604800 3600','SOA',86400,NULL);
--INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$TLD_DOMAIN_PTR.in-addr.arpa','${PROJECT_NAME}.iglu.lu','NS',86400,NULL);
INSERT INTO records (domain_id, name, content, type,ttl,prio) VALUES (2,'$MAIL_IP_HOST_ID.$TLD_DOMAIN_PTR.in-addr.arpa','mail.${PROJECT_NAME}.iglu.lu','A',120,NULL);
EOF
docker cp records.sql dns-db:/tmp/
docker exec dns-db psql -f /tmp/records.sql pdns -U admin

echo "#####################################################"
echo ""
echo " Creating LDAP schema and inserting users..."
echo ""
echo "#####################################################"

# create groups and users for the project structure from script present inside container

NEXT_UID=$(docker exec openldap ldapsearch -D "cn=admin,dc=iglu,dc=lu" -w Tigrou007 -h 127.0.0.1 -b "dc=iglu,dc=lu" -s sub "(objectclass=*)" | awk '/uidNumber: / {print $2}' | sort | tail -n 1)
declare -i NEXT_UID
NEXT_UID=$NEXT_UID+1

INPUT=users.csv

# create new users
while IFS=, read -r name surname username group
do
if [ ! "$name" = "name" ]; then

# search is user exist, if not, create it
QUERY=$(docker exec openldap ldapsearch -D "cn=admin,dc=iglu,dc=lu" -w Tigrou007 -h 127.0.0.1 -b "dc=iglu,dc=lu" -s sub "(uid=${username})")
if [[ ! "$QUERY" = *"# numEntries: 1"* ]]; then
# if it's not here, create it

if [ "$group" = "administrators" ]; then
    GID="600"
elif [ "$group" = "users" ]; then
    GID="601"
elif [ "$group" = "externals" ]; then
    GID="602"
fi

cat > users.ldif << EOF

dn: cn=${name} ${surname},ou=users,dc=iglu,dc=lu
cn: ${name} ${surname}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: PostfixBookMailAccount
mail: ${username}@iglu.lu
mail: ${username}@${PROJECT_NAME}.iglu.lu
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

else
    # update existing user with project email address
cat > modify.ldif << EOF
dn: cn=${name} ${surname},ou=users,dc=iglu,dc=lu
changetype: modify
add: mail
mail: ${username}@${PROJECT_NAME}.iglu.lu
EOF

docker cp modify.ldif openldap:/tmp/
docker exec openldap ldapmodify -H ldap://127.0.0.1 -x -v -D "cn=admin,dc=iglu,dc=lu" -f /tmp/modify.ldif -w Tigrou007

fi

fi
done < $INPUT

# create groups and add members

NEXT_GID=$(docker exec openldap ldapsearch -D "cn=admin,dc=iglu,dc=lu" -w Tigrou007 -h 127.0.0.1 -b "dc=iglu,dc=lu" -s sub "(objectclass=*)" | awk '/gidNumber: / {print $2}' | sort | tail -n 1)
declare -i NEXT_GID
NEXT_GID=$NEXT_GID+1

cat > groups.ldif << EOF

# create the groups and assigned members

dn: cn=${PROJECT_NAME}Administrators,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Administrators
description: ${PROJECT_NAME} administrators group
gidNumber: ${NEXT_GID}
EOF

while IFS=, read -r name surname username group
do
    if [ ! "$name" = "name" ]; then
        if [ "$group" = "administrators" ]; then
            echo "memberUid: ${username}" >> groups.ldif
        fi
    fi
done < $INPUT

NEXT_GID=$NEXT_GID+1

cat >> groups.ldif << EOF

# create the users group

dn: cn=${PROJECT_NAME}Users,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Users
description: ${PROJECT_NAME} Users group
gidNumber: ${NEXT_GID}
EOF

while IFS=, read -r name surname username group
do
    if [ ! "$name" = "name" ]; then
        if [ "$group" = "users" ]; then
            echo "memberUid: ${username}" >> groups.ldif
        fi
    fi
done < $INPUT

NEXT_GID=$NEXT_GID+1

cat >> groups.ldif << EOF

# create the Externals group

dn: cn=${PROJECT_NAME}Externals,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Externals
description: ${PROJECT_NAME} Externals group
gidNumber: ${NEXT_GID}
EOF

while IFS=, read -r name surname username group
do
    if [ ! "$name" = "name" ]; then
        if [ "$group" = "externals" ]; then
            echo "memberUid: ${username}" >> groups.ldif
        fi
    fi
done < $INPUT

NEXT_GID=$NEXT_GID+1

cat >> groups.ldif << EOF

# create the Mails group

dn: cn=${PROJECT_NAME}Mails,ou=groups,dc=iglu,dc=lu
objectclass: posixGroup
objectclass: top
cn: ${PROJECT_NAME}Mails
description: ${PROJECT_NAME} Mails group
gidNumber: ${NEXT_GID}
EOF

while IFS=, read -r name surname username group
do
    if [ ! "$name" = "name" ]; then
        echo "memberUid: ${username}" >> groups.ldif
    fi
done < $INPUT

docker cp groups.ldif openldap:/tmp/
docker exec openldap ldapadd -H ldap://127.0.0.1 -x -v -D "cn=admin,dc=iglu,dc=lu" -f /tmp/groups.ldif -w $LDAP_ADMIN_PASSWD

# launch git lab

echo "#####################################################"
echo ""
echo " Configuring gitlab"
echo ""
echo "#####################################################"

su -c "chmod 777 -R /mnt/share/${PROJECT_NAME}/"
sed -i "13s/.*/ external_url 'http:\/\/gitlab.$PROJECT_NAME.iglu.lu'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "223s/.*/ gitlab_rails['ldap_enabled'] = true/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "226s/.*/ gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "227s/.*/   main: /" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "228s/.*/     label: 'LDAP'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "229s/.*/     host: '$IP_LDAP_HOST'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "230s/.*/     port: 389/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "231s/.*/     uid: 'uid'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "232s/.*/     bind_dn: '$LDAP_ADMIN_DN'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "233s/.*/     password: '$LDAP_ADMIN_PASSWD'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "234s/.*/     encryption: 'plain'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "235s/.*/     verify_certificates: true/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "236s/.*/     active_directory: true/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "237s/.*/     allow_username_or_email_login: false/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "238s/.*/     lowercase_usernames: false/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "239s/.*/     block_auto_created_users: false/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "240s/.*/     base: 'OU=users,DC=iglu,DC=lu'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "241s/.*/     user_filter: '\(objectClass=posixAccount\)\(memberof=cn=${PROJECT_NAME}Mails,ou=groups,DC=iglu,DC=lu\)'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
sed -i "266s/.*/ EOS/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
echo "updating configuration file"
sleep 20
echo "reconfiguring..."
docker exec gitlab.${PROJECT_NAME} gitlab-ctl reconfigure
echo "restarting..."
docker exec gitlab.${PROJECT_NAME} gitlab-ctl restart
echo "done"

su -c "chmod 777 -R /mnt/share/${PROJECT_NAME}/mail/mails"

echo "#############################################################################"
echo ""
echo "${PROJECT_NAME} services launched"
echo ""
echo "# Services available:"
echo "## RoundCube: http://${PUBLIC_IP}:${ROUNDCUBE_PORT}/"
echo "## GitLab: http://${PUBLIC_IP}:${GITLAB_PORT}/"
echo "## Wordpress: http://${PUBLIC_IP}:${WORDPRESS_PORT}/"
echo "## Web: http://${PUBLIC_IP}:${PHPMYADMIN_PORT}/"
echo "## phpMyAdmin: http://${PUBLIC_IP}:${ROUNDCUBE_PORT}/"
echo ""
echo "# Credentials"
echo "Default LDAP user password: Tigrou007"
echo ""
echo "GitLab"
echo "Username: <username>"
echo "Password: Tigrou007"
echo ""
echo "WordPress"
echo "User created on first connection"
echo ""
echo "phpMyAdmin"
echo "Username: root"
echo "Password: ${MYSQL_ROOT_PASSWD}"
echo ""
echo ""
echo "# Partage de fichier Samba"
echo "Partage \\\\${PUBLIC_IP}\\data"
echo "Username: ${SMB_PROJECT_USER}"
echo "Password: ${SMB_PROJECT_USER_PASSWD}"
echo "Partage \\\\${PUBLIC_IP}\\data"
echo "Username: ${SMB_EXTERNAL_USER}"
echo "Password: ${SMB_EXTERNAL_USER_PASSWD}"
echo ""
echo " ! Note: the mail server takes a while to initialize !"
echo "          wait a couple of minutes before trying to connect" 
echo "Roundcube login"
echo "Username: <username>@${PROJECT_NAME}.iglu.lu"
echo "Password: Tigrou007"
echo ""
echo "#############################################################################"
