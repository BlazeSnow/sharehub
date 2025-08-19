#!/bin/bash

set -e

# 全局初始化
main_setup() {
    echo "正在初始化sharehub"
    echo "设置时区为：${TZ:-UTC}"
    ln -snf /usr/share/zoneinfo/${TZ:-UTC} /etc/localtime
    echo "${TZ:-UTC}" >/etc/timezone

    echo "创建用户：$USERNAME"
    addgroup "sharehub"
    adduser -D -G sharehub -s /bin/bash -h "$SHAREPATH" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd

    echo "创建共享目录：$SHAREPATH"
    mkdir -p "$SHAREPATH"
    chown -R "$USERNAME":"$USERNAME" "$SHAREPATH"

    # 创建必要的目录
    echo "创建服务目录"
    mkdir -p /var/log/samba
    mkdir -p /etc/vsftpd
    mkdir -p /var/www/htdocs
    mkdir -p /var/lib/nfs/rpc_pipefs
    mkdir -p /var/lib/nfs/v4recovery

    if [ "$WRITABLE" == "true" ]; then
        echo "授予共享目录写权限"
        chmod -R 775 "$SHAREPATH"
    else
        echo "设置共享目录为只读权限"
        chmod -R 555 "$SHAREPATH"
    fi
}

# 配置FTP
setup_ftp() {
    if [ "$FTP" != "true" ]; then return; fi
    echo "正在配置FTP"
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
        if [ "$WRITABLE" == "true" ]; then
            echo "anon_upload_enable=YES" >>/etc/vsftpd/vsftpd.conf
            echo "anon_mkdir_write_enable=YES" >>/etc/vsftpd/vsftpd.conf
        fi
    else
        echo "anonymous_enable=NO" >>/etc/vsftpd/vsftpd.conf
    fi
    echo "$USERNAME" >/etc/vsftpd/user_list
}

# 配置SFTP
setup_sftp() {
    if [ "$SFTP" != "true" ]; then return; fi
    echo "正在配置SFTP"
    ssh-keygen -A
    cat >>/etc/ssh/sshd_config <<EOF

Match User $USERNAME
    ChrootDirectory %h
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOF
    if [ "$SSH" != "true" ]; then
        echo "仅启用SFTP"
        echo "    ForceCommand internal-sftp" >>/etc/ssh/sshd_config
    else
        echo "同时启用SSH和SFTP"
    fi
}

# 配置SMB
setup_smb() {
    if [ "$SMB" != "true" ]; then return; fi
    echo "正在配置SMB"
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

# 配置NFS
setup_nfs() {
    if [ "$NFS" != "true" ]; then return; fi
    echo "正在配置NFS"
    echo -n "$SHAREPATH" >/etc/exports
    local nfs_perms=$([ "$WRITABLE" == "true" ] && echo "rw" || echo "ro")
    echo " *(${nfs_perms},sync,no_subtree_check,insecure,no_root_squash)" >>/etc/exports
}

# 配置WebDAV
setup_webdav() {
    if [ "$WEBDAV" != "true" ]; then return; fi
    echo "正在配置WebDAV"

    if [ -f /usr/lib/nginx/modules/ngx_http_dav_ext_module.so ]; then
        WEBDAV_EXT_AVAILABLE=true
    else
        WEBDAV_EXT_AVAILABLE=false
    fi

    # 创建基本认证文件
    if command -v htpasswd >/dev/null 2>&1; then
        htpasswd -cb /etc/nginx/webdav.passwd "$USERNAME" "$PASSWORD"
    else
        # 手动创建基本认证文件
        if command -v openssl >/dev/null 2>&1; then
            HASH=$(openssl passwd -apr1 "$PASSWORD")
        else
            HASH=$(echo "$PASSWORD" | busybox cryptpw -m sha512)
        fi
        echo "$USERNAME:$HASH" >/etc/nginx/webdav.passwd
    fi

    cat >/etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

EOF

    if [ "$WEBDAV_EXT_AVAILABLE" = "true" ]; then
        cat >>/etc/nginx/nginx.conf <<EOF
# 加载 WebDAV 扩展模块
load_module modules/ngx_http_dav_ext_module.so;

EOF
    fi

    cat >>/etc/nginx/nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # WebDAV 服务器配置
    server {
        listen 80;
        server_name _;
        
        # 根路径 - 文件浏览
        location / {
            root $SHAREPATH;
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
            
            auth_basic "ShareHub File Share";
            auth_basic_user_file /etc/nginx/webdav.passwd;
        }
        
        # WebDAV 路径
        location /webdav {
            alias $SHAREPATH;
            
            # 基本 WebDAV 方法（nginx 核心支持）
            dav_methods PUT DELETE MKCOL COPY MOVE;
            
EOF

    if [ "$WEBDAV_EXT_AVAILABLE" = "true" ]; then
        cat >>/etc/nginx/nginx.conf <<EOF
            # 扩展 WebDAV 方法（需要 dav_ext 模块）
            dav_ext_methods PROPFIND OPTIONS LOCK UNLOCK;
            
EOF
    fi

    cat >>/etc/nginx/nginx.conf <<EOF
            # 创建完整路径
            create_full_put_path on;
            
            # 访问权限
            dav_access user:rw group:rw all:r;
            
            # 认证
            auth_basic "ShareHub WebDAV";
            auth_basic_user_file /etc/nginx/webdav.passwd;
            
            # 客户端最大上传大小
            client_max_body_size 0;
            
            # 自动索引
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
            
            # WebDAV 兼容性设置
            if (\$request_method = PROPFIND) {
                add_header Content-Type text/xml;
            }
            
            # 允许的方法
            add_header Allow "GET, HEAD, POST, PUT, DELETE, OPTIONS, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK";
            add_header DAV "1, 2";
EOF

    if [ "$WRITABLE" != "true" ]; then
        cat >>/etc/nginx/nginx.conf <<EOF
            
            # 只读模式：禁止写操作
            limit_except GET HEAD OPTIONS PROPFIND {
                deny all;
            }
EOF
    fi

    cat >>/etc/nginx/nginx.conf <<EOF
        }
        
        # 处理 OPTIONS 请求
        location ~ ^/webdav/.*$ {
            if (\$request_method = OPTIONS) {
                add_header Allow "GET, HEAD, POST, PUT, DELETE, OPTIONS, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK";
                add_header DAV "1, 2";
                add_header Content-Length 0;
                add_header Content-Type text/plain;
                return 200;
            }
        }
        
        # 错误页面
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
        
        location = /50x.html {
            root /var/lib/nginx/html;
        }
    }
}
EOF
}

# 启动所有已启用的服务
start_services() {
    echo "正在启动已启用的服务"

    if [ "$FTP" == "true" ]; then
        echo "启动FTP"
        /usr/sbin/vsftpd /etc/vsftpd/vsftpd.conf &
    fi

    if [ "$SSH" == "true" -o "$SFTP" == "true" ]; then
        echo "启动SSH/SFTP"
        /usr/sbin/sshd &
    fi

    if [ "$SMB" == "true" ]; then
        echo "启动SMB"
        /usr/sbin/smbd -F --no-process-group &
        /usr/sbin/nmbd -F --no-process-group &
    fi

    if [ "$NFS" == "true" ]; then
        echo "启动NFS"
        # 启动 rpcbind
        /sbin/rpcbind -f &
        sleep 2
        # 启动 NFS 相关服务
        /usr/sbin/rpc.mountd -F &
        /usr/sbin/rpc.nfsd 8 &
        exportfs -a 2>/dev/null
    fi

    sleep 3

    echo "================================================="
    echo "ShareHub服务已全部启动！"
    echo "================================================="
    echo " 连接信息："
    echo "ftp://$USERNAME:$PASSWORD@<host>:21"
    echo "sftp://$USERNAME:$PASSWORD@<host>:22"
    echo "ssh $USERNAME@<host>"
    echo "http://<host>/webdav"
    echo "smb://<host>/share"
    echo "<host>:$SHAREPATH"
    echo "================================================="

    if [ "$WEBDAV" == "true" ]; then
        exec nginx -g "daemon off;"
    else
        exec tail -f /dev/null
    fi
}

echo "================================================="
echo " ShareHub 多功能文件共享服务正在启动..."
echo "================================================="
echo " 配置信息："
echo " - 用户名: $USERNAME"
echo " - 共享路径: $SHAREPATH"
echo " - 可写权限: $WRITABLE"
echo " - 访客模式: $GUEST"
echo " - 时区: $TZ"
echo " - 启用服务: FTP=$FTP SSH=$SSH SFTP=$SFTP WebDAV=$WEBDAV SMB=$SMB NFS=$NFS"
echo "================================================="

if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

main_setup
setup_ftp
setup_sftp
setup_smb
setup_nfs
setup_webdav

start_services
