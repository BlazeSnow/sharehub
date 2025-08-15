FROM debian:13

RUN apt-get update && apt-get install samba -y

COPY ./sharehub.conf /srv/sharehub.conf

RUN useradd -m -s /bin/bash admin
RUN echo "admin:password" | chpasswd
RUN (echo "password"; echo "password") | smbpasswd -a -s admin

RUN mkdir -p /data
RUN chown admin:admin /data
RUN chmod 775 /data

EXPOSE 445 139

CMD [ "smbd", "-s", "/srv/sharehub.conf" ]