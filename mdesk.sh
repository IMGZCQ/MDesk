#!/usr/bin/env bash
#
# MDesk Linux installer / uninstaller
#
# Usage:
#   sudo bash mdesk.sh                Detect installation, then install or manage it
#   sudo bash mdesk.sh install        Force install or upgrade
#   sudo bash mdesk.sh uninstall      Force uninstall
#   sudo mdeskctl uninstall
#
# Optional environment variables:
#   MDESK_PORT              Default service port (default: 19188)
#   MDESK_INSTALL_DIR       Default install directory (default: /opt/MDesk)
#   MDESK_GITHUB_PROXY      Comma-separated GitHub accelerators. The default
#                           list is replaced when this variable is set.
#                           Each item can contain the {url} placeholder.

set -Eeuo pipefail
umask 022

APP_NAME="MDesk"
SERVICE_NAME="mdesk"
DEFAULT_PORT="19188"
DEFAULT_INSTALL_DIR="/opt/MDesk"
REPO="IMGZCQ/MDesk"
PRIMARY_DOWNLOAD_BASE="https://fndesk.imcq.top/FPK/MDesk"
STATE_DIR="/etc/mdesk"
STATE_FILE="${STATE_DIR}/install.conf"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
COMMAND_FILE="/usr/local/sbin/mdeskctl"
DOWNLOAD_TIMEOUT="${MDESK_DOWNLOAD_TIMEOUT:-900}"

DEFAULT_MIRRORS=(
  "https://gh-proxy.com/"
  "https://gh-proxy.org/"
  "https://ghfast.top/"
  "https://ghps.cc/"
  "https://ghproxy.org/"
  "https://ghproxy.cn/"
  "https://ghproxy.net/"
  "https://gh.llkk.cc/"
  "https://github.moeyy.xyz/"
  "https://gh-proxy.net/"
)

MIRRORS=()
TMP_DIR=""
SCRIPT_PATH="$0"
SCRIPT_IS_FILE=0

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'
else
  C_RESET=""
  C_BLUE=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
fi

info() {
  printf '%s[信息]%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

success() {
  printf '%s[完成]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

warn() {
  printf '%s[警告]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
}

die() {
  printf '%s[错误]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    rm -rf -- "$TMP_DIR"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
MDesk Linux 安装脚本

用法：
  sudo bash mdesk.sh                自动检测：未安装则安装，已安装则选择操作
  sudo bash mdesk.sh install        强制安装或升级 MDesk
  sudo bash mdesk.sh uninstall      强制卸载 MDesk
  sudo mdeskctl uninstall           卸载 MDesk（安装后）
  sudo bash mdesk.sh --help         显示帮助

未安装时，安装向导会询问：
  1. 服务端口，留空使用 19188
  2. 安装目录，留空使用 /opt/MDesk

检测到已安装时，可选择重新安装/升级、卸载或取消。
卸载向导会询问是否删除用户数据，默认保留。

脚本会优先从 MDesk 镜像下载，失败后自动识别 amd64 / arm64 / armv7，
测速并选择可用的 GitHub 加速地址，下载 GitHub 最新 Release 二进制
文件，然后注册 systemd 服务并设置开机自启。

可选环境变量：
  MDESK_PORT             指定默认端口
  MDESK_INSTALL_DIR      指定默认安装目录
  MDESK_GITHUB_PROXY     逗号分隔的加速地址，支持 {url} 占位符
  MDESK_DOWNLOAD_TIMEOUT 下载超时秒数，默认 900
EOF
}

resolve_script_path() {
  local candidate="${BASH_SOURCE[0]:-}"
  SCRIPT_PATH="$0"

  if [[ -n "$candidate" && -f "$candidate" && -r "$candidate" ]]; then
    SCRIPT_IS_FILE=1
    if command -v readlink >/dev/null 2>&1; then
      local resolved
      resolved="$(readlink -f "$candidate" 2>/dev/null || true)"
      if [[ -n "$resolved" ]]; then
        SCRIPT_PATH="$resolved"
      else
        SCRIPT_PATH="$candidate"
      fi
    else
      SCRIPT_PATH="$candidate"
    fi
  fi
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    info "需要管理员权限，正在通过 sudo 重新运行脚本。"
    [[ "$SCRIPT_IS_FILE" -eq 1 ]] || die "管道安装请使用 root 用户运行：curl -fsSL https://raw.githubusercontent.com/${REPO}/main/mdesk.sh | sudo bash"
    exec sudo -E "$SCRIPT_PATH" "$@"
  fi
  if [[ "$SCRIPT_IS_FILE" -eq 1 ]]; then
    die "请使用 root 用户运行：sudo bash $SCRIPT_PATH"
  fi
  die "请使用 root 用户运行，例如：curl -fsSL https://raw.githubusercontent.com/${REPO}/main/mdesk.sh | sudo bash"
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "缺少必要命令：$name"
}

require_base_commands() {
  local name
  for name in awk cat cut grep head install mkdir mktemp mv od rm rmdir sed sort tr uname; do
    require_command "$name"
  done
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    die "缺少下载工具，请先安装 curl 或 wget。"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

init_mirrors() {
  local configured="${MDESK_GITHUB_MIRRORS:-${MDESK_GITHUB_PROXY:-}}"
  local item
  local -a items=()

  MIRRORS=()
  if [[ -n "$configured" ]]; then
    IFS=',' read -r -a items <<< "$configured"
    for item in "${items[@]}"; do
      item="$(trim "$item")"
      [[ -n "$item" ]] || continue
      if [[ "$item" != http://* && "$item" != https://* ]]; then
        warn "忽略无效加速地址：$item"
        continue
      fi
      MIRRORS+=("$item")
    done
  else
    MIRRORS=("${DEFAULT_MIRRORS[@]}")
  fi
}

prompt_value() {
  local label="$1"
  local default_value="$2"
  local answer=""

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf '%s [%s]: ' "$label" "$default_value" > /dev/tty
    IFS= read -r answer < /dev/tty || true
  elif [[ -t 0 ]]; then
    printf '%s [%s]: ' "$label" "$default_value"
    IFS= read -r answer || true
  else
    printf '%s' "$default_value"
    return
  fi

  if [[ -z "$answer" ]]; then
    printf '%s' "$default_value"
  else
    printf '%s' "$answer"
  fi
}

prompt_yes_no() {
  local label="$1"
  local default_answer="${2:-n}"
  local answer=""
  local suffix="[y/N]"

  if [[ "$default_answer" == "y" ]]; then
    suffix="[Y/n]"
  fi

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf '%s %s: ' "$label" "$suffix" > /dev/tty
    IFS= read -r answer < /dev/tty || true
  elif [[ -t 0 ]]; then
    printf '%s %s: ' "$label" "$suffix"
    IFS= read -r answer || true
  else
    [[ "$default_answer" == "y" ]]
    return
  fi

  answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$answer" ]]; then
    [[ "$default_answer" == "y" ]]
    return
  fi
  case "$answer" in
    y|yes|是|好|确定) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_path() {
  local value="$1"
  case "$value" in
    "~") value="${HOME:-/root}" ;;
    "~/"*) value="${HOME:-/root}/${value#\~/}" ;;
  esac
  printf '%s' "$value"
}

validate_absolute_path() {
  local value="$1"
  [[ -n "$value" ]] || die "路径不能为空。"
  [[ "$value" == /* ]] || die "请输入绝对路径，例如 /opt/MDesk。"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die "路径不能包含换行符。"
}

validate_install_directory() {
  local value="$1"
  case "$value" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      die "不允许直接安装到系统目录：$value"
      ;;
  esac
  [[ "$value" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "安装目录只能包含字母、数字、点、下划线、斜杠和连字符：$value"
}

resolve_directory() {
  local path="$1"
  mkdir -p -- "$path" || die "无法创建目录：$path"
  [[ -d "$path" ]] || die "路径不是目录：$path"
  (cd "$path" && pwd -P)
}

validate_port() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  ((value >= 1 && value <= 65535)) || return 1
  return 0
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .
    return
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk -v suffix=":${port}" '
      $4 ~ suffix "$" { found = 1 }
      END { exit(found ? 0 : 1) }
    '
    return
  fi
  return 1
}

load_state() {
  INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
  DATA_DIR="${DATA_DIR:-${INSTALL_DIR}/data}"
  LOG_DIR="${LOG_DIR:-${INSTALL_DIR}/logs}"
  LOG_FILE="${LOG_FILE:-${LOG_DIR}/mdesk.log}"
  PORT="${PORT:-$DEFAULT_PORT}"
  BINARY_PATH="${BINARY_PATH:-${INSTALL_DIR}/${APP_NAME}}"

  if [[ -r "$STATE_FILE" ]]; then
    # The state file is root-owned and created by this installer.
    # shellcheck disable=SC1090
    . "$STATE_FILE"
  fi
}

detect_arch() {
  local machine
  machine="$(uname -m | tr '[:upper:]' '[:lower:]')"
  case "$machine" in
    x86_64|amd64)
      printf 'amd64'
      ;;
    aarch64|arm64)
      printf 'arm64'
      ;;
    armv7l|armv7|armv8l|armhf)
      printf 'armv7'
      ;;
    *)
      die "暂不支持当前 CPU 架构：$machine"
      ;;
  esac
}

asset_name_for_arch() {
  case "$1" in
    amd64|arm64|armv7)
      printf 'MDesk-linux-%s' "$1"
      ;;
    *)
      die "未知架构：$1"
      ;;
  esac
}

build_candidate_urls() {
  local source_url="$1"
  local prefix=""

  printf '%s\n' "$source_url"
  for prefix in "${MIRRORS[@]}"; do
    if [[ "$prefix" == *"{url}"* ]]; then
      printf '%s\n' "${prefix//\{url\}/$source_url}"
    else
      printf '%s/%s\n' "${prefix%/}" "$source_url"
    fi
  done | awk '!seen[$0]++'
}

rank_urls() {
  local -a urls=("$@")
  local -a pids=()
  local probe_dir="${TMP_DIR}/probes"
  local index=0
  local url=""
  local pid=""

  if [[ "${#urls[@]}" -eq 0 ]]; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' "${urls[@]}"
    return
  fi

  mkdir -p "$probe_dir"
  for url in "${urls[@]}"; do
    (
      local elapsed=""
      elapsed="$(curl -fsSL -o /dev/null --range 0-0 \
        --connect-timeout 3 --max-time 8 --retry 0 \
        -w '%{time_total}' "$url" 2>/dev/null)" || exit 1
      [[ -n "$elapsed" ]] || exit 1
      printf '%s\t%s\n' "$elapsed" "$url" > "${probe_dir}/${index}.result"
    ) &
    pids+=("$!")
    index=$((index + 1))
  done

  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  if compgen -G "${probe_dir}/*.result" >/dev/null 2>&1; then
    cat "${probe_dir}"/*.result | sort -n -k1,1 | cut -f2-
  else
    warn "加速地址测速未成功，按默认顺序尝试。"
    printf '%s\n' "${urls[@]}"
  fi
}

download_file() {
  local url="$1"
  local destination="$2"

  rm -f -- "$destination"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 1 \
      --connect-timeout 10 --max-time "$DOWNLOAD_TIMEOUT" \
      --progress-bar -o "$destination" "$url"
    return
  fi

  wget --tries=3 --timeout=30 -O "$destination" "$url"
}

fetch_text() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 5 --max-time 15 "$url"
    return
  fi

  wget -qO- --timeout=15 --tries=1 "$url"
}

resolve_latest_tag() {
  local api_url="https://api.github.com/repos/${REPO}/releases/latest"
  local candidate=""
  local body=""
  local tag=""

  while IFS= read -r candidate; do
    body="$(fetch_text "$candidate" 2>/dev/null || true)"
    [[ -n "$body" ]] || continue
    tag="$(printf '%s' "$body" |
      sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
      head -n 1)"
    if [[ -n "$tag" ]]; then
      printf '%s' "$tag"
      return 0
    fi
  done < <(build_candidate_urls "$api_url")

  return 1
}

validate_elf_arch() {
  local file="$1"
  local arch="$2"
  local magic=""
  local machine=""
  local expected=""

  [[ -s "$file" ]] || return 1
  magic="$(od -An -N4 -tx1 "$file" 2>/dev/null | tr -d '[:space:]')"
  [[ "$magic" == "7f454c46" ]] || return 1
  machine="$(od -An -j18 -N2 -tx1 "$file" 2>/dev/null | tr -d '[:space:]')"

  case "$arch" in
    amd64) expected="3e00" ;;
    arm64) expected="b700" ;;
    armv7) expected="2800" ;;
    *) return 1 ;;
  esac
  [[ "$machine" == "$expected" ]]
}

download_binary_with_candidates() {
  local destination="$1"
  local arch="$2"
  local -a urls=("${@:3}")
  local candidate=""

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    info "尝试下载：$candidate"
    if download_file "$candidate" "$destination"; then
      if validate_elf_arch "$destination" "$arch"; then
        return 0
      fi
      warn "下载内容不是匹配 ${arch} 的 Linux ELF 文件，继续尝试其他地址。"
      rm -f -- "$destination"
    else
      warn "下载失败：$candidate"
      rm -f -- "$destination"
    fi
  done < <(rank_urls "${urls[@]}")

  return 1
}

download_latest_binary() {
  local destination="$1"
  local arch="$2"
  local asset=""
  local latest_url=""
  local primary_url=""
  local tag=""
  local tagged_url=""
  local -a primary_urls=()
  local -a latest_urls=()
  local -a tagged_urls=()
  local url=""

  asset="$(asset_name_for_arch "$arch")"
  primary_url="${PRIMARY_DOWNLOAD_BASE}/${asset}"
  primary_urls=("$primary_url")

  info "优先从 MDesk 镜像下载：$primary_url"
  if download_binary_with_candidates "$destination" "$arch" "${primary_urls[@]}"; then
    return 0
  fi

  warn "MDesk 镜像下载失败，回退到 GitHub 加速地址。"
  latest_url="https://github.com/${REPO}/releases/latest/download/${asset}"
  while IFS= read -r url; do
    latest_urls+=("$url")
  done < <(build_candidate_urls "$latest_url")

  info "开始测速并选择 GitHub 加速地址。"
  if download_binary_with_candidates "$destination" "$arch" "${latest_urls[@]}"; then
    return 0
  fi

  warn "latest/download 地址均不可用，尝试通过 GitHub API 获取最新版本号。"
  if tag="$(resolve_latest_tag)"; then
    info "GitHub 最新版本：$tag"
    tagged_url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
    while IFS= read -r url; do
      tagged_urls+=("$url")
    done < <(build_candidate_urls "$tagged_url")
    if download_binary_with_candidates "$destination" "$arch" "${tagged_urls[@]}"; then
      return 0
    fi
  fi

  die "无法下载 MDesk 最新版，请检查网络或通过 MDESK_GITHUB_PROXY 指定可用加速地址。"
}

write_state() {
  mkdir -p -- "$STATE_DIR"
  {
    printf 'INSTALL_DIR=%q\n' "$INSTALL_DIR"
    printf 'DATA_DIR=%q\n' "$DATA_DIR"
    printf 'LOG_DIR=%q\n' "$LOG_DIR"
    printf 'LOG_FILE=%q\n' "$LOG_FILE"
    printf 'PORT=%q\n' "$PORT"
    printf 'BINARY_PATH=%q\n' "$BINARY_PATH"
  } > "$STATE_FILE"
  chmod 0600 "$STATE_FILE"
}

write_service() {
  cat > "$UNIT_FILE" <<EOF
[Unit]
Description=MDesk service
Documentation=https://github.com/${REPO}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$BINARY_PATH -port $PORT -data $DATA_DIR -log $LOG_FILE
Restart=on-failure
RestartSec=5
TimeoutStopSec=20
KillMode=mixed
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
  chmod 0644 "$UNIT_FILE"
}

download_installer_copy() {
  local destination="$1"
  local source_url="https://raw.githubusercontent.com/${REPO}/main/mdesk.sh"
  local -a urls=()
  local url=""
  local candidate=""

  while IFS= read -r url; do
    urls+=("$url")
  done < <(build_candidate_urls "$source_url")

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if download_file "$candidate" "$destination" >/dev/null 2>&1; then
      if head -n 1 "$destination" 2>/dev/null | grep -q '^#!/usr/bin/env bash$'; then
        return 0
      fi
    fi
    rm -f -- "$destination"
  done < <(rank_urls "${urls[@]}")

  return 1
}

write_fallback_helper() {
  local destination="$1"

  cat > "$destination" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO="IMGZCQ/MDesk"
SOURCE_URL="https://raw.githubusercontent.com/${REPO}/main/mdesk.sh"
MIRRORS=(
  "https://gh-proxy.com/"
  "https://gh-proxy.org/"
  "https://ghfast.top/"
  "https://ghps.cc/"
  "https://ghproxy.org/"
  "https://ghproxy.cn/"
  "https://ghproxy.net/"
  "https://gh.llkk.cc/"
  "https://github.moeyy.xyz/"
  "https://gh-proxy.net/"
)

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mdeskctl.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT
SCRIPT_FILE="${TMP_DIR}/mdesk.sh"

URLS=("$SOURCE_URL")
for prefix in "${MIRRORS[@]}"; do
  URLS+=("${prefix%/}/${SOURCE_URL}")
done

for url in "${URLS[@]}"; do
  rm -f -- "$SCRIPT_FILE"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 10 --max-time 60 --retry 1 \
      -o "$SCRIPT_FILE" "$url" 2>/dev/null || continue
  else
    wget -q --timeout=20 --tries=1 -O "$SCRIPT_FILE" "$url" || continue
  fi
  if head -n 1 "$SCRIPT_FILE" 2>/dev/null | grep -q '^#!/usr/bin/env bash$'; then
    exec bash "$SCRIPT_FILE" "$@"
  fi
done

printf '[错误] 无法下载 MDesk 安装脚本，暂时无法执行卸载。\n' >&2
exit 1
EOF
}

install_command_helper() {
  local temporary=""

  [[ "$SCRIPT_PATH" != "$COMMAND_FILE" ]] || return 0
  temporary="$(mktemp "${COMMAND_FILE}.XXXXXX")"

  if [[ "$SCRIPT_IS_FILE" -eq 1 && -f "$SCRIPT_PATH" && -r "$SCRIPT_PATH" ]]; then
    install -m 0755 "$SCRIPT_PATH" "$temporary"
  else
    info "检测到管道方式运行，正在保存卸载命令 mdeskctl。"
    if ! download_installer_copy "$temporary"; then
      warn "暂时无法重新下载安装脚本，将创建联网卸载命令。"
      write_fallback_helper "$temporary"
    fi
  fi

  chmod 0755 "$temporary"
  mv -f -- "$temporary" "$COMMAND_FILE"
}

install_mdesk() {
  require_base_commands
  require_command systemctl

  if [[ ! -d /run/systemd/system ]]; then
    die "当前系统未运行 systemd，无法注册开机自启服务。"
  fi

  init_mirrors
  load_state

  local default_port="${MDESK_PORT:-${PORT:-$DEFAULT_PORT}}"
  local default_install_dir="${MDESK_INSTALL_DIR:-${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}}"
  local arch=""
  local input=""
  local resolved=""
  local temporary_binary=""
  local service_was_active="no"

  printf '\n%sMDesk Linux 安装向导%s\n\n' "$C_BLUE" "$C_RESET"

  while true; do
    input="$(prompt_value "请输入服务端口" "$default_port")"
    if ! validate_port "$input"; then
      warn "端口必须是 1-65535 之间的整数。"
      continue
    fi
    if port_in_use "$input" && ! systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
      warn "端口 ${input} 已被其他程序占用，请换一个端口。"
      continue
    fi
    PORT="$input"
    break
  done

  input="$(prompt_value "请输入安装目录" "$default_install_dir")"
  input="$(normalize_path "$input")"
  validate_absolute_path "$input"
  INSTALL_DIR="$(resolve_directory "$input")"
  validate_install_directory "$INSTALL_DIR"
  DATA_DIR="${INSTALL_DIR}/data"
  LOG_DIR="${INSTALL_DIR}/logs"
  LOG_FILE="${LOG_DIR}/mdesk.log"
  BINARY_PATH="${INSTALL_DIR}/${APP_NAME}"

  mkdir -p -- "$DATA_DIR" "$LOG_DIR"
  arch="$(detect_arch)"
  temporary_binary="${TMP_DIR}/MDesk-linux-${arch}"

  printf '\n'
  info "架构：$arch"
  info "端口：$PORT"
  info "安装目录：$INSTALL_DIR"
  info "数据目录：$DATA_DIR"
  printf '\n'

  download_latest_binary "$temporary_binary" "$arch"
  chmod 0755 "$temporary_binary"

  if systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
    service_was_active="yes"
    info "正在停止旧服务。"
    systemctl stop "${SERVICE_NAME}.service" || true
  fi

  install -m 0755 "$temporary_binary" "${INSTALL_DIR}/.MDesk.new"
  mv -f -- "${INSTALL_DIR}/.MDesk.new" "$BINARY_PATH"
  chmod 0755 "$BINARY_PATH"

  write_state
  write_service
  install_command_helper

  info "正在注册并启动 systemd 服务。"
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service" >/dev/null
  if ! systemctl restart "${SERVICE_NAME}.service"; then
    systemctl status "${SERVICE_NAME}.service" --no-pager || true
    printf '\n%s\n' "systemd unit 内容：" >&2
    cat "$UNIT_FILE" >&2 || true
    die "启动失败，请检查上方 unit 内容和 systemd 日志。"
  fi
  sleep 2

  if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    systemctl status "${SERVICE_NAME}.service" --no-pager || true
    die "服务启动失败，请使用 journalctl -u ${SERVICE_NAME}.service -n 100 查看日志。"
  fi

  if [[ "$service_was_active" == "yes" ]]; then
    success "MDesk 已升级并重新启动。"
  else
    success "MDesk 已安装并设置为开机自启。"
  fi
  printf '\n'
  printf '  管理地址：http://<服务器IP>:%s/@admin\n' "$PORT"
  printf '  安装目录：%s\n' "$INSTALL_DIR"
  printf '  数据目录：%s\n' "$DATA_DIR"
  printf '  服务名称：%s.service\n' "$SERVICE_NAME"
  printf '  卸载命令：sudo %s uninstall\n' "$COMMAND_FILE"
  printf '\n'
}

safe_remove_tree() {
  local target="$1"
  local resolved=""

  [[ -n "$target" ]] || die "拒绝删除空路径。"
  target="$(normalize_path "$target")"
  validate_absolute_path "$target"
  resolved="$(readlink -f "$target" 2>/dev/null || printf '%s' "$target")"

  case "$resolved" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/usr/local|/var)
      die "拒绝删除系统目录：$resolved"
      ;;
  esac
  [[ "$resolved" == /* && "${#resolved}" -gt 4 ]] || die "拒绝删除危险路径：$resolved"

  rm -rf -- "$target"
}

uninstall_mdesk() {
  require_command systemctl
  load_state
  validate_install_directory "$INSTALL_DIR"
  [[ "$DATA_DIR" == "$INSTALL_DIR"/* ]] || die "状态文件中的用户数据目录无效：$DATA_DIR"
  [[ "$LOG_DIR" == "$INSTALL_DIR"/* ]] || die "状态文件中的日志目录无效：$LOG_DIR"
  [[ "$BINARY_PATH" == "$INSTALL_DIR"/* ]] || die "状态文件中的程序路径无效：$BINARY_PATH"

  local delete_data="no"
  local keep_message=""

  printf '\n%sMDesk Linux 卸载向导%s\n\n' "$C_BLUE" "$C_RESET"
  info "服务名称：${SERVICE_NAME}.service"
  info "安装目录：$INSTALL_DIR"
  info "数据目录：$DATA_DIR"
  printf '\n'

  if prompt_yes_no "是否删除用户数据（${DATA_DIR}）？" "n"; then
    delete_data="yes"
  fi

  info "正在停止服务。"
  systemctl disable --now "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
  rm -f -- "$UNIT_FILE"
  systemctl daemon-reload >/dev/null 2>&1 || true

  rm -f -- "$BINARY_PATH"
  rm -f -- "${INSTALL_DIR}/.MDesk.new" 2>/dev/null || true

  if [[ "$delete_data" == "yes" ]]; then
    safe_remove_tree "$DATA_DIR"
    rm -rf -- "$LOG_DIR" 2>/dev/null || true
    rmdir "$INSTALL_DIR" 2>/dev/null || true
    success "MDesk 已卸载，用户数据已删除。"
  else
    rm -rf -- "$LOG_DIR" 2>/dev/null || true
    rmdir "$INSTALL_DIR" 2>/dev/null || true
    keep_message="用户数据已保留：$DATA_DIR"
    success "MDesk 已卸载，用户数据已保留。"
  fi

  rm -f -- "$STATE_FILE"
  rmdir "$STATE_DIR" 2>/dev/null || true
  rm -f -- "$COMMAND_FILE"

  printf '\n'
  if [[ -n "$keep_message" ]]; then
    printf '  %s\n' "$keep_message"
  fi
  printf '  如需重新安装：curl -fsSL https://raw.githubusercontent.com/%s/main/mdesk.sh | sudo bash\n' "$REPO"
  printf '\n'
}

detect_installation() {
  load_state

  [[ -e "$STATE_FILE" || -e "$UNIT_FILE" || -e "$BINARY_PATH" || -e "$COMMAND_FILE" ]]
}

choose_installed_action() {
  load_state

  local answer=""

  printf '\n%s检测到 MDesk 已安装。%s\n\n' "$C_YELLOW" "$C_RESET"
  printf '  安装目录：%s\n' "$INSTALL_DIR"
  printf '  数据目录：%s\n' "$DATA_DIR"
  printf '  服务名称：%s.service\n' "$SERVICE_NAME"
  printf '\n'
  printf '  1. 重新安装 / 升级\n'
  printf '  2. 卸载\n'
  printf '  0. 取消\n'
  printf '\n'

  while true; do
    answer="$(prompt_value "请选择操作" "1")"
    answer="$(trim "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
      1|install|reinstall|upgrade)
        install_mdesk
        return
        ;;
      2|uninstall|remove|u)
        uninstall_mdesk
        return
        ;;
      0|q|quit|cancel|exit)
        info "已取消操作。"
        return
        ;;
      *)
        warn "请输入 1、2 或 0。"
        ;;
    esac
  done
}

main() {
  resolve_script_path

  local command=""
  local -a original_args=("$@")
  case "${1:-}" in
    "")
      command="auto"
      ;;
    install|--install)
      command="install"
      shift || true
      ;;
    uninstall|remove|--uninstall|-u)
      command="uninstall"
      shift || true
      ;;
    help|--help|-h)
      usage
      return 0
      ;;
    *)
      die "未知命令：$1（可用命令：install、uninstall）"
      ;;
  esac

  if [[ "$#" -gt 0 ]]; then
    die "不支持的参数：$*"
  fi

  if [[ "${#original_args[@]}" -eq 0 ]]; then
    need_root
  else
    need_root "${original_args[@]}"
  fi
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mdesk-install.XXXXXX")"

  case "$command" in
    auto)
      if detect_installation; then
        choose_installed_action
      else
        install_mdesk
      fi
      ;;
    install) install_mdesk ;;
    uninstall) uninstall_mdesk ;;
  esac
}

main "$@"
