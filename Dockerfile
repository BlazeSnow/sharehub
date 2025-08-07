FROM alpine:latest

# 安装所需服务
RUN apk add --no-cache \
    vsftpd \
    openssh \
    apache2 apache2-webdav apache2-utils \
    samba \
    nfs-utils \
    rpcbind \
    bash

# 创建配置文件目录
RUN mkdir -p /srv/configs /configs

# 添加启动脚本
COPY entrypoint.sh /srv/entrypoint.sh
RUN chmod +x /srv/entrypoint.sh

# 创建数据目录
RUN mkdir -p /srv/data && chmod 777 /srv/data

# 暴露端口
EXPOSE 21 22 80 139 445 2049 21000-21010

ENTRYPOINT ["/srv/entrypoint.sh"]
