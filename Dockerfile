FROM alpine:3

RUN apk update \
    && apk add --no-cache bash \
    vsftpd openssh apache2 samba nfs-utils

ENV AGREE true
ENV USERNAME sharehub
ENV PASSWORD password
ENV SHAREPATH /sharehub
ENV WRITABLE true
ENV GUEST false
ENV TZ UTC
ENV FTP true
ENV FTP_PASSIVE true
ENV SFTP true
ENV SSH true
ENV WEBDAV true
ENV SMB true
ENV NFS true

RUN mkdir -p /sharehub && chmod 777 /sharehub

EXPOSE 20 21 22 80 139 443 445 2049 21100-21110 

COPY ./entrypoint.sh /srv/entrypoint.sh
RUN chmod 700 /srv/entrypoint.sh

ENTRYPOINT [ "/srv/entrypoint.sh" ]