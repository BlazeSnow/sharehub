FROM alpine:3.22.1

RUN apk update \
    && apk add --no-cache bash tzdata shadow \
    vsftpd \
    openssh \
    nginx nginx-mod-http-dav-ext \
    samba \
    nfs-utils rpcbind

ARG S6_OVERLAY_VERSION=3.2.1.0
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
RUN rm -f /tmp/s6-overlay-*.tar.xz

RUN echo "oneshot" > /etc/s6-overlay/s6-rc.d/sharehub/type \
    && echo "longrun" > /etc/s6-overlay/s6-rc.d/ftp/type \
    && echo "longrun" > /etc/s6-overlay/s6-rc.d/sftp/type \
    && echo "longrun" > /etc/s6-overlay/s6-rc.d/webdav/type \
    && echo "longrun" > /etc/s6-overlay/s6-rc.d/smb/type \
    && echo "longrun" > /etc/s6-overlay/s6-rc.d/nfs/type

ENV AGREE=true
ENV USERNAME=sharehub
ENV PASSWORD=password
ENV SHAREPATH=/sharehub
ENV WRITABLE=true
ENV GUEST=false
ENV TZ=UTC
ENV FTP=true
ENV FTP_PASSIVE=true
ENV SFTP=true
ENV SSH=true
ENV WEBDAV=true
ENV SMB=true
ENV NFS=true

EXPOSE 20 21 22 80 139 443 445 2049 21100-21110

ENTRYPOINT [ "/init" ]