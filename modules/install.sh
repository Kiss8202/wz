# ==================== sing-box 安装模块 ====================
# ==================== 安装 sing-box ====================
install_singbox() {
    print_info "检查 sing-box 安装状态（支持断点续装）..."

    # ---------- 1. 安装系统依赖 ----------
    local missing_deps=()
    for cmd in jq curl wget openssl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_info "缺少依赖: ${missing_deps[*]}，开始安装..."
        if [[ $ALPINE -eq 1 ]]; then
            for pkg in curl wget jq openssl util-linux coreutils iproute2; do
                if ! apk add --no-cache "$pkg" >/dev/null 2>&1; then
                    print_warning "包 ${pkg} 安装失败，继续尝试其他包..."
                fi
                sleep 0.5
            done
        else
            apt-get update -qq && apt-get install -y curl wget jq openssl uuid-runtime >/dev/null 2>&1
        fi

        # 验证关键依赖是否安装成功
        local still_missing=()
        for cmd in jq curl wget openssl; do
            if ! command -v "$cmd" &>/dev/null; then
                still_missing+=("$cmd")
            fi
        done
        if [[ ${#still_missing[@]} -gt 0 ]]; then
            print_error "以下依赖安装失败: ${still_missing[*]}"
            return 1
        fi
        print_success "依赖安装完成"
    else
        print_success "基础依赖已就绪"
    fi

    # ---------- 2. 检查 sing-box 二进制是否可执行 ----------
    local need_download=1
    if [[ -x "${INSTALL_DIR}/sing-box" ]]; then
        # 尝试运行版本检查，若返回正常则认为可用
        if ${INSTALL_DIR}/sing-box version >/dev/null 2>&1; then
            local version=$(${INSTALL_DIR}/sing-box version 2>&1 | awk '/sing-box version/{print $3}' || echo "unknown")
            print_success "sing-box 已安装且可执行 (版本: ${version})"
            need_download=0
        else
            # sing-box 默认构建是纯 Go 静态编译，不需要 glibc 兼容层
            # 如果无法运行，可能是架构不匹配
            print_warning "检测到损坏的 sing-box，将重新下载安装"
            rm -f "${INSTALL_DIR}/sing-box"
        fi
    fi

    # ---------- 3. 下载、解压、安装二进制（如需要） ----------
    if [[ $need_download -eq 1 ]]; then
        local LATEST=""
        local retry=0
        local max_retries=3
        while [[ $retry -lt $max_retries ]]; do
            local api_response
            api_response=$(curl -sf --connect-timeout 10 --max-time 30 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" 2>/dev/null)
            if [[ -n "$api_response" ]]; then
                LATEST=$(echo "$api_response" | jq -r '.tag_name' 2>/dev/null | sed 's/v//')
            fi
            [[ -n "$LATEST" ]] && break
            ((retry++))
            print_warning "获取版本信息失败，重试 ${retry}/${max_retries}..."
            [[ $retry -lt $max_retries ]] && sleep 3
        done
        [[ -z "$LATEST" ]] && LATEST="1.12.0"
        print_info "目标版本: ${LATEST}"

        # 清理可能残留的半成品
        rm -rf /tmp/sb.tar.gz /tmp/sing-box-${LATEST}-linux-${ARCH}
        TEMP_FILES+=("/tmp/sb.tar.gz" "/tmp/sing-box-${LATEST}-linux-${ARCH}")

        print_info "下载 sing-box (${LATEST} linux-${ARCH}) ..."
        wget -q --show-progress -O /tmp/sb.tar.gz \
            "https://github.com/SagerNet/sing-box/releases/download/v${LATEST}/sing-box-${LATEST}-linux-${ARCH}.tar.gz" 2>&1
        if [[ ! -f /tmp/sb.tar.gz ]]; then
            print_error "下载失败，请检查网络后重新运行脚本"
            return 1
        fi

        # 小内存机器解压时很可能被杀，解压前确保文件完整
        print_info "解压 sing-box ..."
        if tar -xzf /tmp/sb.tar.gz -C /tmp 2>/dev/null; then
            rm -f /tmp/sb.tar.gz
        else
            print_error "解压失败（可能内存不足被 kill），请增加 swap 后重新运行脚本"
            rm -f /tmp/sb.tar.gz
            return 1
        fi

        # 安装二进制
        if [[ -f "/tmp/sing-box-${LATEST}-linux-${ARCH}/sing-box" ]]; then
            install -Dm755 "/tmp/sing-box-${LATEST}-linux-${ARCH}/sing-box" "${INSTALL_DIR}/sing-box"
            rm -rf "/tmp/sing-box-${LATEST}-linux-${ARCH}"

            # 验证安装后的二进制是否可执行
            if ${INSTALL_DIR}/sing-box version >/dev/null 2>&1; then
                local version=$(${INSTALL_DIR}/sing-box version 2>&1 | awk '/sing-box version/{print $3}' || echo "unknown")
                print_success "sing-box 二进制安装完成 (版本: ${version})"
            else
                # sing-box 默认构建是纯 Go 静态编译，不需要 glibc 兼容层
                # 如果无法运行，说明架构不匹配或文件损坏
                print_error "sing-box 安装后无法执行，可能架构不匹配或文件损坏"
                return 1
            fi
        else
            print_error "解压后未找到 sing-box 二进制，请检查"
            return 1
        fi
    fi

    # ---------- 4. 创建或修复服务文件 ----------
    local need_service=0
    if [[ $ALPINE -eq 1 ]]; then
        if [[ ! -f /etc/init.d/sing-box ]]; then
            need_service=1
        else
            # 如果服务文件不含预期的日志重定向命令，则重写
            if ! grep -q "/var/log/sing-box.log" /etc/init.d/sing-box; then
                need_service=1
            fi
        fi
    else
        if [[ ! -f /etc/systemd/system/sing-box.service ]]; then
            need_service=1
        fi
    fi

    if [[ $need_service -eq 1 ]]; then
        print_info "创建/更新服务文件..."
        if [[ $ALPINE -eq 1 ]]; then
            cat > /etc/init.d/sing-box << 'EOF'
#!/sbin/openrc-run

name="sing-box"
description="sing-box service"

command="/bin/sh"
command_args="-c 'exec /usr/local/bin/sing-box run -c /etc/sing-box/config.json >> /var/log/sing-box.log 2>&1'"
pidfile="/run/${name}.pid"
required_files="/etc/sing-box/config.json"

supervisor="supervise-daemon"
respawn_delay=10
respawn_max=0

depend() {
    need net
    after firewall
}
EOF
            chmod +x /etc/init.d/sing-box
            print_success "OpenRC 服务已创建"
        else
            cat > /etc/systemd/system/sing-box.service << 'EOFSVC'
[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOFSVC
            systemctl daemon-reload
            print_success "systemd 服务已创建"
        fi
    else
        print_success "服务文件已就绪"
    fi

    # ---------- 5. 开机自启 ----------
    svc_enable

    # ---------- 6. 配置日志清理（首次安装自动设置） ----------
    setup_log_cleanup

    print_success "sing-box 安装/修复完成"
}
# ==================== 证书生成 ====================
gen_cert_for_sni() {
    local sni="$1"
    local node_cert_dir="${CERT_DIR}/${sni}"
    
    mkdir -p "${node_cert_dir}"
    
    openssl genrsa -out "${node_cert_dir}/private.key" 2048 2>/dev/null
    openssl req -new -x509 -days 36500 -key "${node_cert_dir}/private.key" -out "${node_cert_dir}/cert.pem" -subj "/C=US/ST=California/L=Cupertino/O=Apple Inc./CN=${sni}" 2>/dev/null
    
    print_success "证书生成完成 (${sni}, 有效期100年)"
}

# ==================== 密钥管理 ====================
gen_keys() {
    print_info "生成 Reality 密钥对..."
    
    if [[ -f "${KEY_FILE}" ]] && [[ -r "${KEY_FILE}" ]]; then
        print_info "从文件加载已保存的密钥..."
        while IFS='=' read -r key value; do
            value="${value#\"}"
            value="${value%\"}"
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            case "$key" in
                REALITY_PRIVATE) REALITY_PRIVATE="$value" ;;
                REALITY_PUBLIC) REALITY_PUBLIC="$value" ;;
                SHORT_ID) SHORT_ID="$value" ;;
            esac
        done < "${KEY_FILE}"
        print_success "密钥加载完成"
        return 0
    fi
    
    KEYS=$(${INSTALL_DIR}/sing-box generate reality-keypair 2>/dev/null)
    REALITY_PRIVATE=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
    REALITY_PUBLIC=$(echo "$KEYS" | grep "PublicKey" | awk '{print $2}')

    if [[ -z "$REALITY_PRIVATE" || -z "$REALITY_PUBLIC" ]]; then
        print_error "Reality 密钥生成失败"
        print_error "请检查 sing-box 是否正常安装: ${INSTALL_DIR}/sing-box version"
        return 1
    fi
    SHORT_ID=$(openssl rand -hex 8)
    print_info "Reality Short ID 已自动生成: ${SHORT_ID}"
    print_info "如需修改 Short ID，可在添加节点时自定义"
    save_keys_to_file
    print_success "密钥生成完成"
}

save_keys_to_file() {
    mkdir -p "$(dirname "${KEY_FILE}")"
    
    cat > "${KEY_FILE}" << EOF
REALITY_PRIVATE="${REALITY_PRIVATE}"
REALITY_PUBLIC="${REALITY_PUBLIC}"
SHORT_ID="${SHORT_ID}"
EOF
    
    chmod 600 "${KEY_FILE}"
    print_success "密钥已保存到 ${KEY_FILE}"
}

