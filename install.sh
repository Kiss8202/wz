#!/usr/bin/env bash
# ============================================================
#  Reality SNI 伪装站点 + sing-box 管理脚本
#  模块化架构 - 一键部署
#
#  用法:
#    bash install.sh              # 进入交互菜单
#    bash install.sh -d 域名 -e 邮箱 -m standalone
#    bash install.sh -u           # 卸载
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
MODULES_DIR="/etc/sing-box/modules"
MODULES_URL="https://raw.githubusercontent.com/Kiss8202/wz/main/modules"

# 模块列表（按加载顺序）
MODULE_LIST=(core install links dns relay protocols config site security menu)

# 如果本地模块目录不存在，从 GitHub 下载
if [[ ! -d "$MODULES_DIR" ]]; then
    echo "[引导] 模块目录不存在，正在从 GitHub 下载..."
    mkdir -p "$MODULES_DIR"
    for module in "${MODULE_LIST[@]}"; do
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
        for module in "${MODULE_LIST[@]}"; do
            echo -n "[引导] 更新模块 ${module}.sh ... "
            if curl -sfL --connect-timeout 10 --max-time 30 "${MODULES_URL}/${module}.sh" -o "${MODULES_DIR}/${module}.sh" 2>/dev/null; then
                echo "完成"
            else
                echo "失败（保留旧版本）"
            fi
        done
    fi
fi

# 加载所有模块
for module in "${MODULE_LIST[@]}"; do
    source "${MODULES_DIR}/${module}.sh" || { echo "错误: 无法加载 ${module}.sh"; exit 1; }
done

# ==================== 启动主函数 ====================
main "$@"
