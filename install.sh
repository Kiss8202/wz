#!/usr/bin/env bash
# ============================================================
#  Reality SNI 伪装站点 一键部署脚本
#  模块化架构 - 参考 sing-box 管理脚本设计
#
#  用法:
#    bash install.sh -d <域名> -e <邮箱> [-m <模式>]
#    bash install.sh -u          # 卸载
#
#  模式:
#    standalone   - 独立模式（Caddy 占用 80/443）
#    with-singbox - 共存模式（Caddy 监听本地，sing-box 占 443）
# ============================================================
set -euo pipefail

# ==================== POSIX sh 引导 ====================
if [ -z "$BASH_VERSION" ]; then
    if ! command -v bash >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            echo "[引导] Alpine 系统，正在安装 bash ..."
            apk add --no-cache bash >/dev/null 2>&1
        elif command -v apt-get >/dev/null 2>&1; then
            echo "[引导] 正在安装 bash ..."
            apt-get update -qq && apt-get install -y bash >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y bash >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y bash >/dev/null 2>&1
        fi
    fi
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "错误: 需要 bash，请先安装"
    exit 1
fi

# ==================== 模块加载 ====================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
MODULES_URL="https://raw.githubusercontent.com/Kiss8202/wz/main/modules"

# 如果本地模块目录不存在，从 GitHub 下载
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "[引导] 模块目录不存在，正在从 GitHub 下载..."
    mkdir -p "$MODULES_DIR"
    for module in core site security; do
        echo -n "[引导] 下载模块 ${module}.sh ... "
        if curl -sfL --connect-timeout 10 --max-time 30 "${MODULES_URL}/${module}.sh" -o "${MODULES_DIR}/${module}.sh" 2>/dev/null; then
            echo "完成"
        else
            echo "失败"
            echo "错误: 无法下载模块 ${module}.sh，请检查网络连接"
            exit 1
        fi
    done
else
    # 检查版本更新
    CURRENT_VERSION=""
    if [[ -f "${MODULES_DIR}/core.sh" ]]; then
        CURRENT_VERSION=$(grep '^MODULE_VERSION=' "${MODULES_DIR}/core.sh" 2>/dev/null | head -1 | cut -d'"' -f2)
    fi
    REMOTE_VERSION=""
    REMOTE_VERSION=$(curl -sf --connect-timeout 5 --max-time 10 "${MODULES_URL}/core.sh" 2>/dev/null | grep '^MODULE_VERSION=' | head -1 | cut -d'"' -f2)
    if [[ -n "$REMOTE_VERSION" && "$REMOTE_VERSION" != "$CURRENT_VERSION" ]]; then
        echo "[引导] 检测到模块更新 (本地: ${CURRENT_VERSION:-未知} → 远程: ${REMOTE_VERSION})，正在更新..."
        for module in core site security; do
            echo -n "[引导] 更新模块 ${module}.sh ... "
            if curl -sfL --connect-timeout 10 --max-time 30 "${MODULES_URL}/${module}.sh" -o "${MODULES_DIR}/${module}.sh" 2>/dev/null; then
                echo "完成"
            else
                echo "失败（保留旧版本）"
            fi
        done
    fi
fi

# 加载模块
source "${MODULES_DIR}/core.sh"     || { echo "错误: 无法加载 core.sh"; exit 1; }
source "${MODULES_DIR}/site.sh"     || { echo "错误: 无法加载 site.sh"; exit 1; }
source "${MODULES_DIR}/security.sh" || { echo "错误: 无法加载 security.sh"; exit 1; }

# ==================== 参数解析 ====================
DOMAIN=""
EMAIL=""
MODE="standalone"
ACTION="install"

usage() {
    cat <<EOF
${BOLD}Reality SNI 伪装站点 一键部署${NC}

用法:
  bash install.sh -d <域名> -e <邮箱> [-m <模式>]
  bash install.sh -u                            # 卸载

选项:
  -d  域名    你的完整域名 (例如 blog.example.com)
  -e  邮箱    用于 Let's Encrypt 证书通知
  -m  模式    standalone (默认) 或 with-singbox
              standalone:   Caddy 占用 80/443，自动 HTTPS
              with-singbox: Caddy 监听本地 8080，sing-box 占 443
  -u          卸载已部署的站点
  -h          显示帮助
EOF
}

while getopts "d:e:m:uh" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        u) ACTION="uninstall" ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# ==================== 卸载 ====================
if [[ "$ACTION" == "uninstall" ]]; then
    remove_site
    exit 0
fi

# ==================== 检查 root ====================
if [[ $EUID -ne 0 ]]; then
    print_fatal "请使用 root 用户运行: sudo bash install.sh"
fi

# ==================== 交互式输入 ====================
menu_header "Reality SNI 伪装站点 一键部署"

if [[ -z "$DOMAIN" ]]; then
    read -rp "请输入你的域名 (例如 blog.example.com): " DOMAIN
fi
if [[ -z "$EMAIL" ]]; then
    read -rp "请输入你的邮箱 (用于 Let's Encrypt 通知): " EMAIL
fi
if [[ -z "$MODE" || ( "$MODE" != "standalone" && "$MODE" != "with-singbox" ) ]]; then
    echo ""
    echo "请选择部署模式:"
    echo "  1) standalone   - Caddy 占用 80/443（独立部署）"
    echo "  2) with-singbox - Caddy 监听本地 8080（与 sing-box 共存）"
    read -rp "请选择 [1/2]: " mode_choice
    case "$mode_choice" in
        2) MODE="with-singbox" ;;
        *) MODE="standalone" ;;
    esac
fi

[[ -z "$DOMAIN" || -z "$EMAIL" ]] && print_fatal "域名和邮箱不能为空"

# ==================== 步骤 1: 系统检测 ====================
print_step "1/6" "系统检测..."
detect_system

# ==================== 步骤 2: 安装依赖 ====================
print_step "2/6" "安装基础依赖..."
pkg_install curl wget

# ==================== 步骤 3: 安装 Docker ====================
if ! command -v docker &>/dev/null; then
    print_step "3/6" "安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker  >/dev/null 2>&1
    print_success "Docker 安装完成"
else
    print_step "3/6" "Docker 已安装，跳过"
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

# ==================== 步骤 4: 端口检测 ====================
print_step "4/6" "检测端口..."
if [[ "$MODE" == "standalone" ]]; then
    PORT_OK=true
    check_port 80  || PORT_OK=false
    check_port 443 || PORT_OK=false
    if [[ "$PORT_OK" == "false" ]]; then
        print_warn "检测到 80 或 443 端口被占用"
        confirm "是否继续?" || print_fatal "用户取消"
    fi
else
    check_port "${CADDY_PORT:-8080}" || print_warn "端口 ${CADDY_PORT:-8080} 已被占用"
fi

# ==================== 步骤 5: 防火墙 + 安全加固 ====================
print_step "5/6" "安全加固..."
if [[ "$MODE" == "standalone" ]]; then
    open_firewall_ports
fi
harden_security

# ==================== 步骤 6: 部署站点 ====================
print_step "6/6" "部署伪装站点..."
deploy_site "$MODE"

# ==================== 保存配置 ====================
save_config

# ==================== 最终报告 ====================
VPS_IP=$(get_ip)

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║               部署结果                          ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    print_success "容器状态: 运行中"
    print_info "部署目录: ${DEPLOY_DIR}"
    print_info "部署模式: ${MODE}"

    if [[ "$MODE" == "standalone" ]]; then
        print_info "访问地址: https://${DOMAIN}"
        print_info "Xray/Sing-box SNI: ${DOMAIN}"
    else
        print_info "Caddy 监听: 127.0.0.1:${CADDY_PORT:-8080}"
        print_info "请在 sing-box Reality 配置中设置:"
        print_info "  handshake.server: \"${DOMAIN}\""
        print_info "  handshake.server_port: 443"
        print_info "  fallback: 127.0.0.1:${CADDY_PORT:-8080}"
    fi
else
    print_error "容器状态: 未运行"
    print_fatal "请查看日志: docker logs ${CONTAINER_NAME}"
fi

echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║             DNS 配置提醒                        ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
print_warn "Cloudflare DNS 设置:"
print_warn "  类型: A"
print_warn "  名称: ${DOMAIN%%.*}"
print_warn "  IP:   ${VPS_IP}"
print_warn "  代理: 灰色云朵 (仅DNS，不开CDN)"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

# 安全报告
security_report

echo ""
print_info "常用命令:"
echo "  查看日志:   docker logs ${CONTAINER_NAME}"
echo "  重启服务:   cd ${CADDY_DIR} && docker compose restart"
echo "  卸载站点:   bash install.sh -u"
