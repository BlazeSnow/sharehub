# Sharehub-SMB

## 介绍

此镜像基于Debian 13，使用Samba进行文件共享。

```bash
docker pull blazesnow/sharehub-smb:beta
```

## `docker-compose.yml`

```yml
services:
  smb:
    image: blazesnow/sharehub-smb:beta
    container_name: smb
    restart: no
    ports:
      - 445:445
      - 139:139
    volumes:
      - ./data:/data
```

## 用户名与密码

- 默认用户名：`admin`
- 默认密码：`password`

修改密码步骤：

```bash
# 进入终端
docker exec -it smb /bin/bash

# 修改密码
smbpasswd admin
```
