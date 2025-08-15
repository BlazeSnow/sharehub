FROM debian:13

RUN apt-get update && apt-get install pure-ftpd -y

RUN groupadd -f sharehub

RUN useradd -g sharehub -m -s /bin/bash admin

RUN echo "admin:password" | chpasswd

EXPOSE 21 35000-35999

CMD ["pure-ftpd", "-c", "5", "-E", "-j", "-l", "puredb:/etc/pure-ftpd/pureftpd.pdb", "-p", "35000:35999"]
