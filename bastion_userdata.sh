#!/bin/bash

sudo yum update -y
sudo yum install sshpass -y
# Install SSH server
sudo yum -y install openssh-server

sudo systemctl restart sshd
