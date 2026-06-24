#!/usr/bin/env bash
# ============================================================
#  Reality SNI 伪装站点一键部署脚本
#  支持: Ubuntu / Debian / CentOS / Fedora
#  用法: bash deploy.sh [-d 域名] [-e 邮箱] [-u 卸载]
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
ACTION="install"

# ==================== 解析参数 ====================
usage() {
    cat <<EOF
${BOLD}Reality SNI 伪装站点 一键部署脚本${NC}

用法:
  bash deploy.sh -d <域名> -e <邮箱>    # 一键安装
  bash deploy.sh -u                      # 卸载

选项:
  -d  域名    你的完整域名 (例如 blog.example.com)
  -e  邮箱    用于 Let's Encrypt 证书通知
  -u          卸载已部署的站点
  -h          显示帮助
EOF
}

while getopts "d:e:uh" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
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

    docker volume rm reality-site_caddy_data >/dev/null 2>&1 || true

    info "卸载完成"
    exit 0
}

[[ "$ACTION" == "uninstall" ]] && uninstall

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

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    die "域名和邮箱不能为空"
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

PORT_OK=true
check_port 80  || PORT_OK=false
check_port 443 || PORT_OK=false

if [[ "$PORT_OK" == "false" ]]; then
    warn "检测到 80 或 443 端口被占用，Caddy 可能无法启动"
    read -rp "是否继续? (y/N): " CONTINUE
    [[ "${CONTINUE,,}" != "y" ]] && die "用户取消"
fi

# ==================== 步骤 4: 配置防火墙 ====================
info "[4/7] 配置防火墙..."
if command -v ufw &>/dev/null; then
    ufw allow 80/tcp  >/dev/null 2>&1 || true
    ufw allow 443/tcp >/dev/null 2>&1 || true
    info "UFW 已放行 80/443"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-service=http  >/dev/null 2>&1 || true
    firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
    info "firewalld 已放行 80/443"
elif command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport 80  -j ACCEPT 2>/dev/null || true
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
    info "iptables 已放行 80/443"
else
    warn "未检测到防火墙，请确保云服务商安全组已放行 80/443"
fi

# ==================== 步骤 5: 生成配置文件 ====================
info "[5/7] 生成配置文件..."
mkdir -p "$DEPLOY_DIR"

# --- Caddyfile ---
cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
${DOMAIN} {
    tls ${EMAIL} {
        protocols tls1.2 tls1.3
        curves x25519
    }
    root * /usr/share/caddy
    file_server

    # 安全头
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy no-referrer-when-downgrade
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }

    # 自定义 404
    handle_errors {
        respond "{http.error.status_code} {http.error.status_text}"
    }
}

# 拒绝未配置域名的请求（防SNI探测/防偷用）
:443 {
    tls {
        protocols tls1.2 tls1.3
    }
    abort
}

:80 {
    @notmyhost not host ${DOMAIN}
    abort @notmyhost
}
CADDYEOF

# --- index.html ---
cat > "$DEPLOY_DIR/index.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>林一的技术笔记</title>
    <meta name="description" content="林一的个人技术博客，记录Go、Kubernetes、网络协议的实践笔记">
    <meta name="author" content="林一">
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#faf9f8;color:#1e1e1e;line-height:1.6;padding:2rem 1rem}
        .container{max-width:780px;margin:0 auto;background:#fff;padding:2.5rem 2rem;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.05)}
        h1{font-size:2.2rem;font-weight:700;margin-bottom:.25rem}
        .subhead{color:#6b6b6b;font-size:1.1rem;border-bottom:2px solid #eaeaea;padding-bottom:1rem;margin-bottom:1.5rem}
        h2{font-size:1.4rem;margin:1.8rem 0 .8rem;font-weight:600}
        p{margin-bottom:1rem}
        ul{list-style:none;padding-left:0}
        ul li{background:#f4f4f4;margin-bottom:.5rem;padding:.6rem 1rem;border-radius:8px;font-size:.95rem}
        .footer{margin-top:2rem;padding-top:1.5rem;border-top:1px solid #eaeaea;color:#888;font-size:.9rem;text-align:center}
        a{color:#0066cc;text-decoration:none}
        a:hover{text-decoration:underline}
        .badge{display:inline-block;background:#eaeaea;padding:.2rem .6rem;border-radius:20px;font-size:.8rem;color:#555}
    </style>
</head>
<body>
<div class="container">
    <h1>👋 你好，我是 林一</h1>
    <div class="subhead">后端开发 · 云原生爱好者 · 独立博客</div>
    <p>欢迎来到我的技术小站。这里会记录一些关于 <strong>Go、Kubernetes、网络协议</strong> 的实践笔记。</p>
    <h2>📝 近期文章</h2>
    <ul>
        <li><span class="badge">2026-06-20</span> 在 VPS 上搭建 TLS 伪装站点的小记</li>
        <li><span class="badge">2026-06-15</span> 浅析 Cloudflare 回源证书配置</li>
        <li><span class="badge">2026-06-10</span> Hugo vs Hexo：我为什么选择 Caddy</li>
    </ul>
    <h2>📦 开源项目</h2>
    <ul>
        <li><a href="#">go-dns-proxy</a> – 轻量级 DNS 转发器 (GitHub 300+ star)</li>
        <li><a href="#">k8s-toolkit</a> – 日常运维脚本集合</li>
    </ul>
    <h2>📬 联系</h2>
    <p>✉️ <a href="mailto:linyi@example.com">linyi@example.com</a> ｜ 🐦 <a href="#">@linyi_dev</a></p>
    <div class="footer">© 2026 林一 · 自建小站 · 所有内容均为原创</div>
</div>
</body>
</html>
HTMLEOF

# --- docker-compose.yml ---
cat > "$DEPLOY_DIR/docker-compose.yml" <<'COMPOSEEOF'
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: reality-site
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./index.html:/usr/share/caddy/index.html:ro
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
COMPOSEEOF

# ==================== 步骤 6: 防扫描加固 ====================
info "[6/9] 配置防扫描规则..."

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
# 限制新连接速率（每秒不超过 30 个，突发不超过 50）
iptables -I INPUT -p tcp --syn -m connlimit --connlimit-above 20 -j DROP 2>/dev/null || true
iptables -I INPUT -p tcp --syn -m limit --limit 30/s --limit-burst 50 -j ACCEPT 2>/dev/null || true

# 只允许已建立的连接和相关连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# 允许 ICMP（ping）但限制速率
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
info "[7/9] 拉取 Caddy 镜像并启动..."

# 停止旧容器
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "检测到旧容器，正在替换..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
fi

cd "$DEPLOY_DIR"
docker compose up -d 2>/dev/null || docker-compose up -d

# ==================== 步骤 8: 等待证书签发并验证 ====================
info "[8/9] 等待 Caddy 自动签发 SSL 证书..."
echo -n "  "

CERT_OK=false
for i in $(seq 1 30); do
    echo -n "."
    sleep 2

    # 检查容器是否还在运行
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo ""
        die "容器异常退出，请查看日志: docker logs $CONTAINER_NAME"
    fi

    # 检查 443 端口是否已监听
    if docker exec "$CONTAINER_NAME" sh -c "netstat -tlnp 2>/dev/null | grep -q ':443'" 2>/dev/null; then
        CERT_OK=true
        break
    fi

    # 检查日志中是否有证书签发成功的信息
    if docker logs "$CONTAINER_NAME" 2>&1 | grep -qi "certificate obtained successfully"; then
        CERT_OK=true
        break
    fi
done
echo ""

# ==================== 最终报告 ====================
VPS_IP=$(curl -s4 --connect-timeout 3 ifconfig.me 2>/dev/null || curl -s4 --connect-timeout 3 icanhazip.com 2>/dev/null || echo "<你的VPS公网IP>")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          部署结果                                ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "容器状态: ${GREEN}运行中${NC}"
    info "部署目录: $DEPLOY_DIR"
    info "访问地址: https://${DOMAIN}"

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
info "Xray/Sing-box SNI: ${DOMAIN}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
info "常用命令:"
echo "  查看日志:   docker logs $CONTAINER_NAME"
echo "  重启服务:   cd $DEPLOY_DIR && docker compose restart"
echo "  卸载站点:   bash deploy.sh -u"
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             安全加固说明                        ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
info "已启用的安全措施:"
echo "  [1] TLS 1.3 + X25519 强制加密"
echo "  [2] SNI 过滤 - 非本域名请求直接 abort"
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
