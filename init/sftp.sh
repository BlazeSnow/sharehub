#!/bin/bash

echo "正在配置 SFTP 服务"

ssh-keygen -A 2>/dev/null || true

cat >>/etc/ssh/sshd_config <<EOF

# ShareHub SFTP Configuration
Match User $USERNAME
    ChrootDirectory %h
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOF

if [ "$SSH" != "true" ]; then
    echo "    ForceCommand internal-sftp" >>/etc/ssh/sshd_config
fi
