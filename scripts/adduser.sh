#!/bin/bash
set -euo pipefail

# 从环境变量读取用户名和密码
USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"

# 校验环境变量
if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    echo "ERROR: 必须设置环境变量 USERNAME 和 PASSWORD"
    exit 1
fi

# 创建用户
if ! id "$USERNAME" &>/dev/null; then
    addgroup sharehub
    adduser --group sharehub "$USERNAME"
fi

# 通过openssl生成加密密码
ENCRYPTED_PWD=$(openssl passwd -6 -salt $(openssl rand -base64 4) <<<"$PASSWORD")

# 安全更新密码
echo "${USERNAME}:${ENCRYPTED_PWD}" | chpasswd -e

# 验证用户创建
id "$USERNAME" && echo "用户 ${USERNAME} 创建成功"
