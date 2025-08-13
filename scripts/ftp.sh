#!/bin/sh

/srv/adduser.sh

mkdir -p /var/run/vsftpd/empty

mkdir -p /home/$USERNAME/data

/usr/sbin/vsftpd /etc/vsftpd.conf

tail -f /dev/null
