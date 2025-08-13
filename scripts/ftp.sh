#!/bin/sh

/srv/adduser.sh

mkdir -p /var/run/vsftpd/empty

/usr/sbin/vsftpd /etc/vsftpd.conf

tail -f /dev/null
