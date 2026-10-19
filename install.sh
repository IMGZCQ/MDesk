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
readonly SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
readonly SYSTEMD_WANTS_LINK="/etc/systemd/system/multi-user.target.wants/${SERVICE_NAME}.service"
readonly INIT_SCRIPT="/etc/init.d/${SERVICE_NAME}"
readonly PID_FILE="/run/${SERVICE_NAME}.pid"
readonly CRON_FILE="/etc/cron.d/${SERVICE_NAME}"
readonly GITHUB_REPO="IMGZCQ/MDesk"
readonly MIRROR_BASE="https://fndesk.imcq.top/FPK/MDesk"

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
  if [ -n "${TEMP_DIR}" ] && [ -d "${TEMP_DIR}" ]; then
    rm -rf -- "${TEMP_DIR}"
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
  sudo bash install.sh uninstall     卸载
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

prompt_read() {
  local prompt="$1"
  local value=""

  if [ -t 0 ]; then
    printf '%s' "${prompt}"
    IFS= read -r value || true
  elif { exec 3</dev/tty; } 2>/dev/null; then
    printf '%s' "${prompt}" >&3
    IFS= read -r value <&3 || true
    exec 3<&-
  else
    printf '%s' "${prompt}" >&2
    IFS= read -r value || true
  fi

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

  answer="$(prompt_read "${prompt} ${hint} ")"
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
      [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
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
  chmod 755 "${INIT_SCRIPT}"
}

write_process_cron() {
  mkdir -p "$(dirname "${CRON_FILE}")"
  cat >"${CRON_FILE}" <<EOF
@reboot root ${CONTROL_BIN} start >/dev/null 2>&1
EOF
  chmod 644 "${CRON_FILE}"
}

start_background_process() {
  local pid=""

  if service_is_active; then
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
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
}

stop_background_process() {
  local pid=""
  local count=0

  [ -f "${PID_FILE}" ] || return 0
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
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
      stop_background_process
      ;;
  esac
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
      stop_background_process
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
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL --max-time 2 "http://127.0.0.1:${PORT}/@admin" >/dev/null 2>&1; then
        return 0
      fi
    else
      if wget -q -T 2 -O /dev/null "http://127.0.0.1:${PORT}/@admin" >/dev/null 2>&1; then
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
      write_systemd_unit
      verify_systemd_unit
      systemctl daemon-reload
      systemctl enable "${SERVICE_NAME}"
      systemctl restart "${SERVICE_NAME}"
      ;;
    openrc)
      write_openrc_script
      if command -v rc-update >/dev/null 2>&1; then
        rc-update add "${SERVICE_NAME}" default
      else
        mkdir -p /etc/runlevels/default
        ln -sf "${INIT_SCRIPT}" "/etc/runlevels/default/${SERVICE_NAME}"
      fi
      rc-service "${SERVICE_NAME}" restart
      ;;
    sysv)
      write_sysv_script
      if command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d "${SERVICE_NAME}" defaults
      elif command -v chkconfig >/dev/null 2>&1; then
        chkconfig --add "${SERVICE_NAME}"
        chkconfig "${SERVICE_NAME}" on
      else
        local level=""
        for level in 2 3 4 5; do
          ln -sf "${INIT_SCRIPT}" "/etc/rc${level}.d/S20${SERVICE_NAME}"
        done
        for level in 0 1 6; do
          ln -sf "${INIT_SCRIPT}" "/etc/rc${level}.d/K20${SERVICE_NAME}"
        done
      fi
      "${INIT_SCRIPT}" restart
      ;;
    process)
      write_process_cron
      start_background_process
      if ! command -v crond >/dev/null 2>&1 && ! command -v cron >/dev/null 2>&1; then
        warn "当前系统没有 cron，后台进程已启动，但系统重启后不会自动恢复。"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

write_controller() {
  mkdir -p "${CONFIG_DIR}" "$(dirname "${CONTROL_BIN}")"
  cat >"${CONTROL_SCRIPT}" <<'CONTROL_EOF'
#!/usr/bin/env bash
set -u

CONFIG_FILE="/etc/mdesk/mdesk.conf"
CONTROL_BIN="/usr/local/sbin/mdeskctl"
CONTROL_SCRIPT="/etc/mdesk/mdeskctl"
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
      [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null
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
    process)
      if [ -f "${PID_FILE}" ]; then
        pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
        [ -n "${pid}" ] && kill "${pid}" 2>/dev/null || true
        rm -f "${PID_FILE}"
      fi
      ;;
  esac
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

show_status() {
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

  rm -f "${SYSTEMD_UNIT}" "${SYSTEMD_WANTS_LINK}" "${INIT_SCRIPT}" "${CRON_FILE}" "${PID_FILE}"
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl reset-failed mdesk >/dev/null 2>&1 || true
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

  rm -f "${CONTROL_BIN}" "${CONTROL_SCRIPT}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp"
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
  uninstall)
    if [ "${2:-}" = "--purge" ]; then
      uninstall_service yes
    else
      uninstall_service no
    fi
    ;;
  *)
    echo "用法: mdeskctl {start|stop|restart|status|uninstall [--purge]}" >&2
    exit 2
    ;;
esac
CONTROL_EOF
  chmod 755 "${CONTROL_SCRIPT}"
  ln -sfn "${CONTROL_SCRIPT}" "${CONTROL_BIN}"
}

backup_service_files() {
  local file=""
  [ -f "${SYSTEMD_UNIT}" ] && cp -p "${SYSTEMD_UNIT}" "${TEMP_DIR}/backup-systemd-unit"
  [ -f "${INIT_SCRIPT}" ] && cp -p "${INIT_SCRIPT}" "${TEMP_DIR}/backup-init-script"
  [ -f "${CRON_FILE}" ] && cp -p "${CRON_FILE}" "${TEMP_DIR}/backup-cron-file"
}

restore_service_files() {
  rm -f "${SYSTEMD_UNIT}" "${INIT_SCRIPT}" "${CRON_FILE}"
  if [ -f "${TEMP_DIR}/backup-systemd-unit" ]; then
    mkdir -p "$(dirname "${SYSTEMD_UNIT}")"
    cp -p "${TEMP_DIR}/backup-systemd-unit" "${SYSTEMD_UNIT}"
  fi
  if [ -f "${TEMP_DIR}/backup-init-script" ]; then
    mkdir -p "$(dirname "${INIT_SCRIPT}")"
    cp -p "${TEMP_DIR}/backup-init-script" "${INIT_SCRIPT}"
  fi
  if [ -f "${TEMP_DIR}/backup-cron-file" ]; then
    mkdir -p "$(dirname "${CRON_FILE}")"
    cp -p "${TEMP_DIR}/backup-cron-file" "${CRON_FILE}"
  fi
}

rollback_install() {
  local old_config="${TEMP_DIR}/old-mdesk.conf"
  local old_binary="${TEMP_DIR}/old-MDesk"
  local old_install_dir="${OLD_INSTALL_DIR}"
  local old_binary_path="${OLD_BINARY}"
  local old_service_mode="${OLD_SERVICE_MODE}"

  warn "安装未完成，正在恢复原安装。"
  service_stop || true
  disable_service_registration || true
  remove_all_service_files || true

  if [ "${OLD_INSTALL_EXISTS}" = "yes" ]; then
    if [ -f "${old_binary}" ]; then
      mkdir -p "$(dirname "${old_binary_path}")"
      install -m 0755 "${old_binary}" "${old_binary_path}" || true
    fi
    if [ -f "${old_config}" ]; then
      mkdir -p "${CONFIG_DIR}"
      cp -p "${old_config}" "${CONFIG_FILE}"
      load_config
    else
      INSTALL_DIR="${old_install_dir}"
      BINARY="${old_binary_path}"
      DATA_DIR="${old_install_dir}/data"
      LOG_FILE="${old_install_dir}/mdesk.log"
      CONSOLE_LOG="${old_install_dir}/mdesk-console.log"
      SERVICE_MODE="${old_service_mode}"
      PORT="${OLD_PORT}"
      save_config
    fi
    restore_service_files
    write_controller
    if [ -n "${SERVICE_MODE}" ]; then
      register_service >/dev/null 2>&1 || warn "原服务自动恢复失败，请检查系统服务日志。"
    fi
  else
    rm -f "${BINARY}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp" "${CONTROL_BIN}" "${CONTROL_SCRIPT}"
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
    rmdir "${CONFIG_DIR}" 2>/dev/null || true
  fi
}

install_flow() {
  prepare_install

  local previous_installed="no"
  local default_port="${DEFAULT_PORT}"
  local default_dir="${DEFAULT_INSTALL_DIR}"
  local input=""
  local old_config="${TEMP_DIR}/old-mdesk.conf"
  local old_binary="${TEMP_DIR}/old-MDesk"
  local target_service_mode=""

  if is_installed; then
    previous_installed="yes"
    load_existing_config
    default_port="${PORT}"
    default_dir="${INSTALL_DIR}"
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
    [ -f "${BINARY}" ] && cp -p "${BINARY}" "${old_binary}"
    backup_service_files
  else
    OLD_INSTALL_EXISTS="no"
    OLD_INSTALL_DIR=""
    OLD_BINARY=""
    OLD_SERVICE_MODE=""
    OLD_PORT=""
    OLD_CONFIG_EXISTS="no"
  fi

  printf '\n%s\n' "=== ${APP_NAME} 安装向导 ==="
  input="$(prompt_read "监听端口 [默认 ${default_port}]: ")"
  input="$(trim "${input}")"
  PORT="${input:-${default_port}}"
  validate_port "${PORT}"

  input="$(prompt_read "安装路径 [默认 ${default_dir}]: ")"
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

  if [ "${previous_installed}" = "no" ] && command -v ss >/dev/null 2>&1; then
    if ss -ltn 2>/dev/null | awk -v port=":${PORT}" 'NR > 1 && $4 ~ port "$" { found=1 } END { exit !found }'; then
      die "端口 ${PORT} 已被其他程序占用，请更换端口。"
    fi
  fi

  fetch_binary "${TEMP_DIR}/MDesk.new" ||
    die "所有下载地址均失败，请检查网络、DNS 或代理设置。"

  mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "$(dirname "${PID_FILE}")"

  if [ "${previous_installed}" = "yes" ]; then
    info "正在停止旧服务。"
    target_service_mode="${SERVICE_MODE}"
    SERVICE_MODE="${OLD_SERVICE_MODE}"
    service_stop || true
    disable_service_registration || true
    remove_all_service_files || true
    SERVICE_MODE="${target_service_mode}"
  fi

  install -m 0755 "${TEMP_DIR}/MDesk.new" "${BINARY}"
  save_config
  write_controller

  info "正在注册并启动 $(service_mode_label "${SERVICE_MODE}") 服务。"
  if ! register_service; then
    show_service_failure
    rollback_install
    die "服务注册或启动失败，已尝试恢复原安装。"
  fi

  if ! wait_http_ready; then
    show_service_failure
    rollback_install
    die "MDesk 未能在预期时间内启动，已尝试恢复原安装。"
  fi

  success "${APP_NAME} 已安装并启动。"
  printf '管理地址：http://<服务器IP>:%s/@admin\n' "${PORT}"
  printf '服务状态：sudo mdeskctl status\n'
  printf '卸载命令：sudo mdeskctl uninstall\n'
}

uninstall_flow() {
  local delete_data="no"

  if ! is_installed; then
    die "未检测到 ${APP_NAME} 安装。"
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

  rm -f "${CONTROL_BIN}" "${CONTROL_SCRIPT}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp"
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
  choice="$(prompt_read "请选择 [1]: ")"
  choice="${choice:-1}"
  case "${choice}" in
    1) install_flow ;;
    2) uninstall_flow ;;
    3) info "已退出。" ;;
    *) die "无效选择：${choice}" ;;
  esac
}

main() {
  local command="${1:-auto}"

  case "${command}" in
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
