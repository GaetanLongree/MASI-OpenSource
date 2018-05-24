#!/bin/bash
# installing Docker
apt-get update &&
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common &&
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - &&
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" &&
apt-get update &&
apt-get install -y docker-ce &&

# installing Docker Compose
curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
