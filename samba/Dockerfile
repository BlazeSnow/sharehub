FROM debian:13

RUN apt-get update && apt-get install -y --no-install-recommends samba \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY ./sharehub.conf /srv/sharehub.conf

RUN useradd -m -s /bin/bash admin \
    && echo "admin:password" | chpasswd \
    && (echo "password"; echo "password") | smbpasswd -a -s admin

RUN mkdir -p /data \
    && chown admin:admin /data \
    && chmod 775 /data

EXPOSE 445 139

CMD [ "smbd", "--configfile=/srv/sharehub.conf", "--foreground", "--debug-stdout", "--debuglevel=1", "--no-process-group" ]