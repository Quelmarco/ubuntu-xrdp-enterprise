#!/usr/bin/env bash
#
# XRDP + XFCE deployment script for Ubuntu Desktop 26.04
#
# Features:
# - Installs and repairs XRDP, xorgxrdp, XFCE and im-config
# - Disables the system GNOME Remote Desktop service
# - Configures a clean XFCE/X11 environment for XRDP
# - Configures existing and future local users
# - Disables xiccd only for configured users
# - Creates timestamped backups
# - Writes a complete installation log
# - Performs final service, port and package checks
#
# Usage:
#   sudo bash setup-xrdp-xfce-enterprise.sh
#
# Optional:
#   sudo bash setup-xrdp-xfce-enterprise.sh --disable-wayland
#

set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/xrdp-xfce-setup.log"
readonly BACKUP_ROOT="/var/backups/xrdp-xfce"
readonly TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
readonly BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

DISABLE_WAYLAND=false

###############################################################################
# Output helpers
###############################################################################

if [[ -t 1 ]]; then
    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[1;33m'
    readonly BLUE=$'\033[0;34m'
    readonly BOLD=$'\033[1m'
    readonly RESET=$'\033[0m'
else
    readonly RED=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly BLUE=""
    readonly BOLD=""
    readonly RESET=""
fi

info() {
    printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"
}

success() {
    printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"
}

warning() {
    printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2
}

fatal() {
    printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    local line_number=${1:-unknown}

    printf '%s[ERROR]%s Script failed at line %s with exit code %s.\n' \
        "$RED" "$RESET" "$line_number" "$exit_code" >&2

    printf 'Consult the log: %s\n' "$LOG_FILE" >&2
    exit "$exit_code"
}

trap 'on_error "$LINENO"' ERR

###############################################################################
# Arguments
###############################################################################

for argument in "$@"; do
    case "$argument" in
        --disable-wayland)
            DISABLE_WAYLAND=true
            ;;
        --help|-h)
            cat <<EOF
Usage:
  sudo bash ${SCRIPT_NAME} [options]

Options:
  --disable-wayland   Disable Wayland globally in GDM.
  --help, -h          Display this help.

Wayland does not normally need to be disabled for XRDP because XRDP creates
its own Xorg session. Use --disable-wayland only when specifically required.
EOF
            exit 0
            ;;
        *)
            fatal "Unknown argument: ${argument}"
            ;;
    esac
done

###############################################################################
# Root and logging
###############################################################################

[[ ${EUID} -eq 0 ]] || fatal "Run this script as root using sudo."

install -d -m 0755 "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 0600 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

printf '\n'
printf '%s============================================================%s\n' "$BOLD" "$RESET"
printf '%sXRDP + XFCE setup started: %s%s\n' "$BOLD" "$(date --iso-8601=seconds)" "$RESET"
printf '%s============================================================%s\n' "$BOLD" "$RESET"

###############################################################################
# Operating-system checks
###############################################################################

[[ -r /etc/os-release ]] || fatal "/etc/os-release is not available."

# shellcheck disable=SC1091
source /etc/os-release

if [[ ${ID:-} != "ubuntu" ]]; then
    fatal "This script supports Ubuntu only. Detected: ${ID:-unknown}"
fi

info "Detected operating system: ${PRETTY_NAME:-Ubuntu}"

case "${VERSION_ID:-}" in
    26.04)
        success "Ubuntu 26.04 detected."
        ;;
    *)
        warning "This script was prepared for Ubuntu 26.04."
        warning "Detected version: ${VERSION_ID:-unknown}. Continuing cautiously."
        ;;
esac

if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != "root" ]]; then
    info "Administrator invoking the script: ${SUDO_USER}"
fi

###############################################################################
# Backup helpers
###############################################################################

install -d -m 0700 "$BACKUP_DIR"

backup_path() {
    local source_path="$1"

    [[ -e "$source_path" || -L "$source_path" ]] || return 0

    local destination="${BACKUP_DIR}${source_path}"
    install -d -m 0700 "$(dirname "$destination")"

    cp -a "$source_path" "$destination"
    info "Backed up ${source_path}"
}

backup_path /etc/xrdp/startwm.sh
backup_path /etc/xrdp/xrdp.ini
backup_path /etc/xrdp/sesman.ini
backup_path /etc/gdm3/custom.conf
backup_path /etc/xdg/autostart/xiccd.desktop
backup_path /etc/skel/.xsession
backup_path /etc/skel/.config/autostart/xiccd.desktop

success "Backups stored in ${BACKUP_DIR}"

###############################################################################
# Package installation
###############################################################################

export DEBIAN_FRONTEND=noninteractive

info "Refreshing package metadata..."
apt-get update

info "Installing XRDP, XFCE and supporting packages..."

apt-get install -y \
    xrdp \
    xorgxrdp \
    xfce4 \
    xfce4-goodies \
    dbus-x11 \
    xauth \
    x11-xserver-utils \
    xserver-xorg-core \
    xserver-xorg-legacy \
    im-config \
    ssl-cert

info "Reinstalling im-config to restore any missing initializer files..."

apt-get install -y --reinstall im-config

required_commands=(
    startxfce4
    dbus-run-session
    Xorg
    xrdp
    xrdp-sesman
)

for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 \
        || fatal "Required command not found after installation: ${command_name}"
done

if [[ ! -e /usr/lib/xorg/modules/drivers/xrdpdev_drv.so ]]; then
    fatal "The xorgxrdp video driver is missing."
fi

if [[ ! -e /usr/share/im-config/initializer ]]; then
    warning "The im-config initializer is missing."
    warning "Continuing because XRDP starts XFCE directly and does not load im-config."
fi

success "Required packages and commands are available."

###############################################################################
# Disable GNOME Remote Desktop
###############################################################################

info "Disabling GNOME Remote Desktop system service..."

systemctl disable --now gnome-remote-desktop.service 2>/dev/null || true
systemctl stop gnome-remote-desktop-configuration.service 2>/dev/null || true

###############################################################################
# Optionally disable Wayland
###############################################################################

if [[ "$DISABLE_WAYLAND" == true ]]; then
    info "Disabling Wayland in GDM..."

    install -d -m 0755 /etc/gdm3

    if [[ ! -f /etc/gdm3/custom.conf ]]; then
        cat > /etc/gdm3/custom.conf <<'EOF'
[daemon]
WaylandEnable=false
EOF
    elif grep -qE '^[[:space:]]*WaylandEnable=' /etc/gdm3/custom.conf; then
        sed -i \
            's/^[[:space:]]*WaylandEnable=.*/WaylandEnable=false/' \
            /etc/gdm3/custom.conf
    elif grep -qE '^[[:space:]]*#[[:space:]]*WaylandEnable=' \
        /etc/gdm3/custom.conf; then
        sed -i \
            's/^[[:space:]]*#[[:space:]]*WaylandEnable=.*/WaylandEnable=false/' \
            /etc/gdm3/custom.conf
    elif grep -qE '^[[:space:]]*\[daemon\][[:space:]]*$' \
        /etc/gdm3/custom.conf; then
        sed -i \
            '/^[[:space:]]*\[daemon\][[:space:]]*$/a WaylandEnable=false' \
            /etc/gdm3/custom.conf
    else
        cat >> /etc/gdm3/custom.conf <<'EOF'

[daemon]
WaylandEnable=false
EOF
    fi

    success "Wayland disabled in /etc/gdm3/custom.conf."
else
    info "Leaving the local GNOME/Wayland configuration unchanged."
fi

###############################################################################
# XRDP TLS permissions
###############################################################################

if getent group ssl-cert >/dev/null 2>&1; then
    usermod -aG ssl-cert xrdp
    success "User xrdp belongs to the ssl-cert group."
else
    warning "Group ssl-cert was not found."
fi

###############################################################################
# Global XRDP window-manager script
###############################################################################

info "Configuring /etc/xrdp/startwm.sh..."

cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
#
# Managed XRDP session launcher.
# XRDP sessions use XFCE on Xorg independently of the local GNOME session.
#

unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
unset WAYLAND_DISPLAY
unset XDG_SESSION_DESKTOP
unset XDG_CURRENT_DESKTOP
unset DESKTOP_SESSION
unset GDMSESSION

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export DESKTOP_SESSION=xfce
export GDMSESSION=xfce
export GTK_USE_PORTAL=0

if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session -- startxfce4
fi

exec startxfce4
EOF

chmod 0755 /etc/xrdp/startwm.sh

success "XRDP will start XFCE directly without loading the local Wayland environment."

###############################################################################
# User session template
###############################################################################

readonly XSESSION_TEMPLATE="/etc/skel/.xsession"

cat > "$XSESSION_TEMPLATE" <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
unset WAYLAND_DISPLAY
unset XDG_SESSION_DESKTOP
unset XDG_CURRENT_DESKTOP
unset DESKTOP_SESSION
unset GDMSESSION

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export DESKTOP_SESSION=xfce
export GDMSESSION=xfce
export GTK_USE_PORTAL=0

if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session -- startxfce4
fi

exec startxfce4
EOF

chmod 0700 "$XSESSION_TEMPLATE"

###############################################################################
# Disable xiccd for XRDP/XFCE users
###############################################################################

install -d -m 0755 /etc/skel/.config/autostart

cat > /etc/skel/.config/autostart/xiccd.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=xiccd
Hidden=true
X-GNOME-Autostart-enabled=false
EOF

chmod 0644 /etc/skel/.config/autostart/xiccd.desktop

###############################################################################
# Existing-user configuration
###############################################################################

configure_user() {
    local username="$1"
    local user_home="$2"
    local primary_group

    primary_group="$(id -gn "$username")"

    info "Configuring XRDP environment for user ${username}..."

    install -d -m 0700 -o "$username" -g "$primary_group" \
        "${user_home}/.config"

    install -d -m 0700 -o "$username" -g "$primary_group" \
        "${user_home}/.config/autostart"

    install -m 0700 -o "$username" -g "$primary_group" \
        "$XSESSION_TEMPLATE" \
        "${user_home}/.xsession"

    install -m 0644 -o "$username" -g "$primary_group" \
        /etc/skel/.config/autostart/xiccd.desktop \
        "${user_home}/.config/autostart/xiccd.desktop"

    rm -f \
        "${user_home}/.xsessionrc" \
        "${user_home}/.Xauthority" \
        "${user_home}/.ICEauthority"

    success "Configured user ${username}."
}

info "Discovering existing regular user accounts..."

while IFS=: read -r username _ uid _ _ user_home user_shell; do
    [[ "$uid" =~ ^[0-9]+$ ]] || continue

    if (( uid < 1000 || uid >= 65534 )); then
        continue
    fi

    [[ "$user_home" == /home/* ]] || continue
    [[ -d "$user_home" ]] || continue

    case "$user_shell" in
        */nologin|*/false)
            continue
            ;;
    esac

    configure_user "$username" "$user_home"
done < /etc/passwd

success "Existing and future regular users are configured for XFCE over XRDP."

###############################################################################
# Firewall
###############################################################################

if command -v ufw >/dev/null 2>&1; then
    ufw_status="$(ufw status 2>/dev/null | head -n 1 || true)"

    if grep -q "Status: active" <<< "$ufw_status"; then
        info "UFW is active. Allowing TCP port 3389..."
        ufw allow 3389/tcp
        success "UFW allows XRDP on TCP port 3389."
    else
        info "UFW is installed but inactive. No firewall rule was changed."
    fi
else
    info "UFW is not installed."
fi

###############################################################################
# Service activation
###############################################################################

info "Reloading systemd and enabling XRDP services..."

systemctl daemon-reload

systemctl enable xrdp.service
systemctl enable xrdp-sesman.service

systemctl restart xrdp-sesman.service
systemctl restart xrdp.service

sleep 2

###############################################################################
# Package verification
###############################################################################

verification_failed=false

verify_package() {
    local package_name="$1"

    if dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null \
        | grep -qx installed; then
        success "Package installed: ${package_name}"
    else
        warning "Package verification failed: ${package_name}"
        verification_failed=true
    fi
}

verify_package xrdp
verify_package xorgxrdp
verify_package xfce4
verify_package dbus-x11
verify_package im-config

###############################################################################
# Service verification
###############################################################################

for service_name in xrdp.service xrdp-sesman.service; do
    if systemctl is-active --quiet "$service_name"; then
        success "Service active: ${service_name}"
    else
        warning "Service is not active: ${service_name}"
        systemctl status "$service_name" --no-pager || true
        verification_failed=true
    fi
done

###############################################################################
# Port verification
###############################################################################

listener_output="$(ss -ltnp 2>/dev/null | awk '$4 ~ /:3389$/')"

if [[ -n "$listener_output" ]]; then
    success "TCP port 3389 is listening."
    printf '%s\n' "$listener_output"

    if grep -q 'xrdp' <<< "$listener_output"; then
        success "Port 3389 is owned by XRDP."
    else
        warning "Port 3389 is listening, but XRDP was not identified as its owner."
        verification_failed=true
    fi
else
    warning "No service is listening on TCP port 3389."
    verification_failed=true
fi

###############################################################################
# NVIDIA information
###############################################################################

if command -v nvidia-smi >/dev/null 2>&1; then
    info "NVIDIA GPU detected:"
    nvidia-smi \
        --query-gpu=name,driver_version \
        --format=csv,noheader 2>/dev/null || true

    info "XRDP will normally use its virtual framebuffer rather than the physical GPU."
fi

###############################################################################
# Final report
###############################################################################

printf '\n'
printf '%s============================================================%s\n' "$BOLD" "$RESET"

if [[ "$verification_failed" == true ]]; then
    warning "Setup completed, but one or more verification checks failed."
    printf 'Review the log: %s\n' "$LOG_FILE"
    printf 'Review the backup: %s\n' "$BACKUP_DIR"
    exit 2
fi

success "XRDP + XFCE setup completed successfully."

cat <<EOF

Connect from Windows using:

  mstsc

Server:
  IP address or hostname of this Ubuntu machine

XRDP login screen:
  Session: Xorg
  Username: Linux username
  Password: Linux account password

Important:
  - Use different Linux accounts for simultaneous users.
  - Avoid opening a local and XRDP desktop session with the same user.
  - The local GNOME session may remain on Wayland.
  - XRDP sessions use XFCE and Xorg.
  - New users created with adduser will inherit the XRDP configuration.

Installation log:
  ${LOG_FILE}

Backups:
  ${BACKUP_DIR}

Useful checks:
  systemctl status xrdp xrdp-sesman --no-pager
  ss -ltnp | grep 3389
  journalctl -u xrdp -u xrdp-sesman -n 100 --no-pager

EOF

if [[ "$DISABLE_WAYLAND" == true ]]; then
    warning "Wayland was disabled in GDM. Reboot the machine to apply that change."
else
    info "A reboot is normally unnecessary, but recommended before production use."
fi

printf '%s============================================================%s\n' "$BOLD" "$RESET"
