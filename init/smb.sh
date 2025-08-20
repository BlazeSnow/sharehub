#!/bin/bash

echo "正在配置 SMB 服务"

(
    echo "$PASSWORD"
    echo "$PASSWORD"
) | smbpasswd -a -s "$USERNAME" 2>/dev/null || true

cat >/etc/samba/smb.conf <<EOF
[global]
    workgroup = WORKGROUP
    server string = ShareHub Samba Server
    security = user
    map to guest = bad user
    log file = /var/log/samba/log.%m
    max log size = 50
    
[share]
    path = $SHAREPATH
    browseable = yes
    guest ok = $([ "$GUEST" == "true" ] && echo "yes" || echo "no")
    read only = $([ "$WRITABLE" == "true" ] && echo "no" || echo "yes")
    writable = $([ "$WRITABLE" == "true" ] && echo "yes" || echo "no")
    valid users = $USERNAME $([ "$GUEST" == "true" ] && echo "nobody")
EOF
