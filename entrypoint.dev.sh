#!/bin/bash
set -e

# ==============================================================================
# 欢迎语和环境检查
# ==============================================================================
echo "================================================="
echo " ShareHub 多功能文件共享服务正在启动..."
echo "================================================="

# 检查是否同意条款（一个形式上的检查）
if [ "$AGREE" != "true" ]; then
    echo "错误：你必须设置环境变量 AGREE=true 才能启动此容器。"
    exit 1
fi

# ==============================================================================
# 主要的初始化函数
# ==============================================================================
main_setup() {
    echo "-> 正在进行全局初始化..."

    # 1. 设置时区
    echo "   - 设置时区为: $TZ"
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ >/etc/timezone

    # 2. 创建共享用户和组
    echo "   - 创建用户和组: $USERNAME"
    addgroup "$USERNAME"
    adduser -D -G "$USERNAME" -s /bin/bash -h "$SHAREPATH" "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd

    # 3. 创建并设置共享目录的权限
    echo "   - 创建共享目录: $SHAREPATH"
    mkdir -p "$SHAREPATH"
    chown -R "$USERNAME":"$USERNAME" "$SHAREPATH"

    if [ "$WRITABLE" == "true" ]; then
        echo "   - 授予共享目录 '写' 权限"
        chmod -R 775 "$SHAREPATH"
    else
        echo "   - 设置共享目录为 '只读' 权限"
        chmod -R 555 "$SHAREPATH"
    fi
}

# ==============================================================================
# 各个服务的配置函数
# ==============================================================================

# --- FTP (vsftpd) ---
setup_ftp() {
    if [ "$FTP" != "true" ]; then return; fi
    echo "-> 正在配置 FTP 服务 (vsftpd)..."
}

# --- SSH / SFTP (openssh) ---
setup_ssh_sftp() {
    if [ "$SSH" != "true" ] && [ "$SFTP" != "true" ]; then return; fi
    echo "-> 正在配置 SSH / SFTP 服务..."
}

# --- SAMBA (SMB/CIFS) ---
setup_smb() {
    if [ "$SMB" != "true" ]; then return; fi
    echo "-> 正在配置 Samba 服务 (SMB)..."
}

# --- NFS ---
setup_nfs() {
    if [ "$NFS" != "true" ]; then return; fi
    echo "-> 正在配置 NFS 服务..."
}

# --- WebDAV (apache2) ---
setup_webdav() {
    if [ "$WEBDAV" != "true" ]; then return; fi
    echo "-> 正在配置 WebDAV 服务 (Apache2)..."

    echo "   - 为 WebDAV 创建用户凭证"

    # ==========================================================================
    # !! 诊断模块 !!
    # 我们将在这里打印出关于 $PASSWORD 变量的一切信息，然后退出。
    # ==========================================================================
    echo ""
    echo "================================================="
    echo "--- 开始密码变量诊断 ---"
    echo "================================================="
    echo ""

    echo "1. 使用 echo 打印密码 (用尖括号包裹，检查前后是否有空格):"
    echo "<${PASSWORD}>"
    echo ""

    echo "2. 密码的原始字节 (Hexdump):"
    echo "   这会显示所有字符，包括隐藏的控制字符。"
    echo -n "${PASSWORD}" | hexdump -C
    echo ""

    # 为了对比，我们创建一个已知内容的变量
    KNOWN_VAR="test"
    echo "3. 对比：一个已知变量 'test' 的 Hexdump 应该是这样的 (4字节):"
    echo -n "${KNOWN_VAR}" | hexdump -C
    echo ""

    echo "4. 检查密码长度 (使用 wc -c 统计字节数):"
    LENGTH=$(echo -n "${PASSWORD}" | wc -c)
    echo "   密码变量包含 ${LENGTH} 个字节。"
    echo ""

    echo "================================================="
    echo "--- 诊断结束 ---"
    echo "================================================="
    echo "脚本已停止以便进行诊断。请将上面的输出提供给技术支持。"
    echo "特别是 'Hexdump' 部分，它揭示了密码变量的真实内容。"

    # 立即退出脚本，不执行后续命令
    exit 1
}

# ==============================================================================
# 启动所有已配置的服务
# ==============================================================================
start_services() {
    # 在诊断模式下，此函数不会被调用
    echo "-> 跳过服务启动（诊断模式）"
}

# ==============================================================================
# 脚本主执行逻辑
# ==============================================================================
main_setup
setup_ftp
setup_ssh_sftp
setup_smb
setup_nfs
# 只运行 WebDAV 设置来进行诊断
setup_webdav

# 后续步骤不会执行，因为 setup_webdav 会退出
start_services
wait -n
echo "一个关键服务已停止，正在关闭容器..."
exit 0
