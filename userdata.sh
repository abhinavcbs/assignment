#!/bin/bash

#Install httpd
sudo yum update -y
#sudo yum install -y httpd
sudo yum install -y httpd.x86_64
systemctl start httpd.service
systemctl enable httpd.service
echo "SIEMENS Assignment Completed" > /var/www/html/index.html

# Install SSH server
sudo yum -y install openssh-server

# Enable password authentication in SSH configuration
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart sshd

sudo useradd -m application
echo 'application:password' | sudo chpasswd



device="/dev/nvme1n1"

function handle_mounts
{
   echo "Wait until we have the EBS attached (new or reattached)"
   ls -l "$device" > /dev/null
   while [ $? -ne 0 ]; do
       echo "Device $device is still NOT available, sleeping..."
       sleep 15
       ls -l "$device" > /dev/null
   done
   echo "Device $device is available"


   lsblk "$device" --output FSTYPE | grep xfs > /dev/null
   if [ $? -ne 0 ]; then
        echo "Device $device is new, formatting"
        sudo mkfs -t xfs $device

        sleep 20
        echo "Add to entry to fstab"
        UUID=$(blkid $device -o value | head -1)
        echo "UUID=$UUID /var/log    xfs defaults,noatime,nofail 0 0" >> /etc/fstab
   else
       echo "Device $device was reattached"
   fi

   echo "Make sure mount is available"
   sleep 2;
   mount -a > /dev/null
   while [ $? -ne 0 ]; do
       echo "Error mounting all filesystems from /etc/fstab, sleeping..."
       sleep 2;
       mount -a > /dev/null
   done
   echo "Mounted all filesystems from /etc/fstab, proceeding"
}

handle_mounts

