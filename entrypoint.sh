#!/bin/bash
set -e

# ==============================================================================
# 欢迎语和环境检查
# ==============================================================================
echo "================================================="
echo " ShareHub 多功能文件共享服务正在启动..."
echo "================================================="

if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

# ==============================================================================
# 主要的初始化函数
# ==============================================================================
main_setup() {
    echo "-> 正在进行全局初始化..."
    echo "   - 设置时区为: $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ >/etc/timezone

    echo "   - 创建用户和组: $USERNAME"
    addgroup "$USERNAME"
    adduser -D -G "$USERNAME" -s /bin/bash -h "$SHAREPATH" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd

    echo "   - 创建共享目录: $SHAREPATH"
    mkdir -p "$SHAREPATH"
    chown -R "$USERNAME":"$USERNAME" "$SHAREPATH"

    if [ "$WRITABLE" == "true" ]; then
        echo "   - 授予共享目录 '写' 权限"
        chmod -R 775 "$SHAREPATH"
    else
        echo "   - 设置共享目录为 '只读' 权限"
        chmod -R 555 "$SHAREPATH"
    fi
}

# ==============================================================================
# 各个服务的配置函数
# ==============================================================================

setup_ftp() {
    if [ "$FTP" != "true" ]; then return; fi
    echo "-> 正在配置 FTP 服务 (vsftpd)..."
    cat >/etc/vsftpd/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
connect_from_port_20=YES
pasv_enable=${FTP_PASSIVE:-YES}
pasv_min_port=21100
pasv_max_port=21110
pasv_address_resolve=NO
userlist_enable=YES
userlist_file=/etc/vsftpd/user_list
userlist_deny=NO
dirmessage_enable=YES
xferlog_enable=YES
xferlog_std_format=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_enable=YES
EOF
    if [ "$WRITABLE" == "true" ]; then echo "write_enable=YES" >>/etc/vsftpd/vsftpd.conf; fi
    if [ "$GUEST" == "true" ]; then
        echo "anonymous_enable=YES" >>/etc/vsftpd/vsftpd.conf
        echo "anon_root=$SHAREPATH" >>/etc/vsftpd/vsftpd.conf
        echo "no_anon_password=YES" >>/etc/vsftpd/vsftpd.conf
    else
        echo "anonymous_enable=NO" >>/etc/vsftpd/vsftpd.conf
    fi
    echo "$USERNAME" >/etc/vsftpd/user_list
}

setup_ssh_sftp() {
    if [ "$SSH" != "true" ] && [ "$SFTP" != "true" ]; then return; fi
    echo "-> 正在配置 SSH / SFTP 服务..."
    ssh-keygen -A
    cat >>/etc/ssh/sshd_config <<EOF

Match User $USERNAME
    ForceCommand internal-sftp
    ChrootDirectory %h
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOF
    if [ "$SSH" == "true" ]; then
        echo "   - 同时启用 SSH 和 SFTP"
        sed -i "s/ForceCommand internal-sftp/#ForceCommand internal-sftp/" /etc/ssh/sshd_config
    else
        echo "   - 仅启用 SFTP (禁用 shell 访问)"
    fi
}

setup_smb() {
    if [ "$SMB" != "true" ]; then return; fi
    echo "-> 正在配置 Samba 服务 (SMB)..."
    (
        echo "$PASSWORD"
        echo "$PASSWORD"
    ) | smbpasswd -a -s "$USERNAME"
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
    guest ok = ${GUEST:-no}
    read only = $([ "$WRITABLE" == "true" ] && echo "no" || echo "yes")
    writable = $([ "$WRITABLE" == "true" ] && echo "yes" || echo "no")
    valid users = $USERNAME $([ "$GUEST" == "true" ] && echo "nobody")
EOF
}

setup_nfs() {
    if [ "$NFS" != "true" ]; then return; fi
    echo "-> 正在配置 NFS 服务..."
    echo -n "$SHAREPATH" >/etc/exports
    local nfs_perms=$([ "$WRITABLE" == "true" ] && echo "rw" || echo "ro")
    echo " *(${nfs_perms},sync,no_subtree_check)" >>/etc/exports
}

setup_webdav() {
    if [ "$WEBDAV" != "true" ]; then return; fi
    echo "-> 正在配置 WebDAV 服务 (Apache2)..."
    sed -i -e '/LoadModule dav_module/s/^#//' \
        -e '/LoadModule dav_fs_module/s/^#//' \
        -e '/LoadModule auth_digest_module/s/^#//' /etc/apache2/httpd.conf

    echo "   - 为 WebDAV 创建用户凭证"
    # ========================== 最终解决方案 ==========================
    # 使用批处理模式 (-b) 直接通过命令行参数传递密码，
    # 绕开了 Alpine Linux 上 htdigest 工具从 stdin 读取密码的 bug。
    htdigest -b -c /etc/apache2/webdav.passwd "ShareHub" "$USERNAME" "$PASSWORD"
    # ================================================================

    cat >/etc/apache2/conf.d/webdav.conf <<EOF
Listen 80
DavLockDB /var/run/apache2/DavLock
<VirtualHost *:80>
    Alias /webdav $SHAREPATH
    <Directory $SHAREPATH>
        DAV On
        AuthType Digest
        AuthName "ShareHub"
        AuthUserFile /etc/apache2/webdav.passwd
        Require valid-user
    </Directory>
</VirtualHost>
EOF
    if [ "$WRITABLE" != "true" ]; then
        echo "   - WebDAV 已配置为只读"
        sed -i "/Require valid-user/a \    <LimitExcept GET OPTIONS PROPFIND>\n        Require user \"\"\n    </LimitExcept>" /etc/apache2/conf.d/webdav.conf
    else
        echo "   - WebDAV 已配置为可写"
    fi
}

start_services() {
    echo "-> 正在启动已启用的服务..."
    [ "$FTP" == "true" ] && /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &
    [ "$SSH" == "true" -o "$SFTP" == "true" ] && /usr/sbin/sshd &
    if [ "$SMB" == "true" ]; then
        /usr/sbin/smbd -F --no-process-group &
        /usr/sbin/nmbd -F --no-process-group &
    fi
    if [ "$NFS" == "true" ]; then
        rpcbind -f &
        sleep 1
        rpc.mountd -F &
        rpc.nfsd 8
    fi
    [ "$WEBDAV" == "true" ] && /usr/sbin/httpd -D FOREGROUND &
    echo "================================================="
    echo " ShareHub 服务已全部启动完毕！"
    echo "================================================="
}

# ==============================================================================
# 脚本主执行流程
# ==============================================================================
main_setup
setup_ftp
setup_ssh_sftp
setup_smb
setup_nfs
setup_webdav
start_services

# 等待任何一个后台进程退出
wait -n

# 如果有进程退出，则脚本结束，容器将停止
echo "一个关键服务已停止，正在关闭容器..."
exit 0
