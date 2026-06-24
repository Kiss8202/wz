#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Reality SNI 伪装站点一键部署脚本
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ---------- 检查 root ----------
if [[ $EUID -ne 0 ]]; then
    error "请使用 root 用户运行此脚本: sudo bash deploy.sh"
fi

# ---------- 收集信息 ----------
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Reality SNI 伪装站点 一键部署${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

read -rp "请输入你的域名 (例如 blog.example.com): " DOMAIN
read -rp "请输入你的邮箱 (用于 Let's Encrypt 证书通知): " EMAIL

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    error "域名和邮箱不能为空"
fi

# ---------- 安装 Docker ----------
if ! command -v docker &>/dev/null; then
    info "正在安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker && systemctl start docker
    info "Docker 安装完成"
else
    info "Docker 已安装，跳过"
fi

# ---------- 安装 Docker Compose ----------
if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
    info "正在安装 Docker Compose 插件..."
    apt-get update -y && apt-get install -y docker-compose-plugin 2>/dev/null || {
        info "通过 pip 安装 docker-compose..."
        apt-get install -y python3-pip >/dev/null 2>&1
        pip3 install docker-compose >/dev/null 2>&1
    }
fi

# ---------- 安装 Git ----------
if ! command -v git &>/dev/null; then
    info "正在安装 Git..."
    apt-get update -y && apt-get install -y git
fi

# ---------- 开放防火墙端口 ----------
info "正在配置防火墙..."
if command -v ufw &>/dev/null; then
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    info "UFW 已放行 80/443 端口"
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-service=http >/dev/null 2>&1
    firewall-cmd --permanent --add-service=https >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    info "firewalld 已放行 80/443 端口"
else
    warn "未检测到防火墙，请确保云服务商安全组已放行 80 和 443 端口"
fi

# ---------- 创建项目目录 ----------
DEPLOY_DIR="/opt/my-site"
mkdir -p "$DEPLOY_DIR"

# ---------- 生成 Caddyfile ----------
info "正在生成 Caddyfile..."
cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
${DOMAIN} {
    tls ${EMAIL}
    root * /usr/share/caddy
    file_server
}
CADDYEOF

# ---------- 生成 index.html ----------
info "正在生成伪装页面..."
cat > "$DEPLOY_DIR/index.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>林一的技术笔记</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background: #faf9f8;
            color: #1e1e1e;
            line-height: 1.6;
            padding: 2rem 1rem;
        }
        .container {
            max-width: 780px;
            margin: 0 auto;
            background: white;
            padding: 2.5rem 2rem;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.05);
        }
        h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.25rem; }
        .subhead { color: #6b6b6b; font-size: 1.1rem; border-bottom: 2px solid #eaeaea; padding-bottom: 1rem; margin-bottom: 1.5rem; }
        h2 { font-size: 1.4rem; margin: 1.8rem 0 0.8rem 0; font-weight: 600; }
        p { margin-bottom: 1rem; }
        ul { list-style: none; padding-left: 0; }
        ul li { background: #f4f4f4; margin-bottom: 0.5rem; padding: 0.6rem 1rem; border-radius: 8px; font-size: 0.95rem; }
        .footer { margin-top: 2rem; padding-top: 1.5rem; border-top: 1px solid #eaeaea; color: #888; font-size: 0.9rem; text-align: center; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .badge { display: inline-block; background: #eaeaea; padding: 0.2rem 0.6rem; border-radius: 20px; font-size: 0.8rem; color: #555; }
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

# ---------- 生成 docker-compose.yml ----------
info "正在生成 docker-compose.yml..."
cat > "$DEPLOY_DIR/docker-compose.yml" <<'COMPOSEEOF'
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: my-site
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./index.html:/usr/share/caddy/index.html:ro
      - caddy_data:/data
    restart: unless-stopped

volumes:
  caddy_data:
COMPOSEEOF

# ---------- 停止旧容器（如有） ----------
if docker ps -a --format '{{.Names}}' | grep -q '^my-site$'; then
    info "检测到旧容器，正在停止并移除..."
    docker rm -f my-site >/dev/null 2>&1
fi

# ---------- 启动容器 ----------
cd "$DEPLOY_DIR"
info "正在拉取 Caddy 镜像并启动..."
docker compose up -d 2>/dev/null || docker-compose up -d

# ---------- 等待证书签发 ----------
info "等待 Caddy 签发 SSL 证书（可能需要 30 秒）..."
sleep 10

# ---------- 验证 ----------
echo ""
echo -e "${CYAN}========================================${NC}"
if docker ps --format '{{.Names}}' | grep -q '^my-site$'; then
    info "容器运行正常"
    echo ""
    info "访问地址: https://${DOMAIN}"
    echo ""
    warn "请在 Cloudflare DNS 中添加 A 记录："
    warn "  名称: ${DOMAIN%%.*}  |  IP: $(curl -s4 ifconfig.me 2>/dev/null || echo '你的VPS公网IP')  |  代理: 灰色云朵（仅DNS）"
    echo ""
    info "Xray/Sing-box SNI 设置: ${DOMAIN}"
    echo ""
    info "查看日志: docker logs my-site"
    info "重启服务: cd ${DEPLOY_DIR} && docker compose restart"
else
    error "容器启动失败，请查看日志: docker logs my-site"
fi
echo -e "${CYAN}========================================${NC}"
