#!/bin/bash

echo "正在配置 NFS 服务"

echo -n "$SHAREPATH" >/etc/exports

nfs_perms=$([ "$WRITABLE" == "true" ] && echo "rw" || echo "ro")

echo " *(${nfs_perms},sync,no_subtree_check,insecure,no_root_squash)" >>/etc/exports
