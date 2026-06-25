#!/usr/bin/env bash
# ============================================================
#  Reality SNI 伪装站点一键部署脚本 (NAT 容器版)
#  使用 DNS-01 验证，不需要 80/443 端口
#  支持: Ubuntu / Debian / CentOS / Fedora
#  用法:
#    bash deploy.sh -d <域名> -t <CF_Token>         # 一键安装
#    bash deploy.sh -d <域名> -t <CF_Token> -p 8085  # 指定端口
#    bash deploy.sh -m <新域名>                        # 修改域名
#    bash deploy.sh -u                                 # 卸载
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
CF_TOKEN=""
ACTION="install"
NEW_DOMAIN=""

# ==================== 解析参数 ====================
usage() {
    cat <<EOF
${BOLD}Reality SNI 伪装站点 一键部署脚本 (NAT 容器版)${NC}

适用场景: NAT 容器机（80/443 端口不可用）
证书验证: DNS-01（通过 Cloudflare API，无需开放任何端口）

用法:
  bash deploy.sh -d <域名> -t <CF_Token>         # 一键安装
  bash deploy.sh -d <域名> -t <CF_Token> -p 8085  # 指定端口
  bash deploy.sh -m <新域名>                        # 修改域名
  bash deploy.sh -u                                 # 卸载

选项:
  -d  域名      你的完整域名 (例如 blog.example.com)
  -t  CF Token  Cloudflare API Token (需要 DNS 编辑权限)
  -e  邮箱      用于 Let's Encrypt 证书通知 (可选)
  -p  端口      HTTPS 端口 (默认 443)
  -m  新域名    修改已部署站点的域名
  -u            卸载已部署的站点
  -h            显示帮助

Cloudflare API Token 获取:
  1. 登录 https://dash.cloudflare.com/profile/api-tokens
  2. 创建令牌 → 编辑区域 DNS (模板)
  3. 区域资源 → 包含 → 你的域名
  4. 复制生成的 Token
EOF
}

while getopts "d:t:e:p:m:uh" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        t) CF_TOKEN="$OPTARG" ;;
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
    echo -e "${CYAN}  正在卸载 Reality 伪装站点 (NAT版)...${NC}"
    echo -e "${CYAN}========================================${NC}"

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        info "停止并移除容器..."
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    # 删除自定义镜像
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "caddy-cloudflare:latest"; then
        info "删除自定义 Caddy 镜像..."
        docker rmi caddy-cloudflare:latest >/dev/null 2>&1 || true
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
    echo -e "${CYAN}  修改伪装站点域名 (NAT版)${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    if [[ ! -f "$DEPLOY_DIR/Caddyfile" ]]; then
        die "未检测到已部署的站点，请先安装"
    fi

    # 获取当前域名
    local first_line
    first_line=$(head -1 "$DEPLOY_DIR/Caddyfile")
    OLD_DOMAIN=$(echo "$first_line" | sed 's/:[0-9]*$//' | sed 's/ {//')
    if [[ -z "$OLD_DOMAIN" ]]; then
        OLD_DOMAIN=$(echo "$first_line" | awk '{print $1}' | sed 's/:[0-9]*$//')
    fi

    OLD_PORT=$(echo "$first_line" | grep -oP ':\K[0-9]+' | head -1 || true)
    [[ -z "$OLD_PORT" ]] && OLD_PORT="443"

    if [[ -z "$NEW_DOMAIN" ]]; then
        info "当前域名: ${OLD_DOMAIN} (端口: ${OLD_PORT})"
        read -rp "请输入新域名: " NEW_DOMAIN
    fi

    if [[ -z "$NEW_DOMAIN" ]]; then die "新域名不能为空"; fi
    if [[ "$NEW_DOMAIN" == "$OLD_DOMAIN" ]]; then die "新域名与当前域名相同"; fi

    # 读取当前 CF Token
    OLD_CF_TOKEN=$(grep -oP 'dns cloudflare \K\S+' "$DEPLOY_DIR/Caddyfile" 2>/dev/null | head -1 || true)
    NEW_CF_TOKEN="$OLD_CF_TOKEN"
    echo ""
    info "当前 CF Token: ${OLD_CF_TOKEN:0:8}..."
    read -rp "是否修改 CF Token? 输入新 Token 或留空保持不变: " INPUT_TOKEN
    if [[ -n "$INPUT_TOKEN" ]]; then
        NEW_CF_TOKEN="$INPUT_TOKEN"
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
    info "端口:   ${OLD_PORT}"
    echo ""
    read -rp "确认修改? (y/N): " CONFIRM
    [[ "${CONFIRM,,}" != "y" ]] && die "用户取消"

    # 1. 重新生成 Caddyfile
    info "更新 Caddyfile..."
    local site_addr="${NEW_DOMAIN}"
    [[ "$OLD_PORT" != "443" ]] && site_addr="${NEW_DOMAIN}:${OLD_PORT}"

    cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
{
    acme_dns cloudflare ${NEW_CF_TOKEN}
}

${site_addr} {
    tls {
        dns cloudflare ${NEW_CF_TOKEN}
        protocols tls1.3
        curves x25519
    }
    root * /usr/share/caddy
    file_server

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
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
CADDYEOF

    # 2. 替换站点文件中的旧域名
    info "更新站点文件中的域名..."
    if [[ -d "$DEPLOY_DIR/site" ]]; then
        find "$DEPLOY_DIR/site" -type f \( -name "*.xml" -o -name "*.txt" -o -name "*.html" \) \
            -exec sed -i "s|${OLD_DOMAIN}|${NEW_DOMAIN}|g" {} + 2>/dev/null || true
        find "$DEPLOY_DIR/site" -type f \( -name "*.xml" -o -name "*.txt" \) \
            -exec sed -i "s|__DOMAIN__|${NEW_DOMAIN}|g" {} + 2>/dev/null || true
    fi

    # 3. 更新 docker-compose.yml
    info "更新 docker-compose.yml..."
    cat > "$DEPLOY_DIR/docker-compose.yml" <<COMPOSEEOF
version: '3.8'

services:
  caddy:
    image: caddy-cloudflare:latest
    build: .
    container_name: reality-site
    ports:
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

    info "重建并启动容器..."
    cd "$DEPLOY_DIR"
    docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
    docker compose up -d --build 2>/dev/null || docker-compose up -d --build

    # 5. 等待新证书签发
    info "等待新域名 SSL 证书签发 (DNS-01)..."
    echo -n "  "

    CERT_OK=false
    for i in $(seq 1 45); do
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

    local access_url="https://${NEW_DOMAIN}"
    [[ "$OLD_PORT" != "443" ]] && access_url="https://${NEW_DOMAIN}:${OLD_PORT}"

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          域名修改结果 (NAT版)                    ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    info "旧域名: ${OLD_DOMAIN}"
    info "新域名: ${NEW_DOMAIN}"
    info "访问地址: ${access_url}"

    if [[ "$CERT_OK" == "true" ]]; then
        info "SSL 证书: ${GREEN}已签发${NC}"
    else
        warn "SSL 证书: ${YELLOW}签发中，DNS-01 验证较慢，请稍后检查${NC}"
        echo "  查看日志: docker logs $CONTAINER_NAME"
    fi
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    exit 0
}

[[ "$ACTION" == "modify" ]] && modify_domain

# ==================== 检查 root ====================
if [[ $EUID -ne 0 ]]; then
    die "请使用 root 用户运行: sudo bash deploy.sh"
fi

# ==================== 交互式输入 ====================
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Reality SNI 伪装站点 一键部署${NC}"
echo -e "${CYAN}  (NAT 容器版 - DNS-01 验证)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if [[ -z "$DOMAIN" ]]; then
    read -rp "请输入你的域名 (例如 blog.example.com): " DOMAIN
fi
if [[ -z "$CF_TOKEN" ]]; then
    echo ""
    info "需要 Cloudflare API Token (DNS 编辑权限)"
    info "获取方式: https://dash.cloudflare.com/profile/api-tokens"
    echo ""
    read -rp "请输入 CF API Token: " CF_TOKEN
fi
if [[ -z "$EMAIL" ]]; then
    read -rp "请输入你的邮箱 (可选，用于 Let's Encrypt 通知): " EMAIL
fi
if [[ -z "$PORT" ]]; then
    echo ""
    info "HTTPS 端口选择 (NAT 容器版):"
    echo "  443   - 默认（需要 NAT 映射了 443 端口）"
    echo "  8085  - 常用 NAT 映射端口"
    echo "  其他  - 你的 NAT 映射端口"
    echo ""
    read -rp "请输入 HTTPS 端口 (留空默认 443): " PORT
    [[ -z "$PORT" ]] && PORT="443"
fi

if [[ -z "$DOMAIN" || -z "$CF_TOKEN" ]]; then
    die "域名和 CF Token 不能为空"
fi

# 验证端口
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -lt 1 || "$PORT" -gt 65535 ]]; then
    die "端口无效，请输入 1-65535 之间的数字"
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
info "[1/7] 安装基础依赖..."
pkg_install curl wget

# ==================== 步骤 2: 安装 Docker ====================
if ! command -v docker &>/dev/null; then
    info "[2/7] 安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker  >/dev/null 2>&1
    info "Docker 安装完成"
else
    info "[2/7] Docker 已安装，跳过"
fi

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
info "[3/7] 检测端口..."
check_port() {
    if ss -tlnp 2>/dev/null | grep -q ":${1} "; then
        local proc
        proc=$(ss -tlnp 2>/dev/null | grep ":${1} " | head -1 || true)
        warn "端口 $1 已被占用: $proc"
        return 1
    fi
    return 0
}

if ! check_port "$PORT"; then
    warn "端口 ${PORT} 被占用，Caddy 可能无法启动"
    read -rp "是否继续? (y/N): " CONTINUE
    [[ "${CONTINUE,,}" != "y" ]] && die "用户取消"
fi

# ==================== 步骤 4: 生成配置文件 ====================
info "[4/7] 生成配置文件..."
mkdir -p "$DEPLOY_DIR"

# --- Dockerfile (含 Cloudflare DNS 插件) ---
cat > "$DEPLOY_DIR/Dockerfile" <<'DOCKEREOF'
FROM caddy:builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare
FROM caddy:alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
DOCKEREOF

# --- Caddyfile ---
SITE_ADDR="${DOMAIN}"
[[ "$PORT" != "443" ]] && SITE_ADDR="${DOMAIN}:${PORT}"

# 邮箱可选，不填就不加 email 参数
TLS_EXTRA=""
if [[ -n "$EMAIL" ]]; then
    TLS_EXTRA="issuer acme ${EMAIL}"
fi

cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
{
    acme_dns cloudflare ${CF_TOKEN}
}

${SITE_ADDR} {
    tls {
        dns cloudflare ${CF_TOKEN}
        protocols tls1.3
        curves x25519
    }
    root * /usr/share/caddy
    file_server

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
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
CADDYEOF

# --- 生成站点文件 ---
info "生成站点文件（随机模板）..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/site-templates/generate.sh" ]]; then
    bash "$SCRIPT_DIR/site-templates/generate.sh" "$DEPLOY_DIR/site"
else
    info "下载站点模板生成器..."
    REPO_URL="https://github.com/Kiss8202/wz"
    GEN_URL="${REPO_URL}/releases/latest/download/generate.sh"
    if curl -fSL --connect-timeout 10 --max-time 60 -o /tmp/generate.sh "$GEN_URL" 2>/dev/null; then
        bash /tmp/generate.sh "$DEPLOY_DIR/site"
        rm -f /tmp/generate.sh
    else
        info "下载预生成站点包..."
        RELEASE_URL="${REPO_URL}/releases/latest/download/reality-site.tar.gz"
        if curl -fSL --connect-timeout 10 --max-time 120 -o /tmp/reality-site.tar.gz "$RELEASE_URL" 2>/dev/null; then
            tar xzf /tmp/reality-site.tar.gz -C /tmp/
            cp -r /tmp/reality-site/site "$DEPLOY_DIR/site"
            rm -rf /tmp/reality-site /tmp/reality-site.tar.gz
        else
            die "下载失败，请手动将 site-templates/ 目录放到脚本同目录"
        fi
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
    image: caddy-cloudflare:latest
    build: .
    container_name: reality-site
    ports:
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

# --- .env (保存敏感信息，不提交到 git) ---
cat > "$DEPLOY_DIR/.env" <<ENVEOF
DOMAIN=${DOMAIN}
PORT=${PORT}
CF_TOKEN=${CF_TOKEN}
ENVEOF
chmod 600 "$DEPLOY_DIR/.env"

# ==================== 步骤 5: 防扫描加固 ====================
info "[5/7] 配置防扫描规则..."

# 屏蔽已知扫描器 IP 段
info "屏蔽 Shodan/Censys 等扫描器 IP..."
SCAN_NETS=(
    "198.51.44.0/24" "71.6.165.0/24" "71.6.146.0/24" "66.240.192.0/18" "74.82.160.0/19"
    "104.248.0.0/16" "128.199.0.0/16" "138.68.0.0/16" "159.89.0.0/16"
    "162.142.148.0/24" "167.248.133.0/24" "192.35.168.0/23"
    "157.230.0.0/16" "167.71.0.0/16" "167.99.0.0/16"
    "184.105.247.0/24" "184.105.139.0/24" "216.218.185.0/24"
    "71.6.128.0/17" "89.36.128.0/18" "185.42.12.0/24"
    "35.192.0.0/12" "35.208.0.0/14"
)
for net in "${SCAN_NETS[@]}"; do
    iptables -I INPUT -s "$net" -j DROP 2>/dev/null || true
done
info "已屏蔽 ${#SCAN_NETS[@]} 个扫描器 IP 段"

# fail2ban
if ! command -v fail2ban-server &>/dev/null; then
    info "安装 fail2ban..."
    pkg_install fail2ban
fi

mkdir -p /etc/fail2ban/jail.d
SSH_LOG="/var/log/auth.log"
[[ -f /var/log/secure ]] && SSH_LOG="/var/log/secure"
SYS_LOG="/var/log/syslog"
[[ -f /var/log/messages ]] && SYS_LOG="/var/log/messages"

cat > /etc/fail2ban/jail.d/reality-site.conf << F2BEOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = ${SSH_LOG}
maxretry = 3
bantime = 3600
findtime = 600

[port-scan]
enabled = true
filter = port-scan
logpath = ${SYS_LOG}
maxretry = 5
bantime = 86400
findtime = 300
F2BEOF

cat > /etc/fail2ban/filter.d/port-scan.conf << 'F2BEOF'
[Definition]
failregex = ^.*kernel:.*DROP.*SRC=<HOST>.*DPT=\d+.*$
            ^.*kernel:.*REJECT.*SRC=<HOST>.*DPT=\d+.*$
ignoreregex =
F2BEOF

systemctl enable fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban >/dev/null 2>&1 || true

# iptables 防扫描
iptables -N SYN_FLOOD 2>/dev/null || true
iptables -F SYN_FLOOD 2>/dev/null || true
iptables -A SYN_FLOOD -p tcp --syn -m limit --limit 10/s --limit-burst 20 -j RETURN 2>/dev/null || true
iptables -A SYN_FLOOD -j DROP 2>/dev/null || true
iptables -I INPUT -p tcp --syn -j SYN_FLOOD 2>/dev/null || true
iptables -I INPUT -p tcp --syn -m connlimit --connlimit-above 30 --connlimit-mask 32 -j DROP 2>/dev/null || true
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 3 -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP 2>/dev/null || true

# 保存规则
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

# ==================== 步骤 6: 构建并启动容器 ====================
info "[6/7] 构建自定义 Caddy 镜像 (含 Cloudflare DNS 插件)..."

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "检测到旧容器，正在替换..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
fi

cd "$DEPLOY_DIR"
docker compose build 2>/dev/null || docker-compose build
docker compose up -d 2>/dev/null || docker-compose up -d

# ==================== 步骤 7: 等待证书签发 ====================
info "[7/7] 等待 SSL 证书签发 (DNS-01 验证)..."
echo -n "  "
warn "DNS-01 验证比 HTTP-01 慢，通常需要 1-3 分钟"
echo -n "  "

CERT_OK=false
for i in $(seq 1 45); do
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

    # 检查是否有错误
    if docker logs "$CONTAINER_NAME" 2>&1 | grep -qi "error.*dns"; then
        echo ""
        error "DNS-01 验证失败，请检查:"
        echo "  1. CF Token 是否有 DNS 编辑权限"
        echo "  2. 域名是否托管在 Cloudflare"
        echo "  3. 查看详细日志: docker logs $CONTAINER_NAME"
        exit 1
    fi
done
echo ""

# ==================== 最终报告 ====================
ACCESS_URL="https://${DOMAIN}"
[[ "$PORT" != "443" ]] && ACCESS_URL="https://${DOMAIN}:${PORT}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     部署结果 (NAT 容器版)                       ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "容器状态: ${GREEN}运行中${NC}"
    info "部署目录: $DEPLOY_DIR"
    info "HTTPS 端口: ${PORT}"
    info "证书验证: DNS-01 (Cloudflare API)"
    info "访问地址: ${ACCESS_URL}"

    if [[ "$CERT_OK" == "true" ]]; then
        info "SSL 证书: ${GREEN}已签发${NC}"
    else
        warn "SSL 证书: ${YELLOW}签发中，DNS-01 较慢，请稍后检查${NC}"
        echo "  查看日志: docker logs $CONTAINER_NAME"
    fi
else
    error "容器状态: ${RED}未运行${NC}"
    die "请查看日志: docker logs $CONTAINER_NAME"
fi

echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║     NAT 容器配置提醒                             ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
warn "确保 NAT 容器已映射 ${PORT} 端口到外网"
warn "Cloudflare DNS 设置:"
warn "  类型: A"
warn "  名称: ${DOMAIN%%.*}"
warn "  IP:   NAT 容器的外网映射 IP"
warn "  代理: 灰色云朵 (仅DNS，不开CDN)"
echo ""
info "SNI 伪装域名: ${DOMAIN}"
if [[ "$PORT" != "443" ]]; then
    echo ""
    info "Reality handshake 配置参考:"
    echo "  sing-box: handshake.server = \"${DOMAIN}\", handshake.server_port = 443"
    echo "  (需 443 端口由其他服务监听，或用 127.0.0.1:${PORT})"
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
echo -e "${CYAN}║     NAT 版与标准版的区别                         ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo "  证书验证: DNS-01 (不需要 80/443 端口)"
echo "  Caddy 镜像: 自定义构建 (含 Cloudflare DNS 插件)"
echo "  额外依赖: Cloudflare API Token"
echo "  证书续签: 自动 (通过 Cloudflare API)"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
