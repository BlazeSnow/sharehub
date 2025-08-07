#!/bin/bash

set -eu

if [ -z "${SERVICE:-}" ] || [ -z "${USERNAME:-}" ] || [ -z "${PASSWORD:-}" ]; then
    echo "错误: 必须同时设置 'SERVICE', 'USERNAME', 和 'PASSWORD' 环境变量。" >&2
    exit 1
fi

create_system_user() {
    if ! id -u "${USERNAME}" &>/dev/null; then
        echo "正在创建系统用户: ${USERNAME}"
        useradd -m -s /bin/false "${USERNAME}"
    fi
    echo "正在为用户 ${USERNAME} 设置密码..."
    echo "${USERNAME}:${PASSWORD}" | chpasswd
}

case "$SERVICE" in
ftp)
    echo "启动 FTP 服务..."
    create_system_user
    cp /configs/vsftpd.conf /etc/vsftpd/vsftpd.conf
    sed -i "s#\$USER#${USERNAME}#g" /etc/vsftpd/vsftpd.conf
    echo "FTP 服务配置完成，正在启动 vsftpd..."
    exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
    ;;

sftp)
    echo "启动 SFTP 服务..."
    create_system_user
    cp /configs/sshd_config /etc/ssh/sshd_config
    echo "Match User ${USERNAME}" >>/etc/ssh/sshd_config
    echo "    ChrootDirectory /data" >>/etc/ssh/sshd_config
    echo "    ForceCommand internal-sftp" >>/etc/ssh/sshd_config
    echo "    AllowTcpForwarding no" >>/etc/ssh/sshd_config
    echo "    X11Forwarding no" >>/etc/ssh/sshd_config
    echo "SFTP 服务配置完成，正在启动 sshd..."
    exec /usr/sbin/sshd -D
    ;;

webdav)
    echo "启动 WebDAV 服务..."
    cp /configs/webdav.conf /etc/apache2/conf.d/webdav.conf
    htpasswd -bc /etc/apache2/webdav.password "${USERNAME}" "${PASSWORD}"
    sed -i 's/^#ServerName .*/ServerName localhost/' /etc/apache2/httpd.conf
    echo "Include /etc/apache2/conf.d/webdav.conf" >>/etc/apache2/httpd.conf
    echo "WebDAV 服务配置完成，正在启动 Apache httpd..."
    exec httpd -D FOREGROUND
    ;;

smb)
    echo "启动 SMB/Samba 服务..."
    cp /configs/smb.conf /etc/samba/smb.conf
    (
        echo "${PASSWORD}"
        echo "${PASSWORD}"
    ) | smbpasswd -a -s "${USERNAME}"
    echo "Samba 服务配置完成，正在启动 smbd..."
    exec smbd --foreground --no-process-group
    ;;

nfs)
    echo "启动 NFS 服务..."
    cp /configs/exports /etc/exports
    echo "正在启动 NFS 依赖服务..."
    /usr/sbin/rpcbind
    /usr/sbin/rpc.nfsd
    /usr/sbin/exportfs -ra
    echo "NFS 服务配置完成，正在启动 rpc.mountd 作为主进程..."
    exec /usr/sbin/rpc.mountd -F
    ;;

*)
    echo "错误: 无效的 SERVICE 值 '${SERVICE}'。" >&2
    echo "支持的服务为: ftp, sftp, webdav, smb, nfs" >&2
    exit 1
    ;;
esac
