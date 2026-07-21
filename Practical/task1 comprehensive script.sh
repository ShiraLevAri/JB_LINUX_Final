#!/bin/bash
#############################################################
# Task 1: Comprehensive Script for System Configuration
#
# 1. Install a Web Application (Apache) + Hello World page
# 2. Install and configure a DNS Server (BIND9)
# 3. Backup Script (/etc and /var/log -> /backups)
# 4. System Health Check Script (disk/memory/network -> log)
#
# Usage:
#   sudo ./task1_comprehensive_script.sh          # runs everything
#   sudo ./task1_comprehensive_script.sh <function>  # runs one part
#     functions: install_web_app, install_dns_server,
#                backup_script, health_check_script
#############################################################

set -uo pipefail

BACKUP_DIR="/backups"
HEALTH_LOG="/var/log/system_health.log"

if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root (sudo)."
    exit 1
fi

#############################################
# 1. Install a Web Application
#############################################
install_web_app() {
    echo ">>> [1] Installing Apache and deploying Hello World page..."

    apt update -y
    apt install -y apache2

    echo "<html><body><h1>Hello, world!</h1></body></html>" > /var/www/html/index.html

    systemctl enable apache2
    systemctl restart apache2

    echo "Done. Test with: curl http://localhost"
}

#############################################
# 2. Install and Configure a DNS Server
#############################################
install_dns_server() {
    echo ">>> [2] Installing and configuring BIND9 for example.com..."

    apt update -y
    apt install -y bind9 bind9utils bind9-doc

    local MY_IP
    MY_IP=$(hostname -I | awk '{print $1}')
    echo "Detected local IP: $MY_IP"

    if ! grep -q "example.com" /etc/bind/named.conf.local; then
        cat >> /etc/bind/named.conf.local << EOF
zone "example.com" {
    type master;
    file "/etc/bind/db.example.com";
};
EOF
    fi

    cp -f /etc/bind/db.local /etc/bind/db.example.com
    sed -i "s/localhost\./example.com./g" /etc/bind/db.example.com
    sed -i "/@\s*IN\s*A/c\@       IN      A       $MY_IP" /etc/bind/db.example.com
    grep -q "www" /etc/bind/db.example.com || \
        echo "www     IN      A       $MY_IP" >> /etc/bind/db.example.com

    named-checkconf
    named-checkzone example.com /etc/bind/db.example.com

    systemctl enable bind9
    systemctl restart bind9

    echo "Done. Test with: dig @localhost example.com"
}

#############################################
# 3. Backup Script
#############################################
backup_script() {
    echo ">>> [3] Backing up /etc and /var/log..."

    local DATE
    DATE=$(date +%Y-%m-%d_%H-%M-%S)
    mkdir -p "$BACKUP_DIR"
    local BACKUP_FILE="$BACKUP_DIR/backup_$DATE.tar.gz"
    local ERROR_LOG="$BACKUP_DIR/backup_errors_$DATE.log"

    tar -czvf "$BACKUP_FILE" /etc /var/log 2> "$ERROR_LOG"

    if [ $? -eq 0 ]; then
        echo "Backup completed successfully: $BACKUP_FILE"
    else
        echo "Backup finished with errors. See: $ERROR_LOG"
    fi

    # Suggested cron schedule (daily at 2 AM):
    #   0 2 * * * /path/to/task1_comprehensive_script.sh backup_script
}

#############################################
# 4. System Health Check Script
#############################################
health_check_script() {
    echo ">>> [4] Running system health check..."

    local DATE
    DATE=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo "=== System Health Check: $DATE ==="

        echo ""
        echo "--- Disk Usage ---"
        df -h

        echo ""
        echo "--- Memory Usage ---"
        free -h

        echo ""
        echo "--- Active Network Connections ---"
        ss -tunap

        echo "=================================="
    } >> "$HEALTH_LOG"

    echo "Logged to $HEALTH_LOG"

    # Suggested cron schedule (every 10 minutes):
    #   */10 * * * * /path/to/task1_comprehensive_script.sh health_check_script
}

#############################################
# MAIN
#############################################
run_all() {
    install_web_app
    install_dns_server
    backup_script
    health_check_script
}

if [ $# -eq 0 ]; then
    run_all
else
    if declare -f "$1" > /dev/null; then
        "$1"
    else
        echo "Unknown function: $1"
        echo "Available: install_web_app, install_dns_server, backup_script, health_check_script"
        exit 1
    fi
fi
