FROM debian:13

RUN apt-get update && apt-get install -y --no-install-recommends pure-ftpd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -f sharehub \
    && useradd -g sharehub -m -s /bin/bash admin \
    && echo "admin:password" | chpasswd

RUN mkdir -p /data \
    && chown admin:admin /data \
    && chmod 775 /data

EXPOSE 21 35000-35999

CMD ["pure-ftpd", "-c", "5", "-E", "-j", "-l", "puredb:/etc/pure-ftpd/pureftpd.pdb", "-p", "35000:35999"]
