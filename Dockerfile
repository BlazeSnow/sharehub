FROM alpine:3.22.1

RUN apk update \
    && apk add --no-cache bash tzdata shadow \
    vsftpd \
    openssh \
    apache2 apache2-utils \
    samba \
    nfs-utils rpcbind

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

EXPOSE 20 21 22 80 139 443 445 2049 21100-21110 

COPY ./entrypoint.sh /srv/entrypoint.sh
RUN chmod 700 /srv/entrypoint.sh

RUN mkdir -p /etc/apache2/conf.d \
    && mkdir -p /var/run/apache2 \
    && touch /etc/apache2/webdav.passwd \
    && chmod 666 /etc/apache2/webdav.passwd

RUN echo "LoadModule dav_module modules/mod_dav.so" >> /etc/apache2/httpd.conf \
    && echo "LoadModule dav_fs_module modules/mod_dav_fs.so" >> /etc/apache2/httpd.conf \
    && echo "LoadModule auth_digest_module modules/mod_auth_digest.so" >> /etc/apache2/httpd.conf

ENTRYPOINT [ "/srv/entrypoint.sh" ]