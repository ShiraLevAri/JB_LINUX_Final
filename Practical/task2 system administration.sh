#!/bin/bash
#############################################################
# Task 2: System Administration Tasks
#
# 1. User Management (useradd, usermod, userdel)
# 2. Disk and Filesystem Management (format + /etc/fstab)
# 3. Advanced User Management (logged-in users + processes)
# 4. Security and Permissions (sensitive file)
# 5. Advanced Networking (static IP + port forwarding)
# 6. Process and Job Control (jobs, bg, fg)
#
# Usage:
#   sudo ./task2_system_administration.sh             # runs everything
#   sudo ./task2_system_administration.sh <function>   # runs one part
#     functions: user_management, disk_filesystem_management,
#                advanced_user_management, security_permissions,
#                advanced_networking, process_job_control
#
# NOTE: Before running disk_filesystem_management or
#       advanced_networking, edit the variables below to match
#       your real disk partition / network interface.
#############################################################

set -uo pipefail

SENSITIVE_FILE="/etc/sensitive_file.conf"
DISK_PARTITION="/dev/sdb1"    # <-- change to your actual partition
MOUNT_POINT="/mnt/mydisk"
NET_IF="eth0"                 # <-- change to your actual interface name
STATIC_IP="192.168.1.100/24"  # <-- change to your desired static IP
GATEWAY="192.168.1.1"         # <-- change to your gateway

if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root (sudo)."
    exit 1
fi

#############################################
# 1. User Management
#############################################
user_management() {
    echo ">>> [1] Demonstrating useradd / usermod / userdel..."

    local USERNAME="demoUser"

    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:StrongPass123!" | chpasswd

    usermod -aG sudo "$USERNAME"
    id "$USERNAME"

    userdel -r "$USERNAME"

    echo "Done. $USERNAME was created, modified, and deleted."
}

#############################################
# 2. Disk and Filesystem Management
#############################################
disk_filesystem_management() {
    echo ">>> [2] Formatting $DISK_PARTITION and configuring /etc/fstab..."

    if [ ! -b "$DISK_PARTITION" ]; then
        echo "Partition $DISK_PARTITION not found - edit DISK_PARTITION and rerun."
        return
    fi

    mkfs.ext4 -F "$DISK_PARTITION"
    mkdir -p "$MOUNT_POINT"

    local UUID
    UUID=$(blkid -s UUID -o value "$DISK_PARTITION")

    grep -q "$UUID" /etc/fstab || \
        echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults  0  2" >> /etc/fstab

    mount -a
    echo "Done. Mounted at $MOUNT_POINT and persisted in /etc/fstab."
}

#############################################
# 3. Advanced User Management
#############################################
advanced_user_management() {
    echo ">>> [3] Logged-in users and their processes:"

    who

    for user in $(who | awk '{print $1}' | sort -u); do
        echo ""
        echo "--- User: $user ---"
        ps -u "$user" -o pid,ppid,cmd,%mem,%cpu
    done
}

#############################################
# 4. Security and Permissions
#############################################
security_permissions() {
    echo ">>> [4] Setting ownership and permissions on $SENSITIVE_FILE..."

    touch "$SENSITIVE_FILE"
    chown root:root "$SENSITIVE_FILE"
    chmod 600 "$SENSITIVE_FILE"

    ls -l "$SENSITIVE_FILE"
}

#############################################
# 5. Advanced Networking
#############################################
advanced_networking() {
    echo ">>> [5] Configuring static IP on $NET_IF and port forwarding..."

    local NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

    cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  ethernets:
    $NET_IF:
      dhcp4: no
      addresses:
        - $STATIC_IP
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
    netplan apply

    sysctl -w net.ipv4.ip_forward=1
    iptables -t nat -A PREROUTING -p tcp --dport 8080 -j REDIRECT --to-port 80

    apt install -y iptables-persistent
    netfilter-persistent save

    echo "Done. Static IP set and port 8080 forwarded to 80."
}

#############################################
# 6. Process and Job Control
#############################################
process_job_control() {
    echo ">>> [6] Demonstrating jobs / bg / fg..."

    sleep 60 &
    jobs -l

    echo ""
    echo "To bring the job to the foreground, run:  fg %1"
    echo "To resume a stopped job in the background, run:  bg %1"
    echo "(These commands only work in an interactive shell session.)"
}

#############################################
# MAIN
#############################################
run_all() {
    user_management
    disk_filesystem_management
    advanced_user_management
    security_permissions
    advanced_networking
    process_job_control
}

if [ $# -eq 0 ]; then
    run_all
else
    if declare -f "$1" > /dev/null; then
        "$1"
    else
        echo "Unknown function: $1"
        echo "Available: user_management, disk_filesystem_management,"
        echo "           advanced_user_management, security_permissions,"
        echo "           advanced_networking, process_job_control"
        exit 1
    fi
fi
