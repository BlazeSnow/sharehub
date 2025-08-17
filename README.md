# Sharehub

> DockerHub链接：<https://hub.docker.com/r/blazesnow/sharehub>

此镜像致力于解决文件共享问题，目前支持FTP、SFTP、WebDav、SMB和NFS共享协议

```bash
docker pull blazesnow/sharehub:beta
```

`docker-compose.yml`示例如下：

```yml
services:
  sharehub:
    image: blazesnow/sharehub:beta
    container_name: sharehub
    restart: unless-stopped
    cap_add:
      - SYS_ADMIN
    volumes:
      - ./data:/sharehub
    ports:
      - 20:20
      - 21:21
      - 22:22
      - 80:80
      - 139:139
      - 443:443
      - 445:445
      - 2049:2049
      - 21100-21110:21100-21110
    environment:
      - AGREE=true
      - USERNAME=sharehub
      - PASSWORD=password
      - SHAREPATH=/sharehub
      - WRITABLE=true
      - GUEST=false
      - TZ=UTC
      - FTP=true
      - FTP_PASSIVE=true
      - SFTP=true
      - SSH=true
      - WEBDAV=true
      - SMB=true
      - NFS=true
```
