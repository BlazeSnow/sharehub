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

COPY ./entrypoint.sh /sharehub/entrypoint.sh
RUN chmod 700 /sharehub/entrypoint.sh

ENTRYPOINT [ "/sharehub/entrypoint.sh" ]