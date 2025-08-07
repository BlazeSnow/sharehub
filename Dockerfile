#使用Alpine Linux作为基础镜像
FROM alpine:3.22.1

# 安装服务
RUN apk add --no-cache vsftpd openssh apache2 apache2-utils samba-server nfs-utils rpcbind bash

# 创建挂载点目录
RUN mkdir -p /data
RUN chmod 755 /data

# 拷贝配置文件
COPY ./config/ /srv/config

# 添加并授权启动脚本
COPY entrypoint.sh /srv/entrypoint.sh
RUN chmod 700 /srv/entrypoint.sh

# 环境变量
ENV SERVICE=**string**
ENV USERNAME=blazesnow
ENV PASSWORD=**random**

# 暴露所有服务端口
EXPOSE 21 22 80 139 445 2049 21000-21010

# 设置容器入口点
ENTRYPOINT ["/srv/entrypoint.sh"]