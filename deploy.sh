#!/usr/bin/env bash
# ============================================================
#  Reality SNI 伪装站点一键部署脚本
#  支持: Ubuntu / Debian / CentOS / Fedora / Rocky / Alma
#  用法:
#    bash deploy.sh -d <域名> -e <邮箱> [-r <仓库地址>]
#    bash deploy.sh -u                      # 卸载
#
#  一键远程部署:
#    bash <(curl -sL <仓库>/releases/latest/download/deploy.sh) \
#      -d blog.example.com -e you@mail.com -r <仓库地址>
# ============================================================
set -euo pipefail

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
REPO_URL=""
ACTION="install"

# ==================== 解析参数 ====================
usage() {
    cat <<EOF
${BOLD}Reality SNI 伪装站点 一键部署脚本${NC}

用法:
  bash deploy.sh -d <域名> -e <邮箱> [-r <仓库地址>]
  bash deploy.sh -u                            # 卸载

选项:
  -d  域名      你的完整域名 (例如 blog.example.com)
  -e  邮箱      用于 Let's Encrypt 证书通知
  -r  仓库地址  GitHub 仓库 URL (例如 https://github.com/user/repo)
                指定后从 Release 下载站点文件，否则本地生成
  -u            卸载已部署的站点
  -h            显示帮助
EOF
}

while getopts "d:e:r:uh" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        r) REPO_URL="$OPTARG" ;;
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

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
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

# ==================== 检查 root ====================
if [[ $EUID -ne 0 ]]; then
    die "请使用 root 用户运行: sudo bash deploy.sh"
fi

# ==================== 交互式输入 ====================
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Reality SNI 伪装站点 一键部署               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

if [[ -z "$DOMAIN" ]]; then
    read -rp "请输入你的域名 (例如 blog.example.com): " DOMAIN
fi
if [[ -z "$EMAIL" ]]; then
    read -rp "请输入你的邮箱 (用于 Let's Encrypt 通知): " EMAIL
fi

[[ -z "$DOMAIN" || -z "$EMAIL" ]] && die "域名和邮箱不能为空"

# ==================== 检测操作系统 ====================
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        OS_ID="centos"
    else
        OS_ID="unknown"
    fi
}
detect_os
info "检测到系统: $OS_ID"

pkg_install() {
    case "$OS_ID" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1
            apt-get install -y "$@" >/dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y "$@" >/dev/null 2>&1 || dnf install -y "$@" >/dev/null 2>&1
            ;;
        *) die "不支持的系统: $OS_ID" ;;
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

# ==================== 步骤 3: 检测端口 ====================
info "[3/8] 检测端口..."
check_port() {
    if ss -tlnp 2>/dev/null | grep -q ":${1} "; then
        warn "端口 $1 已被占用"
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
info "[4/8] 配置防火墙..."
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

# ==================== 步骤 5: 获取站点文件 ====================
info "[5/8] 获取站点文件..."
mkdir -p "$DEPLOY_DIR"

if [[ -n "$REPO_URL" ]]; then
    # 从 GitHub Release 下载压缩包
    # 将 https://github.com/user/repo 转换为 API 地址
    REPO_API="${REPO_URL%.git}"
    REPO_API="${REPO_API#https://github.com/}"
    RELEASE_URL="https://github.com/${REPO_API}/releases/latest/download/reality-site.tar.gz"

    info "从 Release 下载站点文件..."
    info "下载地址: $RELEASE_URL"

    if ! curl -fSL --connect-timeout 10 --max-time 120 -o /tmp/reality-site.tar.gz "$RELEASE_URL"; then
        die "下载 Release 失败，请检查仓库地址是否正确，以及是否已创建 Release"
    fi

    info "解压站点文件..."
    tar xzf /tmp/reality-site.tar.gz -C /tmp/

    # 复制文件到部署目录
    cp -r /tmp/reality-site/site/ "$DEPLOY_DIR/site/"
    cp /tmp/reality-site/Caddyfile "$DEPLOY_DIR/Caddyfile"
    cp /tmp/reality-site/docker-compose.yml "$DEPLOY_DIR/docker-compose.yml"

    # 清理临时文件
    rm -rf /tmp/reality-site /tmp/reality-site.tar.gz

    info "站点文件下载完成"
else
    # 本地生成站点文件
    info "未指定仓库地址，本地生成站点文件..."
    generate_site
fi

# ==================== 步骤 6: 生成 Caddyfile ====================
info "[6/8] 生成 Caddyfile..."
cat > "$DEPLOY_DIR/Caddyfile" <<CADDYEOF
${DOMAIN} {
    tls ${EMAIL}
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
CADDYEOF

# ==================== 步骤 7: 启动容器 ====================
info "[7/8] 拉取 Caddy 镜像并启动..."

# 停止旧容器
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
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

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        echo ""
        die "容器异常退出，请查看日志: docker logs $CONTAINER_NAME"
    fi

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
echo -e "${CYAN}║               部署结果                          ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
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
echo -e "${CYAN}║             DNS 配置提醒                        ║${NC}"
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
echo "  更新站点:   重新运行部署脚本即可"
echo "  卸载站点:   bash deploy.sh -u"

# ==================== 生成站点文件的函数 ====================
generate_site() {
    local SITE_DIR="$DEPLOY_DIR/site"
    mkdir -p "$SITE_DIR"/{assets/css,about,posts/{tls-camouflage,cloudflare-origin,hugo-vs-hexo},categories,tags,links}

    # ---------- CSS ----------
    cat > "$SITE_DIR/assets/css/style.css" << 'CSSEOF'
:root{--color-primary:#2d5af0;--color-text:#1a1a2e;--color-text-secondary:#555770;--color-text-tertiary:#8b8fa3;--color-bg:#f8f9fa;--color-bg-card:#fff;--color-border:#e8e8ed;--color-code-bg:#f1f3f5;--color-link:#2d5af0;--color-link-hover:#1a3fb5;--color-tag-bg:#eef1ff;--color-tag-text:#4a6cf7;--shadow-sm:0 1px 3px rgba(0,0,0,.04);--shadow-md:0 4px 12px rgba(0,0,0,.06);--radius:8px;--max-width:800px}
*,*::before,*::after{margin:0;padding:0;box-sizing:border-box}
html{font-size:16px;scroll-behavior:smooth;-webkit-text-size-adjust:100%}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'PingFang SC','Hiragino Sans GB','Microsoft YaHei','Helvetica Neue',Arial,sans-serif;background:var(--color-bg);color:var(--color-text);line-height:1.8;-webkit-font-smoothing:antialiased}
a{color:var(--color-link);text-decoration:none;transition:color .2s}
a:hover{color:var(--color-link-hover);text-decoration:underline}
img{max-width:100%;height:auto}
.container{max-width:var(--max-width);margin:0 auto;padding:0 1.25rem}
.site-header{background:var(--color-bg-card);border-bottom:1px solid var(--color-border);position:sticky;top:0;z-index:100;backdrop-filter:blur(12px);background:rgba(255,255,255,.92)}
.site-header .container{display:flex;align-items:center;justify-content:space-between;height:60px}
.site-title{font-size:1.2rem;font-weight:700;color:var(--color-text);letter-spacing:-.02em}
.site-title:hover{color:var(--color-primary);text-decoration:none}
.site-nav{display:flex;gap:1.5rem}
.site-nav a{font-size:.9rem;color:var(--color-text-secondary);position:relative;padding:.25rem 0}
.site-nav a:hover,.site-nav a.active{color:var(--color-primary);text-decoration:none}
.site-nav a.active::after{content:'';position:absolute;bottom:-2px;left:0;right:0;height:2px;background:var(--color-primary);border-radius:1px}
.main-content{padding:2.5rem 0 4rem;min-height:calc(100vh - 60px - 120px)}
.post-card{background:var(--color-bg-card);border-radius:var(--radius);padding:1.75rem;margin-bottom:1rem;box-shadow:var(--shadow-sm);transition:box-shadow .2s,transform .2s;border:1px solid var(--color-border)}
.post-card:hover{box-shadow:var(--shadow-md);transform:translateY(-1px)}
.post-card-title{font-size:1.25rem;font-weight:600;line-height:1.4;margin-bottom:.5rem}
.post-card-title a{color:var(--color-text)}
.post-card-title a:hover{color:var(--color-primary);text-decoration:none}
.post-card-meta{display:flex;align-items:center;gap:1rem;font-size:.85rem;color:var(--color-text-tertiary);margin-bottom:.75rem}
.post-card-summary{font-size:.95rem;color:var(--color-text-secondary);line-height:1.7}
.post-card-tags{display:flex;gap:.5rem;margin-top:.75rem;flex-wrap:wrap}
.tag{display:inline-block;background:var(--color-tag-bg);color:var(--color-tag-text);font-size:.78rem;padding:.15rem .6rem;border-radius:20px;transition:background .2s}
.tag:hover{background:#dce3ff;text-decoration:none;color:var(--color-tag-text)}
.article-header{margin-bottom:2rem}
.article-title{font-size:1.85rem;font-weight:700;line-height:1.35;letter-spacing:-.02em;margin-bottom:.75rem}
.article-meta{display:flex;align-items:center;gap:1rem;font-size:.88rem;color:var(--color-text-tertiary);padding-bottom:1.25rem;border-bottom:1px solid var(--color-border)}
.article-content{font-size:1rem;line-height:1.9;color:var(--color-text-secondary)}
.article-content h2{font-size:1.4rem;font-weight:600;color:var(--color-text);margin:2rem 0 1rem;padding-top:.5rem}
.article-content h3{font-size:1.15rem;font-weight:600;color:var(--color-text);margin:1.5rem 0 .75rem}
.article-content p{margin-bottom:1.15rem}
.article-content ul,.article-content ol{margin-bottom:1.15rem;padding-left:1.5rem}
.article-content li{margin-bottom:.35rem}
.article-content code{font-family:'SF Mono','Fira Code',Consolas,monospace;background:var(--color-code-bg);padding:.15rem .4rem;border-radius:4px;font-size:.88em;color:#c7254e}
.article-content pre{background:#282c34;color:#abb2bf;border-radius:var(--radius);padding:1.25rem;overflow-x:auto;margin-bottom:1.25rem;line-height:1.6}
.article-content pre code{background:none;color:inherit;padding:0;font-size:.88rem}
.article-content blockquote{border-left:3px solid var(--color-primary);padding:.5rem 1rem;margin:1.25rem 0;background:var(--color-code-bg);border-radius:0 var(--radius) var(--radius) 0;color:var(--color-text-secondary)}
.article-content blockquote p{margin-bottom:0}
.article-content strong{color:var(--color-text);font-weight:600}
.article-content hr{border:none;border-top:1px solid var(--color-border);margin:2rem 0}
.article-content table{width:100%;border-collapse:collapse;margin-bottom:1.25rem;font-size:.92rem}
.article-content th,.article-content td{border:1px solid var(--color-border);padding:.6rem .8rem;text-align:left}
.article-content th{background:var(--color-code-bg);font-weight:600}
.section-title{font-size:1.5rem;font-weight:700;margin-bottom:1.5rem;padding-bottom:.75rem;border-bottom:2px solid var(--color-border)}
.archive-year{font-size:1.1rem;font-weight:600;color:var(--color-text-tertiary);margin:1.5rem 0 .75rem}
.archive-item{display:flex;align-items:baseline;gap:1rem;padding:.5rem 0;border-bottom:1px dashed var(--color-border)}
.archive-item:last-child{border-bottom:none}
.archive-date{font-size:.85rem;color:var(--color-text-tertiary);white-space:nowrap;min-width:80px}
.archive-item a{color:var(--color-text);font-size:.95rem}
.archive-item a:hover{color:var(--color-primary)}
.cloud-list{display:flex;flex-wrap:wrap;gap:.6rem}
.cloud-item{display:inline-flex;align-items:center;gap:.3rem;background:var(--color-bg-card);border:1px solid var(--color-border);padding:.4rem .9rem;border-radius:20px;font-size:.9rem;color:var(--color-text-secondary);transition:all .2s}
.cloud-item:hover{border-color:var(--color-primary);color:var(--color-primary);text-decoration:none}
.cloud-count{font-size:.75rem;background:var(--color-code-bg);padding:.1rem .4rem;border-radius:10px;color:var(--color-text-tertiary)}
.link-card{display:flex;align-items:center;gap:1rem;background:var(--color-bg-card);border:1px solid var(--color-border);border-radius:var(--radius);padding:1rem 1.25rem;margin-bottom:.75rem;transition:box-shadow .2s}
.link-card:hover{box-shadow:var(--shadow-md);text-decoration:none}
.link-avatar{width:48px;height:48px;border-radius:50%;background:var(--color-code-bg);display:flex;align-items:center;justify-content:center;font-size:1.2rem;flex-shrink:0}
.link-info h3{font-size:.95rem;font-weight:600;color:var(--color-text);margin-bottom:.15rem}
.link-info p{font-size:.82rem;color:var(--color-text-tertiary);margin:0}
.about-content{background:var(--color-bg-card);border:1px solid var(--color-border);border-radius:var(--radius);padding:2rem}
.about-content h2{font-size:1.2rem;margin-bottom:.75rem;color:var(--color-text)}
.about-content p{margin-bottom:1rem;color:var(--color-text-secondary)}
.about-content ul{padding-left:1.25rem;margin-bottom:1rem;color:var(--color-text-secondary)}
.about-content li{margin-bottom:.35rem}
.not-found{text-align:center;padding:4rem 0}
.not-found h1{font-size:6rem;font-weight:800;color:var(--color-border);line-height:1;margin-bottom:1rem}
.not-found p{color:var(--color-text-tertiary);margin-bottom:1.5rem}
.not-found a{display:inline-block;background:var(--color-primary);color:#fff;padding:.6rem 1.5rem;border-radius:var(--radius);font-size:.9rem;transition:background .2s}
.not-found a:hover{background:var(--color-link-hover);text-decoration:none;color:#fff}
.site-footer{border-top:1px solid var(--color-border);padding:1.5rem 0;text-align:center;font-size:.82rem;color:var(--color-text-tertiary);background:var(--color-bg-card)}
.site-footer p{margin-bottom:.25rem}
.site-footer a{color:var(--color-text-tertiary)}
.site-footer a:hover{color:var(--color-primary)}
@media(max-width:640px){.site-header .container{flex-direction:column;height:auto;padding:.75rem 1rem;gap:.5rem}.site-nav{gap:1rem;flex-wrap:wrap;justify-content:center}.article-title{font-size:1.4rem}.post-card{padding:1.25rem}.archive-item{flex-direction:column;gap:.15rem}}
CSSEOF

    # ---------- Favicon ----------
    cat > "$SITE_DIR/assets/favicon.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#2d5af0"/><text x="16" y="22" text-anchor="middle" font-family="sans-serif" font-size="18" font-weight="bold" fill="white">林</text></svg>
SVGEOF

    # ---------- robots.txt ----------
    sed "s|__DOMAIN__|${DOMAIN}|g" > "$SITE_DIR/robots.txt" << 'ROBOTEOF'
User-agent: *
Allow: /
Sitemap: https://__DOMAIN__/sitemap.xml
ROBOTEOF

    # ---------- sitemap.xml ----------
    sed "s|__DOMAIN__|${DOMAIN}|g" > "$SITE_DIR/sitemap.xml" << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://__DOMAIN__/</loc><lastmod>2026-06-20</lastmod><changefreq>weekly</changefreq><priority>1.0</priority></url>
  <url><loc>https://__DOMAIN__/about/</loc><lastmod>2026-06-01</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>
  <url><loc>https://__DOMAIN__/posts/</loc><lastmod>2026-06-20</lastmod><changefreq>weekly</changefreq><priority>0.9</priority></url>
  <url><loc>https://__DOMAIN__/posts/tls-camouflage/</loc><lastmod>2026-06-20</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>
  <url><loc>https://__DOMAIN__/posts/cloudflare-origin/</loc><lastmod>2026-06-15</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>
  <url><loc>https://__DOMAIN__/posts/hugo-vs-hexo/</loc><lastmod>2026-06-10</lastmod><changefreq>monthly</changefreq><priority>0.7</priority></url>
  <url><loc>https://__DOMAIN__/categories/</loc><lastmod>2026-06-20</lastmod><changefreq>weekly</changefreq><priority>0.6</priority></url>
  <url><loc>https://__DOMAIN__/tags/</loc><lastmod>2026-06-20</lastmod><changefreq>weekly</changefreq><priority>0.6</priority></url>
  <url><loc>https://__DOMAIN__/links/</loc><lastmod>2026-06-01</lastmod><changefreq>monthly</changefreq><priority>0.5</priority></url>
</urlset>
XMLEOF

    # ---------- atom.xml ----------
    sed "s|__DOMAIN__|${DOMAIN}|g" > "$SITE_DIR/atom.xml" << 'ATOMEOF'
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>林一的技术笔记</title>
  <subtitle>专注Go、Kubernetes、网络协议的实践笔记与分享</subtitle>
  <link href="https://__DOMAIN__/" rel="alternate"/>
  <link href="https://__DOMAIN__/atom.xml" rel="self"/>
  <id>https://__DOMAIN__/</id>
  <updated>2026-06-20T00:00:00+08:00</updated>
  <author><name>林一</name><email>linyi@example.com</email><uri>https://github.com/linyi-dev</uri></author>
  <generator uri="https://gohugo.io/" version="0.130.0">Hugo</generator>
  <entry>
    <title>在 VPS 上搭建 TLS 伪装站点的小记</title>
    <link href="https://__DOMAIN__/posts/tls-camouflage/" rel="alternate"/>
    <id>https://__DOMAIN__/posts/tls-camouflage/</id>
    <published>2026-06-20T00:00:00+08:00</published>
    <updated>2026-06-20T00:00:00+08:00</updated>
    <summary>记录使用 Caddy 在 VPS 上搭建 TLS 站点的完整过程。</summary>
    <category term="技术"/><category term="TLS"/><category term="Caddy"/><category term="VPS"/>
  </entry>
  <entry>
    <title>浅析 Cloudflare 回源证书配置</title>
    <link href="https://__DOMAIN__/posts/cloudflare-origin/" rel="alternate"/>
    <id>https://__DOMAIN__/posts/cloudflare-origin/</id>
    <published>2026-06-15T00:00:00+08:00</published>
    <updated>2026-06-15T00:00:00+08:00</updated>
    <summary>详解 Cloudflare 回源证书的配置流程。</summary>
    <category term="技术"/><category term="Cloudflare"/><category term="SSL"/><category term="Nginx"/>
  </entry>
  <entry>
    <title>Hugo vs Hexo：我为什么选择 Caddy 作为静态站点服务器</title>
    <link href="https://__DOMAIN__/posts/hugo-vs-hexo/" rel="alternate"/>
    <id>https://__DOMAIN__/posts/hugo-vs-hexo/</id>
    <published>2026-06-10T00:00:00+08:00</published>
    <updated>2026-06-10T00:00:00+08:00</updated>
    <summary>从 Hexo 迁移到 Hugo 后的部署方案对比。</summary>
    <category term="技术"/><category term="Hugo"/><category term="Caddy"/><category term="Docker"/>
  </entry>
</feed>
ATOMEOF

    # ---------- docker-compose.yml ----------
    cat > "$DEPLOY_DIR/docker-compose.yml" << 'COMPOSEEOF'
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
      - ./site:/usr/share/caddy:ro
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped
volumes:
  caddy_data:
  caddy_config:
COMPOSEEOF

    # ---------- HTML 页面 ----------
    _nav='<a href="/">首页</a> <a href="/about/">关于</a> <a href="/posts/">归档</a> <a href="/categories/">分类</a> <a href="/tags/">标签</a> <a href="/links/">友链</a>'
    _footer='<p>© 2024–2026 林一 · 自建小站 · 所有内容均为原创</p><p>Powered by <a href="https://gohugo.io/" target="_blank" rel="noopener">Hugo</a> & <a href="https://caddyserver.com/" target="_blank" rel="noopener">Caddy</a></p>'

    cat > "$SITE_DIR/index.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>林一的技术笔记</title><meta name="description" content="林一的个人技术博客，专注Go、Kubernetes、网络协议的实践笔记与分享"><meta property="og:title" content="林一的技术笔记"><meta property="og:type" content="website"><link rel="canonical" href="/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="alternate" type="application/atom+xml" title="林一的技术笔记" href="/atom.xml"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><article class="post-card"><h2 class="post-card-title"><a href="/posts/tls-camouflage/">在 VPS 上搭建 TLS 伪装站点的小记</a></h2><div class="post-card-meta"><time datetime="2026-06-20">2026-06-20</time><span>·</span><span>约 8 分钟</span></div><p class="post-card-summary">最近在研究 TLS 协议的 SNI 扩展机制时，发现通过合理配置 Caddy，可以让服务器在 TLS 握手阶段返回与域名匹配的合法证书。本文记录了使用 Caddy 自动签发 Let's Encrypt 证书并配置静态站点的完整过程。</p><div class="post-card-tags"><a href="/tags/tls/" class="tag">TLS</a><a href="/tags/caddy/" class="tag">Caddy</a><a href="/tags/vps/" class="tag">VPS</a></div></article><article class="post-card"><h2 class="post-card-title"><a href="/posts/cloudflare-origin/">浅析 Cloudflare 回源证书配置</a></h2><div class="post-card-meta"><time datetime="2026-06-15">2026-06-15</time><span>·</span><span>约 6 分钟</span></div><p class="post-card-summary">Cloudflare 的回源证书是保障 CDN 到源站通信安全的重要机制。本文从证书签发、Nginx 配置到 Cloudflare 控制台设置，逐步演示完整配置流程。</p><div class="post-card-tags"><a href="/tags/cloudflare/" class="tag">Cloudflare</a><a href="/tags/ssl/" class="tag">SSL</a><a href="/tags/nginx/" class="tag">Nginx</a></div></article><article class="post-card"><h2 class="post-card-title"><a href="/posts/hugo-vs-hexo/">Hugo vs Hexo：我为什么选择 Caddy 作为静态站点服务器</a></h2><div class="post-card-meta"><time datetime="2026-06-10">2026-06-10</time><span>·</span><span>约 5 分钟</span></div><p class="post-card-summary">从 Hexo 迁移到 Hugo 后，部署方案也需要同步更新。在对比了 Nginx、Caddy 和 Apache 后，我最终选择了 Caddy——自动 HTTPS、极简配置文件、Docker 一键部署。</p><div class="post-card-tags"><a href="/tags/hugo/" class="tag">Hugo</a><a href="/tags/caddy/" class="tag">Caddy</a><a href="/tags/docker/" class="tag">Docker</a></div></article></div></main><footer class="site-footer"><div class="container">${_footer}</div></footer></body></html>
HTMLEOF

    cat > "$SITE_DIR/404.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>404 页面未找到 | 林一的技术笔记</title><meta name="robots" content="noindex,nofollow"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><div class="not-found"><h1>404</h1><p>抱歉，你访问的页面不存在或已被移除</p><a href="/">返回首页</a></div></div></main><footer class="site-footer"><div class="container"><p>© 2024–2026 林一 · 自建小站</p></div></footer></body></html>
HTMLEOF

    cat > "$SITE_DIR/about/index.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>关于 | 林一的技术笔记</title><meta name="description" content="关于林一 - 后端开发工程师，专注Go、Kubernetes与云原生技术"><link rel="canonical" href="/about/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><h1 class="section-title">关于我</h1><div class="about-content"><h2>👋 你好，我是林一</h2><p>一名后端开发工程师，目前在杭州工作。日常主要使用 Go 语言开发微服务，对 Kubernetes、容器化和网络协议有浓厚兴趣。</p><h2>技术栈</h2><ul><li><strong>语言：</strong>Go、Python、Shell</li><li><strong>框架：</strong>Gin、gRPC、Echo</li><li><strong>运维：</strong>Kubernetes、Docker、Terraform</li><li><strong>数据库：</strong>PostgreSQL、Redis、etcd</li><li><strong>网络：</strong>TLS/SSL、HTTP/2、gRPC、DNS</li></ul><h2>关于本站</h2><p>本站使用 <a href="https://gohugo.io/" target="_blank" rel="noopener">Hugo</a> 生成静态页面，由 <a href="https://caddyserver.com/" target="_blank" rel="noopener">Caddy</a> 提供服务，部署在日本 VPS 上。所有文章均为原创，转载请注明出处。</p><h2>联系方式</h2><ul><li>邮箱：<a href="mailto:linyi@example.com">linyi@example.com</a></li><li>GitHub：<a href="https://github.com/linyi-dev" target="_blank" rel="noopener">linyi-dev</a></li><li>Twitter：<a href="https://twitter.com/linyi_dev" target="_blank" rel="noopener">@linyi_dev</a></li></ul></div></div></main><footer class="site-footer"><div class="container">${_footer}</div></footer></body></html>
HTMLEOF

    cat > "$SITE_DIR/posts/index.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>文章归档 | 林一的技术笔记</title><link rel="canonical" href="/posts/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><h1 class="section-title">文章归档</h1><div class="archive-year">2026</div><div class="archive-item"><span class="archive-date">06-20</span><a href="/posts/tls-camouflage/">在 VPS 上搭建 TLS 伪装站点的小记</a></div><div class="archive-item"><span class="archive-date">06-15</span><a href="/posts/cloudflare-origin/">浅析 Cloudflare 回源证书配置</a></div><div class="archive-item"><span class="archive-date">06-10</span><a href="/posts/hugo-vs-hexo/">Hugo vs Hexo：我为什么选择 Caddy 作为静态站点服务器</a></div></div></main><footer class="site-footer"><div class="container">${_footer}</div></footer></body></html>
HTMLEOF

    cat > "$SITE_DIR/categories/index.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>分类 | 林一的技术笔记</title><link rel="canonical" href="/categories/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><h1 class="section-title">分类</h1><div class="cloud-list"><a href="#技术" class="cloud-item">技术 <span class="cloud-count">3</span></a></div><h2 id="技术" style="margin-top:2rem;font-size:1.2rem;color:var(--color-text-secondary)">技术</h2><div class="archive-item"><span class="archive-date">06-20</span><a href="/posts/tls-camouflage/">在 VPS 上搭建 TLS 伪装站点的小记</a></div><div class="archive-item"><span class="archive-date">06-15</span><a href="/posts/cloudflare-origin/">浅析 Cloudflare 回源证书配置</a></div><div class="archive-item"><span class="archive-date">06-10</span><a href="/posts/hugo-vs-hexo/">Hugo vs Hexo：我为什么选择 Caddy 作为静态站点服务器</a></div></div></main><footer class="site-footer"><div class="container">${_footer}</div></footer></body></html>
HTMLEOF

    cat > "$SITE_DIR/tags/index.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>标签 | 林一的技术笔记</title><link rel="canonical" href="/tags/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><h1 class="section-title">标签</h1><div class="cloud-list"><a class="cloud-item">Caddy <span class="cloud-count">2</span></a><a class="cloud-item">Cloudflare <span class="cloud-count">1</span></a><a class="cloud-item">Docker <span class="cloud-count">1</span></a><a class="cloud-item">Hugo <span class="cloud-count">1</span></a><a class="cloud-item">Nginx <span class="cloud-count">1</span></a><a class="cloud-item">SSL <span class="cloud-count">1</span></a><a class="cloud-item">TLS <span class="cloud-count">1</span></a><a class="cloud-item">VPS <span class="cloud-count">1</span></a></div></div></main><footer class="site-footer"><div class="container">${_footer}</div></footer></body></html>
HTMLEOF

    cat > "$SITE_DIR/links/index.html" << HTMLEOF
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>友情链接 | 林一的技术笔记</title><link rel="canonical" href="/links/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav">${_nav}</nav></div></header><main class="main-content"><div class="container"><h1 class="section-title">友情链接</h1><a href="https://lruihao.cn/" target="_blank" rel="noopener" class="link-card"><div class="link-avatar">L</div><div class="link-info"><h3>LRUIHAO's Blog</h3><p>专注前端与全栈开发的技术博客</p></div></a><a href="https://www.ruanyifeng.com/blog/" target="_blank" rel="noopener" class="link-card"><div class="link-avatar">阮</div><div class="link-info"><h3>阮一峰的网络日志</h3><p>互联网、科技与人文的思考</p></div></a><a href="https://fly.io/blog/" target="_blank" rel="noopener" class="link-card"><div class="link-avatar">F</div><div class="link-info"><h3>Fly.io Blog</h3><p>边缘计算与容器化部署实践</p></div></a><a href="https://blog.cloudflare.com/" target="_blank" rel="noopener" class="link-card"><div class="link-avatar">CF</div><div class="link-info"><h3>Cloudflare Blog</h3><p>网络基础设施与安全前沿</p></div></a><div class="about-content" style="margin-top:2rem"><h2>申请友链</h2><p>如果你也有技术博客，欢迎交换友链。请通过邮件 <a href="mailto:linyi@example.com">linyi@example.com</a> 联系我。</p></div></div></main><footer class="site-footer"><div class="container">${_footer}</div></footer></body></html>
HTMLEOF

    # Blog posts
    mkdir -p "$SITE_DIR/posts"/{tls-camouflage,cloudflare-origin,hugo-vs-hexo}

    cat > "$SITE_DIR/posts/tls-camouflage/index.html" << 'POSTEOF'
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>在 VPS 上搭建 TLS 伪装站点的小记 | 林一的技术笔记</title><meta name="description" content="记录使用 Caddy 在 VPS 上搭建 TLS 站点的完整过程"><meta property="og:type" content="article"><meta property="article:published_time" content="2026-06-20"><link rel="canonical" href="/posts/tls-camouflage/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav"><a href="/">首页</a><a href="/about/">关于</a><a href="/posts/">归档</a><a href="/categories/">分类</a><a href="/tags/">标签</a><a href="/links/">友链</a></nav></div></header><main class="main-content"><div class="container"><article><div class="article-header"><h1 class="article-title">在 VPS 上搭建 TLS 伪装站点的小记</h1><div class="article-meta"><time datetime="2026-06-20">2026-06-20</time><span>·</span><span>约 8 分钟</span></div></div><div class="article-content"><p>最近在研究 TLS 协议的 SNI（Server Name Indication）扩展机制时，产生了一个想法：能不能在自己的 VPS 上搭建一个拥有合法 TLS 证书的站点，让外部看起来就是一个普通的个人博客？</p><p>经过几天的折腾，我使用 Caddy + Docker 的方案完成了搭建。本文记录完整过程，供有同样需求的朋友参考。</p><h2>为什么选择 Caddy</h2><p>传统的方案是用 Nginx + Certbot 手动申请 Let's Encrypt 证书，但 Certbot 需要定期续签，配置也比较繁琐。Caddy 的最大优势是<strong>自动 HTTPS</strong>——它内置了 ACME 客户端，会在启动时自动向 Let's Encrypt 申请证书，并在证书即将过期时自动续签，完全不需要人工干预。</p><h2>环境准备</h2><p>我使用的是一台日本 VPS，系统为 Ubuntu 22.04。你需要准备：</p><ul><li>一个域名（建议使用子域名，如 <code>blog.example.com</code>）</li><li>一台有公网 IP 的 VPS</li><li>已安装 Docker 和 Docker Compose</li></ul><h2>DNS 配置</h2><p>在域名 DNS 管理处添加一条 A 记录，将子域名指向 VPS 的公网 IP。如果你使用 Cloudflare 管理 DNS，<strong>请确保代理状态为"仅 DNS"（灰色云朵）</strong>，否则流量会经过 Cloudflare CDN，Caddy 无法完成 ACME 验证。</p><h2>Caddy 配置文件</h2><p>Caddy 的配置文件叫 <code>Caddyfile</code>，语法非常简洁：</p><pre><code>blog.example.com {
    tls your-email@example.com
    root * /usr/share/caddy
    file_server
}</code></pre><h2>Docker Compose 部署</h2><p>使用 Docker 部署是最省心的方式：</p><pre><code>version: '3.8'
services:
  caddy:
    image: caddy:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./site:/usr/share/caddy:ro
      - caddy_data:/data
    restart: unless-stopped</code></pre><p>启动后，Caddy 会自动完成证书申请、HTTPS 启用和 HTTP 跳转配置。</p><h2>验证结果</h2><p>容器启动后，可以通过以下命令查看日志：</p><pre><code>docker logs my-site 2>&1 | grep certificate</code></pre><p>如果看到 <code>certificate obtained successfully</code> 字样，说明一切正常。</p><h2>常见问题</h2><h3>证书签发失败</h3><p>最常见的原因是 80 端口不可达。请检查防火墙、安全组和 DNS 配置。</p><h3>端口被占用</h3><p>如果 VPS 上已经运行了 Nginx 或 Apache，80/443 端口会被占用。你需要先停止这些服务。</p><hr><p>整个搭建过程不到 10 分钟，Caddy 的自动 HTTPS 功能确实大大简化了 TLS 站点的部署流程。如果你也有类似需求，强烈推荐试试这个方案。</p></div><div class="post-card-tags" style="margin-top:2rem;padding-top:1.5rem;border-top:1px solid var(--color-border)"><a href="/tags/tls/" class="tag">TLS</a><a href="/tags/caddy/" class="tag">Caddy</a><a href="/tags/vps/" class="tag">VPS</a></div></article></div></main><footer class="site-footer"><div class="container"><p>© 2024–2026 林一 · 自建小站 · 所有内容均为原创</p><p>Powered by <a href="https://gohugo.io/" target="_blank" rel="noopener">Hugo</a> & <a href="https://caddyserver.com/" target="_blank" rel="noopener">Caddy</a></p></div></footer></body></html>
POSTEOF

    cat > "$SITE_DIR/posts/cloudflare-origin/index.html" << 'POSTEOF'
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>浅析 Cloudflare 回源证书配置 | 林一的技术笔记</title><meta name="description" content="详解 Cloudflare 回源证书的配置流程"><meta property="og:type" content="article"><meta property="article:published_time" content="2026-06-15"><link rel="canonical" href="/posts/cloudflare-origin/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav"><a href="/">首页</a><a href="/about/">关于</a><a href="/posts/">归档</a><a href="/categories/">分类</a><a href="/tags/">标签</a><a href="/links/">友链</a></nav></div></header><main class="main-content"><div class="container"><article><div class="article-header"><h1 class="article-title">浅析 Cloudflare 回源证书配置</h1><div class="article-meta"><time datetime="2026-06-15">2026-06-15</time><span>·</span><span>约 6 分钟</span></div></div><div class="article-content"><p>当你的网站通过 Cloudflare CDN 加速时，用户到 Cloudflare 的连接是加密的，但 Cloudflare 到你源站的连接是否加密，取决于你的 SSL/TLS 模式设置。本文重点介绍 <strong>Full (Strict)</strong> 模式下的回源证书配置。</p><h2>Cloudflare SSL/TLS 模式对比</h2><table><thead><tr><th>模式</th><th>用户→CF</th><th>CF→源站</th><th>证书要求</th></tr></thead><tbody><tr><td>Flexible</td><td>HTTPS</td><td>HTTP</td><td>无</td></tr><tr><td>Full</td><td>HTTPS</td><td>HTTPS</td><td>有证书即可</td></tr><tr><td>Full (Strict)</td><td>HTTPS</td><td>HTTPS</td><td>受信任证书</td></tr></tbody></table><p><strong>强烈建议使用 Full (Strict) 模式</strong>，这是唯一能保证端到端加密的选项。</p><h2>回源证书方案选择</h2><ol><li><strong>Cloudflare Origin CA Certificate</strong> — 免费，有效期最长 15 年，仅被 Cloudflare 信任</li><li><strong>Let's Encrypt 证书</strong> — 公开信任，有效期 90 天，需自动续签</li></ol><h2>配置步骤</h2><h3>1. 签发 Origin CA 证书</h3><p>登录 Cloudflare 控制台，进入 <code>SSL/TLS → Origin Server</code>，点击 <code>Create Certificate</code>。</p><h3>2. 在源站配置证书</h3><p>Nginx 配置示例：</p><pre><code>server {
    listen 443 ssl http2;
    server_name blog.example.com;
    ssl_certificate     /etc/ssl/certs/cloudflare-origin.pem;
    ssl_certificate_key /etc/ssl/private/cloudflare-origin.key;
    root /var/www/blog;
}</code></pre><h3>3. 设置 SSL 模式为 Full (Strict)</h3><p>在 Cloudflare 控制台的 <code>SSL/TLS → Overview</code> 中切换模式。</p><h2>常见问题</h2><h3>ERR_TOO_MANY_REDIRECTS</h3><p>通常是因为 SSL 模式设为 Flexible，而源站又配置了 HTTP→HTTPS 跳转。解决方法是将 SSL 模式改为 Full 或 Full (Strict)。</p><h3>525 SSL Handshake Failed</h3><p>检查源站 443 端口、证书私钥匹配和证书有效期。</p><hr><p>回源证书的配置并不复杂，但选择正确的模式和证书类型很重要。对于大多数场景，Full (Strict) + Origin CA Certificate 是最佳组合。</p></div><div class="post-card-tags" style="margin-top:2rem;padding-top:1.5rem;border-top:1px solid var(--color-border)"><a href="/tags/cloudflare/" class="tag">Cloudflare</a><a href="/tags/ssl/" class="tag">SSL</a><a href="/tags/nginx/" class="tag">Nginx</a></div></article></div></main><footer class="site-footer"><div class="container"><p>© 2024–2026 林一 · 自建小站 · 所有内容均为原创</p><p>Powered by <a href="https://gohugo.io/" target="_blank" rel="noopener">Hugo</a> & <a href="https://caddyserver.com/" target="_blank" rel="noopener">Caddy</a></p></div></footer></body></html>
POSTEOF

    cat > "$SITE_DIR/posts/hugo-vs-hexo/index.html" << 'POSTEOF'
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Hugo vs Hexo：我为什么选择 Caddy 作为静态站点服务器 | 林一的技术笔记</title><meta name="description" content="从 Hexo 迁移到 Hugo 后的部署方案对比"><meta property="og:type" content="article"><meta property="article:published_time" content="2026-06-10"><link rel="canonical" href="/posts/hugo-vs-hexo/"><link rel="stylesheet" href="/assets/css/style.css"><link rel="icon" type="image/svg+xml" href="/assets/favicon.svg"></head><body><header class="site-header"><div class="container"><a href="/" class="site-title">林一的技术笔记</a><nav class="site-nav"><a href="/">首页</a><a href="/about/">关于</a><a href="/posts/">归档</a><a href="/categories/">分类</a><a href="/tags/">标签</a><a href="/links/">友链</a></nav></div></header><main class="main-content"><div class="container"><article><div class="article-header"><h1 class="article-title">Hugo vs Hexo：我为什么选择 Caddy 作为静态站点服务器</h1><div class="article-meta"><time datetime="2026-06-10">2026-06-10</time><span>·</span><span>约 5 分钟</span></div></div><div class="article-content"><p>这个博客之前是用 Hexo 搭建的，托管在 GitHub Pages 上。但随着文章增多，Hexo 的构建速度越来越慢，GitHub Pages 在国内的访问也不太稳定。经过一番调研，我决定迁移到 Hugo，并把部署方案从 GitHub Pages 换成了自建 Caddy 服务器。</p><h2>Hugo vs Hexo</h2><table><thead><tr><th>特性</th><th>Hexo</th><th>Hugo</th></tr></thead><tbody><tr><td>语言</td><td>Node.js</td><td>Go</td></tr><tr><td>构建速度</td><td>较慢</td><td>极快</td></tr><tr><td>依赖管理</td><td>需要 node_modules</td><td>单二进制，无依赖</td></tr><tr><td>主题生态</td><td>丰富</td><td>丰富</td></tr></tbody></table><p>对我来说，Hugo 最大的优势是<strong>构建速度</strong>和<strong>零依赖</strong>。</p><h2>为什么不用 GitHub Pages</h2><ul><li>国内访问速度不稳定</li><li>不支持自定义 HTTPS</li><li>仓库必须是 public</li><li>自定义域名配置繁琐</li></ul><h2>为什么选择 Caddy</h2><ul><li><strong>自动 HTTPS</strong>：自动申请和续签 Let's Encrypt 证书</li><li><strong>极简配置</strong>：Caddyfile 只有几行</li><li><strong>HTTP/2 默认开启</strong></li><li><strong>Docker 友好</strong>：官方 Alpine 镜像只有 40MB</li></ul><p>一个最简单的 Caddyfile：</p><pre><code>blog.example.com {
    root * /var/www/blog
    file_server
}</code></pre><p>就这几行，Caddy 会自动处理 HTTPS、HTTP→HTTPS 跳转、HTTP/2 等所有事情。</p><hr><p>从 Hexo 迁移到 Hugo + Caddy 的组合，让我的博客维护成本降到了最低。写文章、推送、自动部署，整个流程非常流畅。</p></div><div class="post-card-tags" style="margin-top:2rem;padding-top:1.5rem;border-top:1px solid var(--color-border)"><a href="/tags/hugo/" class="tag">Hugo</a><a href="/tags/caddy/" class="tag">Caddy</a><a href="/tags/docker/" class="tag">Docker</a></div></article></div></main><footer class="site-footer"><div class="container"><p>© 2024–2026 林一 · 自建小站 · 所有内容均为原创</p><p>Powered by <a href="https://gohugo.io/" target="_blank" rel="noopener">Hugo</a> & <a href="https://caddyserver.com/" target="_blank" rel="noopener">Caddy</a></p></div></footer></body></html>
POSTEOF

    info "站点文件生成完成"
}
