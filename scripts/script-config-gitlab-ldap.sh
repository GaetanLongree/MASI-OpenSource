    #!/bin/bash
    source .env
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
    sed -i "241s/.*/     user_filter: '\(objectClass=posixAccount\)\(memberof=cn=users,ou=groups,DC=iglu,DC=lu\)'/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
    sed -i "266s/.*/ EOS/" /mnt/share/${PROJECT_NAME}/gitlab/config/gitlab.rb
    echo updating configuration file
    sleep 20
    echo reconfiguring...
    docker exec gitlab.${PROJECT_NAME} gitlab-ctl reconfigure
    echo restarting...
    docker exec gitlab.${PROJECT_NAME} gitlab-ctl restart
    echo "done"