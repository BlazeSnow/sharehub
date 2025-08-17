#!/bin/bash
set -e

# ==============================================================================
# 欢迎语和环境检查
# ==============================================================================
echo "================================================="
echo " ShareHub 多功能文件共享服务正在启动..."
echo "================================================="

# 检查是否同意条款（一个形式上的检查）
if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

# ==============================================================================
# 主要的初始化函数
# ==============================================================================
main_setup() {
    echo "-> 正在进行全局初始化..."

    # 1. 设置时区
    echo "   - 设置时区为: $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ >/etc/timezone

    # 2. 创建共享用户和组
    echo "   - 创建用户和组: $USERNAME"
    addgroup "$USERNAME"
    adduser -D -G "$USERNAME" -s /bin/bash -h "$SHAREPATH" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd

    # 3. 创建并设置共享目录的权限
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

# --- FTP (vsftpd) ---
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

    if [ "$WRITABLE" == "true" ]; then
        echo "write_enable=YES" >>/etc/vsftpd/vsftpd.conf
    fi

    if [ "$GUEST" == "true" ]; then
        echo "anonymous_enable=YES" >>/etc/vsftpd/vsftpd.conf
        echo "anon_root=$SHAREPATH" >>/etc/vsftpd/vsftpd.conf
        echo "no_anon_password=YES" >>/etc/vsftpd/vsftpd.conf
    else
        echo "anonymous_enable=NO" >>/etc/vsftpd/vsftpd.conf
    fi
    echo "$USERNAME" >/etc/vsftpd/user_list
}

# --- SSH / SFTP (openssh) ---
setup_ssh_sftp() {
    if [ "$SSH" != "true" ] && [ "$SFTP" != "true" ]; then return; fi
    echo "-> 正在配置 SSH / SFTP 服务..."
    ssh-keygen -A
    cat >>/etc/ssh/sshd_config <<EOF

# ShareHub 自定义配置
Match User $USERNAME
    ForceCommand internal-sftp
    ChrootDirectory %h
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOF
    if [ "$SSH" != "true" ] && [ "$SFTP" == "true" ]; then
        echo "   - 仅启用 SFTP (禁用 shell 访问)"
    elif [ "$SSH" == "true" ]; then
        echo "   - 同时启用 SSH 和 SFTP"
        sed -i "s/ForceCommand internal-sftp/#ForceCommand internal-sftp/" /etc/ssh/sshd_config
    fi
}

# --- SAMBA (SMB/CIFS) ---
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
    netbios name = sharehub
    security = user
    map to guest = bad user
    log file = /var/log/samba/log.%m
    max log size = 50

[share]
    path = $SHAREPATH
    comment = Shared Folder
    browseable = yes
    guest ok = ${GUEST:-no}
    read only = $([ "$WRITABLE" == "true" ] && echo "no" || echo "yes")
    writable = $([ "$WRITABLE" == "true" ] && echo "yes" || echo "no")
    valid users = $USERNAME $([ "$GUEST" == "true" ] && echo "nobody")
EOF
}

# --- NFS ---
setup_nfs() {
    if [ "$NFS" != "true" ]; then return; fi
    echo "-> 正在配置 NFS 服务..."
    echo -n "$SHAREPATH" >/etc/exports
    local nfs_perms="ro"
    if [ "$WRITABLE" == "true" ]; then
        nfs_perms="rw"
    fi
    echo " *(no_subtree_check,sync,${nfs_perms})" >>/etc/exports
}

# --- WebDAV (apache2) ---
setup_webdav() {
    if [ "$WEBDAV" != "true" ]; then return; fi
    echo "-> 正在配置 WebDAV 服务 (Apache2)..."

    sed -i '/LoadModule dav_module/s/^#//g' /etc/apache2/httpd.conf
    sed -i '/LoadModule dav_fs_module/s/^#//g' /etc/apache2/httpd.conf
    sed -i '/LoadModule auth_digest_module/s/^#//g' /etc/apache2/httpd.conf

    echo "   - 为 WebDAV 创建用户凭证"
    # ==========================================================================
    # !! 最终修正 !!
    # 结合使用 printf 和参数扩展来确保传递给 htdigest 的是纯净的密码字符串。
    # 1. `printf "%s"`: 这是最可靠的、不输出末尾换行符的方法，比 `echo -n` 更具可移植性。
    # 2. `${PASSWORD%$'\r'}`: 这个语法会删除 $PASSWORD 变量末尾可能存在的单个回车符(\r)，
    #    这能有效解决从 Windows 环境(如 .env 文件或 PowerShell)传入环境变量时带来的问题。
    # ==========================================================================
    printf "%s" "${PASSWORD%$'\r'}" | htdigest -c /etc/apache2/webdav.passwd "ShareHub" "$USERNAME"

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
    if [ "$WRITABLE" == "true" ]; then
        echo "   - WebDAV 已配置为可写"
    else
        sed -i "/Require valid-user/a \
    <LimitExcept GET OPTIONS PROPFIND>\n        Require user \"\"\n    </LimitExcept>" /etc/apache2/conf.d/webdav.conf
        echo "   - WebDAV 已配置为只读"
    fi
}

# ==============================================================================
# 启动所有已配置的服务
# ==============================================================================
start_services() {
    echo "-> 正在启动已启用的服务..."

    if [ "$FTP" == "true" ]; then
        echo "   - 启动 vsftpd..."
        /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &
    fi
    if [ "$SSH" == "true" ] || [ "$SFTP" == "true" ]; then
        echo "   - 启动 sshd..."
        /usr/sbin/sshd &
    fi
    if [ "$SMB" == "true" ]; then
        echo "   - 启动 smbd 和 nmbd..."
        /usr/sbin/smbd -F --no-process-group &
        /usr/sbin/nmbd -F --no-process-group &
    fi
    if [ "$NFS" == "true" ]; then
        echo "   - 启动 nfsd..."
        rpcbind -f &
        sleep 1
        rpc.mountd -F &
        rpc.nfsd 8
    fi
    if [ "$WEBDAV" == "true" ]; then
        echo "   - 启动 httpd (apache2)..."
        /usr/sbin/httpd -D FOREGROUND &
    fi

    echo "================================================="
    echo " ShareHub 服务已全部启动完毕！"
    echo "================================================="
}

# ==============================================================================
# 脚本主执行逻辑
# ==============================================================================
main_setup
setup_ftp
setup_ssh_sftp
setup_smb
setup_nfs
setup_webdav
start_services
wait -n
echo "一个关键服务已停止，正在关闭容器..."
exit 0
