#!/bin/sh

/srv/adduser.sh

/usr/sbin/vsftpd /etc/vsftpd.conf

tail -f /dev/null
