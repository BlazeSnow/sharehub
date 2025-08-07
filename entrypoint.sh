case "$SERVICE" in
ftp)
    cp /configs/vsftpd.conf /etc/vsftpd/vsftpd.conf
    sed -i "s/\$USER/$USER_NAME/g" /etc/vsftpd/vsftpd.conf
    exec /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf
    ;;
sftp)
    cp /configs/sshd_config /etc/ssh/sshd_config
    echo "Match User $USER_NAME" >>/etc/ssh/sshd_config
    echo "    ChrootDirectory /data" >>/etc/ssh/sshd_config
    echo "    ForceCommand internal-sftp" >>/etc/ssh/sshd_config
    echo "    AllowTcpForwarding no" >>/etc/ssh/sshd_config
    echo "    X11Forwarding no" >>/etc/ssh/sshd_config
    exec /usr/sbin/sshd -D
    ;;
webdav)
    cp /configs/webdav.conf /etc/apache2/conf.d/webdav.conf
    htpasswd -bc /etc/apache2/webdav.password $USER_NAME $USER_PASS
    sed -i 's/^#ServerName .*/ServerName localhost/' /etc/apache2/httpd.conf
    echo "Include /etc/apache2/conf.d/webdav.conf" >>/etc/apache2/httpd.conf
    httpd -k start
    tail -f /var/log/apache2/access.log
    ;;
smb)
    cp /configs/smb.conf /etc/samba/smb.conf
    (
        echo $USER_PASS
        echo $USER_PASS
    ) | smbpasswd -a -s $USER_NAME
    exec smbd --foreground --no-process-group
    ;;
nfs)
    cp /configs/exports /etc/exports
    /usr/sbin/rpcbind
    /usr/sbin/rpc.nfsd
    /usr/sbin/exportfs -ra
    exec /usr/sbin/rpc.mountd -F
    ;;
esac
