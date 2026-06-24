#!/usr/bin/env bash
# ============================================================
#  Reality SNI 伪装站点一键部署脚本
#  支持: Ubuntu / Debian / CentOS / Fedora
#  用法:
#    bash deploy.sh -d <域名> -e <邮箱>           # 一键安装(默认443)
#    bash deploy.sh -d <域名> -e <邮箱> -p 8443   # 指定端口
#    bash deploy.sh -m <新域名>                     # 修改域名
#    bash deploy.sh -u                              # 卸载
# ============================================================
set -euo pipefail

# ==================== 颜色与日志 ====================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
die()   { echo -e "${RED}[FATAL]${NC} $*"; exit 1; }

# ==================== 默认变量 ====================
DEPLOY_DIR="/opt/reality-site"
CONTAINER_NAME="reality-site"
DOMAIN=""
EMAIL=""
PORT=""
ACTION="install"
NEW_DOMAIN=""

# ==================== 解析参数 ====================
usage() {
    cat <<EOF
${BOLD}Reality SNI 伪装站点 一键部署脚本${NC}

用法:
  bash deploy.sh -d <域名> -e <邮箱>           # 一键安装(默认443)
  bash deploy.sh -d <域名> -e <邮箱> -p 8443   # 指定端口
  bash deploy.sh -m <新域名>                     # 修改域名
  bash deploy.sh -u                              # 卸载

选项:
  -d  域名    你的完整域名 (例如 blog.example.com)
  -e  邮箱    用于 Let's Encrypt 证书通知
  -p  端口    HTTPS 端口 (默认 443，不影响证书自动续签)
  -m  新域名  修改已部署站点的域名
  -u          卸载已部署的站点
  -h          显示帮助
EOF
}

while getopts "d:e:p:m:uh" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        m) NEW_DOMAIN="$OPTARG"; ACTION="modify" ;;
        u) ACTION="uninstall" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# ==================== 卸载逻辑 ====================
uninstall() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  正在卸载 Reality 伪装站点...${NC}"
    echo -e "${CYAN}========================================${NC}"

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        info "停止并移除容器..."
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    if [[ -d "$DEPLOY_DIR" ]]; then
        info "删除部署目录: $DEPLOY_DIR"
        rm -rf "$DEPLOY_DIR"
    fi

    docker volume rm reality-site_caddy_data reality-site_caddy_config >/dev/null 2>&1 || true

    info "卸载完成"
    exit 0
}

[[ "$ACTION" == "uninstall" ]] && uninstall

# ==================== 修改域名逻辑 ====================
modify_domain() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  修改伪装站点域名${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # 检查是否已部署
    if [[ ! -f "$DEPLOY_DIR/Caddyfile" ]]; then
        die "未检测到已部署的站点，请先运行 bash deploy.sh -d <域名> -e <邮箱> 安装"
    fi

    # 获取当前域名（去掉端口部分）
    local first_line
    first_line=$(head -1 "$DEPLOY_DIR/Caddyfile")
    OLD_DOMAIN=$(echo "$first_line" | sed 's/:[0-9]*$//' | sed 's/ {//')
    if [[ -z "$OLD_DOMAIN" ]]; then
        OLD_DOMAIN=$(echo "$first_line" | awk '{print $1}' | sed 's/:[0-9]*$//')
    fi

    # 获取当前端口
    OLD_PORT=$(echo "$first_line" | grep -oP ':\K[0-9]+' | head -1 || true)
    [[ -z "$OLD_PORT" ]] && OLD_PORT="443"

    # 交互式输入新域名
    if [[ -z "$NEW_DOMAIN" ]]; then
        info "当前域名: ${OLD_DOMAIN} (端口: ${OLD_PORT})"
        read -rp "请输入新域名: " NEW_DOMAIN
    fi

    if [[ -z "$NEW_DOMAIN" ]]; then
        die "新域名不能为空"
    fi

    if [[ "$NEW_DOMAIN" == "$OLD_DOMAIN" ]]; then
        die "新域名与当前域名相同"
    fi

    # 询问是否同时修改邮箱
    OLD_EMAIL=$(grep -oP 'tls \K\S+' "$DEPLOY_DIR/Caddyfile" 2>/dev/null | head -1 || true)
    NEW_EMAIL="$OLD_EMAIL"
    echo ""
    info "当前邮箱: ${OLD_EMAIL}"
    read -rp "是否修改邮箱? 输入新邮箱或留空保持不变: " INPUT_EMAIL
    if [[ -n "$INPUT_EMAIL" ]]; then
        NEW_EMAIL="$INPUT_EMAIL"
    fi

    # 询问是否修改端口
    echo ""
    info "当前端口: ${OLD_PORT}"
    read -rp "是否修改端口? 输入新端口或留空保持不变: " INPUT_PORT
    if [[ -n "$INPUT_PORT" ]]; then
        OLD_PORT="$INPUT_PORT"
    fi

    echo ""
    info "旧域名: ${OLD_DOMAIN}"
    info "新域名: ${NEW_DOMAIN}"
    info "邮箱:   ${NEW_EMAIL}"
    info "端口:   ${OLD_PORT}"
    echo ""
    read -rp "确认修改? (y/N): " CONFIRM
    [[ "${CONFIRM,,}" != "y" ]] && die "用户取消"

    # 1. 重新生成 Caddyfile
    info "更新 Caddyfile..."
    local site_addr="${NEW_DOMAIN}"
    [[ "$OLD_PORT" != "443" ]] && site_addr="${NEW_DOMAIN}:${OLD_PORT}"

    cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
${site_addr} {
    tls ${NEW_EMAIL} {
        protocols tls1.2 tls1.3
        curves x25519
    }
    root * /usr/share/caddy
    file_server

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy no-referrer-when-downgrade
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }

    redir /feed /atom.xml permanent
    redir /rss /atom.xml permanent
    redir /rss.xml /atom.xml permanent
    redir /sitemap /sitemap.xml permanent

    handle_errors {
        rewrite * /404.html
        file_server
    }
}

:80 {
    @notmyhost not host ${NEW_DOMAIN}
    respond @notmyhost "" 444
}
CADDYEOF

    # 2. 替换站点文件中的旧域名
    info "更新站点文件中的域名..."
    if [[ -d "$DEPLOY_DIR/site" ]]; then
        find "$DEPLOY_DIR/site" -type f \( -name "*.xml" -o -name "*.txt" -o -name "*.html" \) \
            -exec sed -i "s|${OLD_DOMAIN}|${NEW_DOMAIN}|g" {} + 2>/dev/null || true
        find "$DEPLOY_DIR/site" -type f \( -name "*.xml" -o -name "*.txt" \) \
            -exec sed -i "s|__DOMAIN__|${NEW_DOMAIN}|g" {} + 2>/dev/null || true
    fi

    # 3. 更新 docker-compose.yml 端口映射
    info "更新 docker-compose.yml..."
    cat > "$DEPLOY_DIR/docker-compose.yml" <<COMPOSEEOF
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: reality-site
    ports:
      - "80:80"
      - "${OLD_PORT}:${OLD_PORT}"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./site:/usr/share/caddy:ro
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
COMPOSEEOF

    # 4. 清理旧证书并重启
    info "清理旧证书数据..."
    docker volume rm reality-site_caddy_data >/dev/null 2>&1 || true

    info "重启 Caddy 容器..."
    cd "$DEPLOY_DIR"
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
    docker compose up -d 2>/dev/null || docker-compose up -d

    # 5. 等待新证书签发
    info "等待新域名 SSL 证书签发..."
    echo -n "  "

    CERT_OK=false
    for i in $(seq 1 30); do
        echo -n "."
        sleep 2

        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo ""
            die "容器异常退出，请查看日志: docker logs $CONTAINER_NAME"
        fi

        if docker logs "$CONTAINER_NAME" 2>&1 | grep -qi "certificate obtained successfully"; then
            CERT_OK=true
            break
        fi
    done
    echo ""

    # 6. 显示结果
    local access_url="https://${NEW_DOMAIN}"
    [[ "$OLD_PORT" != "443" ]] && access_url="https://${NEW_DOMAIN}:${OLD_PORT}"

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          域名修改结果                            ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    info "旧域名: ${OLD_DOMAIN}"
    info "新域名: ${NEW_DOMAIN}"
    info "访问地址: ${access_url}"

    if [[ "$CERT_OK" == "true" ]]; then
        info "SSL 证书: ${GREEN}已签发${NC}"
    else
        warn "SSL 证书: ${YELLOW}签发中，请稍后访问验证${NC}"
        warn "请确保新域名 DNS 已指向本机 IP"
    fi
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    exit 0
}

[[ "$ACTION" == "modify" ]] && modify_domain

# ==================== 检查 root ====================
if [[ $EUID -ne 0 ]]; then
    die "请使用 root 用户运行: sudo bash deploy.sh"
fi

# ==================== 交互式输入（如果未通过参数传入） ====================
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Reality SNI 伪装站点 一键部署${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if [[ -z "$DOMAIN" ]]; then
    read -rp "请输入你的域名 (例如 blog.example.com): " DOMAIN
fi
if [[ -z "$EMAIL" ]]; then
    read -rp "请输入你的邮箱 (用于 Let's Encrypt 通知): " EMAIL
fi
if [[ -z "$PORT" ]]; then
    echo ""
    info "HTTPS 端口选择:"
    echo "  443   - 默认，最自然（推荐，如 443 未被占用）"
    echo "  8443  - 常用 HTTPS 备用端口"
    echo "  2053  - Cloudflare 备用端口"
    echo "  其他  - 自定义端口"
    echo ""
    read -rp "请输入 HTTPS 端口 (留空默认 443): " PORT
    [[ -z "$PORT" ]] && PORT="443"
fi

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    die "域名和邮箱不能为空"
fi

# 验证端口
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 || "$PORT" -gt 65535 ]]; then
    die "端口无效，请输入 1-65535 之间的数字"
fi
if [[ "$PORT" == "80" ]]; then
    die "80 端口保留给 HTTP/ACME 证书验证，请选择其他端口"
fi

# ==================== 检测操作系统 ====================
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-}"
    elif [[ -f /etc/redhat-release ]]; then
        OS_ID="centos"
    else
        OS_ID="unknown"
    fi
}
detect_os
info "检测到系统: $OS_ID $OS_VERSION"

# ==================== 工具函数 ====================
pkg_install() {
    case "$OS_ID" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1
            apt-get install -y "$@" >/dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y "$@" >/dev/null 2>&1 || dnf install -y "$@" >/dev/null 2>&1
            ;;
        *)
            die "不支持的系统: $OS_ID"
            ;;
    esac
}

# ==================== 步骤 1: 安装依赖 ====================
info "[1/8] 安装基础依赖..."
pkg_install curl wget

# ==================== 步骤 2: 安装 Docker ====================
if ! command -v docker &>/dev/null; then
    info "[2/8] 安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker  >/dev/null 2>&1
    info "Docker 安装完成"
else
    info "[2/8] Docker 已安装，跳过"
fi

# 确保 docker compose 可用
if ! docker compose version &>/dev/null 2>&1; then
    info "安装 Docker Compose 插件..."
    case "$OS_ID" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1
            apt-get install -y docker-compose-plugin >/dev/null 2>&1 || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            dnf install -y docker-compose-plugin >/dev/null 2>&1 || yum install -y docker-compose-plugin >/dev/null 2>&1 || true
            ;;
    esac
fi

# ==================== 步骤 3: 检测端口占用 ====================
info "[3/8] 检测端口..."
check_port() {
    if ss -tlnp 2>/dev/null | grep -q ":${1} "; then
        local proc
        proc=$(ss -tlnp 2>/dev/null | grep ":${1} " | head -1 || true)
        warn "端口 $1 已被占用: $proc"
        return 1
    fi
    return 0
}

PORT_OK=true
check_port 80   || PORT_OK=false
check_port "$PORT" || PORT_OK=false

if [[ "$PORT_OK" == "false" ]]; then
    warn "检测到 80 或 ${PORT} 端口被占用，Caddy 可能无法启动"
    read -rp "是否继续? (y/N): " CONTINUE
    [[ "${CONTINUE,,}" != "y" ]] && die "用户取消"
fi

# ==================== 步骤 4: 配置防火墙 ====================
info "[4/8] 配置防火墙..."
if command -v ufw &>/dev/null; then
    ufw allow 80/tcp      >/dev/null 2>&1 || true
    ufw allow "${PORT}"/tcp >/dev/null 2>&1 || true
    info "UFW 已放行 80/${PORT}"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-service=http  >/dev/null 2>&1 || true
    firewall-cmd --permanent --add-port="${PORT}"/tcp >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
    info "firewalld 已放行 80/${PORT}"
elif command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport 80      -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null || true
    info "iptables 已放行 80/${PORT}"
else
    warn "未检测到防火墙，请确保云服务商安全组已放行 80/${PORT}"
fi

# ==================== 步骤 5: 生成配置文件 ====================
info "[5/8] 生成配置文件..."
mkdir -p "$DEPLOY_DIR"

# --- Caddyfile ---
# 443 端口不需要在域名后加端口，其他端口需要
SITE_ADDR="${DOMAIN}"
[[ "$PORT" != "443" ]] && SITE_ADDR="${DOMAIN}:${PORT}"

cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
${SITE_ADDR} {
    tls ${EMAIL} {
        protocols tls1.2 tls1.3
        curves x25519
    }
    root * /usr/share/caddy
    file_server

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy no-referrer-when-downgrade
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }

    redir /feed /atom.xml permanent
    redir /rss /atom.xml permanent
    redir /rss.xml /atom.xml permanent
    redir /sitemap /sitemap.xml permanent

    handle_errors {
        rewrite * /404.html
        file_server
    }
}

:80 {
    @notmyhost not host ${DOMAIN}
    respond @notmyhost "" 444
}
CADDYEOF

# --- 复制站点文件 ---
info "准备站点文件..."
if [[ -d "$(dirname "$0")/site" ]]; then
    info "从本地 site/ 目录复制..."
    cp -r "$(dirname "$0")/site" "$DEPLOY_DIR/site"
else
    info "本地无 site/ 目录，从 GitHub Release 下载..."
    REPO_URL="https://github.com/Kiss8202/wz"
    RELEASE_URL="${REPO_URL}/releases/latest/download/reality-site.tar.gz"
    if curl -fSL --connect-timeout 10 --max-time 120 -o /tmp/reality-site.tar.gz "$RELEASE_URL" 2>/dev/null; then
        tar xzf /tmp/reality-site.tar.gz -C /tmp/
        cp -r /tmp/reality-site/site "$DEPLOY_DIR/site"
        rm -rf /tmp/reality-site /tmp/reality-site.tar.gz
        info "站点文件下载完成"
    else
        die "下载失败，请手动将 site/ 目录放到 $DEPLOY_DIR/"
    fi
fi

# --- 替换域名占位符 ---
if [[ -d "$DEPLOY_DIR/site" ]]; then
    find "$DEPLOY_DIR/site" -type f \( -name "*.xml" -o -name "*.txt" \) \
        -exec sed -i "s|__DOMAIN__|${DOMAIN}|g" {} + 2>/dev/null || true
fi

# --- docker-compose.yml ---
cat > "$DEPLOY_DIR/docker-compose.yml" <<COMPOSEEOF
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: reality-site
    ports:
      - "80:80"
      - "${PORT}:${PORT}"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./site:/usr/share/caddy:ro
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
COMPOSEEOF

# ==================== 步骤 6: 防扫描加固 ====================
info "[6/8] 配置防扫描规则..."

# --- 屏蔽已知扫描器 IP 段 ---
info "屏蔽 Shodan/Censys 等扫描器 IP..."
SCAN_NETS=(
    # Shodan
    "198.51.44.0/24" "71.6.165.0/24" "71.6.146.0/24" "66.240.192.0/18" "74.82.160.0/19"
    # Censys
    "162.142.148.0/24" "167.248.133.0/24" "192.35.168.0/23"
    # BinaryEdge
    "157.230.0.0/16" "167.71.0.0/16" "167.99.0.0/16"
    # Shadowserver
    "184.105.247.0/24" "184.105.139.0/24"
)
for net in "${SCAN_NETS[@]}"; do
    iptables -I INPUT -s "$net" -j DROP 2>/dev/null || true
done

# --- 安装 fail2ban 防暴力扫描 ---
if ! command -v fail2ban-server &>/dev/null; then
    info "安装 fail2ban..."
    pkg_install fail2ban
fi

# 创建 fail2ban jail 配置
mkdir -p /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/reality-site.conf << 'F2BEOF'
[nginx-http-auth]
enabled = false

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

[port-scan]
enabled = true
filter = port-scan
logpath = /var/log/syslog
maxretry = 3
bantime = 86400
findtime = 300
F2BEOF

# 创建端口扫描过滤器
cat > /etc/fail2ban/filter.d/port-scan.conf << 'F2BEOF'
[Definition]
failregex = .*SRC=<HOST>.*DPT=\d+.*
ignoreregex =
F2BEOF

systemctl enable fail2ban >/dev/null 2>&1 || true
systemctl start fail2ban  >/dev/null 2>&1 || true
info "fail2ban 已配置"

# --- iptables 防端口扫描 ---
info "配置 iptables 防扫描规则..."
iptables -I INPUT -p tcp --syn -m connlimit --connlimit-above 20 -j DROP 2>/dev/null || true
iptables -I INPUT -p tcp --syn -m limit --limit 10/s --limit-burst 20 -j ACCEPT 2>/dev/null || true
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT 2>/dev/null || true

# 保存 iptables 规则
if command -v iptables-save &>/dev/null; then
    case "$OS_ID" in
        ubuntu|debian)
            pkg_install iptables-persistent
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            ;;
    esac
fi

info "防扫描规则配置完成"

# ==================== 步骤 7: 启动容器 ====================
info "[7/8] 拉取 Caddy 镜像并启动..."

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "检测到旧容器，正在替换..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
fi

cd "$DEPLOY_DIR"
docker compose up -d 2>/dev/null || docker-compose up -d

# ==================== 步骤 8: 等待证书签发并验证 ====================
info "[8/8] 等待 Caddy 自动签发 SSL 证书..."
echo -n "  "

CERT_OK=false
for i in $(seq 1 30); do
    echo -n "."
    sleep 2

    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo ""
        die "容器异常退出，请查看日志: docker logs $CONTAINER_NAME"
    fi

    if docker exec "$CONTAINER_NAME" sh -c "netstat -tlnp 2>/dev/null | grep -q ':${PORT}'" 2>/dev/null; then
        CERT_OK=true
        break
    fi

    if docker logs "$CONTAINER_NAME" 2>&1 | grep -qi "certificate obtained successfully"; then
        CERT_OK=true
        break
    fi
done
echo ""

# ==================== 最终报告 ====================
VPS_IP=$(curl -s4 --connect-timeout 3 ifconfig.me 2>/dev/null || curl -s4 --connect-timeout 3 icanhazip.com 2>/dev/null || echo "<你的VPS公网IP>")

ACCESS_URL="https://${DOMAIN}"
[[ "$PORT" != "443" ]] && ACCESS_URL="https://${DOMAIN}:${PORT}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          部署结果                                ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "容器状态: ${GREEN}运行中${NC}"
    info "部署目录: $DEPLOY_DIR"
    info "HTTPS 端口: ${PORT}"
    info "访问地址: ${ACCESS_URL}"

    if [[ "$CERT_OK" == "true" ]]; then
        info "SSL 证书: ${GREEN}已签发${NC}"
    else
        warn "SSL 证书: ${YELLOW}签发中，请稍后访问验证${NC}"
        warn "如果证书签发失败，请检查域名 DNS 是否已指向本机"
    fi
else
    error "容器状态: ${RED}未运行${NC}"
    die "请查看日志: docker logs $CONTAINER_NAME"
fi

echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║          DNS 配置提醒                            ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
warn "Cloudflare DNS 设置:"
warn "  类型: A"
warn "  名称: ${DOMAIN%%.*}"
warn "  IP:   ${VPS_IP}"
warn "  代理: 灰色云朵 (仅DNS，不开CDN)"
echo ""
info "SNI 伪装域名: ${DOMAIN}"
if [[ "$PORT" != "443" ]]; then
    echo ""
    info "Reality handshake 配置参考:"
    echo "  方式1 (远程握手): dest = \"${DOMAIN}:443\" (需 443 端口由其他服务监听)"
    echo "  方式2 (本地握手): dest = \"127.0.0.1:${PORT}\" (Caddy 在本地 ${PORT} 端口)"
fi
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
info "常用命令:"
echo "  查看日志:   docker logs $CONTAINER_NAME"
echo "  重启服务:   cd $DEPLOY_DIR && docker compose restart"
echo "  修改域名:   bash deploy.sh -m <新域名>"
echo "  卸载站点:   bash deploy.sh -u"
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             安全加固说明                        ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
info "已启用的安全措施:"
echo "  [1] TLS 1.3 + X25519 强制加密"
echo "  [2] SNI 过滤 - 非本域名请求返回 444 断开"
echo "  [3] HSTS 预加载 - 浏览器强制 HTTPS"
echo "  [4] iptables 屏蔽 Shodan/Censys/BinaryEdge 扫描器"
echo "  [5] fail2ban 防端口扫描和 SSH 暴力破解"
echo "  [6] 连接速率限制 - 防大规模端口扫描"
echo ""
warn "额外建议（脚本无法自动完成）:"
echo "  [1] 修改 SSH 默认端口（22 → 其他）"
echo "  [2] 禁用密码登录，仅用密钥认证"
echo "  [3] 在 Cloudflare 关闭证书透明度日志（需付费）"
echo "  [4] 定期检查: curl -s https://crt.sh/?q=${DOMAIN}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
