#!/bin/sh
set -e

SHARE_DIR="/srv/data"
USER_NAME=${USERNAME:-user}
USER_PASS=${PASSWORD:-pass}

add_system_user() {
    if ! id -u "$USER_NAME" >/dev/null 2>&1; then
        adduser -D -h "$SHARE_DIR" -s /bin/false "$USER_NAME"
    fi
    echo "$USER_NAME:$USER_PASS" | chpasswd
}

start_ftp() {
    echo "Starting FTP server..."
    add_system_user
    chown -R "$USER_NAME:$USER_NAME" "$SHARE_DIR"

    cat >/etc/vsftpd/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
pasv_enable=YES
pasv_min_port=21000
pasv_max_port=21010
pasv_address=0.0.0.0
user_sub_token=\$USER
local_root=\$SHARE_DIR
EOF
    /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
}

start_sftp() {
    echo "Starting SFTP server..."
    if ! id -u "$USER_NAME" >/dev/null 2>&1; then
        adduser -D -h "$SHARE_DIR" -s /sbin/nologin "$USER_NAME"
    fi
    echo "$USER_NAME:$USER_PASS" | chpasswd
    chown -R "$USER_NAME:$USER_NAME" "$SHARE_DIR"

    cat >/etc/ssh/sshd_config <<EOF
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
Subsystem sftp internal-sftp

Match User $USER_NAME
    ChrootDirectory $SHARE_DIR
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
    /usr/sbin/sshd -D
}

start_webdav() {
    echo "Starting WebDAV (Apache) server..."
    htpasswd -cb /etc/apache2/htpasswd "$USER_NAME" "$USER_PASS"
    chown -R apache:apache "$SHARE_DIR"

    cat >/etc/apache2/httpd.conf <<EOF
ServerRoot "/etc/apache2"
Listen 80
LoadModule mpm_event_module modules/mod_mpm_event.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule authn_file_module modules/mod_authn_file.so
LoadModule dav_module modules/mod_dav.so
LoadModule dav_fs_module modules/mod_dav_fs.so
User apache
Group apache

DavLockDB /var/lib/dav/lock.db
<Directory "$SHARE_DIR">
    Dav On
    AuthType Basic
    AuthName "WebDAV"
    AuthUserFile /etc/apache2/htpasswd
    Require valid-user
</Directory>
EOF
    mkdir -p /var/lib/dav
    chown apache:apache /var/lib/dav
    httpd -D FOREGROUND
}

start_smb() {
    echo "Starting SMB server..."
    add_system_user
    (
        echo "$USER_PASS"
        echo "$USER_PASS"
    ) | smbpasswd -a -s "$USER_NAME"
    chown -R "$USER_NAME:$USER_NAME" "$SHARE_DIR"

    cat >/etc/samba/smb.conf <<EOF
[global]
workgroup = WORKGROUP
server string = ShareHub SMB Server
netbios name = sharehub
security = user
map to guest = bad user
dns proxy = no
[public]
path = $SHARE_DIR
browseable = yes
writable = yes
guest ok = no
read only = no
valid users = $USER_NAME
EOF
    /usr/sbin/smbd -F --no-process-group
}

start_nfs() {
    echo "Starting NFS server..."
    if ! grep -q "$SHARE_DIR" /etc/exports; then
        echo "$SHARE_DIR *(rw,sync,no_subtree_check,no_root_squash)" >>/etc/exports
    fi

    rpcbind -f &
    /usr/sbin/exportfs -r
    exec /usr/sbin/nfsd --no-udp 8
}

case "$SERVICE" in
ftp)
    start_ftp
    ;;
sftp)
    start_sftp
    ;;
webdav)
    start_webdav
    ;;
smb)
    start_smb
    ;;
nfs)
    start_nfs
    ;;
*)
    echo "Error: Unknown service '$SERVICE'"
    echo "Available services: ftp, sftp, webdav, smb, nfs"
    exit 1
    ;;
esac
