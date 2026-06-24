#!/usr/bin/env bash
# ==================== 伪装站点模块 ====================
# Caddy 配置、站点文件生成、Docker 部署

# ==================== 生成 Caddyfile ====================
generate_caddyfile() {
    local listen_addr="${1:-127.0.0.1}"
    local listen_port="${2:-8080}"

    print_step "站点" "生成 Caddyfile (监听 ${listen_addr}:${listen_port})..."

    mkdir -p "${CADDY_DIR}"

    cat > "${CADDY_DIR}/Caddyfile" <<CADDYEOF
${DOMAIN} {
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

# 拒绝用IP直接访问（防SNI探测）
:80 {
    @notmyhost not host ${DOMAIN}
    respond @notmyhost "" 444
}
CADDYEOF

    # 如果 Caddy 监听本地端口（非443），覆盖配置
    if [[ "$listen_addr" == "127.0.0.1" || "$listen_addr" == "localhost" ]]; then
        cat > "${CADDY_DIR}/Caddyfile" <<CADDYEOF
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
    fi
}

# ==================== 生成 docker-compose.yml ====================
generate_docker_compose() {
    local caddy_port="${1:-8080}"
    local expose_ports="${2:-false}"

    print_step "站点" "生成 docker-compose.yml..."

    local ports_block=""
    if [[ "$expose_ports" == "true" ]]; then
        # Caddy 对外暴露 80/443（独立部署模式）
        ports_block='      - "80:80"
      - "443:443"'
    else
        # Caddy 仅监听本地（与 sing-box 共存模式）
        ports_block="      - \"127.0.0.1:${caddy_port}:${caddy_port}\""
    fi

    cat > "${CADDY_DIR}/docker-compose.yml" <<COMPOSEEOF
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: ${CONTAINER_NAME}
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
    print_step "站点" "替换域名占位符..."
    if [[ -d "${SITE_DIR}" ]]; then
        find "${SITE_DIR}" -type f \( -name "*.xml" -o -name "*.txt" \) \
            -exec sed -i "s|__DOMAIN__|${DOMAIN}|g" {} + 2>/dev/null || true
    fi
}

# ==================== 启动 Caddy 容器 ====================
start_caddy() {
    print_step "站点" "启动 Caddy 容器..."

    # 停止旧容器
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        print_info "检测到旧容器，正在替换..."
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    cd "${CADDY_DIR}"
    docker compose up -d 2>/dev/null || docker-compose up -d
}

# ==================== 等待证书签发 ====================
wait_for_cert() {
    # 仅在 Caddy 对外暴露 443 时需要等待
    if ! grep -q ":443" "${CADDY_DIR}/Caddyfile" 2>/dev/null; then
        return
    fi

    print_step "站点" "等待 SSL 证书签发..."
    echo -n "  "

    local cert_ok=false
    for i in $(seq 1 30); do
        echo -n "."
        sleep 2

        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
            echo ""
            print_fatal "容器异常退出，请查看日志: docker logs ${CONTAINER_NAME}"
        fi

        if docker logs "$CONTAINER_NAME" 2>&1 | grep -qi "certificate obtained successfully"; then
            cert_ok=true
            break
        fi
    done
    echo ""

    if [[ "$cert_ok" == "true" ]]; then
        print_success "SSL 证书已签发"
    else
        print_warn "SSL 证书签发中，请稍后访问验证"
    fi
}

# ==================== 站点部署主函数 ====================
deploy_site() {
    local mode="${1:-standalone}"

    mkdir -p "${DEPLOY_DIR}" "${CADDY_DIR}"

    # 检查站点文件来源
    if [[ -d "${DEPLOY_DIR}/site" && -f "${DEPLOY_DIR}/site/index.html" ]]; then
        print_info "使用已有站点文件"
        ln -sf "${DEPLOY_DIR}/site" "${CADDY_DIR}/site" 2>/dev/null || cp -r "${DEPLOY_DIR}/site" "${CADDY_DIR}/site"
    else
        print_fatal "站点文件不存在，请先确保 site/ 目录存在"
    fi

    case "$mode" in
        standalone)
            # 独立模式：Caddy 占用 80/443，自动 HTTPS
            print_info "部署模式: 独立（Caddy 占用 80/443）"
            generate_caddyfile
            generate_docker_compose 8080 "true"
            replace_domain_placeholders
            start_caddy
            wait_for_cert
            ;;
        with-singbox)
            # 共存模式：Caddy 监听本地 8080，sing-box 占用 443
            local caddy_port="${CADDY_PORT:-8080}"
            print_info "部署模式: 与 sing-box 共存（Caddy 监听 127.0.0.1:${caddy_port}）"
            generate_caddyfile "127.0.0.1" "$caddy_port"
            generate_docker_compose "$caddy_port" "false"
            replace_domain_placeholders
            start_caddy
            print_success "Caddy 已启动，监听 127.0.0.1:${caddy_port}"
            print_info "请在 sing-box Reality 配置中设置 fallback 到 127.0.0.1:${caddy_port}"
            ;;
        *)
            print_fatal "未知部署模式: $mode"
            ;;
    esac
}

# ==================== 卸载站点 ====================
remove_site() {
    print_step "站点" "正在卸载..."

    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
    fi

    [[ -d "${DEPLOY_DIR}" ]] && rm -rf "${DEPLOY_DIR}"
    docker volume rm reality-site_caddy_data reality-site_caddy_config >/dev/null 2>&1 || true

    print_success "站点已卸载"
}
