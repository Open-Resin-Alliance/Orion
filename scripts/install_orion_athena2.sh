#!/usr/bin/env bash

# Temporary Orion installer for Athena 2
# Performs the following actions:
# 1. Ensures the script runs with sudo/root privileges.
# 2. Copies /root/nanodlp/hmi/dsi to the invoking user's home directory.
# 3. Downloads Orion release v0.3.2, extracts to ~/orion, and adjusts ownership.
# 4. Creates systemd unit orion.service pointing at the copied dsi binary.
# 5. Disables nanodlp-dsi service and enables the new orion.service.

set -euo pipefail

tmp_tar=""
tmp_dir=""
CLEAR_THUMBNAILS=0

cleanup() {
  if [[ -n "$tmp_tar" && -f "$tmp_tar" ]]; then
    rm -f "$tmp_tar"
  fi
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}

trap cleanup EXIT

SCRIPT_NAME="$(basename "$0")"
ORION_URL="https://github.com/Open-Resin-Alliance/Orion/releases/download/BRANCH_athena_features/orion_armv7.tar.gz"
DOWNSAMPLED_RES="210, 210"

uninstall_orion() {
  local mode=${1:-manual}
  local enable_nano=1
  if [[ $mode == "reinstall" ]]; then
    enable_nano=0
  elif [[ $mode == "reinstall_keep" ]]; then
    enable_nano=0
  fi

  printf '\n[%s] Removing existing Orion installation...\n' "$SCRIPT_NAME"

  if systemctl list-unit-files | grep -q '^orion.service'; then
    systemctl disable --now orion.service || true
  else
    systemctl stop orion.service 2>/dev/null || true
    systemctl disable orion.service 2>/dev/null || true
  fi
  rm -f "$SERVICE_PATH"

  systemctl daemon-reload

  if (( enable_nano )); then
    printf '\n[%s] Attempting to re-enable nanodlp-dsi.service...\n' "$SCRIPT_NAME"
    # Reload systemd in case unit files changed
    systemctl daemon-reload || true

    # Ensure service is not masked, then enable & start it. Prefer --now to
    # enable+start atomically; fall back to start if enable fails.
    if systemctl list-unit-files | grep -q '^nanodlp-dsi.service'; then
      systemctl unmask nanodlp-dsi.service 2>/dev/null || true
      if ! systemctl enable --now nanodlp-dsi.service 2>/dev/null; then
        systemctl start nanodlp-dsi.service 2>/dev/null || true
      fi
    else
      # If the unit is not registered as an installed unit, still try to
      # start it in case the runtime unit exists.
      systemctl start nanodlp-dsi.service 2>/dev/null || true
    fi

    # Print status for debugging in case the start failed
    systemctl --no-pager status nanodlp-dsi.service || true
  fi

  rm -rf "$ORION_DIR"
  rm -f "$DEST_DSI"
  # Delete configs only for full override reinstall or manual uninstall
  if [[ $mode != "reinstall_keep" ]]; then
    if [[ -f "$CONFIG_PATH" ]]; then
      rm -f "$CONFIG_PATH"
    fi
    if [[ -f "$VENDOR_CONFIG_PATH" ]]; then
      rm -f "$VENDOR_CONFIG_PATH"
    fi
  fi

  rm -f "$ACTIVATE_PATH" "$REVERT_PATH"

  # Clear thumbnail cache automatically on full override reinstall
  if [[ $mode == "reinstall" ]]; then
    clear_thumbnail_cache_for_user "$ORIGINAL_USER"
  fi

  if [[ $mode != "reinstall" ]]; then
    printf '\n[%s] Orion has been removed from this system.\n' "$SCRIPT_NAME"
  else
    printf '[%s] Previous installation cleared; continuing with reinstall...\n' "$SCRIPT_NAME"
  fi
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      printf '\n[%s] This script must be run as root or via sudo.\n' "$SCRIPT_NAME" >&2
      exit 1
    fi
    printf '\n[%s] Elevating privileges with sudo...\n' "$SCRIPT_NAME"
    exec sudo -E bash "$0" "$@"
  fi
}

main() {
  require_root "$@"

  # Parse CLI options (e.g., --clear-thumbnails)
  for arg in "$@"; do
    case "$arg" in
      --clear-thumbnails|--clear-thumbnail-cache)
        CLEAR_THUMBNAILS=1
        ;;
    esac
  done

  ORIGINAL_USER=${SUDO_USER:-}
  if [[ -z "$ORIGINAL_USER" || "$ORIGINAL_USER" == "root" ]]; then
    printf '\n[%s] Unable to determine invoking non-root user. Please run with sudo from the target account.\n' "$SCRIPT_NAME" >&2
    exit 1
  fi

  for dep in curl install systemctl tar; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      printf '\n[%s] Required command "%s" not found in PATH.\n' "$SCRIPT_NAME" "$dep" >&2
      exit 1
    fi
  done

  TARGET_HOME=$(eval echo "~${ORIGINAL_USER}")
  if [[ ! -d "$TARGET_HOME" ]]; then
    printf '\n[%s] Home directory for %s not found at %s.\n' "$SCRIPT_NAME" "$ORIGINAL_USER" "$TARGET_HOME" >&2
    exit 1
  fi

  if [[ "$TARGET_HOME" != /home/* ]]; then
    printf '\n[%s] Expected %s to reside under /home (got %s). Adjust the script before proceeding.\n' "$SCRIPT_NAME" "$ORIGINAL_USER" "$TARGET_HOME" >&2
    exit 1
  fi

  SRC_DSI="/root/nanodlp/hmi/dsi"
  DEST_DSI="${TARGET_HOME}/dsi"
  ORION_DIR="${TARGET_HOME}/orion"
  SERVICE_PATH="/etc/systemd/system/orion.service"
  CONFIG_PATH="${TARGET_HOME}/orion.cfg"
  VENDOR_CONFIG_PATH="${TARGET_HOME}/vendor.cfg"
  BIN_DIR="/usr/local/bin"
  ACTIVATE_PATH="${BIN_DIR}/activate_orion"
  REVERT_PATH="${BIN_DIR}/revert_orion"
  CLEAR_THUMBS_PATH="${BIN_DIR}/clear_orion_thumbnails"

  printf '\nTemporary Orion installer for Athena 2\n========================================\n'
  printf ' - Target user  : %s\n' "$ORIGINAL_USER"
  printf ' - Target home  : %s\n' "$TARGET_HOME"
  printf ' - Orion source : %s\n\n' "$ORION_URL"
  printf 'Options:\n'
  printf '  --clear-thumbnails   Clear Orion thumbnail disk cache for the target user during install.\n\n'

  read -r -p "Continue with installation? [y/N] " reply
  reply=${reply:-N}
  if [[ ! $reply =~ ^[Yy]$ ]]; then
    printf '\n[%s] Installation aborted by user.\n' "$SCRIPT_NAME"
    exit 0
  fi

  local existing=false
  if [[ -d "$ORION_DIR" || -f "$SERVICE_PATH" || -f "$CONFIG_PATH" || -f "$DEST_DSI" ]]; then
    existing=true
  fi

  if [[ $existing == true ]]; then
    printf '\n[%s] Existing Orion installation detected.\n' "$SCRIPT_NAME"
    while true; do
      read -r -p "Choose: [O]verride & reinstall (clears cache & configs) / [R]einstall (keep cache & configs) / [T]humbnail cache clear / [U]ninstall / [C]ancel: " choice
      choice=${choice:-C}
      case "$choice" in
        [Oo])
          uninstall_orion reinstall
          break
          ;;
        [Rr])
          uninstall_orion reinstall_keep
          break
          ;;
        [Tt])
          printf '\n[%s] Clearing thumbnail cache for %s...\n' "$SCRIPT_NAME" "$ORIGINAL_USER"
          clear_thumbnail_cache_for_user "$ORIGINAL_USER"
          printf '[%s] Thumbnail cache cleared.\n' "$SCRIPT_NAME"
          exit 0
          ;;
        [Uu])
          uninstall_orion manual
          exit 0
          ;;
        [Cc])
          printf '\n[%s] Operation cancelled.\n' "$SCRIPT_NAME"
          exit 0
          ;;
        *)
          printf '  Invalid selection. Please choose O, R, T, U, or C.\n'
          ;;
      esac
    done
  fi

  if [[ ! -x "$SRC_DSI" ]]; then
    printf '\n[%s] Required source binary %s not found or not executable.\n' "$SCRIPT_NAME" "$SRC_DSI" >&2
    exit 1
  fi

  printf '\n[%s] Copying dsi binary to %s...\n' "$SCRIPT_NAME" "$DEST_DSI"
  install -m 0755 "$SRC_DSI" "$DEST_DSI"
  chown "$ORIGINAL_USER":"$ORIGINAL_USER" "$DEST_DSI"

  tmp_tar=$(mktemp)
  tmp_dir=$(mktemp -d)

  printf '\n[%s] Downloading Orion release...\n' "$SCRIPT_NAME"
  curl -Lf "$ORION_URL" -o "$tmp_tar"

  printf '[%s] Extracting archive to %s...\n' "$SCRIPT_NAME" "$ORION_DIR"
  rm -rf "$ORION_DIR"
  mkdir -p "$ORION_DIR"
  tar -xzf "$tmp_tar" -C "$tmp_dir"
  if [[ -d "$tmp_dir/orion" ]]; then
    cp -a "$tmp_dir/orion/." "$ORION_DIR/"
  else
    cp -a "$tmp_dir/." "$ORION_DIR/"
  fi
  chown -R "$ORIGINAL_USER":"$ORIGINAL_USER" "$ORION_DIR"

  if [[ -f "$CONFIG_PATH" ]]; then
    local ts
    ts=$(date +%s)
    cp "$CONFIG_PATH" "${CONFIG_PATH}.bak.${ts}"
  fi
  if [[ -f "$VENDOR_CONFIG_PATH" ]]; then
    local vts
    vts=$(date +%s)
    cp "$VENDOR_CONFIG_PATH" "${VENDOR_CONFIG_PATH}.bak.${vts}"
  fi
  HOSTNAME_VALUE=$(hostname)
  # Attempt to read a hardware serial from the device tree. Some systems
  # expose a serial at /sys/firmware/devicetree/base/serial-number.
  # The file may contain a trailing NUL; strip it. If unavailable, fall
  # back to a safe default to keep the config valid.
  if [[ -r "/sys/firmware/devicetree/base/serial-number" ]]; then
    MACHINE_SERIAL=$(tr -d '\0' </sys/firmware/devicetree/base/serial-number 2>/dev/null || true)
    # Remove newlines/carriage returns and any remaining non-printables.
    MACHINE_SERIAL=$(printf '%s' "$MACHINE_SERIAL" | tr -d '\r\n' | sed 's/[^[:print:]]//g')
    # Escape any double quotes to keep the JSON valid.
    MACHINE_SERIAL=$(printf '%s' "$MACHINE_SERIAL" | sed 's/"/\\\"/g')
    MACHINE_SERIAL=${MACHINE_SERIAL:-ATHENA2-0001}
    printf '[%s] Detected machine serial: %s\n' "$SCRIPT_NAME" "$MACHINE_SERIAL"
  else
    MACHINE_SERIAL="ATHENA2-0001"
  fi
  printf '\n[%s] Writing default Orion configuration to %s...\n' "$SCRIPT_NAME" "$CONFIG_PATH"
  cat >"$CONFIG_PATH" <<EOF
{
  "general": {
    "themeMode": "glass",
    "colorSeed": "vendor",
    "useUsbByDefault": true
  },
  "advanced": {
    "screenRotation": "0",
    "developerMode": true,
    "backend": "nanodlp"
  },
  "machine": {
    "machineName": "${HOSTNAME_VALUE}",
    "machineSerial": "${MACHINE_SERIAL}",
    "firstRun": true
  },
  "developer": {
    "releaseOverride": true,
    "overrideRelease": "BRANCH_nanodlp_basic_support",
    "overrideUpdateCheck": false
  },
  "topsecret": {
    "selfDestructMode": true
  }
}
EOF
  chown "$ORIGINAL_USER":"$ORIGINAL_USER" "$CONFIG_PATH"

  printf '\n[%s] Writing vendor configuration to %s...\n' "$SCRIPT_NAME" "$VENDOR_CONFIG_PATH"
  cat >"$VENDOR_CONFIG_PATH" <<'EOF'
{
  "vendor": {
    "vendorName": "Concepts 3D",
    "vendorMachineName": "Athena 2",
    "machineModelName": "Athena 2",
    "homePosition": "up",
    "vendorUrl": "https://concepts3d.ca",
    "vendorThemeSeed": "#FFFFA500",
    "vendorThemeGradient": [
      "#FF221505",
      "#FF3A2605",
      "#FF5B3B05"
    ]
  },
  "featureFlags": {
    "enableBetaFeatures": false,
    "enableDeveloperSettings": false,
    "enableAdvancedSettings": true,
    "enableExperimentalFeatures": false,
    "enableResinProfiles": true,
    "enableCustomName": false,
    "hardwareFeatures": {
        "hasHeatedChamber": true,
        "hasHeatedVat": true,
        "hasCamera": true,
        "hasAirFilter": true,
        "hasForceSensor": true
    }
  },
  "advanced": {
    "backend": "nanodlp",
    "defaultLanguage": "en"
  }
}
EOF
  chown "$ORIGINAL_USER":"$ORIGINAL_USER" "$VENDOR_CONFIG_PATH"

  printf '\n[%s] Writing systemd service to %s...\n' "$SCRIPT_NAME" "$SERVICE_PATH"
  cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Orion UI for Athena 2
After=network.target
Requires=network.target

[Service]
Type=simple
User=$ORIGINAL_USER
Group=$ORIGINAL_USER
WorkingDirectory=/home/$ORIGINAL_USER
ExecStart=/home/$ORIGINAL_USER/dsi --drm-vout-display DSI-2 -d "$DOWNSAMPLED_RES" --release /home/$ORIGINAL_USER/orion
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

  printf '\n[%s] Disabling existing nanodlp-dsi service (if present)...\n' "$SCRIPT_NAME"
  if systemctl list-unit-files | grep -q '^nanodlp-dsi.service'; then
    systemctl disable --now nanodlp-dsi.service || true
  else
    systemctl stop nanodlp-dsi.service 2>/dev/null || true
    systemctl disable nanodlp-dsi.service 2>/dev/null || true
  fi

  printf '\n[%s] Enabling and starting orion.service...\n' "$SCRIPT_NAME"
  systemctl daemon-reload
  systemctl enable orion.service
  systemctl start orion.service

  mkdir -p "$BIN_DIR"

  printf '\n[%s] Installing helper commands: %s and %s...\n' "$SCRIPT_NAME" "$ACTIVATE_PATH" "$REVERT_PATH"

  cat >"$ACTIVATE_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E "$0" "$@"
  else
    echo "activate_orion must be run as root or via sudo" >&2
    exit 1
  fi
fi

systemctl stop nanodlp-dsi.service 2>/dev/null || true
systemctl disable nanodlp-dsi.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable orion.service
systemctl start orion.service
EOF
  chmod 0755 "$ACTIVATE_PATH"

  cat >"$REVERT_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E "$0" "$@"
  else
    echo "revert_orion must be run as root or via sudo" >&2
    exit 1
  fi
fi

systemctl stop orion.service 2>/dev/null || true
systemctl disable orion.service 2>/dev/null || true
systemctl daemon-reload
systemctl enable nanodlp-dsi.service
systemctl start nanodlp-dsi.service
EOF
  chmod 0755 "$REVERT_PATH"

  # Install helper to clear thumbnail cache for the Orion user
  printf '\n[%s] Installing helper command: %s...\n' "$SCRIPT_NAME" "$CLEAR_THUMBS_PATH"
  cat >"$CLEAR_THUMBS_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E "$0" "$@"
  else
    echo "clear_orion_thumbnails must be run as root or via sudo" >&2
    exit 1
  fi
fi

# Determine target non-root user
TARGET_USER=${SUDO_USER:-${USER}}
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  echo "Unable to determine non-root target user." >&2
  exit 1
fi

TARGET_HOME=$(eval echo "~${TARGET_USER}")
if [[ ! -d "${TARGET_HOME}" ]]; then
  echo "Home directory for ${TARGET_USER} not found at ${TARGET_HOME}" >&2
  exit 1
fi

# Default Linux cache dir used by the app: $HOME/.cache/orion_thumbnail_cache
CACHE_DIR="${TARGET_HOME}/.cache/orion_thumbnail_cache"

echo "Clearing Orion thumbnail cache at ${CACHE_DIR} (user: ${TARGET_USER})..."
rm -rf -- "${CACHE_DIR}" || true
echo "Done."
EOF
  chmod 0755 "$CLEAR_THUMBS_PATH"

  # If requested via CLI option, clear thumbnail cache now for target user
  if [[ "$CLEAR_THUMBNAILS" -eq 1 ]]; then
    printf '\n[%s] Clearing thumbnail cache for %s...\n' "$SCRIPT_NAME" "$ORIGINAL_USER"
    clear_thumbnail_cache_for_user "$ORIGINAL_USER"
  fi

  printf '\nInstallation complete!\n'
  printf ' Default config written to %s.\n' "$CONFIG_PATH"
  printf ' Use "activate_orion" to launch Orion and "revert_orion" to restore NanoDLP.\n'
  printf ' Use "clear_orion_thumbnails" to clear the thumbnail disk cache.\n'
  systemctl status orion.service --no-pager
}

# Helper: clear thumbnail disk cache for a given user name
clear_thumbnail_cache_for_user() {
  local user_name="$1"
  local home_dir
  home_dir=$(eval echo "~${user_name}")
  if [[ -z "$home_dir" || ! -d "$home_dir" ]]; then
    printf '[%s] Cannot resolve home for user %s; skipping cache clear.\n' "$SCRIPT_NAME" "$user_name" >&2
    return 0
  fi

  # Default Linux cache dir
  local cache_dir_default="${home_dir}/.cache/orion_thumbnail_cache"
  # If XDG_CACHE_HOME is defined for the environment, also clear that path
  local xdg_cache_home="${XDG_CACHE_HOME:-}"
  local cache_dir_xdg=""
  if [[ -n "$xdg_cache_home" ]]; then
    cache_dir_xdg="${xdg_cache_home%/}/orion_thumbnail_cache"
  fi

  printf '[%s] Clearing thumbnail cache at %s\n' "$SCRIPT_NAME" "$cache_dir_default"
  rm -rf -- "$cache_dir_default" || true
  if [[ -n "$cache_dir_xdg" ]]; then
    printf '[%s] Clearing thumbnail cache at %s\n' "$SCRIPT_NAME" "$cache_dir_xdg"
    rm -rf -- "$cache_dir_xdg" || true
  fi
}

main "$@"