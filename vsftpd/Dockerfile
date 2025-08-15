FROM debian:13

RUN apt-get update && apt-get install -y --no-install-recommends vsftpd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY ./vsftpd.conf /etc/vsftpd.conf

RUN useradd -m -s /bin/bash admin \
    && echo "admin:password" | chpasswd

RUN mkdir -p /data \
    && chown admin:admin /data \
    && chmod 775 /data

EXPOSE 20 21 21100-21110

CMD ["vsftpd", "/etc/vsftpd.conf"]