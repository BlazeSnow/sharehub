# Sharehub

## SMB

```bash
docker pull blazesnow/sharehub-smb:beta
```

`docker-compose.yml`文件：

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

默认用户名：`admin`
默认密码：`password`

修改密码步骤：

```bash
docker exec -it smb /bin/bash
smbpasswd admin
```
