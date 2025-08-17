#!/bin/bash

# 脚本在遇到任何错误时立即退出
set -e

# ==============================================================================
#  函数定义区域
# ==============================================================================

# 全局初始化：创建用户、目录、设置权限等
main_setup() {
    echo "-> 正在进行全局初始化..."
    echo "   - 设置时区为: ${TZ:-UTC}"
    ln -snf /usr/share/zoneinfo/${TZ:-UTC} /etc/localtime
    echo "${TZ:-UTC}" >/etc/timezone

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

# 配置 FTP 服务
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
    else echo "anonymous_enable=NO" >>/etc/vsftpd/vsftpd.conf; fi
    echo "$USERNAME" >/etc/vsftpd/user_list
}

# 配置 SSH / SFTP 服务
setup_ssh_sftp() {
    if [ "$SSH" != "true" ] && [ "$SFTP" != "true" ]; then return; fi
    echo "-> 正在配置 SSH / SFTP 服务..."
    ssh-keygen -A
    cat >>/etc/ssh/sshd_config <<EOF

Match User $USERNAME
    ChrootDirectory %h
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOF
    if [ "$SSH" != "true" ]; then
        echo "   - 仅启用 SFTP (禁用 shell 访问)"
        echo "    ForceCommand internal-sftp" >>/etc/ssh/sshd_config
    else
        echo "   - 同时启用 SSH 和 SFTP"
    fi
}

# 配置 Samba (SMB) 服务
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

# 配置 NFS 服务
setup_nfs() {
    if [ "$NFS" != "true" ]; then return; fi
    echo "-> 正在配置 NFS 服务..."
    echo -n "$SHAREPATH" >/etc/exports
    local nfs_perms=$([ "$WRITABLE" == "true" ] && echo "rw" || echo "ro")
    echo " *(${nfs_perms},sync,no_subtree_check)" >>/etc/exports
}

# 配置 WebDAV 服务
setup_webdav() {
    if [ "$WEBDAV" != "true" ]; then return; fi
    echo "-> 正在配置 WebDAV 服务 (Apache2)..."
    sed -i -e '/LoadModule dav_module/s/^#//' \
        -e '/LoadModule dav_fs_module/s/^#//' \
        -e '/LoadModule auth_digest_module/s/^#//' /etc/apache2/httpd.conf

    echo "   - 为 WebDAV 创建用户凭证 (手动生成，绕过 htdigest)"
    local REALM="ShareHub"
    HASH=$(printf "%s:%s:%s" "$USERNAME" "$REALM" "$PASSWORD" | md5sum | cut -d' ' -f1)
    echo "${USERNAME}:${REALM}:${HASH}" >/etc/apache2/webdav.passwd

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
        sed -i '/Require valid-user/a \    <LimitExcept GET OPTIONS PROPFIND>\n        Require user ""\n    </LimitExcept>' /etc/apache2/conf.d/webdav.conf
    else
        echo "   - WebDAV 已配置为可写"
    fi
}

# 启动所有已启用的服务
start_services() {
    echo "-> 正在启动已启用的服务..."

    # 将所有辅助服务启动到后台
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
        # rpc.nfsd 启动内核线程后会自行退出，这是正常行为
        rpc.nfsd 8
    fi

    echo "================================================="
    echo " ShareHub 服务已全部启动完毕！"
    echo "================================================="

    # 将一个核心服务（这里是 WebDAV）在前台运行以保持容器存活
    if [ "$WEBDAV" == "true" ]; then
        echo "[INFO] 主服务 WebDAV 正在前台运行以保持容器存活..."
        # 使用 exec 可让 httpd 进程替换掉当前的 shell 进程，成为容器的 PID 1
        exec /usr/sbin/httpd -D FOREGROUND
    else
        # 如果 WebDAV 未启用，则使用 tail 作为备用方案来保持运行
        echo "[INFO] WebDAV 未启用。使用 'tail -f /dev/null' 保持容器运行。"
        exec tail -f /dev/null
    fi
}

# ==============================================================================
#  脚本主执行流程
# ==============================================================================

echo "================================================="
echo " ShareHub 多功能文件共享服务正在启动..."
echo "================================================="

# 检查用户是否同意条款（一个简单的安全措施）
if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

# 依次执行所有配置函数
main_setup
setup_ftp
setup_ssh_sftp
setup_smb
setup_nfs
setup_webdav

# 启动服务，此函数将接管进程，不会返回
start_services
