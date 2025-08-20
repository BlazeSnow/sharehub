#!/bin/bash

echo "正在配置 FTP 服务"

mkdir -p /etc/vsftpd
rm -f /etc/vsftpd/vsftpd.conf
touch /etc/vsftpd/vsftpd.conf

cat >/etc/vsftpd/vsftpd.conf <<EOF
# 基础配置
listen=YES
listen_ipv6=NO
anonymous_enable=$([ "$GUEST" == "true" ] && echo "YES" || echo "NO")
local_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES

# 用户配置
userlist_enable=YES
userlist_file=/etc/vsftpd/user_list
userlist_deny=NO
local_root=$SHAREPATH

# chroot 配置
chroot_local_user=YES
allow_writeable_chroot=YES
write_enable=$([ "$WRITABLE" == "true" ] && echo "YES" || echo "NO")
port_enable=YES
pasv_enable=$([ "$FTP_PASSIVE" == "true" ] && echo "YES" || echo "NO")
seccomp_sandbox=NO
hide_ids=YES

# 修复常见连接问题
tcp_wrappers=NO
EOF

if [ "$FTP_PASSIVE" == "true" ]; then
    cat >>/etc/vsftpd/vsftpd.conf <<EOF
pasv_min_port=21100
pasv_max_port=21110
pasv_address=$FTP_PASSIVE_IP
pasv_addr_resolve=NO
pasv_promiscuous=YES
EOF
fi

# 创建用户列表
touch /etc/vsftpd/user_list
echo "$USERNAME" >/etc/vsftpd/user_list
