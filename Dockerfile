#使用Alpine Linux作为基础镜像
FROM alpine:3.22.1

# 安装服务
RUN apk add --no-cache \
    vsftpd \
    openssh \
    apache2 apache2-utils \
    samba-server \
    nfs-utils \
    rpcbind \
    bash

# 创建挂载点目录
# /srv/configs 用于挂载自定义配置文件
# /srv/data 用于挂载持久化数据
RUN mkdir -p /srv/configs /srv/data

# 添加并授权启动脚本
COPY entrypoint.sh /srv/entrypoint.sh
RUN chmod +x /srv/entrypoint.sh

# 暴露所有服务端口
EXPOSE 21 22 80 139 445 2049 21000-21010

# 设置容器入口点
ENTRYPOINT ["/srv/entrypoint.sh"]