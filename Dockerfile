FROM blazesnow/caddy:webdav-alpine AS builder

FROM alpine:3.22.1

RUN apk update \
    && apk add --no-cache bash tzdata shadow s6-overlay \
    vsftpd \
    openssh \
    samba \
    nfs-utils rpcbind

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN chmod +x /usr/bin/caddy

COPY /s6-rc.d/ /etc/s6-overlay/s6-rc.d/

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

COPY entrypoint.sh /srv/entrypoint.sh
RUN chmod +x /srv/entrypoint.sh

ENTRYPOINT [ "/srv/entrypoint.sh" ]