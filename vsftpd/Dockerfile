FROM debian:13

RUN apt-get update && apt-get install vsftpd -y

COPY ./vsftpd.conf /etc/vsftpd.conf

RUN useradd -m -s /bin/bash admin

RUN echo "admin:password" | chpasswd

EXPOSE 20 21 21100-21110

CMD ["vsftpd", "/etc/vsftpd.conf"]