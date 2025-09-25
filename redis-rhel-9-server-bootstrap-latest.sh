#!/bin/bash
set -euo pipefail

# Bootstrap Script for Redis Software on RHEL 9
# Author: Gabriel Cerioni - Redis Solutions Architect
# Date: 2024-11-01 (refactored: 2025-08-21)

# -------------------------
# Config
# -------------------------
FILES=(
  "https://redis-latam-rdi-poc-deps.s3.us-east-1.amazonaws.com/redislabs-7.22.2-14-rhel9-x86_64.tar"
)
DEST_DIR="/root"
SYSCTL_DROPIN="/etc/sysctl.d/99-redis.conf"
FSTAB="/etc/fstab"

# -------------------------
# Helpers
# -------------------------
log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
die() { echo -e "[ERROR] $*" >&2; exit 1; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Please run as root."
  fi
}

pkg_install() {
  log "Updating system and installing required packages..."
  dnf -y update
  dnf -y install wget lsof iproute
  log "System updated and dependencies installed."
}

download_artifacts() {
  log "Downloading artifacts to ${DEST_DIR}..."
  for FILE_URL in "${FILES[@]}"; do
    FILE_NAME="$(basename "$FILE_URL")"
    FOLDER_NAME="${FILE_NAME%.*}"
    mkdir -p "${DEST_DIR}/${FOLDER_NAME}"
    if [[ ! -f "${DEST_DIR}/${FOLDER_NAME}/${FILE_NAME}" ]]; then
      wget -q "${FILE_URL}" -P "${DEST_DIR}/${FOLDER_NAME}/"
      log "Downloaded ${FILE_NAME} -> ${DEST_DIR}/${FOLDER_NAME}/"
    else
      log "Already present: ${DEST_DIR}/${FOLDER_NAME}/${FILE_NAME}"
    fi
  done
  log "Downloads complete."
}

tune_sysctl() {
  log "Applying sysctl tuning for ephemeral ports (avoid RS collisions)..."

  # 1) Set runtime value immediately (current boot)
  sysctl -w net.ipv4.ip_local_port_range="30000 65535" >/dev/null

  # 2) Persist in /etc/sysctl.conf (loaded after sysctl.d and wins)
  if grep -qE '^\s*net\.ipv4\.ip_local_port_range\s*=' /etc/sysctl.conf 2>/dev/null; then
    sed -ri 's|^\s*net\.ipv4\.ip_local_port_range\s*=.*$|net.ipv4.ip_local_port_range = 30000 65535|' /etc/sysctl.conf
  else
    printf '\n# Redis Enterprise: avoid ephemeral port collisions\nnet.ipv4.ip_local_port_range = 30000 65535\n' >> /etc/sysctl.conf
  fi
  sysctl -p /etc/sysctl.conf >/dev/null

  # 3) Also keep a drop-in (harmless; helpful on clean hosts)
  mkdir -p "$(dirname "${SYSCTL_DROPIN}")"
  cat > "${SYSCTL_DROPIN}" <<EOF
# Redis Enterprise: avoid ephemeral port collisions with RS ports
net.ipv4.ip_local_port_range = 30000 65535
EOF

  log "Sysctl applied (runtime + persisted)."
}

disable_swap() {
  log "Disabling swap..."
  swapoff -a || true
  if [[ -f "${FSTAB}" ]]; then
    cp -a "${FSTAB}"{,.bak.$(date +%Y%m%d%H%M%S)}
    # Comment any non-commented lines that reference 'swap'
    sed -ri 's@^([^#].*\bswap\b.*)$@#\1@' "${FSTAB}"
  fi
  if swapon --show | grep -q 'swap'; then
    die "Swap still active after attempting to disable. Investigate manually."
  fi
  log "Swap disabled and will remain off after reboot."
}

service_stop_disable() {
  local svc="$1"
  if systemctl list-unit-files | grep -q "^${svc}\.service"; then
    if systemctl is-active --quiet "${svc}"; then
      log "Stopping ${svc}..."
      systemctl stop "${svc}"
    fi
    if systemctl is-enabled --quiet "${svc}"; then
      log "Disabling ${svc}..."
      systemctl disable "${svc}"
    fi
  fi
}

ensure_port_53_free() {
  log "Ensuring port 53/UDP and 53/TCP are free..."

  # 1) If dnsmasq is installed/running, stop/disable it
  if command -v dnsmasq >/dev/null 2>&1 || rpm -q dnsmasq >/dev/null 2>&1; then
    if systemctl is-active --quiet dnsmasq; then
      warn "dnsmasq is active; stopping to free port 53."
    fi
    service_stop_disable "dnsmasq"
  fi

  # 2) Also consider other common resolvers that may hold :53
  service_stop_disable "named"              # BIND
  service_stop_disable "systemd-resolved"   # uncommon on RHEL but safe

  # 3) Re-check port usage (both TCP/UDP)
  local offenders=""
  offenders="$(ss -tulpnH | awk '($5 ~ /(^|:|\[|\*|\])53$/){print}' || true)"

  if [[ -n "${offenders}" ]]; then
    echo "${offenders}" | while read -r line; do
      warn "Port 53 in use by: ${line}"
    done
    die "Port 53 is in use even after remediation. Free it and re-run."
  fi

  log "Port 53 is free."
}

validate() {
  log "Validating setup..."
  # files present
  for FILE_URL in "${FILES[@]}"; do
    FILE_NAME="$(basename "$FILE_URL")"
    FOLDER_NAME="${FILE_NAME%.*}"
    [[ -f "${DEST_DIR}/${FOLDER_NAME}/${FILE_NAME}" ]] \
      && log "OK: ${DEST_DIR}/${FOLDER_NAME}/${FILE_NAME}" \
      || die "Missing: ${DEST_DIR}/${FOLDER_NAME}/${FILE_NAME}"
  done

  # sysctl applied (read kernel value, not files)
  local pr first last
  pr="$(sysctl -n net.ipv4.ip_local_port_range 2>/dev/null || true)"  # e.g. "30000 65535"
  first="$(awk '{print $1}' <<<"$pr")"
  last="$(awk '{print $2}' <<<"$pr")"
  if [[ "$first" == "30000" && "$last" == "65535" ]]; then
    log "OK: sysctl port range set to ${first} ${last}."
  else
    die "sysctl port range not set (got: '${pr}')."
  fi

  # swap off
  if ! swapon --show | grep -q 'swap'; then
    log "OK: swap is off."
  else
    die "Swap still on."
  fi

  # port 53 free
  if ss -tulpnH | awk '($5 ~ /(^|:|\[|\*|\])53$/){exit 1}'; then
    log "OK: port 53 free."
  else
    die "Port 53 not free."
  fi

  log "All validations passed."
}

main() {
  require_root
  pkg_install
  download_artifacts
  tune_sysctl
  disable_swap
  ensure_port_53_free
  validate
  log "Bootstrap completed successfully."
  log "If you plan to use RoF/Flex/Auto-Tier, remember to run /opt/redislabs/sbin/prepare_flash.sh after install.sh."
}

main "$@"
