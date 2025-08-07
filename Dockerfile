#使用Alpine Linux作为基础镜像
FROM alpine:latest

# 安装服务
RUN apk add vsftpd openssh

# 创建用户组
RUN addgroup sharehub
RUN adduser -D -g sharehub sharehub

# 创建挂载点目录
RUN mkdir -p /data
RUN chown root:sharehub /data
RUN chmod 770 /data

# 拷贝配置文件
COPY ./config/vsftpd.conf /etc/vsftpd/vsftpd.conf

# 添加并授权启动脚本
COPY entrypoint.sh /srv/entrypoint.sh
RUN chmod 700 /srv/entrypoint.sh

# 环境变量
ENV SERVICE="vsftpd ssh webdav samba nfs"
ENV PASSWORD=**random**

# 暴露所有服务端口
EXPOSE 21 22 80 139 445 2049 21000-21010

# 设置容器入口点
ENTRYPOINT ["/srv/entrypoint.sh"]