#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

readonly APP_NAME="MDesk"
readonly SERVICE_NAME="mdesk"
readonly DEFAULT_PORT="19188"
readonly DEFAULT_INSTALL_DIR="/opt/MDesk"
readonly CONFIG_DIR="/etc/mdesk"
readonly CONFIG_FILE="${CONFIG_DIR}/mdesk.conf"
readonly CONTROL_BIN="/usr/local/sbin/mdeskctl"
readonly CONTROL_SCRIPT="${CONFIG_DIR}/mdeskctl"
readonly INSTALLER_FILE="${CONFIG_DIR}/install.sh"
readonly UPDATE_STATUS_FILE="${CONFIG_DIR}/update.status"
readonly UPDATE_LOG="${CONFIG_DIR}/update.log"
readonly UPDATER_UNIT="mdesk-updater.service"
readonly UPDATER_UNIT_FILE="/run/systemd/system/${UPDATER_UNIT}"
readonly SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
readonly SYSTEMD_WANTS_LINK="/etc/systemd/system/multi-user.target.wants/${SERVICE_NAME}.service"
readonly INIT_SCRIPT="/etc/init.d/${SERVICE_NAME}"
readonly PID_FILE="/run/${SERVICE_NAME}.pid"
readonly CRON_FILE="/etc/cron.d/${SERVICE_NAME}"
readonly GITHUB_REPO="IMGZCQ/MDesk"
readonly MIRROR_BASE="https://fndesk.imcq.top/FPK/MDesk"
readonly SCRIPT_MIRROR_URL="https://fndesk.imcq.top/?url=mdesk"

readonly DEFAULT_GITHUB_PROXIES=(
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

if [ -t 1 ]; then
  readonly C_RESET=$'\033[0m'
  readonly C_INFO=$'\033[36m'
  readonly C_OK=$'\033[32m'
  readonly C_WARN=$'\033[33m'
  readonly C_ERR=$'\033[31m'
else
  readonly C_RESET=""
  readonly C_INFO=""
  readonly C_OK=""
  readonly C_WARN=""
  readonly C_ERR=""
fi

TEMP_DIR=""
UPDATE_JOB_DIR=""
KEEP_TEMP_DIR="no"
WORKER_ACTIVE="no"
WORKER_SUCCEEDED="no"
WORKER_LAUNCHED="no"
OLD_INSTALL_EXISTS="no"
OLD_INSTALL_DIR=""
OLD_BINARY=""
OLD_SERVICE_MODE=""
OLD_PORT=""
OLD_CONFIG_EXISTS="no"
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
PORT="${DEFAULT_PORT}"
BINARY=""
DATA_DIR=""
LOG_FILE=""
CONSOLE_LOG=""
SERVICE_MODE=""

info() {
  printf '%s[信息]%s %s\n' "${C_INFO}" "${C_RESET}" "$*"
}

success() {
  printf '%s[完成]%s %s\n' "${C_OK}" "${C_RESET}" "$*"
}

warn() {
  printf '%s[警告]%s %s\n' "${C_WARN}" "${C_RESET}" "$*" >&2
}

die() {
  printf '%s[错误]%s %s\n' "${C_ERR}" "${C_RESET}" "$*" >&2
  exit 1
}

cleanup() {
  if [ "${WORKER_ACTIVE}" = "yes" ] && [ "${WORKER_SUCCEEDED}" != "yes" ] &&
     declare -F write_update_status >/dev/null 2>&1; then
    write_update_status "failed" "升级进程异常结束，请检查 ${UPDATE_LOG}" "$$" || true
  fi
  if [ "${KEEP_TEMP_DIR}" != "yes" ] && [ -n "${TEMP_DIR}" ] && [ -d "${TEMP_DIR}" ]; then
    rm -rf -- "${TEMP_DIR}"
  fi
  if [ "${WORKER_LAUNCHED}" != "yes" ] && [ -n "${UPDATE_JOB_DIR}" ] && [ -d "${UPDATE_JOB_DIR}" ]; then
    rm -rf -- "${UPDATE_JOB_DIR}"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
MDesk Linux 安装、升级与卸载脚本

用法:
  sudo bash install.sh               自动检测并进入安装/重装/卸载向导
  sudo bash install.sh install       安装或重新安装
  sudo bash install.sh reinstall     重新安装或升级
  sudo bash install.sh update        后台升级到最新版本
  sudo bash install.sh uninstall     卸载
  sudo mdeskctl update               后台升级到最新版本
  sudo mdeskctl uninstall            卸载
  sudo mdeskctl status               查看服务状态
  sudo mdeskctl start|stop|restart   管理服务

环境变量:
  MDESK_GITHUB_PROXY   GitHub 加速地址，英文逗号分隔，支持 {url} 占位符
  MDESK_SERVICE_MODE   强制服务模式: systemd|openrc|sysv|process

没有 systemd 时，脚本会自动尝试 OpenRC、SysV；如果都没有可用的
服务管理器，则启动后台进程，并在 cron 可用时注册 @reboot 开机启动。
EOF
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "请使用 root 权限运行：sudo bash $0"
}

prompt_read_into() {
  local target="$1"
  local prompt="$2"
  local value=""
  local read_failed="no"

  if { exec 3<>/dev/tty; } 2>/dev/null; then
    printf '%s' "${prompt}" >&3
    IFS= read -r value <&3 || read_failed="yes"
    exec 3<&-
  else
    printf '%s' "${prompt}" >&2
    IFS= read -r value || read_failed="yes"
  fi

  printf -v "${target}" '%s' "${value}"
  [ "${read_failed}" = "no" ]
}

prompt_read() {
  local value=""
  prompt_read_into value "$1" || true
  printf '%s' "${value}"
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local hint="[y/N]"
  local answer=""

  if [ "${default}" = "y" ]; then
    hint="[Y/n]"
  fi

  prompt_read_into answer "${prompt} ${hint} " || true
  answer="$(trim "${answer}")"
  answer="${answer:-${default}}"
  case "${answer}" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

normalize_text_file() {
  local file="$1"
  local temporary="${file}.lf.$$"

  [ -f "${file}" ] || return 1
  if tr -d '\000' <"${file}" | sed 's/\r$//' >"${temporary}"; then
    mv -f "${temporary}" "${file}"
    return 0
  fi

  rm -f "${temporary}"
  return 1
}

normalize_install_dir() {
  local value="$1"
  while [ "${value%/}" != "${value}" ] && [ "${value}" != "/" ]; do
    value="${value%/}"
  done
  printf '%s' "${value}"
}

validate_port() {
  local value="$1"
  case "${value}" in
    ''|*[!0-9]*) die "端口必须是 1-65535 之间的整数。" ;;
  esac
  if [ "${value}" -lt 1 ] || [ "${value}" -gt 65535 ]; then
    die "端口必须是 1-65535 之间的整数。"
  fi
}

validate_install_dir() {
  local value="$1"
  [ -n "${value}" ] || die "安装路径不能为空。"
  case "${value}" in
    /*) ;;
    *) die "安装路径必须是绝对路径，例如 /opt/MDesk。" ;;
  esac
  if ! [[ "${value}" =~ ^/[A-Za-z0-9._/-]+$ ]]; then
    die "安装路径只能包含字母、数字、点、下划线、斜杠和连字符，且不能有空格。"
  fi
  case "/${value}/" in
    *"/../"*|*"/./"*) die "安装路径不能包含 . 或 .. 路径段。" ;;
  esac
  case "${value}" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      die "不允许直接安装到系统目录：${value}"
      ;;
  esac
}

detect_arch() {
  local machine
  machine="$(uname -m 2>/dev/null || true)"
  case "${machine}" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    armv7l|armv7|armhf) printf 'armv7' ;;
    *)
      die "暂不支持当前 CPU 架构：${machine:-unknown}"
      ;;
  esac
}

load_config() {
  if [ -r "${CONFIG_FILE}" ]; then
    # shellcheck disable=SC1090
    . "${CONFIG_FILE}"
  fi

  INSTALL_DIR="${INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}"
  PORT="${PORT:-${DEFAULT_PORT}}"
  BINARY="${BINARY:-${INSTALL_DIR}/MDesk}"
  DATA_DIR="${DATA_DIR:-${INSTALL_DIR}/data}"
  LOG_FILE="${LOG_FILE:-${INSTALL_DIR}/mdesk.log}"
  CONSOLE_LOG="${CONSOLE_LOG:-${INSTALL_DIR}/mdesk-console.log}"
  SERVICE_MODE="${SERVICE_MODE:-}"
}

infer_existing_install() {
  local candidate=""
  local name=""
  local dir=""
  local exec_start=""
  local marker="no"

  if [ -f "${SYSTEMD_UNIT}" ]; then
    marker="yes"
    exec_start="$(sed -n 's/^ExecStart=//p' "${SYSTEMD_UNIT}" | head -n 1)"
    if [[ "${exec_start}" == \"* ]]; then
      exec_start="${exec_start#\"}"
      exec_start="${exec_start%%\"*}"
    else
      exec_start="${exec_start%%[[:space:]]*}"
    fi
    if [ -n "${exec_start}" ]; then
      candidate="${exec_start}"
    fi
  fi

  if [ -f "${INIT_SCRIPT}" ]; then
    marker="yes"
    if [ -z "${candidate}" ]; then
      exec_start="$(sed -n 's/^BIN=//p' "${INIT_SCRIPT}" | head -n 1)"
      [ -n "${exec_start}" ] || exec_start="$(sed -n 's/^command=//p' "${INIT_SCRIPT}" | head -n 1)"
      exec_start="${exec_start#\"}"
      exec_start="${exec_start%\"}"
      if [ -n "${exec_start}" ]; then
        candidate="${exec_start}"
      fi
    fi
  fi

  if [ -f "${CRON_FILE}" ]; then
    marker="yes"
  fi

  if [ -e "${CONTROL_BIN}" ] || [ -e "${CONTROL_SCRIPT}" ]; then
    marker="yes"
  fi

  if [ -z "${candidate}" ]; then
    for dir in /opt/MDesk /opt/mdesk; do
      for name in MDesk MDesk-linux-amd64 MDesk-linux-arm64 MDesk-linux-armv7; do
        if [ -f "${dir}/${name}" ]; then
          candidate="${dir}/${name}"
          break 2
        fi
      done
    done
  fi

  if [ -z "${candidate}" ]; then
    for candidate in /opt/MDesk/MDesk-linux-* /opt/mdesk/MDesk-linux-*; do
      if [ -f "${candidate}" ]; then
        break
      fi
      candidate=""
    done
  fi

  if [ -z "${candidate}" ]; then
    if [ "${marker}" = "yes" ]; then
      INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
      BINARY="${INSTALL_DIR}/MDesk"
      DATA_DIR="${INSTALL_DIR}/data"
      LOG_FILE="${INSTALL_DIR}/mdesk.log"
      CONSOLE_LOG="${INSTALL_DIR}/mdesk-console.log"
    else
      return 1
    fi
  else
    INSTALL_DIR="$(dirname "${candidate}")"
    BINARY="${candidate}"
    DATA_DIR="${INSTALL_DIR}/data"
    LOG_FILE="${INSTALL_DIR}/mdesk.log"
    CONSOLE_LOG="${INSTALL_DIR}/mdesk-console.log"
  fi

  if [ -f "${SYSTEMD_UNIT}" ]; then
    SERVICE_MODE="systemd"
  elif [ -f "${INIT_SCRIPT}" ]; then
    if command -v rc-service >/dev/null 2>&1; then
      SERVICE_MODE="openrc"
    else
      SERVICE_MODE="sysv"
    fi
  elif [ -f "${CRON_FILE}" ]; then
    SERVICE_MODE="process"
  fi

  if [ -f "${SYSTEMD_UNIT}" ]; then
    local unit_port
    local unit_data
    local unit_log
    unit_port="$(sed -n 's/.*-port[[:space:]]\{1,\}\([0-9][0-9]*\).*/\1/p' "${SYSTEMD_UNIT}" | head -n 1)"
    if [ -n "${unit_port}" ]; then
      PORT="${unit_port}"
    fi
    unit_data="$(sed -n 's/.*-data[[:space:]]\{1,\}\"\{0,1\}\([^"[:space:]]*\)\"\{0,1\}.*/\1/p' "${SYSTEMD_UNIT}" | head -n 1)"
    unit_log="$(sed -n 's/.*-log[[:space:]]\{1,\}\"\{0,1\}\([^"[:space:]]*\)\"\{0,1\}.*/\1/p' "${SYSTEMD_UNIT}" | head -n 1)"
    [ -n "${unit_data}" ] && DATA_DIR="${unit_data}"
    [ -n "${unit_log}" ] && LOG_FILE="${unit_log}"
  fi

  return 0
}

is_installed() {
  if [ -f "${CONFIG_FILE}" ]; then
    return 0
  fi

  if [ -f "${SYSTEMD_UNIT}" ] || [ -f "${INIT_SCRIPT}" ] || [ -f "${CRON_FILE}" ] ||
     [ -e "${CONTROL_BIN}" ] || [ -e "${CONTROL_SCRIPT}" ]; then
    infer_existing_install || true
    return 0
  fi

  infer_existing_install
}

load_existing_config() {
  if [ -r "${CONFIG_FILE}" ]; then
    load_config
    return 0
  fi

  infer_existing_install || true
  load_config
}

detect_service_mode() {
  local override="${MDESK_SERVICE_MODE:-}"
  local pid1=""

  if [ -n "${override}" ]; then
    case "${override}" in
      systemd)
        command -v systemctl >/dev/null 2>&1 || die "已指定 systemd，但系统没有 systemctl。"
        ;;
      openrc)
        command -v rc-service >/dev/null 2>&1 || die "已指定 OpenRC，但系统没有 rc-service。"
        ;;
      sysv)
        [ -d /etc/init.d ] || die "已指定 SysV，但系统没有 /etc/init.d。"
        ;;
      process)
        ;;
      *)
        die "MDESK_SERVICE_MODE 只能是 systemd、openrc、sysv 或 process。"
        ;;
    esac
    printf '%s' "${override}"
    return 0
  fi

  pid1="$(cat /proc/1/comm 2>/dev/null || ps -p 1 -o comm= 2>/dev/null || true)"
  pid1="$(trim "${pid1}")"

  if [ "${pid1}" = "systemd" ] && command -v systemctl >/dev/null 2>&1; then
    printf 'systemd'
    return 0
  fi

  if command -v rc-service >/dev/null 2>&1 &&
     { [ -d /run/openrc ] || [ -x /sbin/openrc-run ] || command -v rc-update >/dev/null 2>&1; }; then
    printf 'openrc'
    return 0
  fi

  case "${pid1}" in
    init|sysvinit|busybox)
      if [ -d /etc/init.d ]; then
        printf 'sysv'
        return 0
      fi
      ;;
  esac

  printf 'process'
}

service_mode_label() {
  case "$1" in
    systemd) printf 'systemd' ;;
    openrc) printf 'OpenRC' ;;
    sysv) printf 'SysV init' ;;
    process) printf '后台进程 + cron 开机启动（如可用）' ;;
    *) printf '未知' ;;
  esac
}

save_config() {
  mkdir -p "${CONFIG_DIR}"
  {
    printf 'INSTALL_DIR=%q\n' "${INSTALL_DIR}"
    printf 'PORT=%q\n' "${PORT}"
    printf 'BINARY=%q\n' "${BINARY}"
    printf 'DATA_DIR=%q\n' "${DATA_DIR}"
    printf 'LOG_FILE=%q\n' "${LOG_FILE}"
    printf 'CONSOLE_LOG=%q\n' "${CONSOLE_LOG}"
    printf 'SERVICE_MODE=%q\n' "${SERVICE_MODE}"
  } > "${CONFIG_FILE}.tmp"
  chmod 600 "${CONFIG_FILE}.tmp"
  mv -f "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
}

require_download_tools() {
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 ||
    die "需要 curl 或 wget 才能下载 MDesk。"
  command -v install >/dev/null 2>&1 || die "系统缺少 install 命令。"
  command -v mktemp >/dev/null 2>&1 || die "系统缺少 mktemp 命令。"
}

prepare_install() {
  require_download_tools
  ARCH="${ARCH:-$(detect_arch)}"
  if [ -z "${TEMP_DIR}" ]; then
    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mdesk-install.XXXXXX")"
  fi
}

download_file() {
  local url="$1"
  local destination="$2"
  local part="${destination}.part"

  rm -f -- "${part}"
  if command -v curl >/dev/null 2>&1; then
    local args=(
      -fL
      --retry 2
      --retry-delay 1
      --connect-timeout 10
      --max-time 900
      --output "${part}"
    )
    if [ -t 2 ]; then
      args+=(--progress-bar)
    else
      args+=(-sS)
    fi
    if ! curl "${args[@]}" "${url}"; then
      rm -f -- "${part}"
      return 1
    fi
  else
    if ! wget -O "${part}" --timeout=20 --tries=2 "${url}"; then
      rm -f -- "${part}"
      return 1
    fi
  fi

  [ -s "${part}" ] || {
    rm -f -- "${part}"
    return 1
  }
  mv -f -- "${part}" "${destination}"
}

validate_binary() {
  local file="$1"
  local magic=""

  [ -s "${file}" ] || return 1
  if command -v od >/dev/null 2>&1; then
    magic="$(od -An -N4 -tx1 "${file}" 2>/dev/null | tr -d '[:space:]')"
    [ "${magic}" = "7f454c46" ] || return 1
  fi

  chmod 0755 "${file}"
  "${file}" --help >/dev/null 2>&1
}

probe_url() {
  local url="$1"
  local result=""
  local code=""
  local elapsed=""

  command -v curl >/dev/null 2>&1 || return 1

  result="$(curl -fL -I --connect-timeout 4 --max-time 8 -sS \
    -o /dev/null -w '%{http_code} %{time_total}' "${url}" 2>/dev/null)" || true
  read -r code elapsed <<<"${result}"

  if [ "${code}" != "200" ]; then
    result="$(curl -fL --range 0-1023 --max-filesize 65536 --connect-timeout 4 --max-time 8 -sS \
      -o /dev/null -w '%{http_code} %{time_total}' "${url}" 2>/dev/null)" || true
    read -r code elapsed <<<"${result}"
  fi

  [ "${code}" = "200" ] || [ "${code}" = "206" ] || return 1
  [ -n "${elapsed}" ] || return 1
  printf '%s' "${elapsed}"
}

contains_value() {
  local needle="$1"
  shift
  local item=""
  for item in "$@"; do
    [ "${item}" = "${needle}" ] && return 0
  done
  return 1
}

download_from_github() {
  local destination="$1"
  local github_url="https://github.com/${GITHUB_REPO}/releases/latest/download/MDesk-linux-${ARCH}"
  local proxy=""
  local proxy_list=()
  local candidates=()
  local ordered=()
  local failed=()
  local candidate=""
  local index=0
  local probe_dir="${TEMP_DIR}/probes"
  local probe_file=""
  local elapsed=""
  local line=""
  local sorted_index=""
  local custom="${MDESK_GITHUB_PROXY:-}"

  if [ -n "${custom}" ]; then
    IFS=',' read -r -a proxy_list <<<"${custom}"
  else
    proxy_list=("${DEFAULT_GITHUB_PROXIES[@]}")
  fi

  for proxy in "${proxy_list[@]}"; do
    proxy="$(trim "${proxy}")"
    [ -n "${proxy}" ] || continue
    if [[ "${proxy}" == *'{url}'* ]]; then
      candidate="${proxy//\{url\}/${github_url}}"
    else
      [[ "${proxy}" == */ ]] || proxy="${proxy}/"
      candidate="${proxy}${github_url}"
    fi
    candidates+=("${candidate}")
  done
  candidates+=("${github_url}")

  if command -v curl >/dev/null 2>&1 && [ "${#candidates[@]}" -gt 1 ]; then
    mkdir -p "${probe_dir}"
    info "正在测试 GitHub 加速线路速度。"
    for candidate in "${candidates[@]}"; do
      probe_file="${probe_dir}/${index}"
      (
        elapsed="$(probe_url "${candidate}" || true)"
        if [ -n "${elapsed}" ]; then
          printf '%s\n' "${elapsed}" >"${probe_file}"
        fi
      ) &
      index=$((index + 1))
    done
    wait || true

    while IFS=' ' read -r elapsed sorted_index; do
      [ -n "${sorted_index}" ] || continue
      ordered+=("${candidates[${sorted_index}]}")
    done < <(
      for probe_file in "${probe_dir}"/*; do
        [ -f "${probe_file}" ] || continue
        elapsed="$(cat "${probe_file}" 2>/dev/null || true)"
        [ -n "${elapsed}" ] || continue
        printf '%s %s\n' "${elapsed}" "${probe_file##*/}"
      done | sort -n
    )

    for candidate in "${candidates[@]}"; do
      if ! contains_value "${candidate}" "${ordered[@]}"; then
        failed+=("${candidate}")
      fi
    done
    ordered+=("${failed[@]}")
  else
    ordered=("${candidates[@]}")
  fi

  index=0
  for candidate in "${ordered[@]}"; do
    index=$((index + 1))
    info "尝试 GitHub 下载线路 ${index}/${#ordered[@]}。"
    if download_file "${candidate}" "${destination}" && validate_binary "${destination}"; then
      return 0
    fi
    rm -f -- "${destination}"
  done

  return 1
}

fetch_binary() {
  local destination="$1"
  local mirror_url="${MIRROR_BASE}/MDesk-linux-${ARCH}"

  info "优先从项目镜像下载 ${APP_NAME}：${mirror_url}"
  if download_file "${mirror_url}" "${destination}" && validate_binary "${destination}"; then
    success "项目镜像下载完成。"
    return 0
  fi

  rm -f -- "${destination}"
  warn "项目镜像不可用，切换到 GitHub Release 加速线路。"
  if download_from_github "${destination}"; then
    success "GitHub Release 下载完成。"
    return 0
  fi

  return 1
}

persist_installer() {
  local source_path="${BASH_SOURCE[0]:-$0}"
  local temporary="${INSTALLER_FILE}.tmp.$$"
  local sanitized="${temporary}.clean"
  local raw_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh"
  local proxy=""
  local candidate=""
  local custom="${MDESK_GITHUB_PROXY:-}"
  local proxy_list=()
  local candidates=()

  mkdir -p "${CONFIG_DIR}"
  rm -f "${temporary}" "${sanitized}"

  # bash <(curl ...) exposes a pipe rather than a regular file. Copy once and
  # normalize it before checking the shebang so the installer copy is reusable
  # by the detached updater and never contains CRLF/NUL bytes.
  # Process substitution paths such as /dev/fd/63 are streams, not reusable
  # installer files. Reading them here can block or save a truncated script.
  if [ -n "${source_path}" ] && [ -f "${source_path}" ] && [ -r "${source_path}" ]; then
    if tr -d '\000' <"${source_path}" | sed 's/\r$//' >"${sanitized}" &&
       [ -s "${sanitized}" ] &&
       head -n 1 "${sanitized}" 2>/dev/null | grep -q '^#!.*bash' &&
       bash -n "${sanitized}" >/dev/null 2>&1; then
      chmod 0755 "${sanitized}"
      mv -f "${sanitized}" "${INSTALLER_FILE}"
      rm -f "${temporary}"
      return 0
    fi
  fi

  if [ -n "${custom}" ]; then
    IFS=',' read -r -a proxy_list <<<"${custom}"
  else
    proxy_list=("${DEFAULT_GITHUB_PROXIES[@]}")
  fi

  candidates=("${SCRIPT_MIRROR_URL}" "${raw_url}")
  for proxy in "${proxy_list[@]}"; do
    proxy="$(trim "${proxy}")"
    [ -n "${proxy}" ] || continue
    if [[ "${proxy}" == *'{url}'* ]]; then
      candidates+=("${proxy//\{url\}/${raw_url}}")
    else
      [[ "${proxy}" == */ ]] || proxy="${proxy}/"
      candidates+=("${proxy}${raw_url}")
    fi
  done

  for candidate in "${candidates[@]}"; do
    rm -f "${temporary}" "${sanitized}"
    if download_file "${candidate}" "${temporary}" &&
       tr -d '\000' <"${temporary}" | sed 's/\r$//' >"${sanitized}" &&
       [ -s "${sanitized}" ] &&
       head -n 1 "${sanitized}" 2>/dev/null | grep -q '^#!.*bash' &&
       bash -n "${sanitized}" >/dev/null 2>&1; then
      chmod 0755 "${sanitized}"
      mv -f "${sanitized}" "${INSTALLER_FILE}"
      rm -f "${temporary}"
      return 0
    fi
  done

  rm -f "${temporary}" "${sanitized}"
  return 1
}

write_update_status() {
  local state="$1"
  local message="$2"
  local pid="${3:-}"
  local temporary="${UPDATE_STATUS_FILE}.tmp.$$"

  mkdir -p "${CONFIG_DIR}"
  {
    printf 'STATE=%s\n' "${state}"
    printf 'MESSAGE=%s\n' "${message}"
    printf 'PID=%s\n' "${pid}"
    printf 'UPDATED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    printf 'LOG=%s\n' "${UPDATE_LOG}"
  } >"${temporary}"
  chmod 600 "${temporary}" 2>/dev/null || true
  mv -f "${temporary}" "${UPDATE_STATUS_FILE}"
}

read_update_value() {
  local key="$1"
  local file="${2:-${UPDATE_STATUS_FILE}}"

  [ -r "${file}" ] || return 1
  sed -n "s/^${key}=//p" "${file}" 2>/dev/null | head -n 1
}

update_in_progress() {
  local state=""
  local pid=""

  state="$(read_update_value STATE || true)"
  case "${state}" in
    starting|running) ;;
    *) return 1 ;;
  esac

  if command -v systemctl >/dev/null 2>&1 &&
     systemctl is-active --quiet "${UPDATER_UNIT}" 2>/dev/null; then
    return 0
  fi

  pid="$(read_update_value PID || true)"
  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null
}

prepare_update_job() {
  local root="${TMPDIR:-/var/tmp}"

  [ -d "${root}" ] || root="/tmp"
  UPDATE_JOB_DIR="$(mktemp -d "${root%/}/mdesk-update.XXXXXX")"
  mv "${TEMP_DIR}" "${UPDATE_JOB_DIR}/work"
  TEMP_DIR="${UPDATE_JOB_DIR}/work"
}

write_update_job() {
  local job_file="${UPDATE_JOB_DIR}/update.conf"

  {
    printf 'PREVIOUS_INSTALLED=%q\n' "yes"
    printf 'ARCH=%q\n' "${ARCH}"
    printf 'PORT=%q\n' "${PORT}"
    printf 'INSTALL_DIR=%q\n' "${INSTALL_DIR}"
    printf 'BINARY=%q\n' "${BINARY}"
    printf 'DATA_DIR=%q\n' "${DATA_DIR}"
    printf 'LOG_FILE=%q\n' "${LOG_FILE}"
    printf 'CONSOLE_LOG=%q\n' "${CONSOLE_LOG}"
    printf 'SERVICE_MODE=%q\n' "${SERVICE_MODE}"
    printf 'OLD_INSTALL_EXISTS=%q\n' "${OLD_INSTALL_EXISTS}"
    printf 'OLD_INSTALL_DIR=%q\n' "${OLD_INSTALL_DIR}"
    printf 'OLD_BINARY=%q\n' "${OLD_BINARY}"
    printf 'OLD_SERVICE_MODE=%q\n' "${OLD_SERVICE_MODE}"
    printf 'OLD_PORT=%q\n' "${OLD_PORT}"
    printf 'OLD_CONFIG_EXISTS=%q\n' "${OLD_CONFIG_EXISTS}"
  } >"${job_file}"
  chmod 600 "${job_file}"
}

launch_detached_update() {
  local unit_file="${UPDATER_UNIT_FILE}"
  local pid=""
  local worker_pid=""
  local state=""
  local attempt=0

  if update_in_progress; then
    die "已有 MDesk 升级任务正在运行，请稍后再试。"
  fi
  persist_installer ||
    die "无法保存安装脚本，不能启动独立升级进程。"
  prepare_update_job
  write_update_job
  # Record the parent PID while the detached worker is being launched. If the
  # parent dies before the worker writes its own PID, this status becomes stale
  # instead of blocking future updates forever.
  write_update_status "starting" "正在启动独立升级任务" "$$" || true

  # Keep the job directory after the interactive parent exits. The worker owns it now.
  KEEP_TEMP_DIR="yes"

  if [ "${OLD_SERVICE_MODE}" = "systemd" ] &&
     command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    mkdir -p "$(dirname "${unit_file}")"
    cat >"${unit_file}" <<EOF
[Unit]
Description=MDesk detached updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash "${INSTALLER_FILE}" --update-worker "${UPDATE_JOB_DIR}"
TimeoutStartSec=3600
Nice=5

[Install]
WantedBy=multi-user.target
EOF
    if ! normalize_text_file "${unit_file}"; then
      warn "无法规范化独立升级单元文件，已取消后台升级。"
      rm -f "${unit_file}"
      write_update_status "failed" "独立升级单元文件写入失败" "" || true
      KEEP_TEMP_DIR="no"
      return 1
    fi
    chmod 644 "${unit_file}"
    systemctl daemon-reload
    systemctl reset-failed "${UPDATER_UNIT}" >/dev/null 2>&1 || true
    WORKER_LAUNCHED="yes"
    if systemctl start --no-block "${UPDATER_UNIT}"; then
      sleep 1
      if ! systemctl is-failed --quiet "${UPDATER_UNIT}" 2>/dev/null; then
        state="$(read_update_value STATE || true)"
        if [ "${state}" != "success" ] && [ "${state}" != "failed" ]; then
          worker_pid="$(read_update_value PID || true)"
          write_update_status "running" "升级任务已启动，正在下载新版本" "${worker_pid}"
        fi
        info "已通过独立 systemd 单元启动升级任务。"
        return 0
      fi
      warn "独立 systemd 升级单元启动失败，正在尝试其他后台方式。"
    fi
    WORKER_LAUNCHED="no"
    rm -f "${unit_file}"
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  WORKER_LAUNCHED="yes"
  if command -v setsid >/dev/null 2>&1; then
    nohup setsid /bin/bash "${INSTALLER_FILE}" --update-worker "${UPDATE_JOB_DIR}" \
      >>"${UPDATE_LOG}" 2>&1 </dev/null &
    pid="$!"
  else
    nohup /bin/bash "${INSTALLER_FILE}" --update-worker "${UPDATE_JOB_DIR}" \
      >>"${UPDATE_LOG}" 2>&1 </dev/null &
    pid="$!"
  fi
  disown "${pid}" 2>/dev/null || true

  while [ "${attempt}" -lt 5 ]; do
    state="$(read_update_value STATE || true)"
    if [ "${state}" = "success" ] || [ "${state}" = "failed" ]; then
      info "升级任务已启动并结束。"
      return 0
    fi

    worker_pid="$(read_update_value PID || true)"
    if [ -z "${worker_pid}" ] && [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
      worker_pid="${pid}"
    fi
    if [ -n "${worker_pid}" ] && kill -0 "${worker_pid}" 2>/dev/null; then
      write_update_status "running" "独立升级进程已启动" "${worker_pid}"
      info "已通过独立后台进程启动升级任务（PID ${worker_pid}）。"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done

  WORKER_LAUNCHED="no"
  KEEP_TEMP_DIR="no"
  write_update_status "failed" "无法启动独立升级进程" "" || true
  return 1
}

run_update_worker() {
  local job_dir="$1"
  local job_file="${job_dir}/update.conf"

  [ -r "${job_file}" ] || {
    printf '[错误] 找不到升级任务配置：%s\n' "${job_file}" >&2
    return 1
  }

  UPDATE_JOB_DIR="${job_dir}"
  # shellcheck disable=SC1090
  . "${job_file}"
  TEMP_DIR="${UPDATE_JOB_DIR}/work"
  KEEP_TEMP_DIR="yes"
  WORKER_LAUNCHED="yes"
  WORKER_ACTIVE="yes"

  mkdir -p "${CONFIG_DIR}"
  exec >>"${UPDATE_LOG}" 2>&1
  require_download_tools
  write_update_status "running" "正在下载并校验新版本" "$$"
  info "独立升级进程已启动（PID $$）。"

  if ! fetch_binary "${TEMP_DIR}/MDesk.new"; then
    WORKER_ACTIVE="no"
    write_update_status "failed" "下载或校验新版本失败，当前服务未修改" "$$"
    warn "下载或校验新版本失败，当前服务未修改。"
    rm -rf -- "${UPDATE_JOB_DIR}"
    return 1
  fi

  write_update_status "running" "正在停止旧服务并安装新版本" "$$"
  if apply_prepared_install; then
    WORKER_SUCCEEDED="yes"
    WORKER_ACTIVE="no"
    write_update_status "success" "MDesk 已升级并通过健康检查" "$$"
    success "MDesk 已升级并重新启动。"
    rm -rf -- "${UPDATE_JOB_DIR}"
    return 0
  fi

  WORKER_ACTIVE="no"
  write_update_status "failed" "升级失败，已尝试恢复旧版本" "$$"
  warn "升级失败，已尝试恢复旧版本。"
  rm -rf -- "${UPDATE_JOB_DIR}"
  return 1
}

process_is_mdesk_pid() {
  local pid="${1:-}"
  local exe=""
  local cmdline=""
  local candidate=""

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 1

  exe="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
  case "${exe}" in
    *" (deleted)") exe="${exe% (deleted)}" ;;
  esac
  cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"

  for candidate in "${BINARY:-}" "${OLD_BINARY:-}"; do
    [ -n "${candidate}" ] || continue
    [ "${exe}" = "${candidate}" ] && return 0
    case " ${cmdline} " in
      *" ${candidate} "*) return 0 ;;
    esac
  done
  if [ -n "${OLD_INSTALL_DIR:-}" ]; then
    candidate="${OLD_INSTALL_DIR}/MDesk"
    [ "${exe}" = "${candidate}" ] && return 0
    case " ${cmdline} " in
      *" ${candidate} "*) return 0 ;;
    esac
  fi

  return 1
}

stop_mdesk_processes() {
  local pid_path=""
  local pid=""
  local count=0
  local running="no"
  local -a pids=()

  stop_background_process || true

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    if process_is_mdesk_pid "${pid}"; then
      pids+=("${pid}")
      kill -TERM "${pid}" 2>/dev/null || true
    fi
  done

  [ "${#pids[@]}" -gt 0 ] || return 0

  while [ "${count}" -lt 15 ]; do
    running="no"
    for pid in "${pids[@]}"; do
      if kill -0 "${pid}" 2>/dev/null; then
        running="yes"
        break
      fi
    done
    [ "${running}" = "no" ] && return 0
    sleep 1
    count=$((count + 1))
  done

  for pid in "${pids[@]}"; do
    kill -KILL "${pid}" 2>/dev/null || true
  done
  return 0
}

service_is_active() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "${SERVICE_NAME}"
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 && rc-service "${SERVICE_NAME}" status >/dev/null 2>&1
      ;;
    sysv)
      [ -x "${INIT_SCRIPT}" ] && "${INIT_SCRIPT}" status >/dev/null 2>&1
      ;;
    process)
      local pid=""
      [ -f "${PID_FILE}" ] || return 1
      pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
      process_is_mdesk_pid "${pid}"
      ;;
    *)
      return 1
      ;;
  esac
}

write_systemd_unit() {
  mkdir -p "$(dirname "${SYSTEMD_UNIT}")"
  cat >"${SYSTEMD_UNIT}" <<EOF
[Unit]
Description=MDesk service
Documentation=https://github.com/${GITHUB_REPO}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BINARY} -port ${PORT} -data ${DATA_DIR} -log ${LOG_FILE}
Restart=on-failure
RestartSec=5s
TimeoutStopSec=15s
KillSignal=SIGTERM
LimitNOFILE=65535
UMask=0022

[Install]
WantedBy=multi-user.target
EOF
  normalize_text_file "${SYSTEMD_UNIT}" || return 1
  chmod 644 "${SYSTEMD_UNIT}"
}

verify_systemd_unit() {
  command -v systemd-analyze >/dev/null 2>&1 || return 0
  systemd-analyze verify "${SYSTEMD_UNIT}"
}

write_openrc_script() {
  mkdir -p "$(dirname "${INIT_SCRIPT}")"
  cat >"${INIT_SCRIPT}" <<EOF
#!/sbin/openrc-run

name="MDesk"
description="MDesk service"
command="${BINARY}"
command_args="-port ${PORT} -data ${DATA_DIR} -log ${LOG_FILE}"
directory="${INSTALL_DIR}"
pidfile="${PID_FILE}"
command_background="yes"

depend() {
  need net
  after firewall
}
EOF
  normalize_text_file "${INIT_SCRIPT}" || return 1
  chmod 755 "${INIT_SCRIPT}"
}

write_sysv_script() {
  mkdir -p "$(dirname "${INIT_SCRIPT}")"
  cat >"${INIT_SCRIPT}" <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          ${SERVICE_NAME}
# Required-Start:    \$local_fs \$network \$remote_fs
# Required-Stop:     \$local_fs \$network \$remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: MDesk service
### END INIT INFO

NAME="${SERVICE_NAME}"
BIN="${BINARY}"
PORT="${PORT}"
DATA_DIR="${DATA_DIR}"
LOG_FILE="${LOG_FILE}"
CONSOLE_LOG="${CONSOLE_LOG}"
PIDFILE="${PID_FILE}"

is_running() {
  [ -f "\$PIDFILE" ] || return 1
  pid=\$(cat "\$PIDFILE" 2>/dev/null || true)
  [ -n "\$pid" ] && kill -0 "\$pid" 2>/dev/null
}

start_service() {
  if is_running; then
    return 0
  fi
  mkdir -p "\$DATA_DIR" "\$(dirname "\$PIDFILE")" || return 1
  cd "\$(dirname "\$BIN")" || return 1
  nohup "\$BIN" -port "\$PORT" -data "\$DATA_DIR" -log "\$LOG_FILE" >>"\$CONSOLE_LOG" 2>&1 &
  pid=\$!
  printf '%s\n' "\$pid" >"\$PIDFILE"
  sleep 1
  kill -0 "\$pid" 2>/dev/null
}

stop_service() {
  if ! is_running; then
    rm -f "\$PIDFILE"
    return 0
  fi
  pid=\$(cat "\$PIDFILE")
  kill "\$pid" 2>/dev/null || true
  count=0
  while kill -0 "\$pid" 2>/dev/null && [ "\$count" -lt 15 ]; do
    sleep 1
    count=\$((count + 1))
  done
  if kill -0 "\$pid" 2>/dev/null; then
    kill -9 "\$pid" 2>/dev/null || true
  fi
  rm -f "\$PIDFILE"
}

case "\${1:-}" in
  start)
    start_service
    ;;
  stop)
    stop_service
    ;;
  restart)
    stop_service
    start_service
    ;;
  status)
    if is_running; then
      echo "\${NAME} is running (PID \$(cat "\$PIDFILE"))"
      exit 0
    fi
    echo "\${NAME} is stopped"
    exit 3
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart|status}" >&2
    exit 2
    ;;
esac
EOF
  normalize_text_file "${INIT_SCRIPT}" || return 1
  chmod 755 "${INIT_SCRIPT}"
}

write_process_cron() {
  mkdir -p "$(dirname "${CRON_FILE}")"
  cat >"${CRON_FILE}" <<EOF
@reboot root ${CONTROL_BIN} start >/dev/null 2>&1
EOF
  normalize_text_file "${CRON_FILE}" || return 1
  chmod 644 "${CRON_FILE}"
}

start_background_process() {
  local pid=""

  if service_is_active; then
    return 0
  fi

  if port_is_listening; then
    warn "端口 ${PORT} 已被占用，无法启动后台 MDesk 进程。"
    return 1
  fi

  mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "$(dirname "${PID_FILE}")"
  (
    cd "${INSTALL_DIR}"
    nohup "${BINARY}" -port "${PORT}" -data "${DATA_DIR}" -log "${LOG_FILE}" \
      >>"${CONSOLE_LOG}" 2>&1 &
    printf '%s\n' "$!" >"${PID_FILE}"
  )
  sleep 1
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
}

stop_background_process() {
  local pid=""
  local count=0

  [ -f "${PID_FILE}" ] || return 0
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [ -n "${pid}" ] && process_is_mdesk_pid "${pid}"; then
    kill "${pid}" 2>/dev/null || true
    while kill -0 "${pid}" 2>/dev/null && [ "${count}" -lt 15 ]; do
      sleep 1
      count=$((count + 1))
    done
    if kill -0 "${pid}" 2>/dev/null; then
      kill -9 "${pid}" 2>/dev/null || true
    fi
  fi
  rm -f "${PID_FILE}"
}

port_is_listening() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null |
      awk -v port=":${PORT}" 'NR > 1 && $4 ~ port "$" { found=1 } END { exit !found }'
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null |
      awk -v port=":${PORT}" 'NR > 2 && $4 ~ port "$" { found=1 } END { exit !found }'
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi

  return 1
}

wait_port_released() {
  local deadline=$((SECONDS + 15))

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if ! port_is_listening; then
      return 0
    fi
    sleep 1
  done

  return 1
}

service_start() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 || return 1
      systemctl start "${SERVICE_NAME}"
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 || return 1
      rc-service "${SERVICE_NAME}" start
      ;;
    sysv)
      "${INIT_SCRIPT}" start
      ;;
    process)
      start_background_process
      ;;
    *)
      return 1
      ;;
  esac
}

service_stop() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 && systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 && rc-service "${SERVICE_NAME}" stop >/dev/null 2>&1 || true
      ;;
    sysv)
      [ -x "${INIT_SCRIPT}" ] && "${INIT_SCRIPT}" stop >/dev/null 2>&1 || true
      ;;
    process)
      ;;
    *)
      return 1
      ;;
  esac
  stop_mdesk_processes || true
}

service_restart() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 || return 1
      systemctl restart "${SERVICE_NAME}"
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 || return 1
      rc-service "${SERVICE_NAME}" restart
      ;;
    sysv)
      "${INIT_SCRIPT}" restart
      ;;
    process)
      stop_mdesk_processes || true
      start_background_process
      ;;
    *)
      return 1
      ;;
  esac
}

service_status() {
  case "${SERVICE_MODE}" in
    systemd)
      if ! command -v systemctl >/dev/null 2>&1; then
        printf '%s 未运行：当前系统没有 systemctl。\n' "${APP_NAME}"
        return 1
      fi
      systemctl status "${SERVICE_NAME}" --no-pager -l
      ;;
    openrc)
      if ! command -v rc-service >/dev/null 2>&1; then
        printf '%s 未运行：当前系统没有 rc-service。\n' "${APP_NAME}"
        return 1
      fi
      rc-service "${SERVICE_NAME}" status
      ;;
    sysv)
      "${INIT_SCRIPT}" status
      ;;
    process)
      if service_is_active; then
        printf '%s 正在运行，PID %s\n' "${APP_NAME}" "$(cat "${PID_FILE}")"
        return 0
      fi
      printf '%s 未运行\n' "${APP_NAME}"
      return 3
      ;;
    *)
      return 1
      ;;
  esac
}

show_service_failure() {
  warn "服务启动失败，最近日志如下："
  if [ -f "${LOG_FILE}" ]; then
    tail -n 40 "${LOG_FILE}" >&2 || true
  fi
  if [ -f "${CONSOLE_LOG}" ]; then
    tail -n 20 "${CONSOLE_LOG}" >&2 || true
  fi
  if [ "${SERVICE_MODE}" = "systemd" ] && command -v systemctl >/dev/null 2>&1; then
    systemctl status "${SERVICE_NAME}" --no-pager -l >&2 || true
    if command -v journalctl >/dev/null 2>&1; then
      journalctl -u "${SERVICE_NAME}" -n 30 --no-pager >&2 || true
    fi
  fi
}

http_probe() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 2 "http://127.0.0.1:${PORT}/@mdesk/healthz" >/dev/null 2>&1
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -T 2 -O /dev/null "http://127.0.0.1:${PORT}/@mdesk/healthz" >/dev/null 2>&1
    return
  fi
  return 1
}

wait_http_ready() {
  local deadline=$((SECONDS + 25))

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    sleep 2
    service_is_active
    return
  fi

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if ! service_is_active; then
      return 1
    fi
    if http_probe; then
      sleep 2
      if service_is_active && http_probe; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

remove_runlevel_links() {
  local link=""
  for link in /etc/rc[0-6S].d/[SK][0-9][0-9]"${SERVICE_NAME}"; do
    [ -L "${link}" ] || [ -e "${link}" ] || continue
    rm -f -- "${link}"
  done
}

disable_service_registration() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 && systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
      rm -f "${SYSTEMD_WANTS_LINK}"
      ;;
    openrc)
      command -v rc-update >/dev/null 2>&1 && rc-update del "${SERVICE_NAME}" default >/dev/null 2>&1 || true
      rm -f "/etc/runlevels/default/${SERVICE_NAME}" 2>/dev/null || true
      ;;
    sysv)
      if command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d -f "${SERVICE_NAME}" remove >/dev/null 2>&1 || true
      elif command -v chkconfig >/dev/null 2>&1; then
        chkconfig --del "${SERVICE_NAME}" >/dev/null 2>&1 || true
      fi
      remove_runlevel_links
      ;;
    process)
      rm -f "${CRON_FILE}"
      ;;
  esac
}

remove_all_service_files() {
  rm -f "${SYSTEMD_UNIT}" "${SYSTEMD_WANTS_LINK}" "${INIT_SCRIPT}" "${CRON_FILE}" "${PID_FILE}"
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl reset-failed "${SERVICE_NAME}" >/dev/null 2>&1 || true
  fi
}

register_service() {
  case "${SERVICE_MODE}" in
    systemd)
      write_systemd_unit || return 1
      verify_systemd_unit || return 1
      systemctl daemon-reload || return 1
      systemctl enable "${SERVICE_NAME}" || return 1
      systemctl restart "${SERVICE_NAME}" || return 1
      ;;
    openrc)
      write_openrc_script || return 1
      if command -v rc-update >/dev/null 2>&1; then
        rc-update add "${SERVICE_NAME}" default || return 1
      else
        mkdir -p /etc/runlevels/default || return 1
        ln -sf "${INIT_SCRIPT}" "/etc/runlevels/default/${SERVICE_NAME}" || return 1
      fi
      rc-service "${SERVICE_NAME}" restart || return 1
      ;;
    sysv)
      write_sysv_script || return 1
      if command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d "${SERVICE_NAME}" defaults || return 1
      elif command -v chkconfig >/dev/null 2>&1; then
        chkconfig --add "${SERVICE_NAME}" || return 1
        chkconfig "${SERVICE_NAME}" on || return 1
      else
        local level=""
        for level in 2 3 4 5; do
          ln -sf "${INIT_SCRIPT}" "/etc/rc${level}.d/S20${SERVICE_NAME}" || return 1
        done
        for level in 0 1 6; do
          ln -sf "${INIT_SCRIPT}" "/etc/rc${level}.d/K20${SERVICE_NAME}" || return 1
        done
      fi
      "${INIT_SCRIPT}" restart || return 1
      ;;
    process)
      if ! write_process_cron; then
        warn "无法注册开机启动项，仍将继续启动 MDesk 后台进程。"
      fi
      start_background_process || return 1
      if ! command -v crond >/dev/null 2>&1 && ! command -v cron >/dev/null 2>&1; then
        warn "当前系统没有 cron，后台进程已启动，但系统重启后不会自动恢复。"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

fallback_to_process_service() {
  local failed_mode="${SERVICE_MODE:-}"

  case "${failed_mode}" in
    systemd|openrc|sysv) ;;
    *) return 1 ;;
  esac
  [ -z "${MDESK_SERVICE_MODE:-}" ] || return 1

  warn "$(service_mode_label "${failed_mode}") 服务注册或启动失败，正在自动降级为独立后台进程。"
  service_stop || true
  disable_service_registration || true
  remove_all_service_files || true
  if ! wait_port_released; then
    warn "端口 ${PORT} 仍被占用，无法启动后台 MDesk 进程。"
    return 1
  fi
  SERVICE_MODE="process"
  save_config || return 1
  write_controller || return 1
  register_service
}

write_controller() {
  mkdir -p "${CONFIG_DIR}" "$(dirname "${CONTROL_BIN}")"
  cat >"${CONTROL_SCRIPT}" <<'CONTROL_EOF'
#!/usr/bin/env bash
set -u

CONFIG_FILE="/etc/mdesk/mdesk.conf"
CONTROL_BIN="/usr/local/sbin/mdeskctl"
CONTROL_SCRIPT="/etc/mdesk/mdeskctl"
INSTALLER_FILE="/etc/mdesk/install.sh"
UPDATE_STATUS_FILE="/etc/mdesk/update.status"
UPDATE_LOG="/etc/mdesk/update.log"
UPDATER_UNIT="mdesk-updater.service"
UPDATER_UNIT_FILE="/run/systemd/system/mdesk-updater.service"
SYSTEMD_UNIT="/etc/systemd/system/mdesk.service"
SYSTEMD_WANTS_LINK="/etc/systemd/system/multi-user.target.wants/mdesk.service"
INIT_SCRIPT="/etc/init.d/mdesk"
CRON_FILE="/etc/cron.d/mdesk"
PID_FILE="/run/mdesk.pid"

if [ ! -r "${CONFIG_FILE}" ]; then
  echo "[错误] 未找到 MDesk 安装配置：${CONFIG_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "${CONFIG_FILE}"

update_value() {
  local key="$1"
  [ -r "${UPDATE_STATUS_FILE}" ] || return 1
  sed -n "s/^${key}=//p" "${UPDATE_STATUS_FILE}" 2>/dev/null | head -n 1
}

update_in_progress() {
  local state=""
  local pid=""

  state="$(update_value STATE || true)"
  case "${state}" in
    starting|running) ;;
    *) return 1 ;;
  esac
  if command -v systemctl >/dev/null 2>&1 &&
     systemctl is-active --quiet "${UPDATER_UNIT}" 2>/dev/null; then
    return 0
  fi
  pid="$(update_value PID || true)"
  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null
}

show_update_status() {
  local state=""
  local message=""
  local updated_at=""

  [ -r "${UPDATE_STATUS_FILE}" ] || return 0
  state="$(update_value STATE || true)"
  message="$(update_value MESSAGE || true)"
  updated_at="$(update_value UPDATED_AT || true)"
  printf '\n最近升级状态：%s\n' "${state:-未知}"
  [ -z "${message}" ] || printf '说明：%s\n' "${message}"
  [ -z "${updated_at}" ] || printf '更新时间：%s\n' "${updated_at}"
  printf '升级日志：%s\n' "${UPDATE_LOG}"
}

run_update() {
  if update_in_progress; then
    echo "[提示] MDesk 升级任务正在运行，请稍后使用 mdeskctl status 查看。" >&2
    return 1
  fi
  if [ ! -r "${INSTALLER_FILE}" ]; then
    echo "[错误] 未找到升级脚本 ${INSTALLER_FILE}，请重新运行安装脚本。" >&2
    return 1
  fi
  exec /bin/bash "${INSTALLER_FILE}" update
}

is_mdesk_pid() {
  local pid="${1:-}"
  local exe=""
  local cmdline=""

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 1

  exe="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
  case "${exe}" in
    *" (deleted)") exe="${exe% (deleted)}" ;;
  esac
  cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"

  [ "${exe}" = "${BINARY}" ] && return 0
  case " ${cmdline} " in
    *" ${BINARY} "*) return 0 ;;
  esac
  return 1
}

stop_mdesk_processes() {
  local pid=""
  local pid_path=""
  local count=0
  local running="no"
  local -a pids=()

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    if is_mdesk_pid "${pid}"; then
      pids+=("${pid}")
    fi
  done

  [ "${#pids[@]}" -gt 0 ] || {
    rm -f "${PID_FILE}"
    return 0
  }

  for pid in "${pids[@]}"; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  while [ "${count}" -lt 15 ]; do
    running="no"
    for pid in "${pids[@]}"; do
      if kill -0 "${pid}" 2>/dev/null; then
        running="yes"
        break
      fi
    done
    [ "${running}" = "no" ] && break
    sleep 1
    count=$((count + 1))
  done
  for pid in "${pids[@]}"; do
    kill -KILL "${pid}" 2>/dev/null || true
  done
  rm -f "${PID_FILE}"
}

is_active() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet mdesk
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 && rc-service mdesk status >/dev/null 2>&1
      ;;
    sysv)
      [ -x "${INIT_SCRIPT}" ] && "${INIT_SCRIPT}" status >/dev/null 2>&1
      ;;
    process)
      [ -f "${PID_FILE}" ] || return 1
      pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
      is_mdesk_pid "${pid}"
      ;;
    *)
      return 1
      ;;
  esac
}

stop_service() {
  case "${SERVICE_MODE}" in
    systemd) systemctl stop mdesk >/dev/null 2>&1 || true ;;
    openrc) rc-service mdesk stop >/dev/null 2>&1 || true ;;
    sysv) [ -x "${INIT_SCRIPT}" ] && "${INIT_SCRIPT}" stop >/dev/null 2>&1 || true ;;
    process) ;;
  esac
  stop_mdesk_processes || true
}

start_service() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 || { echo "[错误] 当前系统没有 systemctl。" >&2; return 1; }
      systemctl start mdesk
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 || { echo "[错误] 当前系统没有 rc-service。" >&2; return 1; }
      rc-service mdesk start
      ;;
    sysv) "${INIT_SCRIPT}" start ;;
    process)
      if is_active; then
        return 0
      fi
      mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "$(dirname "${PID_FILE}")"
      (
        cd "${INSTALL_DIR}"
        nohup "${BINARY}" -port "${PORT}" -data "${DATA_DIR}" -log "${LOG_FILE}" \
          >>"${CONSOLE_LOG}" 2>&1 &
        printf '%s\n' "$!" >"${PID_FILE}"
      )
      sleep 1
      is_active
      ;;
    *)
      echo "[错误] 未知服务模式：${SERVICE_MODE}" >&2
      return 1
      ;;
  esac
}

restart_service() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 || { echo "[错误] 当前系统没有 systemctl。" >&2; return 1; }
      systemctl restart mdesk
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 || { echo "[错误] 当前系统没有 rc-service。" >&2; return 1; }
      rc-service mdesk restart
      ;;
    sysv) "${INIT_SCRIPT}" restart ;;
    process)
      stop_service
      start_service
      ;;
  esac
}

show_service_status() {
  case "${SERVICE_MODE}" in
    systemd)
      command -v systemctl >/dev/null 2>&1 || { echo "MDesk 未运行：当前系统没有 systemctl。" ; return 1; }
      systemctl status mdesk --no-pager -l
      ;;
    openrc)
      command -v rc-service >/dev/null 2>&1 || { echo "MDesk 未运行：当前系统没有 rc-service。" ; return 1; }
      rc-service mdesk status
      ;;
    sysv) "${INIT_SCRIPT}" status ;;
    process)
      if is_active; then
        echo "MDesk 正在运行，PID $(cat "${PID_FILE}")"
        return 0
      fi
      echo "MDesk 未运行"
      return 3
      ;;
  esac
}

show_status() {
  local result=0
  show_service_status || result=$?
  show_update_status
  return "${result}"
}

remove_runlevel_links() {
  for link in /etc/rc[0-6S].d/[SK][0-9][0-9]mdesk; do
    [ -L "${link}" ] || [ -e "${link}" ] || continue
    rm -f -- "${link}"
  done
}

safe_remove_dir() {
  local path="$1"
  case "${path}" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      echo "[错误] 拒绝删除系统目录：${path}" >&2
      return 1
      ;;
    /*) ;;
    *)
      echo "[错误] 拒绝删除非绝对路径：${path}" >&2
      return 1
      ;;
  esac
  rm -rf -- "${path}"
}

uninstall_service() {
  local purge="${1:-no}"
  local delete_data="no"

  if update_in_progress; then
    echo "[错误] MDesk 升级任务正在运行，完成后再卸载。" >&2
    return 1
  fi

  if [ "${purge}" = "yes" ]; then
    delete_data="yes"
  elif [ -r /dev/tty ]; then
    printf '是否同时删除用户数据 %s？[y/N] ' "${DATA_DIR}" >/dev/tty
    IFS= read -r answer </dev/tty || answer=""
    case "${answer}" in
      y|Y|yes|YES|Yes) delete_data="yes" ;;
    esac
  fi

  stop_service

  case "${SERVICE_MODE}" in
    systemd)
      systemctl disable mdesk >/dev/null 2>&1 || true
      ;;
    openrc)
      command -v rc-update >/dev/null 2>&1 && rc-update del mdesk default >/dev/null 2>&1 || true
      rm -f /etc/runlevels/default/mdesk
      ;;
    sysv)
      if command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d -f mdesk remove >/dev/null 2>&1 || true
      elif command -v chkconfig >/dev/null 2>&1; then
        chkconfig --del mdesk >/dev/null 2>&1 || true
      fi
      remove_runlevel_links
      ;;
    process)
      rm -f "${CRON_FILE}"
      ;;
  esac

  rm -f "${SYSTEMD_UNIT}" "${SYSTEMD_WANTS_LINK}" "${INIT_SCRIPT}" "${CRON_FILE}" "${PID_FILE}" "${UPDATER_UNIT_FILE}"
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl reset-failed mdesk >/dev/null 2>&1 || true
    systemctl reset-failed "${UPDATER_UNIT}" >/dev/null 2>&1 || true
  fi

  rm -f "${BINARY}" "${LOG_FILE}" "${CONSOLE_LOG}"
  if [ "${delete_data}" = "yes" ]; then
    if [ "${DATA_DIR}" != "${INSTALL_DIR}" ] && [ -d "${DATA_DIR}" ]; then
      safe_remove_dir "${DATA_DIR}" || true
    fi
    if [ -d "${INSTALL_DIR}" ]; then
      safe_remove_dir "${INSTALL_DIR}" || true
    fi
  else
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
  fi

  rm -f "${CONTROL_BIN}" "${CONTROL_SCRIPT}" "${INSTALLER_FILE}" "${UPDATE_STATUS_FILE}" \
    "${UPDATE_LOG}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp"
  rmdir /etc/mdesk 2>/dev/null || true

  if [ "${delete_data}" = "yes" ]; then
    echo "[完成] MDesk 和服务已卸载，用户数据已删除。"
  else
    echo "[完成] MDesk 和服务已卸载，用户数据已保留在 ${DATA_DIR}。"
  fi
}

case "${1:-status}" in
  start) start_service ;;
  stop) stop_service ;;
  restart) restart_service ;;
  status) show_status ;;
  update) run_update ;;
  uninstall)
    if [ "${2:-}" = "--purge" ]; then
      uninstall_service yes
    else
      uninstall_service no
    fi
    ;;
  *)
    echo "用法: mdeskctl {start|stop|restart|status|update|uninstall [--purge]}" >&2
    exit 2
    ;;
esac
CONTROL_EOF
  normalize_text_file "${CONTROL_SCRIPT}" || return 1
  chmod 755 "${CONTROL_SCRIPT}"
  ln -sfn "${CONTROL_SCRIPT}" "${CONTROL_BIN}"
}

backup_service_files() {
  local file=""
  if [ -f "${SYSTEMD_UNIT}" ]; then
    cp -p "${SYSTEMD_UNIT}" "${TEMP_DIR}/backup-systemd-unit" &&
      normalize_text_file "${TEMP_DIR}/backup-systemd-unit" ||
      rm -f "${TEMP_DIR}/backup-systemd-unit"
  fi
  if [ -f "${INIT_SCRIPT}" ]; then
    cp -p "${INIT_SCRIPT}" "${TEMP_DIR}/backup-init-script" &&
      normalize_text_file "${TEMP_DIR}/backup-init-script" ||
      rm -f "${TEMP_DIR}/backup-init-script"
  fi
  if [ -f "${CRON_FILE}" ]; then
    cp -p "${CRON_FILE}" "${TEMP_DIR}/backup-cron-file" &&
      normalize_text_file "${TEMP_DIR}/backup-cron-file" ||
      rm -f "${TEMP_DIR}/backup-cron-file"
  fi
  return 0
}

restore_service_files() {
  rm -f "${SYSTEMD_UNIT}" "${INIT_SCRIPT}" "${CRON_FILE}"
  if [ -f "${TEMP_DIR}/backup-systemd-unit" ]; then
    mkdir -p "$(dirname "${SYSTEMD_UNIT}")"
    cp -p "${TEMP_DIR}/backup-systemd-unit" "${SYSTEMD_UNIT}"
    normalize_text_file "${SYSTEMD_UNIT}" || rm -f "${SYSTEMD_UNIT}"
  fi
  if [ -f "${TEMP_DIR}/backup-init-script" ]; then
    mkdir -p "$(dirname "${INIT_SCRIPT}")"
    cp -p "${TEMP_DIR}/backup-init-script" "${INIT_SCRIPT}"
    normalize_text_file "${INIT_SCRIPT}" || rm -f "${INIT_SCRIPT}"
  fi
  if [ -f "${TEMP_DIR}/backup-cron-file" ]; then
    mkdir -p "$(dirname "${CRON_FILE}")"
    cp -p "${TEMP_DIR}/backup-cron-file" "${CRON_FILE}"
    normalize_text_file "${CRON_FILE}" || rm -f "${CRON_FILE}"
  fi
  chmod 644 "${SYSTEMD_UNIT}" "${CRON_FILE}" 2>/dev/null || true
  chmod 755 "${INIT_SCRIPT}" 2>/dev/null || true
  return 0
}

rollback_install() {
  local old_config="${TEMP_DIR}/old-mdesk.conf"
  local old_binary="${TEMP_DIR}/old-MDesk"
  local old_install_dir="${OLD_INSTALL_DIR:-${INSTALL_DIR}}"
  local old_binary_path="${OLD_BINARY:-${BINARY}}"
  local old_service_mode="${OLD_SERVICE_MODE:-${SERVICE_MODE}}"
  local old_port="${OLD_PORT:-${PORT}}"

  warn "安装未完成，正在恢复原安装。"
  service_stop || true
  disable_service_registration || true
  remove_all_service_files || true

  if [ "${OLD_INSTALL_EXISTS}" != "yes" ]; then
    rm -f "${BINARY}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp" "${CONTROL_BIN}" "${CONTROL_SCRIPT}"
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
    rmdir "${CONFIG_DIR}" 2>/dev/null || true
    return 0
  fi

  if [ ! -f "${old_binary}" ]; then
    warn "未找到升级前的二进制备份，无法恢复旧版本。"
    return 1
  fi
  mkdir -p "$(dirname "${old_binary_path}")"
  if ! install -m 0755 "${old_binary}" "${old_binary_path}"; then
    warn "无法恢复升级前的二进制文件。"
    return 1
  fi

  INSTALL_DIR="${old_install_dir}"
  BINARY="${old_binary_path}"
  DATA_DIR="${old_install_dir}/data"
  LOG_FILE="${old_install_dir}/mdesk.log"
  CONSOLE_LOG="${old_install_dir}/mdesk-console.log"
  SERVICE_MODE="${old_service_mode}"
  PORT="${old_port}"

  if [ -f "${old_config}" ]; then
    mkdir -p "${CONFIG_DIR}"
    if cp -p "${old_config}" "${CONFIG_FILE}"; then
      load_config || warn "旧配置读取失败，正在使用升级前保存的运行参数。"
    else
      warn "旧配置复制失败，正在使用升级前保存的运行参数。"
    fi
  fi

  save_config || true
  restore_service_files || true
  write_controller || true

  if [ -n "${SERVICE_MODE}" ] &&
     register_service >/dev/null 2>&1 &&
     wait_http_ready; then
    success "原服务已恢复并通过健康检查。"
    return 0
  fi

  show_service_failure
  if fallback_to_process_service && wait_http_ready; then
    success "原版本已自动降级为后台进程并通过健康检查。"
    return 0
  fi

  warn "原版本恢复后仍未通过健康检查，请检查系统服务日志。"
  return 1
}

apply_prepared_install() {
  local previous_installed="${PREVIOUS_INSTALLED:-no}"
  local target_service_mode="${SERVICE_MODE}"

  mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "$(dirname "${PID_FILE}")"

  if [ "${previous_installed}" = "yes" ]; then
    info "正在停止旧服务。"
    SERVICE_MODE="${OLD_SERVICE_MODE:-${SERVICE_MODE}}"
    service_stop || true
    disable_service_registration || true
    remove_all_service_files || true
    if ! wait_port_released; then
      warn "旧服务停止后端口 ${PORT} 仍被占用，已取消本次安装。"
      rollback_install || true
      return 1
    fi
    SERVICE_MODE="${target_service_mode}"
  fi

  if ! install -m 0755 "${TEMP_DIR}/MDesk.new" "${BINARY}"; then
    warn "无法写入新的 MDesk 二进制文件。"
    rollback_install || true
    return 1
  fi

  if ! save_config || ! write_controller; then
    warn "无法保存 MDesk 服务配置。"
    rollback_install || true
    return 1
  fi
  persist_installer || warn "安装已完成，但无法保存 mdeskctl update 所需的安装脚本副本。"

  info "正在注册并启动 $(service_mode_label "${SERVICE_MODE}") 服务。"
  if ! register_service; then
    show_service_failure
    if ! fallback_to_process_service; then
      rollback_install || true
      return 1
    fi
  fi

  if ! wait_http_ready; then
    show_service_failure
    warn "MDesk 未能在预期时间内正常响应。"
    if fallback_to_process_service && wait_http_ready; then
      success "MDesk 已降级为独立后台进程并通过健康检查。"
    else
      rollback_install || true
      return 1
    fi
  fi

  return 0
}

capture_existing_install() {
  local old_config="${TEMP_DIR}/old-mdesk.conf"
  local old_binary="${TEMP_DIR}/old-MDesk"

  OLD_INSTALL_EXISTS="yes"
  OLD_INSTALL_DIR="${INSTALL_DIR}"
  OLD_BINARY="${BINARY}"
  OLD_SERVICE_MODE="${SERVICE_MODE}"
  OLD_PORT="${PORT}"
  OLD_CONFIG_EXISTS="no"
  if [ -f "${CONFIG_FILE}" ]; then
    OLD_CONFIG_EXISTS="yes"
    cp -p "${CONFIG_FILE}" "${old_config}"
  fi
  if [ -f "${BINARY}" ]; then
    cp -p "${BINARY}" "${old_binary}"
  fi
  backup_service_files
}

queue_detached_update() {
  PREVIOUS_INSTALLED="yes"
  launch_detached_update ||
    die "无法启动独立升级进程，旧服务未被修改。"
  success "升级任务已在独立后台继续运行。"
  printf '即使当前 MDesk 终端断开，升级也会继续完成并自动重启服务。\n'
  printf '升级日志：%s\n' "${UPDATE_LOG}"
  printf '完成状态：sudo mdeskctl status\n'
  printf '刷新地址：http://<服务器IP>:%s/@admin\n' "${PORT}"
}

install_flow() {
  prepare_install

  local previous_installed="no"
  local default_port="${DEFAULT_PORT}"
  local default_dir="${DEFAULT_INSTALL_DIR}"
  local input=""

  if is_installed; then
    previous_installed="yes"
    load_existing_config
    default_port="${PORT}"
    default_dir="${INSTALL_DIR}"
    capture_existing_install
  else
    OLD_INSTALL_EXISTS="no"
    OLD_INSTALL_DIR=""
    OLD_BINARY=""
    OLD_SERVICE_MODE=""
    OLD_PORT=""
    OLD_CONFIG_EXISTS="no"
  fi

  printf '\n%s\n' "=== ${APP_NAME} 安装向导 ==="
  prompt_read_into input "监听端口 [默认 ${default_port}]: " || input=""
  input="$(trim "${input}")"
  PORT="${input:-${default_port}}"
  validate_port "${PORT}"

  prompt_read_into input "安装路径 [默认 ${default_dir}]: " || input=""
  input="$(trim "${input}")"
  INSTALL_DIR="$(normalize_install_dir "${input:-${default_dir}}")"
  validate_install_dir "${INSTALL_DIR}"

  BINARY="${INSTALL_DIR}/MDesk"
  DATA_DIR="${INSTALL_DIR}/data"
  LOG_FILE="${INSTALL_DIR}/mdesk.log"
  CONSOLE_LOG="${INSTALL_DIR}/mdesk-console.log"
  SERVICE_MODE="$(detect_service_mode)"

  info "CPU 架构：${ARCH}"
  info "服务模式：$(service_mode_label "${SERVICE_MODE}")"
  info "安装路径：${INSTALL_DIR}"
  info "用户数据：${DATA_DIR}"
  info "监听端口：${PORT}"

  if [ "${previous_installed}" = "no" ] && port_is_listening; then
    die "端口 ${PORT} 已被其他程序占用，请更换端口。"
  fi

  if [ "${previous_installed}" = "yes" ]; then
    queue_detached_update
    return 0
  fi

  fetch_binary "${TEMP_DIR}/MDesk.new" ||
    die "所有下载地址均失败，请检查网络、DNS 或代理设置。"

  PREVIOUS_INSTALLED="no"
  apply_prepared_install ||
    die "安装或启动失败，已尝试清理本次安装。"

  success "${APP_NAME} 已安装并启动。"
  printf '管理地址：http://<服务器IP>:%s/@admin\n' "${PORT}"
  printf '服务状态：sudo mdeskctl status\n'
  printf '卸载命令：sudo mdeskctl uninstall\n'
}

update_flow() {
  prepare_install

  if ! is_installed; then
    die "未检测到 ${APP_NAME} 安装。"
  fi
  load_existing_config
  capture_existing_install
  SERVICE_MODE="$(detect_service_mode)"

  info "CPU 架构：${ARCH}"
  info "服务模式：$(service_mode_label "${SERVICE_MODE}")"
  info "安装路径：${INSTALL_DIR}"
  info "用户数据：${DATA_DIR}"
  info "监听端口：${PORT}"

  queue_detached_update
}

uninstall_flow() {
  local delete_data="no"

  if ! is_installed; then
    die "未检测到 ${APP_NAME} 安装。"
  fi
  if update_in_progress; then
    die "MDesk 升级任务正在运行，完成后再卸载。"
  fi
  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"

  printf '\n%s\n' "=== ${APP_NAME} 卸载向导 ==="
  info "安装路径：${INSTALL_DIR}"
  info "用户数据：${DATA_DIR}"

  if confirm "是否同时删除用户数据 ${DATA_DIR}？" "n"; then
    delete_data="yes"
  fi

  service_stop || true
  disable_service_registration || true
  remove_all_service_files || true
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop "${UPDATER_UNIT}" >/dev/null 2>&1 || true
    systemctl reset-failed "${UPDATER_UNIT}" >/dev/null 2>&1 || true
  fi
  rm -f "${UPDATER_UNIT_FILE}"
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  rm -f "${BINARY}" "${LOG_FILE}" "${CONSOLE_LOG}"
  if [ "${delete_data}" = "yes" ]; then
    if [ "${DATA_DIR}" != "${INSTALL_DIR}" ] && [ -d "${DATA_DIR}" ]; then
      safe_remove_dir "${DATA_DIR}"
    fi
    if [ -d "${INSTALL_DIR}" ]; then
      safe_remove_dir "${INSTALL_DIR}"
    fi
  else
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
  fi

  rm -f "${CONTROL_BIN}" "${CONTROL_SCRIPT}" "${INSTALLER_FILE}" \
    "${UPDATE_STATUS_FILE}" "${UPDATE_LOG}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp"
  rmdir "${CONFIG_DIR}" 2>/dev/null || true

  if [ "${delete_data}" = "yes" ]; then
    success "${APP_NAME} 和服务已卸载，用户数据已删除。"
  else
    success "${APP_NAME} 和服务已卸载，用户数据已保留在 ${DATA_DIR}。"
  fi
}

safe_remove_dir() {
  local path="$1"
  validate_install_dir "${path}"
  rm -rf -- "${path}"
}

installed_menu() {
  local choice=""
  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"

  printf '\n检测到 %s 已安装。\n' "${APP_NAME}"
  printf '  安装路径：%s\n' "${INSTALL_DIR}"
  printf '  监听端口：%s\n' "${PORT}"
  printf '  服务模式：%s\n\n' "$(service_mode_label "${SERVICE_MODE}")"
  printf '  1) 重新安装或升级（保留用户数据）\n'
  printf '  2) 卸载\n'
  printf '  3) 退出\n'
  while true; do
    prompt_read_into choice "请选择 [1]: " || choice=""
    choice="$(trim "${choice}")"
    choice="${choice:-1}"
    case "${choice}" in
      1) install_flow; return 0 ;;
      2) uninstall_flow; return 0 ;;
      3) info "已退出。"; return 0 ;;
      *) warn "无效选择：${choice}，请重新输入。" ;;
    esac
  done
}

main() {
  local command="${1:-auto}"

  case "${command}" in
    --update-worker)
      require_root
      [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
      shift
      [ -n "${1:-}" ] || die "缺少升级任务目录。"
      run_update_worker "$1"
      exit $?
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    status|start|stop|restart)
      require_root
      is_installed || die "未检测到 ${APP_NAME} 安装。"
      load_existing_config
      [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
      case "${command}" in
        status) service_status ;;
        start) service_start ;;
        stop) service_stop ;;
        restart) service_restart ;;
      esac
      exit $?
      ;;
    install|reinstall)
      require_root
      [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
      install_flow
      ;;
    update)
      require_root
      [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
      update_flow
      ;;
    uninstall)
      require_root
      [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
      uninstall_flow
      ;;
    auto)
      require_root
      [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
      if is_installed; then
        installed_menu
      else
        install_flow
      fi
      ;;
    *)
      usage
      die "未知命令：${command}"
      ;;
  esac
}

main "$@"
