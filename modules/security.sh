#!/usr/bin/env bash
# ==================== 安全加固模块 ====================
# 防扫描、fail2ban、iptables 规则

# ==================== 屏蔽扫描器 IP ====================
block_scanner_ips() {
    print_step "安全" "屏蔽已知扫描器 IP 段..."

    local scan_nets=(
        # Shodan
        "198.51.44.0/24" "71.6.165.0/24" "71.6.146.0/24" "66.240.192.0/18" "74.82.160.0/19"
        # Censys
        "162.142.148.0/24" "167.248.133.0/24" "192.35.168.0/23"
        # BinaryEdge
        "157.230.0.0/16" "167.71.0.0/16" "167.99.0.0/16"
        # Shadowserver
        "184.105.247.0/24" "184.105.139.0/24"
    )

    for net in "${scan_nets[@]}"; do
        iptables -I INPUT -s "$net" -j DROP 2>/dev/null || true
    done

    print_success "已屏蔽 ${#scan_nets[@]} 个扫描器 IP 段"
}

# ==================== 配置 fail2ban ====================
setup_fail2ban() {
    print_step "安全" "配置 fail2ban..."

    if ! command -v fail2ban-server &>/dev/null; then
        pkg_install fail2ban
    fi

    mkdir -p /etc/fail2ban/jail.d /etc/fail2ban/filter.d

    cat > /etc/fail2ban/jail.d/reality-site.conf << 'F2BEOF'
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

    cat > /etc/fail2ban/filter.d/port-scan.conf << 'F2BEOF'
[Definition]
failregex = .*SRC=<HOST>.*DPT=\d+.*
ignoreregex =
F2BEOF

    systemctl enable fail2ban >/dev/null 2>&1 || true
    systemctl start fail2ban  >/dev/null 2>&1 || true

    print_success "fail2ban 已配置"
}

# ==================== iptables 防扫描规则 ====================
setup_iptables_rules() {
    print_step "安全" "配置 iptables 防扫描规则..."

    # 限制新连接速率
    iptables -I INPUT -p tcp --syn -m connlimit --connlimit-above 20 -j DROP 2>/dev/null || true
    iptables -I INPUT -p tcp --syn -m limit --limit 30/s --limit-burst 50 -j ACCEPT 2>/dev/null || true

    # 允许已建立的连接
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

    # 限制 ICMP 速率
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT 2>/dev/null || true

    # 保存规则
    case "$OS_ID" in
        ubuntu|debian)
            pkg_install iptables-persistent
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            ;;
    esac

    print_success "iptables 规则已配置"
}

# ==================== 配置防火墙放行端口 ====================
open_firewall_ports() {
    print_step "安全" "配置防火墙放行端口..."

    if command -v ufw &>/dev/null; then
        ufw allow 80/tcp  >/dev/null 2>&1 || true
        ufw allow 443/tcp >/dev/null 2>&1 || true
        print_success "UFW 已放行 80/443"
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-service=http  >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-service=https >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        print_success "firewalld 已放行 80/443"
    else
        print_warn "未检测到防火墙，请确保云服务商安全组已放行 80/443"
    fi
}

# ==================== 安全加固主函数 ====================
harden_security() {
    block_scanner_ips
    setup_fail2ban
    setup_iptables_rules
}

# ==================== 输出安全报告 ====================
security_report() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             安全加固说明                        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    print_info "已启用的安全措施:"
    echo "  [1] TLS 1.3 + X25519 强制加密"
    echo "  [2] SNI 过滤 - 非本域名请求返回444断开"
    echo "  [3] HSTS 预加载 - 浏览器强制 HTTPS"
    echo "  [4] iptables 屏蔽 Shodan/Censys/BinaryEdge 扫描器"
    echo "  [5] fail2ban 防端口扫描和 SSH 暴力破解"
    echo "  [6] 连接速率限制 - 防大规模端口扫描"
    echo ""
    print_warn "额外建议（脚本无法自动完成）:"
    echo "  [1] 修改 SSH 默认端口（22 → 其他）"
    echo "  [2] 禁用密码登录，仅用密钥认证"
    echo "  [3] 定期检查: curl -s https://crt.sh/?q=${DOMAIN}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}
