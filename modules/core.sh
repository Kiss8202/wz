#!/usr/bin/env bash
# ==================== 核心模块 ====================
# 全局常量、变量、通用工具函数

MODULE_VERSION="2.0.0"

# ==================== 路径常量 ====================
DEPLOY_DIR="/opt/reality-site"
SITE_DIR="${DEPLOY_DIR}/site"
CADDY_DIR="${DEPLOY_DIR}/caddy"
MODULES_DIR="/etc/reality-site/modules"
CONFIG_FILE="${DEPLOY_DIR}/config.env"
CONTAINER_NAME="reality-site"

# ==================== 颜色定义 ====================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ==================== 日志函数 ====================
print_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
print_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
print_fatal()   { echo -e "${RED}[FATAL]${NC} $*"; exit 1; }
print_step()    { echo -e "${CYAN}[$1]${NC}  $2"; }

# ==================== 系统检测 ====================
OS_ID="unknown"
OS_VERSION=""

detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-}"
    elif [[ -f /etc/redhat-release ]]; then
        OS_ID="centos"
    fi
    print_info "检测到系统: ${OS_ID} ${OS_VERSION}"
}

# ==================== 包管理 ====================
pkg_install() {
    case "$OS_ID" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1
            apt-get install -y "$@" >/dev/null 2>&1
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y "$@" >/dev/null 2>&1 || dnf install -y "$@" >/dev/null 2>&1
            ;;
        fedora)
            dnf install -y "$@" >/dev/null 2>&1
            ;;
        alpine)
            apk add --no-cache "$@" >/dev/null 2>&1
            ;;
        *)
            print_fatal "不支持的系统: $OS_ID"
            ;;
    esac
}

# ==================== 端口检测 ====================
check_port() {
    local port="$1"
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        local proc
        proc=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1 || true)
        print_warn "端口 ${port} 已被占用: ${proc}"
        return 1
    fi
    return 0
}

# ==================== IP 获取 ====================
get_ip() {
    local ip=""
    ip=$(curl -s4 --connect-timeout 3 ifconfig.me 2>/dev/null) \
        || ip=$(curl -s4 --connect-timeout 3 icanhazip.com 2>/dev/null) \
        || ip=$(curl -s4 --connect-timeout 3 ip.sb 2>/dev/null) \
        || ip="<你的VPS公网IP>"
    echo "$ip"
}

get_ipv6() {
    local ip=""
    ip=$(curl -s6 --connect-timeout 3 ifconfig.me 2>/dev/null) \
        || ip=$(curl -s6 --connect-timeout 3 icanhazip.com 2>/dev/null) \
        || echo ""
}

# ==================== 配置持久化 ====================
save_config() {
    cat > "$CONFIG_FILE" <<EOF
DOMAIN="${DOMAIN}"
EMAIL="${EMAIL}"
CADDY_PORT="${CADDY_PORT:-8080}"
DEPLOY_DIR="${DEPLOY_DIR}"
CONTAINER_NAME="${CONTAINER_NAME}"
EOF
    chmod 600 "$CONFIG_FILE"
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        . "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# ==================== 交互辅助 ====================
confirm() {
    local msg="${1:-是否继续?}"
    read -rp "$(echo -e "${YELLOW}${msg} (y/N):${NC} ")" ans
    [[ "${ans,,}" == "y" ]]
}

menu_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     $*${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}
