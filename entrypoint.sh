#!/bin/bash

USERNAME=${USERNAME:-"sharehub"}
PASSWORD=${PASSWORD:-"password"}
SHAREPATH=${SHAREPATH:-"/sharehub"}
WRITABLE=${WRITABLE:-"true"}
GUEST=${GUEST:-"false"}
TZ=${TZ:-"UTC"}
FTP=${FTP:-"true"}
FTP_PASSIVE=${FTP_PASSIVE:-"false"}
FTP_PASSIVE_IP=${FTP_PASSIVE_IP:-"0.0.0.0"}
SSH=${SSH:-"false"}
SFTP=${SFTP:-"true"}
WEBDAV=${WEBDAV:-"true"}
SMB=${SMB:-"true"}
NFS=${NFS:-"true"}

if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

echo "================================================="
echo "         欢迎使用ShareHub"
echo "================================================="
echo "用户名：$USERNAME"
echo "共享路径：$SHAREPATH"
echo "可写权限：$WRITABLE"
echo "访客模式：$GUEST"
echo "时区：$TZ"
echo "FTP：$FTP"
echo "SSH：$SSH"
echo "SFTP：$SFTP"
echo "WebDAV：$WEBDAV"
echo "SMB：$SMB"
echo "NFS：$NFS"
echo "================================================="

# 设定时区
echo "正在初始化sharehub"
echo "设置时区为：$TZ"
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo "$TZ" >/etc/timezone

# 创建用户
echo "创建用户：$USERNAME"
addgroup "sharehub" 2>/dev/null || true
adduser -D -G sharehub -s /bin/bash -h "$SHAREPATH" "$USERNAME" 2>/dev/null || true
echo "$USERNAME:$PASSWORD" | chpasswd

# 创建目录
echo "创建共享目录：$SHAREPATH"
mkdir -p "$SHAREPATH"
chown -R "$USERNAME":sharehub "$SHAREPATH"

if [ "$WRITABLE" == "true" ]; then
    echo "授予共享目录写权限"
    chmod -R 775 "$SHAREPATH"
else
    echo "设置共享目录为只读权限"
    chmod -R 555 "$SHAREPATH"
fi

# 编辑服务配置文件

# ------------FTP------------

# 创建共享目录
mkdir -p "$SHAREPATH"
# 创建虚拟用户文件
echo -e "$USERNAME\n$PASSWORD" >/etc/vsftpd/virtual_users.txt
/usr/bin/db_load -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db
# 创建用户目录
mkdir -p "$SHAREPATH"
chown -R ftp:ftp "$SHAREPATH"
# 被动模式配置
PASV_CONFIG=""
if [ "$FTP_PASSIVE" = "true" ]; then
    PASV_CONFIG="pasv_enable=YES
pasv_min_port=21100
pasv_max_port=21110"
    if [ "$FTP_PASSIVE_IP" != "0.0.0.0" ]; then
        PASV_CONFIG="$PASV_CONFIG
pasv_address=$FTP_PASSIVE_IP"
    fi
else
    PASV_CONFIG="pasv_enable=NO"
fi
# 可写权限配置
if [ "$WRITABLE" = "true" ]; then
    WRITE_CONFIG="write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES"
else
    WRITE_CONFIG="write_enable=NO
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO"
fi
# 访客模式配置
if [ "$GUEST" = "true" ]; then
    ANON_CONFIG="anonymous_enable=YES
anon_root=$SHAREPATH
no_anon_password=YES"
else
    ANON_CONFIG="anonymous_enable=NO"
fi
# 生成vsftpd配置文件
cat >/etc/vsftpd/vsftpd.conf <<EOF
# 基本配置
listen=YES
listen_ipv6=NO
$ANON_CONFIG
local_enable=NO
guest_enable=YES
guest_username=ftp
virtual_use_local_privs=YES
# 写权限配置
$WRITE_CONFIG
# 虚拟用户配置
user_config_dir=/etc/vsftpd/user_conf
pam_service_name=vsftpd_virtual
# 数据传输
connect_from_port_20=YES
ftp_data_port=20
# 被动模式配置
$PASV_CONFIG
# 目录和权限
local_root=$SHAREPATH
chroot_local_user=YES
allow_writeable_chroot=YES
# 日志
xferlog_enable=YES
xferlog_file=/var/log/xferlog
log_ftp_protocol=YES
# 其他
background=NO
max_clients=10
max_per_ip=5
use_localtime=YES
EOF
# 创建用户配置目录
mkdir -p /etc/vsftpd/user_conf
# 为用户创建个人配置
cat >/etc/vsftpd/user_conf/$USERNAME <<EOF
local_root=$SHAREPATH
write_enable=$([[ "$WRITABLE" = "true" ]] && echo "YES" || echo "NO")
anon_world_readable_only=NO
anon_upload_enable=$([[ "$WRITABLE" = "true" ]] && echo "YES" || echo "NO")
anon_mkdir_write_enable=$([[ "$WRITABLE" = "true" ]] && echo "YES" || echo "NO")
anon_other_write_enable=$([[ "$WRITABLE" = "true" ]] && echo "YES" || echo "NO")
EOF

# ------------SFTP------------

echo "正在配置 SFTP 服务"

rm -f /etc/ssh/sshd_config
touch /etc/ssh/sshd_config

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

# ------------WebDAV------------

echo "正在配置 WebDAV 服务"

PASSWORD_HASH=$(caddy hash-password --plaintext "$PASSWORD" 2>/dev/null || echo "$PASSWORD")

mkdir -p /etc/caddy
rm -f /etc/caddy/Caddyfile
touch /etc/caddy/Caddyfile

if [ "$WRITABLE" = "false" ]; then
    cat >/etc/caddy/Caddyfile <<EOF
{
    order webdav before file_server
}

:80 {
    root * $SHAREPATH
    
    @readonly_methods method GET HEAD OPTIONS PROPFIND
    
    route {
        webdav @readonly_methods
        file_server browse
        respond * "WebDAV is read-only" 405
    }
}
EOF
else
    cat >/etc/caddy/Caddyfile <<EOF
{
    order webdav before file_server
}

:80 {
    root * $SHAREPATH
    webdav
    file_server browse
}
EOF
fi

mkdir -p /var/log/caddy
chown -R caddy:caddy /var/log/caddy 2>/dev/null || true

# ------------SMB------------

echo "正在配置 SMB 服务"

rm -f /etc/samba/smb.conf
touch /etc/samba/smb.conf

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

# ------------NFS------------

echo "正在配置 NFS 服务"

rm -f /etc/exports
touch /etc/exports

echo -n "$SHAREPATH" >/etc/exports

nfs_perms=$([ "$WRITABLE" == "true" ] && echo "rw" || echo "ro")

echo " *(${nfs_perms},sync,no_subtree_check,insecure,no_root_squash)" >>/etc/exports

# 启用服务
mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d

if [ "$FTP" = "true" ]; then
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/ftp
fi

if [ "$SFTP" = "true" ] || [ "$SSH" = "true" ]; then
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/sftp
fi

if [ "$WEBDAV" = "true" ]; then
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/webdav
fi

if [ "$SMB" = "true" ]; then
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/smb
fi

if [ "$NFS" = "true" ]; then
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/nfs-bundle
fi

exec /init
