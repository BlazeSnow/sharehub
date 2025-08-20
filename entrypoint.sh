#!/bin/bash

USERNAME=${USERNAME:-sharehub}
PASSWORD=${PASSWORD:-password}
SHAREPATH=${SHAREPATH:-/sharehub}
WRITABLE=${WRITABLE:-true}
GUEST=${GUEST:-false}
TZ=${TZ:-UTC}
FTP=${FTP:-true}
SSH=${SSH:-false}
SFTP=${SFTP:-true}
WEBDAV=${WEBDAV:-true}
SMB=${SMB:-true}
NFS=${NFS:-true}

if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

echo "================================================="
echo " ShareHub 多功能文件共享服务正在初始化..."
echo "================================================="
echo " 配置信息："
echo " - 用户名: $USERNAME"
echo " - 共享路径: $SHAREPATH"
echo " - 可写权限: $WRITABLE"
echo " - 访客模式: $GUEST"
echo " - 时区: $TZ"
echo " - 启用服务: FTP=$FTP SSH=$SSH SFTP=$SFTP WebDAV=$WEBDAV SMB=$SMB NFS=$NFS"
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

# 启用服务
mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d

if [ "$FTP" = "true" ]; then
    ln -sf /etc/s6-overlay/s6-rc.d/ftp /etc/s6-overlay/s6-rc.d/user/contents.d/ftp
fi

if [ "$SFTP" = "true" ] || [ "$SSH" = "true" ]; then
    ln -sf /etc/s6-overlay/s6-rc.d/sftp /etc/s6-overlay/s6-rc.d/user/contents.d/sftp
fi

if [ "$WEBDAV" = "true" ]; then
    ln -sf /etc/s6-overlay/s6-rc.d/webdav /etc/s6-overlay/s6-rc.d/user/contents.d/webdav
fi

if [ "$SMB" = "true" ]; then
    ln -sf /etc/s6-overlay/s6-rc.d/smb-bundle /etc/s6-overlay/s6-rc.d/user/contents.d/smb-bundle
fi

if [ "$NFS" = "true" ]; then
    ln -sf /etc/s6-overlay/s6-rc.d/nfs-bundle /etc/s6-overlay/s6-rc.d/user/contents.d/nfs-bundle
fi

exec /init
