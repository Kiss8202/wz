#!/usr/bin/env bash
# ==================== 伪装站点模块 ====================
# Caddy 配置、站点文件管理、Docker 部署
# 与 sing-box 管理脚本集成

# ==================== 路径常量 ====================
SITE_DEPLOY_DIR="/opt/reality-site"
SITE_CADDY_DIR="${SITE_DEPLOY_DIR}/caddy"
SITE_DIR="${SITE_DEPLOY_DIR}/site"
SITE_CONTAINER="reality-site"
SITE_CONFIG="${SITE_DEPLOY_DIR}/config.env"
CADDY_PORT="8080"

# ==================== 安装 Docker ====================
install_docker() {
    if ! command -v docker &>/dev/null; then
        print_info "正在安装 Docker..."
        curl -fsSL https://get.docker.com | bash
        systemctl enable docker >/dev/null 2>&1
        systemctl start docker  >/dev/null 2>&1
        print_success "Docker 安装完成"
    else
        print_info "Docker 已安装"
    fi

    # 确保 docker compose 可用
    if ! docker compose version &>/dev/null 2>&1; then
        print_info "安装 Docker Compose 插件..."
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
}

# ==================== 生成 Caddyfile ====================
generate_caddyfile() {
    local listen_addr="${1:-127.0.0.1}"
    local listen_port="${2:-8080}"

    print_info "生成 Caddyfile (监听 ${listen_addr}:${listen_port})..."

    mkdir -p "${SITE_CADDY_DIR}"

    if [[ "$listen_addr" == "127.0.0.1" || "$listen_addr" == "localhost" ]]; then
        # 与 sing-box 共存模式：纯 HTTP，无需证书
        cat > "${SITE_CADDY_DIR}/Caddyfile" <<CADDYEOF
${listen_addr}:${listen_port} {
    root * /usr/share/caddy
    file_server

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy no-referrer-when-downgrade
    }

    redir /feed /atom.xml permanent
    redir /rss /atom.xml permanent
    redir /sitemap /sitemap.xml permanent

    handle_errors {
        rewrite * /404.html
        file_server
    }
}
CADDYEOF
    else
        # 独立模式：自动 HTTPS
        local domain="${1}"
        local email="${2}"
        cat > "${SITE_CADDY_DIR}/Caddyfile" <<CADDYEOF
${domain} {
    tls ${email} {
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
    @notmyhost not host ${domain}
    respond @notmyhost "" 444
}
CADDYEOF
    fi
}

# ==================== 生成 docker-compose.yml ====================
generate_docker_compose() {
    local caddy_port="${1:-8080}"
    local mode="${2:-with-singbox}"

    print_info "生成 docker-compose.yml..."

    local ports_block=""
    if [[ "$mode" == "standalone" ]]; then
        ports_block='      - "80:80"
      - "443:443"'
    else
        ports_block="      - \"127.0.0.1:${caddy_port}:${caddy_port}\""
    fi

    cat > "${SITE_CADDY_DIR}/docker-compose.yml" <<COMPOSEEOF
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: ${SITE_CONTAINER}
    ports:
${ports_block}
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
}

# ==================== 替换站点域名占位符 ====================
replace_domain_placeholders() {
    print_info "替换域名占位符..."
    if [[ -d "${SITE_DIR}" ]]; then
        find "${SITE_DIR}" -type f \( -name "*.xml" -o -name "*.txt" \) \
            -exec sed -i "s|__DOMAIN__|${DOMAIN:-unknown}|g" {} + 2>/dev/null || true
    fi
}

# ==================== 启动 Caddy 容器 ====================
start_caddy() {
    print_info "启动 Caddy 容器..."

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${SITE_CONTAINER}$"; then
        print_info "检测到旧容器，正在替换..."
        docker rm -f "$SITE_CONTAINER" >/dev/null 2>&1
    fi

    cd "${SITE_CADDY_DIR}"
    docker compose up -d 2>/dev/null || docker-compose up -d
}

# ==================== 等待证书签发 ====================
wait_for_cert() {
    if ! grep -q ":443" "${SITE_CADDY_DIR}/Caddyfile" 2>/dev/null; then
        return
    fi

    print_info "等待 SSL 证书签发..."
    echo -n "  "

    local cert_ok=false
    for i in $(seq 1 30); do
        echo -n "."
        sleep 2

        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${SITE_CONTAINER}$"; then
            echo ""
            print_error "容器异常退出，请查看日志: docker logs ${SITE_CONTAINER}"
            return 1
        fi

        if docker logs "$SITE_CONTAINER" 2>&1 | grep -qi "certificate obtained successfully"; then
            cert_ok=true
            break
        fi
    done
    echo ""

    if [[ "$cert_ok" == "true" ]]; then
        print_success "SSL 证书已签发"
    else
        print_warning "SSL 证书签发中，请稍后访问验证"
    fi
}

# ==================== 交互式部署 ====================
site_deploy_interactive() {
    menu_header "部署伪装站点"

    # 检查 Docker
    install_docker

    # 选择模式
    echo "请选择部署模式:"
    echo -e "  ${GREEN}[1]${NC} 与 sing-box 共存 (Caddy 监听本地 ${CADDY_PORT}，sing-box 占 443)"
    echo -e "  ${GREEN}[2]${NC} 独立部署 (Caddy 占用 80/443，自动 HTTPS)"
    read -p "请选择 [1/2，默认1]: " mode_choice
    local mode="with-singbox"
    [[ "$mode_choice" == "2" ]] && mode="standalone"

    local domain=""
    local email=""

    if [[ "$mode" == "standalone" ]]; then
        read -p "请输入你的域名 (例如 blog.example.com): " domain
        read -p "请输入你的邮箱 (用于 Let's Encrypt 通知): " email
        [[ -z "$domain" || -z "$email" ]] && { print_error "域名和邮箱不能为空"; return 1; }
    fi

    # 准备站点文件
    mkdir -p "${SITE_DEPLOY_DIR}" "${SITE_CADDY_DIR}"

    # 从仓库复制站点文件
    if [[ -d "/etc/sing-box/modules/../site" ]]; then
        # 从模块同级目录复制
        cp -r "$(dirname "$MODULES_DIR")/site" "${SITE_CADDY_DIR}/site" 2>/dev/null || true
    fi

    # 如果没有站点文件，从 Release 下载
    if [[ ! -f "${SITE_CADDY_DIR}/site/index.html" ]]; then
        print_info "站点文件不存在，正在从 Release 下载..."
        local repo_url="https://github.com/Kiss8202/wz"
        local release_url="${repo_url}/releases/latest/download/reality-site.tar.gz"
        if curl -fSL --connect-timeout 10 --max-time 120 -o /tmp/reality-site.tar.gz "$release_url" 2>/dev/null; then
            tar xzf /tmp/reality-site.tar.gz -C /tmp/
            cp -r /tmp/reality-site/site "${SITE_CADDY_DIR}/site"
            rm -rf /tmp/reality-site /tmp/reality-site.tar.gz
            print_success "站点文件下载完成"
        else
            print_error "下载失败，请手动将 site/ 目录放到 ${SITE_CADDY_DIR}/"
            return 1
        fi
    fi

    # 部署
    case "$mode" in
        standalone)
            generate_caddyfile "$domain" "$email"
            generate_docker_compose "$CADDY_PORT" "standalone"
            replace_domain_placeholders
            start_caddy
            wait_for_cert
            ;;
        with-singbox)
            generate_caddyfile "127.0.0.1" "$CADDY_PORT"
            generate_docker_compose "$CADDY_PORT" "with-singbox"
            replace_domain_placeholders
            start_caddy
            print_success "Caddy 已启动，监听 127.0.0.1:${CADDY_PORT}"
            echo ""
            print_info "Reality 节点配置提示:"
            print_info "  添加 Reality 节点时，选择使用本地 Caddy fallback"
            print_info "  SNI 可填写你的伪装域名，handshake 将自动指向 127.0.0.1:${CADDY_PORT}"
            ;;
    esac

    # 保存配置
    cat > "$SITE_CONFIG" <<EOF
MODE="${mode}"
DOMAIN="${domain:-}"
EMAIL="${email:-}"
CADDY_PORT="${CADDY_PORT}"
EOF
    chmod 600 "$SITE_CONFIG"
}

# ==================== 查看站点状态 ====================
site_status() {
    menu_header "伪装站点状态"

    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${SITE_CONTAINER}$"; then
        print_warning "伪装站点未运行"
        return
    fi

    print_success "容器运行中"
    echo ""

    # 读取配置
    if [[ -f "$SITE_CONFIG" ]]; then
        . "$SITE_CONFIG"
        print_info "部署模式: ${MODE}"
        print_info "Caddy 端口: ${CADDY_PORT}"
        [[ -n "$DOMAIN" ]] && print_info "域名: ${DOMAIN}"
    fi

    echo ""
    print_info "容器详情:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAMES|${SITE_CONTAINER}" || true
}

# ==================== 重启站点 ====================
site_restart() {
    print_info "重启 Caddy 容器..."
    if [[ -d "${SITE_CADDY_DIR}" ]]; then
        cd "${SITE_CADDY_DIR}"
        docker compose restart 2>/dev/null || docker-compose restart
        print_success "重启完成"
    else
        print_error "部署目录不存在"
    fi
}

# ==================== 卸载站点 ====================
remove_site() {
    print_info "正在卸载伪装站点..."

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${SITE_CONTAINER}$"; then
        docker rm -f "$SITE_CONTAINER" >/dev/null 2>&1
    fi

    [[ -d "${SITE_DEPLOY_DIR}" ]] && rm -rf "${SITE_DEPLOY_DIR}"
    docker volume rm reality-site_caddy_data reality-site_caddy_config >/dev/null 2>&1 || true

    # 检查是否有 Reality 节点使用了本地 Caddy fallback
    if [[ -f "${CONFIG_FILE}" ]] && grep -q "127.0.0.1:8080" "${CONFIG_FILE}" 2>/dev/null; then
        print_warning "检测到有 Reality 节点使用本地 Caddy fallback"
        print_warning "卸载后这些节点将无法正常工作"
        if confirm "是否自动将 fallback 改为远程握手?"; then
            # 将 handshake.server 从 127.0.0.1 改回对应的 SNI 域名
            if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE}" ]]; then
                local sni=""
                for tag in "${INBOUND_TAGS[@]}"; do
                    local idx="${INBOUND_TAGS[(i)$tag]}"
                    local proto="${INBOUND_PROTOS[$idx]}"
                    if [[ "$proto" == "vless" ]]; then
                        local port="${INBOUND_PORTS[$idx]}"
                        sni=$(jq -r ".inbounds[] | select(.tag==\"vless-in-${port}\") | .tls.server_name // empty" "${CONFIG_FILE}" 2>/dev/null)
                        if [[ -n "$sni" ]]; then
                            jq_update_config ".inbounds[] | select(.tag==\"vless-in-${port}\") | .tls.reality.handshake" "{\"server\": \"${sni}\", \"server_port\": 443}"
                            print_info "节点 vless-in-${port} fallback 已改为 ${sni}:443"
                        fi
                    fi
                done
                svc_restart
                print_success "Reality 节点已更新为远程握手"
            else
                print_warning "无法自动修复，请手动修改 Reality 节点的 handshake 配置"
            fi
        fi
    fi

    print_success "伪装站点已卸载"
}
