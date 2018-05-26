#!/bin/bash

echo "Enter the new project name (avoid whitespaces): "
read PROJECT_NAME

mkdir ${PROJECT_NAME}
cp docker-compose.yml ${PROJECT_NAME}
cp .env ${PROJECT_NAME}
cp users.csv ${PROJECT_NAME}
cp start.sh ${PROJECT_NAME}

echo "#####################################################"
echo ""
echo "New project folder created."
echo "    Navigate to the ${PROJECT_NAME} folder and edit"
echo "    the .env and users.csv files according to the"
echo "    project needs."
echo ""
echo "    Once the files are edited as desired, launch the"
echo "    containers with:"
echo ""
echo "        bash start.sh <IP ADDRESS>/<NETMASK>"
echo ""
echo "    NB: the ip address must be a free IP on the "
echo "        outside network, and the netmask must be in"
echo "        CIDR notation (8, 16, 24)"
echo ""
echo "#####################################################"