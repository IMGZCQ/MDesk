#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
readonly APP_NAME="MDesk"
readonly APP_DISPLAY_NAME="M•Desk"
readonly APP_DESCRIPTION="高效轻量桌面系统"
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
readonly PASSWORD_RESET_STATUS_FILE="${CONFIG_DIR}/password-reset.status"
readonly PASSWORD_RESET_LOG="${CONFIG_DIR}/password-reset.log"
readonly PASSWORD_RESET_UNIT="mdesk-password-reset.service"
readonly PASSWORD_RESET_UNIT_FILE="/run/systemd/system/${PASSWORD_RESET_UNIT}"
readonly RESTART_STATUS_FILE="${CONFIG_DIR}/restart.status"
readonly RESTART_LOG="${CONFIG_DIR}/restart.log"
readonly RESTART_UNIT="mdesk-restart.service"
readonly RESTART_UNIT_FILE="/run/systemd/system/${RESTART_UNIT}"
readonly APPCENTER_ACTION_STATUS_FILE="${CONFIG_DIR}/appcenter-action.status"
readonly APPCENTER_ACTION_LOG="${CONFIG_DIR}/appcenter-action.log"
readonly APPCENTER_ACTION_UNIT="mdesk-appcenter-action.service"
readonly APPCENTER_ACTION_UNIT_FILE="/run/systemd/system/${APPCENTER_ACTION_UNIT}"
readonly SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
readonly SYSTEMD_WANTS_LINK="/etc/systemd/system/multi-user.target.wants/${SERVICE_NAME}.service"
readonly INIT_SCRIPT="/etc/init.d/${SERVICE_NAME}"
readonly CRON_FILE="/etc/cron.d/${SERVICE_NAME}"
readonly PID_FILE="/run/${SERVICE_NAME}.pid"
readonly APPCENTER_APP_PID_FILE="/var/apps/mdesk/var/app.pid"
readonly APPCENTER_CLI="/usr/local/bin/appcenter-cli"
readonly APPCENTER_APP_NAME="mdesk"
readonly GITHUB_REPO="IMGZCQ/MDesk"
readonly MIRROR_BASE="https://mdesk.imcq.top/releases"
readonly SCRIPT_MIRROR_URL="https://fndesk.imcq.top/?url=mdesk"
readonly APPCENTER_SCRIPT_UPGRADE_WARNING="本程序是通过飞牛应用FPK嘅安装方式。暂不支持使用脚本升级。请使用飞牛应用FPK升级。"
readonly DEFAULT_GITHUB_PROXIES=(
  "https://gh-proxy.com/"
  "shturl.cc/KuAWfmBOqBq"
  "shturl.cc/Nk0INZMZV"
  "shturl.cc/C2yxX5"
  "shturl.cc/3KyBEw5XJx"
  "https://ghproxy.cn/"
  "shturl.cc/UpO0ul1fMF"
  "https://gh.llkk.cc/"
  "https://github.moeyy.xyz/"
  "shturl.cc/FMDtskprYMe"
)
# 随机密码配置
readonly PW_LEN=24
readonly PW_CHARSET="ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"

# ===================== 美化配色（保留管道兼容）=====================
if [ -t 1 ]; then
  readonly C_RESET=$'\033[0m'
  readonly C_INFO=$'\033[36m'
  readonly C_OK=$'\033[32m'
  readonly C_WARN=$'\033[33m'
  readonly C_ERR=$'\033[31m'
  readonly C_TITLE=$'\033[96m'
  readonly C_LABEL=$'\033[94m'
  readonly C_VAL=$'\033[97m'
  readonly C_MENU=$'\033[92m'
  readonly C_DIM=$'\033[90m'
  readonly C_HI=$'\033[1;93m'
else
  readonly C_RESET=""
  readonly C_INFO=""
  readonly C_OK=""
  readonly C_WARN=""
  readonly C_ERR=""
  readonly C_TITLE=""
  readonly C_LABEL=""
  readonly C_VAL=""
  readonly C_MENU=""
  readonly C_DIM=""
  readonly C_HI=""
fi

TEMP_DIR=""
UPDATE_JOB_DIR=""
PASSWORD_RESET_JOB_DIR=""
KEEP_TEMP_DIR="no"
WORKER_ACTIVE="no"
WORKER_SUCCEEDED="no"
WORKER_LAUNCHED="no"
PASSWORD_RESET_WORKER_ACTIVE="no"
PASSWORD_RESET_WORKER_SUCCEEDED="no"
PASSWORD_RESET_WORKER_LAUNCHED="no"
PASSWORD_RESET_WORKER_IS_CHILD="no"
RESTART_JOB_DIR=""
RESTART_WORKER_ACTIVE="no"
RESTART_WORKER_SUCCEEDED="no"
RESTART_WORKER_LAUNCHED="no"
RESTART_WORKER_IS_CHILD="no"
APPCENTER_ACTION_JOB_DIR=""
APPCENTER_ACTION_TYPE=""
APPCENTER_ACTION_TARGET_VERSION=""
APPCENTER_ACTION_WORKER_ACTIVE="no"
APPCENTER_ACTION_WORKER_SUCCEEDED="no"
APPCENTER_ACTION_WORKER_LAUNCHED="no"
APPCENTER_ACTION_WORKER_IS_CHILD="no"
APPCENTER_ACTION_RECOVERY_ACTIVE="no"
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
INSTALLED_VERSION=""
TARGET_VERSION=""
TARGET_VERSION_LOOKED_UP="no"
DIRECT_RUN_DETECTED="no"
DIRECT_RUN_PID=""
DIRECT_RUN_CWD=""
DIRECT_RUN_ARGS=()
DIRECT_RUN_ARG_COUNT="0"
OLD_DIRECT_RUN_ARGS=()
OLD_DIRECT_RUN_ARG_COUNT="0"
DIRECT_SCAN_DONE="no"
DIRECT_CANDIDATE_PIDS=()
DIRECT_CANDIDATE_PATHS=()
DIRECT_CANDIDATE_VERSIONS=()
DIRECT_CANDIDATE_CHILD_COUNT="0"
APPCENTER_UPGRADE_ACTIVE="no"
APPCENTER_UPGRADE_BACKUP=""
APPCENTER_UPGRADE_STAGING=""
APPCENTER_REAL_BINARY=""
APPCENTER_INSTANCE_PID=""
APPCENTER_CANDIDATE_PIDS=()
APPCENTER_CANDIDATE_PATHS=()
APPCENTER_CANDIDATE_VERSIONS=()
APPCENTER_CANDIDATE_PORTS=()

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

# 生成随机强密码
gen_random_password() {
  local pass=""
  for ((i=0; i < PW_LEN; i++)); do
    local idx
    idx=$(( RANDOM % ${#PW_CHARSET} ))
    pass+=${PW_CHARSET:$idx:1}
  done
  printf '%s' "${pass}"
}

cleanup() {
  local appcenter_upgrade_was_active="no"
  local appcenter_recovery_needed="no"
  local keep_appcenter_action_artifacts="no"

  if [ "${APPCENTER_ACTION_RECOVERY_ACTIVE}" = "yes" ]; then
    appcenter_recovery_needed="yes"
  fi
  if [ "${APPCENTER_ACTION_WORKER_LAUNCHED}" = "yes" ] &&
     [ "${APPCENTER_ACTION_WORKER_IS_CHILD}" != "yes" ]; then
    keep_appcenter_action_artifacts="yes"
  fi
  if [ "${APPCENTER_UPGRADE_ACTIVE}" = "yes" ] &&
     declare -F start_appcenter_service >/dev/null 2>&1; then
    appcenter_upgrade_was_active="yes"
    appcenter_recovery_needed="yes"
  fi
  if [ "${appcenter_recovery_needed}" = "yes" ] &&
     declare -F start_appcenter_service >/dev/null 2>&1; then
    warn "应用中心操作异常结束，正在尝试通过飞牛应用中心恢复服务。"
    start_appcenter_service || true
    APPCENTER_ACTION_RECOVERY_ACTIVE="no"
    APPCENTER_UPGRADE_ACTIVE="no"
  fi
  if [ "${keep_appcenter_action_artifacts}" != "yes" ] &&
     [ -n "${APPCENTER_UPGRADE_STAGING}" ]; then
    rm -f -- "${APPCENTER_UPGRADE_STAGING}"
  fi
  if [ "${keep_appcenter_action_artifacts}" != "yes" ] &&
     [ "${appcenter_upgrade_was_active}" != "yes" ] &&
     [ "${APPCENTER_UPGRADE_ACTIVE}" != "yes" ] &&
     [ -n "${APPCENTER_UPGRADE_BACKUP}" ]; then
    rm -f -- "${APPCENTER_UPGRADE_BACKUP}"
  fi
  if [ "${WORKER_ACTIVE}" = "yes" ] && [ "${WORKER_SUCCEEDED}" != "yes" ] &&
     declare -F write_update_status >/dev/null 2>&1; then
    write_update_status "failed" "升级进程异常结束，请检查 ${UPDATE_LOG}" "$$" || true
  fi
  if [ "${PASSWORD_RESET_WORKER_ACTIVE}" = "yes" ] &&
     [ "${PASSWORD_RESET_WORKER_SUCCEEDED}" != "yes" ] &&
     declare -F write_password_reset_status >/dev/null 2>&1; then
    write_password_reset_status "failed" "密码重置进程异常结束，请检查 ${PASSWORD_RESET_LOG}" "$$" || true
  fi
  if [ "${RESTART_WORKER_ACTIVE}" = "yes" ] &&
     [ "${RESTART_WORKER_SUCCEEDED}" != "yes" ] &&
     declare -F write_restart_status >/dev/null 2>&1; then
    write_restart_status "failed" "重启进程异常结束，请检查 ${RESTART_LOG}" "$$" || true
  fi
  if [ "${APPCENTER_ACTION_WORKER_ACTIVE}" = "yes" ] &&
     [ "${APPCENTER_ACTION_WORKER_SUCCEEDED}" != "yes" ] &&
     declare -F write_appcenter_action_status >/dev/null 2>&1; then
    write_appcenter_action_status "failed" "应用中心操作进程异常结束，请检查 ${APPCENTER_ACTION_LOG}" "$$" || true
  fi
  if [ "${KEEP_TEMP_DIR}" != "yes" ] && [ -n "${TEMP_DIR}" ] && [ -d "${TEMP_DIR}" ]; then
    rm -rf -- "${TEMP_DIR}"
  fi
  if [ "${WORKER_LAUNCHED}" != "yes" ] && [ -n "${UPDATE_JOB_DIR}" ] && [ -d "${UPDATE_JOB_DIR}" ]; then
    rm -rf -- "${UPDATE_JOB_DIR}"
  fi
  if { [ "${PASSWORD_RESET_WORKER_LAUNCHED}" != "yes" ] ||
       [ "${PASSWORD_RESET_WORKER_IS_CHILD}" = "yes" ]; } &&
     [ -n "${PASSWORD_RESET_JOB_DIR}" ] && [ -d "${PASSWORD_RESET_JOB_DIR}" ]; then
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
  fi
  if { [ "${RESTART_WORKER_LAUNCHED}" != "yes" ] ||
       [ "${RESTART_WORKER_IS_CHILD}" = "yes" ]; } &&
     [ -n "${RESTART_JOB_DIR}" ] && [ -d "${RESTART_JOB_DIR}" ]; then
    rm -rf -- "${RESTART_JOB_DIR}"
  fi
  if { [ "${APPCENTER_ACTION_WORKER_LAUNCHED}" != "yes" ] ||
       [ "${APPCENTER_ACTION_WORKER_IS_CHILD}" = "yes" ]; } &&
     [ -n "${APPCENTER_ACTION_JOB_DIR}" ] && [ -d "${APPCENTER_ACTION_JOB_DIR}" ]; then
    rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
M•Desk Linux 安装、升级与卸载脚本
用法:
  sudo bash install.sh               自动检测并进入安装/重装/卸载向导
  sudo bash install.sh install       安装或重新安装
  sudo bash install.sh reinstall     重新安装或升级
  sudo bash install.sh update        后台升级到最新版本
  sudo bash install.sh uninstall     卸载
  sudo bash install.sh uninstall --purge
                                     卸载并删除用户数据
  sudo mdeskctl update               后台升级到最新版本
  sudo mdeskctl uninstall            卸载
  sudo mdeskctl status               查看服务状态
  sudo mdeskctl start|stop|restart   管理服务
  sudo mdeskctl reset-password      重置管理密码（删除密码配置并重新初始化）
环境变量:
  MDESK_GITHUB_PROXY   GitHub 加速地址，英文逗号分隔，支持 {url} 占位符
  MDESK_SERVICE_MODE   强制服务模式: systemd|openrc|sysv|process
没有 systemd 时，脚本会自动尝试 OpenRC、SysV；如果都没有可用的
服务管理器，则启动后台进程，并在 cron 可用时注册 @reboot 开机启动。
EOF
}

# ===================== 美化渲染函数（只改界面，无业务逻辑）=====================
print_banner() {
  printf '\n'
  printf '%s┌─────────────────────────────────────────────┐%s\n' "${C_TITLE}" "${C_RESET}"
  printf '%s│          M•Desk · 高效轻量桌面系统          │%s\n' "${C_TITLE}" "${C_RESET}"
  printf '%s│      安装 / 升级 / 卸载 一体化脚本           │%s\n' "${C_TITLE}" "${C_RESET}"
  printf '%s└─────────────────────────────────────────────┘%s\n' "${C_TITLE}" "${C_RESET}"
  printf '\n'
}

clear_screen() {
  if [ -t 1 ]; then
    clear 2>/dev/null || printf '\033[2J\033[H'
  fi
}

section() {
  local title="$1"
  printf '\n%s├─────────────────────────────────────────────┤%s\n' "${C_DIM}" "${C_RESET}"
  printf '%s│  %-41s │%s\n' "${C_DIM}" "${title}" "${C_RESET}"
  printf '%s└─────────────────────────────────────────────┘%s\n' "${C_DIM}" "${C_RESET}"
}

is_fnos_appcenter_path() {
  local value="${1:-}"
  case "${value}" in
    *@appcenter*|*@AppCenter*|*@APPCENTER*) return 0 ;;
    *) return 1 ;;
  esac
}
is_appcenter_managed() {
  is_fnos_appcenter_path "${BINARY:-}" ||
    is_fnos_appcenter_path "${INSTALL_DIR:-}"
}
warn_appcenter_script_upgrade() {
  warn "${APPCENTER_SCRIPT_UPGRADE_WARNING}"
}
reject_appcenter_script_upgrade() {
  warn_appcenter_script_upgrade
  return 1
}
# 渲染【已安装信息卡片】
print_install_card() {
  local mode_label
  local local_version
  local target_version
  local source_label="安装脚本管理"
  mode_label="$(service_mode_label "${SERVICE_MODE}")"
  local_version="$(version_display "${INSTALLED_VERSION}" "未知")"
  target_version="$(version_display "${TARGET_VERSION}" "下载后确认")"
  if is_appcenter_managed; then
    source_label="飞牛应用 FPK"
    [ -z "${APPCENTER_INSTANCE_PID}" ] ||
      source_label+="（PID ${APPCENTER_INSTANCE_PID}）"
  elif [ "${DIRECT_RUN_DETECTED}" = "yes" ]; then
    source_label="直接运行"
    [ -z "${DIRECT_RUN_PID}" ] || source_label+="（PID ${DIRECT_RUN_PID}）"
  fi
  printf '\n'
  printf '%s┌─────────────────────────────────────────────┐%s\n' "${C_INFO}" "${C_RESET}"
  printf '%s│ ✅ 检测到 M•Desk 已经安装                    │%s\n' "${C_INFO}" "${C_RESET}"
  printf '%s├─────────────────────────────────────────────┤%s\n' "${C_INFO}" "${C_RESET}"
  printf '%s│ %s本地版本：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${local_version}" "${C_RESET}"
  printf '%s│ %s准备安装：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${target_version}" "${C_RESET}"
  printf '%s│ %s运行来源：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${source_label}" "${C_RESET}"
  printf '%s│ %s安装路径：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${INSTALL_DIR}" "${C_RESET}"
  printf '%s│ %s二进制：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${BINARY}" "${C_RESET}"
  printf '%s│ %s监听端口：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${PORT}" "${C_RESET}"
  printf '%s│ %s服务模式：%s %-34s │%s\n' "${C_INFO}" "${C_LABEL}" "${C_VAL}" "${mode_label}" "${C_RESET}"
  printf '%s└─────────────────────────────────────────────┘%s\n' "${C_INFO}" "${C_RESET}"
  printf '\n'
}

# 渲染主菜单：仅喺已安装分支先会调用，所以重启、重置密码唔会喺未安装时出现
print_menu() {
  printf '%s┌─────────────────────────────────────────────┐%s\n' "${C_MENU}" "${C_RESET}"
  printf '%s│                 操作菜单                    │%s\n' "${C_MENU}" "${C_RESET}"
  printf '%s├─────────────────────────────────────────────┤%s\n' "${C_MENU}" "${C_RESET}"
  printf '%s│ %s1)%s 重新安装或升级（保留用户数据）        │%s\n' "${C_MENU}" "${C_OK}" "${C_MENU}" "${C_RESET}"
  if is_appcenter_managed; then
    printf '%s│ %s2)%s 重启服务（调用飞牛应用中心）        │%s\n' "${C_MENU}" "${C_OK}" "${C_MENU}" "${C_RESET}"
  else
    printf '%s│ %s2)%s 重启服务                              │%s\n' "${C_MENU}" "${C_OK}" "${C_MENU}" "${C_RESET}"
  fi
  printf '%s│ %s3)%s 重置管理密码（删除密码配置）          │%s\n' "${C_MENU}" "${C_OK}" "${C_MENU}" "${C_RESET}"
  printf '%s│ %s4)%s 卸载                                  │%s\n' "${C_MENU}" "${C_OK}" "${C_MENU}" "${C_RESET}"
  printf '%s│ %s5)%s 退出                                  │%s\n' "${C_MENU}" "${C_OK}" "${C_MENU}" "${C_RESET}"
  printf '%s└─────────────────────────────────────────────┘%s\n' "${C_MENU}" "${C_RESET}"
  printf '\n%s请选择 [%s1%s]: %s' "${C_DIM}" "${C_OK}" "${C_DIM}" "${C_RESET}"
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
normalize_version() {
  local version
  version="$(trim "${1:-}")"
  version="${version#v}"
  version="${version#V}"
  printf '%s' "${version}"
}
version_display() {
  local version
  local fallback="${2:-下载后确认}"
  version="$(normalize_version "${1:-}")"
  if [ -n "${version}" ]; then
    printf 'v%s' "${version}"
  else
    printf '%s' "${fallback}"
  fi
}
detect_binary_version() {
  local file="$1"
  local marker=""
  [ -r "${file}" ] || return 1
  command -v grep >/dev/null 2>&1 || return 1
  marker="$(LC_ALL=C grep -a -o -m1 \
    'MDesk-Remote/[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' \
    "${file}" 2>/dev/null | head -n 1 || true)"
  [ -n "${marker}" ] || return 1
  normalize_version "${marker#MDesk-Remote/}"
}
restore_direct_run_args() {
  local count="${DIRECT_RUN_ARG_COUNT:-0}"
  local index=""
  local variable=""
  local value=""

  case "${count}" in
    ''|*[!0-9]*) count=0 ;;
  esac
  [ "${count}" -le 256 ] || count=256
  DIRECT_RUN_ARGS=()
  for ((index = 0; index < count; index++)); do
    variable="DIRECT_RUN_ARG_${index}"
    eval "value=\${${variable}-}"
    DIRECT_RUN_ARGS+=("${value}")
  done
  DIRECT_RUN_ARG_COUNT="${#DIRECT_RUN_ARGS[@]}"
}
restore_old_direct_run_args() {
  local count="${OLD_DIRECT_RUN_ARG_COUNT:-0}"
  local index=""
  local variable=""
  local value=""

  case "${count}" in
    ''|*[!0-9]*) count=0 ;;
  esac
  [ "${count}" -le 256 ] || count=256
  OLD_DIRECT_RUN_ARGS=()
  for ((index = 0; index < count; index++)); do
    variable="OLD_DIRECT_RUN_ARG_${index}"
    eval "value=\${${variable}-}"
    OLD_DIRECT_RUN_ARGS+=("${value}")
  done
  OLD_DIRECT_RUN_ARG_COUNT="${#OLD_DIRECT_RUN_ARGS[@]}"
}
write_direct_run_config() {
  local index=""

  DIRECT_RUN_ARG_COUNT="${#DIRECT_RUN_ARGS[@]}"
  printf 'DIRECT_RUN_DETECTED=%q\n' "${DIRECT_RUN_DETECTED}"
  printf 'DIRECT_RUN_PID=%q\n' "${DIRECT_RUN_PID}"
  printf 'DIRECT_RUN_CWD=%q\n' "${DIRECT_RUN_CWD}"
  printf 'DIRECT_RUN_ARG_COUNT=%q\n' "${DIRECT_RUN_ARG_COUNT}"
  for ((index = 0; index < DIRECT_RUN_ARG_COUNT; index++)); do
    printf 'DIRECT_RUN_ARG_%s=%q\n' "${index}" "${DIRECT_RUN_ARGS[${index}]}"
  done
}
write_old_direct_run_config() {
  local index=""

  OLD_DIRECT_RUN_ARG_COUNT="${#OLD_DIRECT_RUN_ARGS[@]}"
  printf 'OLD_DIRECT_RUN_ARG_COUNT=%q\n' "${OLD_DIRECT_RUN_ARG_COUNT}"
  for ((index = 0; index < OLD_DIRECT_RUN_ARG_COUNT; index++)); do
    printf 'OLD_DIRECT_RUN_ARG_%s=%q\n' "${index}" "${OLD_DIRECT_RUN_ARGS[${index}]}"
  done
}
version_from_release_url() {
  local url="$1"
  printf '%s\n' "${url}" |
    sed -n 's#.*/download/v\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/.*#\1#p' |
    head -n 1
}
detect_latest_version() {
  local latest_url="https://github.com/${GITHUB_REPO}/releases/latest/download/MDesk-linux-amd64"
  local headers=""
  local location=""
  local version=""
  command -v curl >/dev/null 2>&1 || return 1
  headers="$(curl -fsS -I --connect-timeout 5 --max-time 12 \
    "${latest_url}" 2>/dev/null || true)"
  location="$(printf '%s\n' "${headers}" |
    sed -n '/^[Ll]ocation:[[:space:]]*/{s///;s/\r$//;p;q;}')"
  version="$(version_from_release_url "${location}")"
  [ -n "${version}" ] || return 1
  normalize_version "${version}"
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
  restore_direct_run_args
  INSTALLED_VERSION="$(normalize_version "${INSTALLED_VERSION:-}")"
  if [ -f "${BINARY}" ] && [ -r "${BINARY}" ]; then
    local detected_version
    detected_version="$(detect_binary_version "${BINARY}" || true)"
    if [ -n "${detected_version}" ]; then
      INSTALLED_VERSION="${detected_version}"
    fi
  fi
  refresh_direct_run_pid || true
}
resolve_install_versions() {
  local detected_version=""
  if [ -f "${BINARY:-}" ] && [ -r "${BINARY:-}" ]; then
    detected_version="$(detect_binary_version "${BINARY}" || true)"
    if [ -n "${detected_version}" ]; then
      INSTALLED_VERSION="${detected_version}"
    fi
  fi
  if [ -z "${TARGET_VERSION}" ] && [ "${TARGET_VERSION_LOOKED_UP}" != "yes" ]; then
    TARGET_VERSION_LOOKED_UP="yes"
    info "正在查询可安装版本..."
    TARGET_VERSION="$(detect_latest_version || true)"
  fi
}
print_version_summary() {
  local show_local="${1:-no}"
  if [ "${show_local}" = "yes" ]; then
    printf '%s本地已安装版本：%s\n' "${C_LABEL}" \
      "$(version_display "${INSTALLED_VERSION}" "未知")${C_RESET}"
  fi
  printf '%s准备安装版本：%s\n' "${C_LABEL}" \
    "$(version_display "${TARGET_VERSION}" "下载后确认")${C_RESET}"
}
direct_run_path_value() {
  local base="$1"
  local value="$2"

  case "${value}" in
    /*) printf '%s' "${value}" ;;
    '') printf '%s' "${base}" ;;
    *)
      if [ -n "${base}" ] && [ "${base}" != "/" ]; then
        printf '%s/%s' "${base%/}" "${value}"
      elif [ "${base}" = "/" ]; then
        printf '/%s' "${value}"
      else
        printf '%s' "${value}"
      fi
      ;;
  esac
}
parse_mdesk_runtime_args() {
  local runtime_cwd="$1"
  shift
  local index=0
  local argument=""
  local value=""
  local count="$#"
  local -a runtime_args=("$@")

  while [ "${index}" -lt "${count}" ]; do
    argument="${runtime_args[${index}]}"
    case "${argument}" in
      -port|--port)
        if [ $((index + 1)) -lt "${count}" ]; then
          value="${runtime_args[$((index + 1))]}"
          if [[ "${value}" =~ ^[0-9]+$ ]]; then
            PORT="${value}"
          fi
          index=$((index + 1))
        fi
        ;;
      -port=*|--port=*)
        value="${argument#*=}"
        if [[ "${value}" =~ ^[0-9]+$ ]]; then
          PORT="${value}"
        fi
        ;;
      -data|--data)
        if [ $((index + 1)) -lt "${count}" ]; then
          value="${runtime_args[$((index + 1))]}"
          DATA_DIR="$(direct_run_path_value "${runtime_cwd}" "${value}")"
          index=$((index + 1))
        fi
        ;;
      -data=*|--data=*)
        DATA_DIR="$(direct_run_path_value "${runtime_cwd}" "${argument#*=}")"
        ;;
      -log|--log)
        if [ $((index + 1)) -lt "${count}" ]; then
          value="${runtime_args[$((index + 1))]}"
          LOG_FILE="$(direct_run_path_value "${runtime_cwd}" "${value}")"
          index=$((index + 1))
        fi
        ;;
      -log=*|--log=*)
        LOG_FILE="$(direct_run_path_value "${runtime_cwd}" "${argument#*=}")"
        ;;
    esac
    index=$((index + 1))
  done
}
parse_direct_run_args() {
  if [ "${#DIRECT_RUN_ARGS[@]}" -gt 0 ]; then
    parse_mdesk_runtime_args "${DIRECT_RUN_CWD}" "${DIRECT_RUN_ARGS[@]}"
  fi
}
set_direct_run_port_arg() {
  local port="$1"
  local index=0
  local argument=""
  local found="no"
  local -a updated=()

  while [ "${index}" -lt "${#DIRECT_RUN_ARGS[@]}" ]; do
    argument="${DIRECT_RUN_ARGS[${index}]}"
    case "${argument}" in
      -port|--port)
        updated+=("${argument}" "${port}")
        found="yes"
        index=$((index + 2))
        continue
        ;;
      -port=*|--port=*)
        updated+=("${argument%%=*}=${port}")
        found="yes"
        ;;
      *)
        updated+=("${argument}")
        ;;
    esac
    index=$((index + 1))
  done
  [ "${found}" = "yes" ] || updated+=(-port "${port}")
  DIRECT_RUN_ARGS=("${updated[@]}")
  DIRECT_RUN_ARG_COUNT="${#DIRECT_RUN_ARGS[@]}"
}
configure_direct_run_instance() {
  local pid="$1"
  local executable="$2"
  local version="$3"
  local index=0
  local cwd=""
  local -a argv=()

  mapfile -d '' -t argv <"/proc/${pid}/cmdline" 2>/dev/null || true
  DIRECT_RUN_ARGS=()
  for ((index = 1; index < ${#argv[@]}; index++)); do
    DIRECT_RUN_ARGS+=("${argv[${index}]}")
  done
  DIRECT_RUN_ARG_COUNT="${#DIRECT_RUN_ARGS[@]}"
  DIRECT_RUN_DETECTED="yes"
  DIRECT_RUN_PID="${pid}"
  BINARY="${executable}"
  INSTALL_DIR="$(dirname "${executable}")"
  DATA_DIR="${INSTALL_DIR}/data"
  LOG_FILE="${INSTALL_DIR}/mdesk.log"
  CONSOLE_LOG="${INSTALL_DIR}/mdesk-console.log"
  PORT="${DEFAULT_PORT}"
  SERVICE_MODE="process"

  cwd="$(readlink "/proc/${pid}/cwd" 2>/dev/null || true)"
  if [ -n "${cwd}" ] && [ -d "${cwd}" ]; then
    DIRECT_RUN_CWD="${cwd}"
  else
    DIRECT_RUN_CWD="${INSTALL_DIR}"
  fi
  parse_direct_run_args
  INSTALLED_VERSION="${version}"
}
proc_parent_pid() {
  local pid="$1"

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  sed -n 's/^PPid:[[:space:]]*//p' "/proc/${pid}/status" 2>/dev/null |
    head -n 1
}
direct_pid_is_candidate() {
  local pid="$1"
  local candidate_pid=""

  for candidate_pid in "${DIRECT_CANDIDATE_PIDS[@]}"; do
    [ "${candidate_pid}" = "${pid}" ] && return 0
  done
  return 1
}
direct_candidate_has_ancestor_candidate() {
  local original_pid="$1"
  local current_pid="${1}"
  local parent_pid=""
  local has_candidate_ancestor="no"
  local hops=0
  local -A visited_pids=()

  case "${original_pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac

  while [ "${hops}" -lt 256 ]; do
    [ -z "${visited_pids["${current_pid}"]:-}" ] || return 1
    visited_pids["${current_pid}"]="yes"

    parent_pid="$(proc_parent_pid "${current_pid}" || true)"
    case "${parent_pid}" in
      ''|*[!0-9]*) return 1 ;;
    esac
    [ "${parent_pid}" != "${current_pid}" ] || return 1

    if [ "${parent_pid}" != "${original_pid}" ] &&
       direct_pid_is_candidate "${parent_pid}"; then
      has_candidate_ancestor="yes"
    fi
    [ -z "${visited_pids["${parent_pid}"]:-}" ] || return 1
    if [ "${parent_pid}" = "0" ]; then
      if [ "${has_candidate_ancestor}" = "yes" ]; then
        return 0
      fi
      return 1
    fi

    current_pid="${parent_pid}"
    hops=$((hops + 1))
  done
  return 1
}
filter_direct_mdesk_child_processes() {
  local index=0
  local pid=""
  local child_count=0
  local -a root_pids=()
  local -a root_paths=()
  local -a root_versions=()

  DIRECT_CANDIDATE_CHILD_COUNT="0"
  [ "${#DIRECT_CANDIDATE_PIDS[@]}" -gt 1 ] || return 0

  for ((index = 0; index < ${#DIRECT_CANDIDATE_PIDS[@]}; index++)); do
    pid="${DIRECT_CANDIDATE_PIDS[${index}]}"
    if direct_candidate_has_ancestor_candidate "${pid}"; then
      child_count=$((child_count + 1))
      continue
    fi
    root_pids+=("${pid}")
    root_paths+=("${DIRECT_CANDIDATE_PATHS[${index}]}")
    root_versions+=("${DIRECT_CANDIDATE_VERSIONS[${index}]}")
  done

  DIRECT_CANDIDATE_PIDS=("${root_pids[@]}")
  DIRECT_CANDIDATE_PATHS=("${root_paths[@]}")
  DIRECT_CANDIDATE_VERSIONS=("${root_versions[@]}")
  DIRECT_CANDIDATE_CHILD_COUNT="${child_count}"
}
direct_selection_is_interactive() {
  [ -r /dev/tty ] || [ -t 0 ]
}
scan_direct_mdesk_instances() {
  local pid_path=""
  local pid=""
  local executable=""
  local version=""
  local argument=""
  local worker_argument="no"
  local -a argv=()
  local -A version_cache=()

  DIRECT_CANDIDATE_PIDS=()
  DIRECT_CANDIDATE_PATHS=()
  DIRECT_CANDIDATE_VERSIONS=()

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    kill -0 "${pid}" 2>/dev/null || continue

    executable="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
    case "${executable}" in
      *" (deleted)") executable="${executable% (deleted)}" ;;
    esac
    [ -n "${executable}" ] && [ -f "${executable}" ] && [ -r "${executable}" ] || continue
    # FPK 托管实例必须走飞牛应用中心，不能混入脚本直接运行实例列表。
    if is_fnos_appcenter_path "${executable}"; then
      continue
    fi

    mapfile -d '' -t argv <"/proc/${pid}/cmdline" 2>/dev/null || true
    [ "${#argv[@]}" -gt 0 ] || continue
    [ "${argv[1]:-}" = "--help" ] && continue
    worker_argument="no"
    for argument in "${argv[@]}"; do
      case "${argument}" in
        --update-worker|--password-reset-worker)
          worker_argument="yes"
          break
          ;;
      esac
    done
    [ "${worker_argument}" = "yes" ] && continue

    if [ -n "${version_cache["${executable}"]:-}" ]; then
      version="${version_cache["${executable}"]}"
    else
      version="$(detect_binary_version "${executable}" || true)"
      version_cache["${executable}"]="${version:-__none__}"
    fi
    [ "${version}" = "__none__" ] && continue
    [ -n "${version}" ] || continue

    DIRECT_CANDIDATE_PIDS+=("${pid}")
    DIRECT_CANDIDATE_PATHS+=("${executable}")
    DIRECT_CANDIDATE_VERSIONS+=("${version}")
  done
  filter_direct_mdesk_child_processes
}
select_direct_mdesk_instance() {
  local count=0
  local selected=0
  local input=""
  local index=0

  if [ "${DIRECT_SCAN_DONE}" != "yes" ]; then
    scan_direct_mdesk_instances
    DIRECT_SCAN_DONE="yes"
  fi
  if [ "${DIRECT_RUN_DETECTED}" = "yes" ]; then
    return 0
  fi

  if [ "${DIRECT_CANDIDATE_CHILD_COUNT}" -gt 0 ]; then
    info "已自动忽略 ${DIRECT_CANDIDATE_CHILD_COUNT} 个属于主实例的子进程。"
  fi
  count="${#DIRECT_CANDIDATE_PIDS[@]}"
  [ "${count}" -gt 0 ] || return 1
  if [ "${count}" -eq 1 ]; then
    selected=0
  elif direct_selection_is_interactive; then
    printf '\n检测到多个直接运行的 MDesk 主实例，请选择要升级的实例：\n'
    for ((index = 0; index < count; index++)); do
      printf '  %d) PID %s  版本 %s  文件 %s\n' \
        "$((index + 1))" \
        "${DIRECT_CANDIDATE_PIDS[${index}]}" \
        "$(version_display "${DIRECT_CANDIDATE_VERSIONS[${index}]}" "未知")" \
        "${DIRECT_CANDIDATE_PATHS[${index}]}"
    done
    while true; do
      if ! prompt_read_into input "请选择 [默认 1]: "; then
        input="1"
      fi
      input="$(trim "${input}")"
      input="${input:-1}"
      if [[ "${input}" =~ ^[0-9]+$ ]] &&
         [ "${input}" -ge 1 ] && [ "${input}" -le "${count}" ]; then
        selected=$((input - 1))
        break
      fi
      warn "请输入 1-${count} 之间的序号。"
    done
  else
    selected=0
    warn "检测到多个直接运行的 MDesk 实例；非交互模式将使用第一个实例：PID ${DIRECT_CANDIDATE_PIDS[0]}，${DIRECT_CANDIDATE_PATHS[0]}"
  fi

  configure_direct_run_instance \
    "${DIRECT_CANDIDATE_PIDS[${selected}]}" \
    "${DIRECT_CANDIDATE_PATHS[${selected}]}" \
    "${DIRECT_CANDIDATE_VERSIONS[${selected}]}"
  return 0
}
print_direct_run_summary() {
  local index=0
  local quoted=""
  local arguments=""

  [ "${DIRECT_RUN_DETECTED}" = "yes" ] || return 0
  info "运行来源：直接运行的 MDesk 实例（PID ${DIRECT_RUN_PID}）"
  info "二进制路径：${BINARY}"
  info "文件名：${BINARY##*/}"
  info "工作目录：${DIRECT_RUN_CWD}"
  for ((index = 0; index < ${#DIRECT_RUN_ARGS[@]}; index++)); do
    printf -v quoted '%q' "${DIRECT_RUN_ARGS[${index}]}"
    arguments+=" ${quoted}"
  done
  [ -z "${arguments}" ] || info "重启参数：${arguments# }"
}
process_option_argument() {
  local pid="$1"
  local option="$2"
  local long_option="--${option#-}"
  local index=0
  local argument=""
  local -a argv=()

  mapfile -d '' -t argv <"/proc/${pid}/cmdline" 2>/dev/null || true
  for ((index = 0; index < ${#argv[@]}; index++)); do
    argument="${argv[${index}]}"
    case "${argument}" in
      "${option}"|"${long_option}")
        if [ $((index + 1)) -lt "${#argv[@]}" ]; then
          printf '%s' "${argv[$((index + 1))]}"
          return 0
        fi
        ;;
      "${option}"=*|"${long_option}"=*)
        printf '%s' "${argument#*=}"
        return 0
        ;;
    esac
  done
  return 1
}
appcenter_process_port() {
  local pid="$1"
  local port=""

  port="$(process_option_argument "${pid}" "-port" || true)"
  if [[ "${port}" =~ ^[0-9]+$ ]] &&
     [ "${port}" -ge 1 ] && [ "${port}" -le 65535 ]; then
    printf '%s' "${port}"
    return 0
  fi
  printf '%s' "${DEFAULT_PORT}"
}
scan_appcenter_mdesk_instances() {
  local pid_path=""
  local pid=""
  local executable=""
  local version=""
  local argument=""
  local worker_argument="no"
  local -a argv=()
  local -A version_cache=()

  APPCENTER_CANDIDATE_PIDS=()
  APPCENTER_CANDIDATE_PATHS=()
  APPCENTER_CANDIDATE_VERSIONS=()
  APPCENTER_CANDIDATE_PORTS=()

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    kill -0 "${pid}" 2>/dev/null || continue

    executable="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
    case "${executable}" in
      *" (deleted)") executable="${executable% (deleted)}" ;;
    esac
    is_fnos_appcenter_path "${executable}" || continue
    case "${executable##*/}" in
      MDesk|MDesk-*) ;;
      *) continue ;;
    esac
    [ -f "${executable}" ] && [ -r "${executable}" ] || continue

    mapfile -d '' -t argv <"/proc/${pid}/cmdline" 2>/dev/null || true
    [ "${#argv[@]}" -gt 0 ] || continue
    [ "${argv[1]:-}" = "--help" ] && continue
    worker_argument="no"
    for argument in "${argv[@]}"; do
      case "${argument}" in
        --update-worker|--password-reset-worker)
          worker_argument="yes"
          break
          ;;
      esac
    done
    [ "${worker_argument}" = "yes" ] && continue

    if [ -n "${version_cache["${executable}"]:-}" ]; then
      version="${version_cache["${executable}"]}"
    else
      version="$(detect_binary_version "${executable}" || true)"
      version_cache["${executable}"]="${version:-__none__}"
    fi
    [ "${version}" = "__none__" ] && continue
    [ -n "${version}" ] || continue

    APPCENTER_CANDIDATE_PIDS+=("${pid}")
    APPCENTER_CANDIDATE_PATHS+=("${executable}")
    APPCENTER_CANDIDATE_VERSIONS+=("${version}")
    APPCENTER_CANDIDATE_PORTS+=("$(appcenter_process_port "${pid}")")
  done

  [ "${#APPCENTER_CANDIDATE_PIDS[@]}" -gt 0 ]
}
appcenter_candidate_index() {
  local wanted_pid="$1"
  local index=0

  for ((index = 0; index < ${#APPCENTER_CANDIDATE_PIDS[@]}; index++)); do
    if [ "${APPCENTER_CANDIDATE_PIDS[${index}]}" = "${wanted_pid}" ]; then
      printf '%s' "${index}"
      return 0
    fi
  done
  return 1
}
select_appcenter_instance_pid() {
  local pid_file_pid="$1"
  local index=0
  local pid=""
  local port=""

  for ((index = 0; index < ${#APPCENTER_CANDIDATE_PIDS[@]}; index++)); do
    pid="${APPCENTER_CANDIDATE_PIDS[${index}]}"
    port="${APPCENTER_CANDIDATE_PORTS[${index}]}"
    [ "${pid}" = "${pid_file_pid}" ] || continue
    if pid_owns_listening_port "${pid}" "${port}"; then
      printf '%s' "${pid}"
      return 0
    fi
  done

  for ((index = 0; index < ${#APPCENTER_CANDIDATE_PIDS[@]}; index++)); do
    pid="${APPCENTER_CANDIDATE_PIDS[${index}]}"
    port="${APPCENTER_CANDIDATE_PORTS[${index}]}"
    if pid_owns_listening_port "${pid}" "${port}"; then
      printf '%s' "${pid}"
      return 0
    fi
  done

  if [ -n "${pid_file_pid}" ] && appcenter_candidate_index "${pid_file_pid}" >/dev/null; then
    printf '%s' "${pid_file_pid}"
    return 0
  fi

  [ "${#APPCENTER_CANDIDATE_PIDS[@]}" -gt 0 ] || return 1
  printf '%s' "${APPCENTER_CANDIDATE_PIDS[0]}"
}
configure_appcenter_run_instance() {
  local pid="$1"
  local executable="$2"
  local version="$3"
  local index=0
  local cwd=""
  local -a argv=()
  local -a runtime_args=()

  APPCENTER_INSTANCE_PID="${pid}"
  BINARY="${executable}"
  INSTALL_DIR="$(dirname "${executable}")"
  DATA_DIR="${INSTALL_DIR}/data"
  LOG_FILE="${INSTALL_DIR}/mdesk.log"
  CONSOLE_LOG="${INSTALL_DIR}/mdesk-console.log"
  PORT="${DEFAULT_PORT}"
  SERVICE_MODE="process"
  DIRECT_RUN_DETECTED="no"
  DIRECT_RUN_PID=""

  cwd="$(readlink "/proc/${pid}/cwd" 2>/dev/null || true)"
  [ -n "${cwd}" ] && [ -d "${cwd}" ] || cwd="${INSTALL_DIR}"

  mapfile -d '' -t argv <"/proc/${pid}/cmdline" 2>/dev/null || true
  for ((index = 1; index < ${#argv[@]}; index++)); do
    runtime_args+=("${argv[${index}]}")
  done
  if [ "${#runtime_args[@]}" -gt 0 ]; then
    parse_mdesk_runtime_args "${cwd}" "${runtime_args[@]}"
  fi
  INSTALLED_VERSION="${version}"
}
infer_appcenter_install() {
  local pid_file_pid=""
  local selected_pid=""
  local selected_index=0

  scan_appcenter_mdesk_instances || return 1
  if [ -r "${APPCENTER_APP_PID_FILE}" ]; then
    pid_file_pid="$(head -n 1 "${APPCENTER_APP_PID_FILE}" 2>/dev/null || true)"
    pid_file_pid="$(trim "${pid_file_pid}")"
  fi

  selected_pid="$(select_appcenter_instance_pid "${pid_file_pid}" || true)"
  [ -n "${selected_pid}" ] || return 1
  selected_index="$(appcenter_candidate_index "${selected_pid}")"
  configure_appcenter_run_instance \
    "${selected_pid}" \
    "${APPCENTER_CANDIDATE_PATHS[${selected_index}]}" \
    "${APPCENTER_CANDIDATE_VERSIONS[${selected_index}]}"

  if [ "${pid_file_pid}" != "${selected_pid}" ]; then
    info "已识别飞牛 FPK 主实例：PID ${selected_pid}（监听端口 ${PORT}）；应用中心 PID 文件记录为 ${pid_file_pid:-空}。"
    if ! write_appcenter_app_pid "${selected_pid}"; then
      warn "已识别飞牛 FPK 主实例 PID ${selected_pid}，但未能校正 ${APPCENTER_APP_PID_FILE}。"
    fi
  fi
  return 0
}
infer_existing_install() {
  local candidate=""
  local name=""
  local dir=""
  local exec_start=""
  local marker="no"
  if infer_appcenter_install; then
    return 0
  fi
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
  if [ "${marker}" = "no" ] && select_direct_mdesk_instance; then
    return 0
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
  if infer_appcenter_install; then
    return 0
  fi
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
  if infer_appcenter_install; then
    return 0
  fi
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
    printf 'INSTALLED_VERSION=%q\n' "${INSTALLED_VERSION}"
    write_direct_run_config
  } > "${CONFIG_FILE}.tmp"
  chmod 600 "${CONFIG_FILE}.tmp"
  mv -f "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
}
require_download_tools() {
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 ||
    die "需要 curl 或 wget 才能下载 M•Desk。"
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
    info "正在测速筛选最优 GitHub 加速节点，请稍候..."
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
    info "尝试 GitHub 下载线路 ${index}/${#ordered[@]}：${candidate}"
    if download_file "${candidate}" "${destination}" && validate_binary "${destination}"; then
      return 0
    fi
    rm -f -- "${destination}"
    warn "该线路下载或校验失败，切换下一个"
  done

  return 1
}
fetch_binary() {
  local destination="$1"
  local mirror_url="${MIRROR_BASE}/MDesk-linux-${ARCH}"
  local detected_version=""
  info "优先从项目镜像下载 ${APP_DISPLAY_NAME}：${mirror_url}"
  if download_file "${mirror_url}" "${destination}" && validate_binary "${destination}"; then
    detected_version="$(detect_binary_version "${destination}" || true)"
    if [ -n "${detected_version}" ]; then
      TARGET_VERSION="${detected_version}"
    fi
    success "项目镜像下载完成"
    return 0
  fi
  rm -f -- "${destination}"
  warn "项目镜像不可用，切换到 GitHub Release 加速线路"
  if download_from_github "${destination}"; then
    detected_version="$(detect_binary_version "${destination}" || true)"
    if [ -n "${detected_version}" ]; then
      TARGET_VERSION="${detected_version}"
    fi
    success "GitHub Release 下载完成"
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

installer_supports_password_reset_worker() {
  local file="${1:-}"

  [ -n "${file}" ] && [ -f "${file}" ] && [ -r "${file}" ] && [ -s "${file}" ] &&
    head -n 1 "${file}" 2>/dev/null | grep -q '^#!.*bash' &&
    grep -Fq -- '--password-reset-worker' "${file}" &&
    bash -n "${file}" >/dev/null 2>&1
}

ensure_password_reset_installer() {
  if installer_supports_password_reset_worker "${INSTALLER_FILE}"; then
    chmod 0755 "${INSTALLER_FILE}" 2>/dev/null || return 1
    return 0
  fi
  persist_installer
}

installer_supports_appcenter_action_worker() {
  local file="${1:-}"

  [ -n "${file}" ] && [ -f "${file}" ] && [ -r "${file}" ] && [ -s "${file}" ] &&
    head -n 1 "${file}" 2>/dev/null | grep -q '^#!.*bash' &&
    grep -Fq -- '--appcenter-action-worker' "${file}" &&
    bash -n "${file}" >/dev/null 2>&1
}

ensure_appcenter_action_installer() {
  if installer_supports_appcenter_action_worker "${INSTALLER_FILE}"; then
    chmod 0755 "${INSTALLER_FILE}" 2>/dev/null || return 1
    return 0
  fi
  persist_installer
}

installer_supports_restart_worker() {
  local file="${1:-}"

  [ -n "${file}" ] && [ -f "${file}" ] && [ -r "${file}" ] && [ -s "${file}" ] &&
    head -n 1 "${file}" 2>/dev/null | grep -q '^#!.*bash' &&
    grep -Fq -- '--restart-worker' "${file}" &&
    bash -n "${file}" >/dev/null 2>&1
}

ensure_restart_installer() {
  if installer_supports_restart_worker "${INSTALLER_FILE}"; then
    chmod 0755 "${INSTALLER_FILE}" 2>/dev/null || return 1
    return 0
  fi
  persist_installer
}

write_appcenter_action_status() {
  local state="$1"
  local message="$2"
  local pid="${3:-}"
  local temporary="${APPCENTER_ACTION_STATUS_FILE}.tmp.$$"

  mkdir -p "${CONFIG_DIR}"
  {
    printf 'STATE=%s\n' "${state}"
    printf 'MESSAGE=%s\n' "${message}"
    printf 'PID=%s\n' "${pid}"
    printf 'TYPE=%s\n' "${APPCENTER_ACTION_TYPE}"
    printf 'TARGET_VERSION=%s\n' "${APPCENTER_ACTION_TARGET_VERSION}"
    printf 'UPDATED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    printf 'LOG=%s\n' "${APPCENTER_ACTION_LOG}"
  } >"${temporary}"
  chmod 600 "${temporary}" 2>/dev/null || true
  mv -f "${temporary}" "${APPCENTER_ACTION_STATUS_FILE}"
}

read_appcenter_action_value() {
  read_update_value "$1" "${APPCENTER_ACTION_STATUS_FILE}"
}

pid_is_appcenter_action_worker() {
  local pid="${1:-}"
  local cmdline=""

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 1
  cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"
  case " ${cmdline} " in
    *" --appcenter-action-worker "*) return 0 ;;
  esac
  return 1
}

appcenter_action_in_progress() {
  local state=""
  local pid=""
  local updated_at=""
  local age=""

  state="$(read_appcenter_action_value STATE || true)"
  case "${state}" in
    starting|running) ;;
    *) return 1 ;;
  esac

  if command -v systemctl >/dev/null 2>&1 &&
     [ -f "${APPCENTER_ACTION_UNIT_FILE}" ] &&
     systemctl is-active --quiet "${APPCENTER_ACTION_UNIT}" 2>/dev/null; then
    return 0
  fi

  pid="$(read_appcenter_action_value PID || true)"
  if pid_is_appcenter_action_worker "${pid}"; then
    return 0
  fi

  if [ "${state}" = "starting" ]; then
    updated_at="$(read_appcenter_action_value UPDATED_AT || true)"
    age="$(status_age_seconds "${updated_at}" || true)"
    if [ -z "${age}" ] || [ "${age}" -lt 60 ]; then
      return 0
    fi
  fi
  return 1
}

prepare_appcenter_action_job() {
  local root="/run"

  if [ ! -d "${root}" ] || [ ! -w "${root}" ]; then
    root="${TMPDIR:-/var/tmp}"
    [ -d "${root}" ] || root="/tmp"
  fi
  APPCENTER_ACTION_JOB_DIR="$(mktemp -d "${root%/}/mdesk-appcenter-action.XXXXXX")" ||
    return 1
  chmod 700 "${APPCENTER_ACTION_JOB_DIR}"
}

write_appcenter_action_job() {
  local job_file="${APPCENTER_ACTION_JOB_DIR}/appcenter-action.conf"

  {
    printf 'ACTION_TYPE=%q\n' "${APPCENTER_ACTION_TYPE}"
    printf 'TARGET_VERSION=%q\n' "${APPCENTER_ACTION_TARGET_VERSION}"
    printf 'INSTALLED_VERSION=%q\n' "${INSTALLED_VERSION}"
    printf 'PORT=%q\n' "${PORT}"
    printf 'INSTALL_DIR=%q\n' "${INSTALL_DIR}"
    printf 'BINARY=%q\n' "${BINARY}"
    printf 'DATA_DIR=%q\n' "${DATA_DIR}"
    printf 'LOG_FILE=%q\n' "${LOG_FILE}"
    printf 'CONSOLE_LOG=%q\n' "${CONSOLE_LOG}"
    printf 'SERVICE_MODE=%q\n' "${SERVICE_MODE}"
    printf 'APPCENTER_REAL_BINARY=%q\n' "${APPCENTER_REAL_BINARY}"
    printf 'APPCENTER_UPGRADE_BACKUP=%q\n' "${APPCENTER_UPGRADE_BACKUP}"
    printf 'APPCENTER_UPGRADE_STAGING=%q\n' "${APPCENTER_UPGRADE_STAGING}"
    write_direct_run_config
  } >"${job_file}"
  chmod 600 "${job_file}"
}

wait_appcenter_action_worker_ready() {
  local ready_file="${APPCENTER_ACTION_JOB_DIR}/worker.ready"
  local deadline=$((SECONDS + 15))
  local pid=""
  local state=""

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if [ -r "${ready_file}" ]; then
      pid="$(head -n 1 "${ready_file}" 2>/dev/null || true)"
      if pid_is_appcenter_action_worker "${pid}"; then
        return 0
      fi
    fi
    state="$(read_appcenter_action_value STATE || true)"
    [ "${state}" = "success" ] && return 0
    [ "${state}" = "failed" ] && return 1
    sleep 1
  done
  return 1
}

launch_detached_appcenter_action() {
  local unit_file="${APPCENTER_ACTION_UNIT_FILE}"
  local pid=""

  APPCENTER_ACTION_WORKER_LAUNCHED="no"
  APPCENTER_ACTION_WORKER_IS_CHILD="no"
  write_appcenter_action_status "starting" \
    "正在准备独立飞牛应用中心操作进程" "$$" || true

  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    mkdir -p "$(dirname "${unit_file}")"
    cat >"${unit_file}" <<EOF
[Unit]
Description=MDesk App Center action worker
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash "${INSTALLER_FILE}" --appcenter-action-worker "${APPCENTER_ACTION_JOB_DIR}"
TimeoutStartSec=600
TimeoutStopSec=60
Nice=5
EOF
    if normalize_text_file "${unit_file}"; then
      chmod 644 "${unit_file}"
      if systemctl daemon-reload >/dev/null 2>&1; then
        systemctl reset-failed "${APPCENTER_ACTION_UNIT}" >/dev/null 2>&1 || true
        APPCENTER_ACTION_WORKER_LAUNCHED="yes"
        if systemctl start --no-block "${APPCENTER_ACTION_UNIT}"; then
          if wait_appcenter_action_worker_ready; then
            info "独立飞牛应用中心操作进程已就绪。"
            return 0
          fi
          if systemctl is-active --quiet "${APPCENTER_ACTION_UNIT}" 2>/dev/null; then
            info "独立飞牛应用中心操作进程正在启动。"
            return 0
          fi
          warn "独立 systemd 操作进程未就绪便已退出。"
        fi
        APPCENTER_ACTION_WORKER_LAUNCHED="no"
      fi
    fi
    rm -f "${unit_file}"
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  APPCENTER_ACTION_WORKER_LAUNCHED="yes"
  if command -v setsid >/dev/null 2>&1; then
    nohup setsid /bin/bash "${INSTALLER_FILE}" --appcenter-action-worker \
      "${APPCENTER_ACTION_JOB_DIR}" >>"${APPCENTER_ACTION_LOG}" 2>&1 </dev/null &
    pid="$!"
  else
    nohup /bin/bash "${INSTALLER_FILE}" --appcenter-action-worker \
      "${APPCENTER_ACTION_JOB_DIR}" >>"${APPCENTER_ACTION_LOG}" 2>&1 </dev/null &
    pid="$!"
  fi
  disown "${pid}" 2>/dev/null || true

  if wait_appcenter_action_worker_ready; then
    info "独立飞牛应用中心操作进程已就绪（PID ${pid}）。"
    return 0
  fi

  APPCENTER_ACTION_WORKER_LAUNCHED="no"
  kill "${pid}" 2>/dev/null || true
  return 1
}

run_appcenter_action_worker() {
  local job_dir="${1:-}"
  local job_file=""
  local ready_file=""
  local new_version=""

  APPCENTER_ACTION_JOB_DIR="${job_dir}"
  APPCENTER_ACTION_WORKER_LAUNCHED="yes"
  APPCENTER_ACTION_WORKER_ACTIVE="yes"
  APPCENTER_ACTION_WORKER_IS_CHILD="yes"
  mkdir -p "${CONFIG_DIR}"
  exec >>"${APPCENTER_ACTION_LOG}" 2>&1
  printf '\n[%s] 飞牛应用中心后台操作进程已启动（PID %s）。\n' \
    "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)" "$$"

  job_file="${APPCENTER_ACTION_JOB_DIR}/appcenter-action.conf"
  ready_file="${APPCENTER_ACTION_JOB_DIR}/worker.ready"
  if [ -z "${APPCENTER_ACTION_JOB_DIR}" ] || [ ! -r "${job_file}" ]; then
    APPCENTER_ACTION_WORKER_ACTIVE="no"
    write_appcenter_action_status "failed" \
      "找不到飞牛应用中心后台操作配置" "$$" || true
    rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
    return 1
  fi

  # shellcheck disable=SC1090
  . "${job_file}"
  APPCENTER_ACTION_TYPE="${ACTION_TYPE:-}"
  APPCENTER_ACTION_TARGET_VERSION="${TARGET_VERSION:-}"
  restore_direct_run_args

  if ! is_appcenter_managed; then
    APPCENTER_ACTION_WORKER_ACTIVE="no"
    write_appcenter_action_status "failed" \
      "无法确认当前是飞牛应用中心托管实例" "$$" || true
    rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
    return 1
  fi

  printf '%s\n' "$$" >"${ready_file}"
  chmod 600 "${ready_file}"

  case "${APPCENTER_ACTION_TYPE}" in
    restart)
      write_appcenter_action_status "running" \
        "正在通过飞牛应用中心停止 MDesk" "$$"
      if ! stop_appcenter_service; then
        APPCENTER_ACTION_WORKER_ACTIVE="no"
        write_appcenter_action_status "failed" \
          "飞牛应用中心停止失败，未尝试重启" "$$" || true
        rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
        return 1
      fi

      write_appcenter_action_status "running" \
        "正在通过飞牛应用中心启动 MDesk" "$$"
      if ! start_appcenter_service || ! wait_http_ready; then
        show_service_failure
        APPCENTER_ACTION_WORKER_ACTIVE="no"
        write_appcenter_action_status "failed" \
          "飞牛应用中心重启失败，请检查操作日志" "$$" || true
        rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
        return 1
      fi

      finish_successful_restart "MDesk 已通过飞牛应用中心重启成功。" || true
      APPCENTER_ACTION_WORKER_ACTIVE="no"
      APPCENTER_ACTION_WORKER_SUCCEEDED="yes"
      write_appcenter_action_status "success" \
        "MDesk 已通过飞牛应用中心重启" "$$"
      rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
      return 0
      ;;
    upgrade)
      if [ -z "${APPCENTER_REAL_BINARY:-}" ] ||
         [ -z "${APPCENTER_UPGRADE_BACKUP:-}" ] ||
         [ -z "${APPCENTER_UPGRADE_STAGING:-}" ] ||
         [ ! -f "${APPCENTER_UPGRADE_BACKUP}" ] ||
         [ ! -f "${APPCENTER_UPGRADE_STAGING}" ]; then
        APPCENTER_ACTION_WORKER_ACTIVE="no"
        write_appcenter_action_status "failed" \
          "升级所需的暂存文件或备份文件不存在" "$$" || true
        rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
        return 1
      fi

      write_appcenter_action_status "running" \
        "正在通过飞牛应用中心停止 MDesk，准备替换二进制" "$$"
      if ! stop_appcenter_service; then
        APPCENTER_ACTION_WORKER_ACTIVE="no"
        write_appcenter_action_status "failed" \
          "飞牛应用中心停止失败，已安装二进制未被修改" "$$" || true
        rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
        return 1
      fi

      APPCENTER_UPGRADE_ACTIVE="yes"
      if ! mv -f -- "${APPCENTER_UPGRADE_STAGING}" "${APPCENTER_REAL_BINARY}"; then
        APPCENTER_UPGRADE_ACTIVE="no"
        start_appcenter_service || true
        APPCENTER_ACTION_WORKER_ACTIVE="no"
        write_appcenter_action_status "failed" \
          "二进制替换失败，已尝试重新启动原有进程" "$$" || true
        rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
        return 1
      fi
      APPCENTER_UPGRADE_STAGING=""

      new_version="${TARGET_VERSION:-}"
      if [ -n "${new_version}" ]; then
        INSTALLED_VERSION="${new_version}"
      fi
      write_appcenter_action_status "running" \
        "正在通过飞牛应用中心启动升级后的 MDesk" "$$"
      if ! start_appcenter_service || ! wait_http_ready; then
        show_service_failure
        rollback_appcenter_upgrade || true
        APPCENTER_ACTION_WORKER_ACTIVE="no"
        write_appcenter_action_status "failed" \
          "升级失败，已尽可能还原原有二进制" "$$" || true
        rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
        return 1
      fi

      APPCENTER_UPGRADE_ACTIVE="no"
      rm -f -- "${APPCENTER_UPGRADE_BACKUP}"
      APPCENTER_UPGRADE_BACKUP=""
      finish_successful_restart \
        "MDesk 已升级到 ${new_version:-目标版本}，并已通过飞牛应用中心重启。" || true
      APPCENTER_ACTION_WORKER_ACTIVE="no"
      APPCENTER_ACTION_WORKER_SUCCEEDED="yes"
      write_appcenter_action_status "success" \
        "MDesk 已升级并已通过飞牛应用中心重启" "$$"
      rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
      return 0
      ;;
    *)
      APPCENTER_ACTION_WORKER_ACTIVE="no"
      write_appcenter_action_status "failed" \
        "不支持的飞牛应用中心操作类型：${APPCENTER_ACTION_TYPE}" "$$" || true
      rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
      return 1
      ;;
  esac
}

queue_detached_appcenter_action() {
  local action_type="$1"
  local target_version="${2:-}"

  APPCENTER_ACTION_TYPE="${action_type}"
  APPCENTER_ACTION_TARGET_VERSION="${target_version}"
  ensure_appcenter_action_installer ||
    die "无法保存支持飞牛应用中心后台操作的安装脚本。"
  prepare_appcenter_action_job ||
    die "无法创建飞牛应用中心后台操作任务目录。"
  if ! write_appcenter_action_job; then
    rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
    APPCENTER_ACTION_JOB_DIR=""
    die "无法写入飞牛应用中心后台操作任务配置。"
  fi

  info "正在将${action_type}操作交给独立 systemd 后台进程..."
  if ! launch_detached_appcenter_action; then
    APPCENTER_ACTION_WORKER_LAUNCHED="no"
    write_appcenter_action_status "failed" \
      "无法启动飞牛应用中心后台操作进程" "" || true
    rm -rf -- "${APPCENTER_ACTION_JOB_DIR}"
    APPCENTER_ACTION_JOB_DIR=""
    warn "无法启动飞牛应用中心后台操作进程。"
    return 1
  fi

  success "飞牛应用中心${action_type}操作已交给独立后台进程继续执行。"
  printf '操作日志：%s\n' "${APPCENTER_ACTION_LOG}"
  printf '查看状态：sudo mdeskctl status\n'
  return 0
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

pid_is_update_worker() {
  local pid="${1:-}"
  local cmdline=""

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 1
  cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"
  case " ${cmdline} " in
    *" --update-worker "*) return 0 ;;
  esac
  return 1
}

status_age_seconds() {
  local ts="$1"
  local then=""
  local now=""

  [ -n "${ts}" ] || return 1
  then="$(date -d "${ts}" +%s 2>/dev/null || true)"
  [ -n "${then}" ] || return 1
  now="$(date +%s 2>/dev/null || true)"
  [ -n "${now}" ] || return 1
  printf '%s' "$(( now - then ))"
}

clear_update_lock() {
  local reason="${1:-stale}"

  rm -f "${UPDATE_STATUS_FILE}" 2>/dev/null || true
  if command -v systemctl >/dev/null 2>&1 && [ -f "${UPDATER_UNIT_FILE}" ]; then
    systemctl stop "${UPDATER_UNIT}" >/dev/null 2>&1 || true
    systemctl reset-failed "${UPDATER_UNIT}" >/dev/null 2>&1 || true
    rm -f "${UPDATER_UNIT_FILE}"
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi
  warn "检测到过期的升级锁（${reason}），已自动清除，可重新执行升级。"
}

readonly UPDATE_LOCK_MAX_AGE=1800
readonly UPDATE_STARTING_GRACE=60

update_in_progress() {
  local state=""
  local pid=""
  local updated_at=""
  local age=""

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

  if pid_is_update_worker "${pid}"; then
    return 0
  fi

  if kill -0 "${pid}" 2>/dev/null; then
    if [ "${state}" = "starting" ]; then
      updated_at="$(read_update_value UPDATED_AT || true)"
      age="$(status_age_seconds "${updated_at}" || true)"
      if [ -z "${age}" ] || [ "${age}" -lt "${UPDATE_STARTING_GRACE}" ]; then
        return 0
      fi
    fi
    updated_at="$(read_update_value UPDATED_AT || true)"
    age="$(status_age_seconds "${updated_at}" || true)"
    if [ -z "${age}" ] || [ "${age}" -ge "${UPDATE_LOCK_MAX_AGE}" ]; then
      clear_update_lock "升级锁超时且进程状态无法确认"
    fi
    return 1
  fi

  updated_at="$(read_update_value UPDATED_AT || true)"
  age="$(status_age_seconds "${updated_at}" || true)"
  if [ -z "${age}" ] || [ "${age}" -ge "${UPDATE_LOCK_MAX_AGE}" ]; then
    clear_update_lock "进程已退出但状态未更新"
  fi
  return 1
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
    printf 'INSTALLED_VERSION=%q\n' "${INSTALLED_VERSION}"
    printf 'TARGET_VERSION=%q\n' "${TARGET_VERSION}"
    write_direct_run_config
    write_old_direct_run_config
  } >"${job_file}"
  chmod 600 "${job_file}"
}

launch_detached_update() {
  local unit_file="${UPDATER_UNIT_FILE}"
  local pid=""
  local worker_pid=""
  local state=""
  local attempt=0

  if is_appcenter_managed; then
    reject_appcenter_script_upgrade
    return 1
  fi
  if update_in_progress; then
    die "已有 M•Desk 升级任务正在运行，请稍后再试。"
  fi
  persist_installer ||
    die "无法保存安装脚本，不能启动独立升级进程。"
  prepare_update_job
  write_update_job
  write_update_status "starting" "正在启动独立升级任务" "$$" || true
  KEEP_TEMP_DIR="yes"

  if [ "${OLD_SERVICE_MODE}" = "systemd" ] &&
     command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    mkdir -p "$(dirname "${unit_file}")"
    cat >"${unit_file}" <<EOF
[Unit]
Description=${APP_DISPLAY_NAME} detached updater
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
  restore_direct_run_args
  restore_old_direct_run_args
  TEMP_DIR="${UPDATE_JOB_DIR}/work"
  KEEP_TEMP_DIR="yes"
  WORKER_LAUNCHED="yes"
  WORKER_ACTIVE="yes"

  mkdir -p "${CONFIG_DIR}"
  exec >>"${UPDATE_LOG}" 2>&1
  if is_appcenter_managed; then
    WORKER_ACTIVE="no"
    write_update_status "failed" "${APPCENTER_SCRIPT_UPGRADE_WARNING}" "$$" || true
    reject_appcenter_script_upgrade || true
    rm -rf -- "${UPDATE_JOB_DIR}"
    return 1
  fi
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

  info "准备安装版本：$(version_display "${TARGET_VERSION}" "下载后确认")"
  write_update_status "running" "正在停止旧服务并安装新版本" "$$"
  if apply_prepared_install; then
    WORKER_SUCCEEDED="yes"
    WORKER_ACTIVE="no"
    write_update_status "success" "M•Desk 已升级并通过健康检查" "$$"
    success "M•Desk 已升级并重新启动。"
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

appcenter_listening_mdesk_pid() {
  local port="${1:-${PORT}}"
  local pid_path=""
  local pid=""

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    process_is_mdesk_pid "${pid}" || continue
    if pid_owns_listening_port "${pid}" "${port}"; then
      printf '%s' "${pid}"
      return 0
    fi
  done
  return 1
}

appcenter_main_pid() {
  local pid_file_pid=""
  local listener_pid=""

  if [ -r "${APPCENTER_APP_PID_FILE}" ]; then
    pid_file_pid="$(head -n 1 "${APPCENTER_APP_PID_FILE}" 2>/dev/null || true)"
    pid_file_pid="$(trim "${pid_file_pid}")"
    if process_is_mdesk_pid "${pid_file_pid}" &&
       pid_owns_listening_port "${pid_file_pid}" "${PORT}"; then
      printf '%s' "${pid_file_pid}"
      return 0
    fi
  fi

  listener_pid="$(appcenter_listening_mdesk_pid "${PORT}" || true)"
  if [ -n "${listener_pid}" ]; then
    printf '%s' "${listener_pid}"
    return 0
  fi

  process_is_mdesk_pid "${pid_file_pid}" || return 1
  printf '%s' "${pid_file_pid}"
}

wait_appcenter_main_pid() {
  local deadline=$((SECONDS + 25))

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if appcenter_main_pid >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

refresh_direct_run_pid() {
  local pid=""
  local pid_path=""
  local executable=""
  local pid_file_pid=""

  [ "${DIRECT_RUN_DETECTED}" = "yes" ] || return 0
  if process_is_mdesk_pid "${DIRECT_RUN_PID}"; then
    return 0
  fi
  if [ -r "${PID_FILE}" ]; then
    pid_file_pid="$(head -n 1 "${PID_FILE}" 2>/dev/null || true)"
    if process_is_mdesk_pid "${pid_file_pid}"; then
      DIRECT_RUN_PID="${pid_file_pid}"
      return 0
    fi
  fi
  [ -n "${BINARY}" ] || return 1

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    executable="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
    case "${executable}" in
      *" (deleted)") executable="${executable% (deleted)}" ;;
    esac
    if [ "${executable}" = "${BINARY}" ]; then
      DIRECT_RUN_PID="${pid}"
      return 0
    fi
  done
  return 1
}

stop_mdesk_processes() {
  local pid_path=""
  local pid=""
  local count=0
  local running="no"
  local -a pids=()

  if [ "${DIRECT_RUN_DETECTED}" = "yes" ]; then
    if [ -n "${DIRECT_RUN_PID}" ] &&
       process_is_mdesk_pid "${DIRECT_RUN_PID}"; then
      pids+=("${DIRECT_RUN_PID}")
      kill -TERM "${DIRECT_RUN_PID}" 2>/dev/null || true
    fi
  else
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
  fi

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
  local pid=""

  if is_appcenter_managed; then
    appcenter_main_pid >/dev/null
    return
  fi

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
      if [ "${DIRECT_RUN_DETECTED}" = "yes" ] &&
         [ -n "${DIRECT_RUN_PID}" ] &&
         process_is_mdesk_pid "${DIRECT_RUN_PID}"; then
        return 0
      fi
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
Description=${APP_DISPLAY_NAME} ${APP_DESCRIPTION}
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

name="${APP_DISPLAY_NAME}"
description="${APP_DISPLAY_NAME} ${APP_DESCRIPTION}"
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
# Short-Description: ${APP_DISPLAY_NAME} ${APP_DESCRIPTION}
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

port_is_listening() {
  local hex_port=""
  local file=""

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

  if command -v fuser >/dev/null 2>&1; then
    fuser -s -n tcp "${PORT}" >/dev/null 2>&1
    return
  fi

  hex_port="$(printf '%04X' "${PORT}")"
  for file in /proc/net/tcp /proc/net/tcp6; do
    [ -r "${file}" ] || continue
    awk -v port=":${hex_port}" '
      NR > 1 && $2 ~ port "$" && $4 == "0A" { found=1 }
      END { exit !found }
    ' "${file}" >/dev/null 2>&1 && return 0
  done
  return 1
}

proc_listening_socket_inodes() {
  local port="$1"
  local hex_port=""
  local file=""

  hex_port="$(printf '%04X' "${port}")"
  for file in /proc/net/tcp /proc/net/tcp6; do
    [ -r "${file}" ] || continue
    awk -v port="${hex_port}" '
      NR > 1 {
        split($2, local_address, ":")
        if (local_address[2] == port && $4 == "0A") print $10
      }
    ' "${file}"
  done | sort -u
}

pid_owns_listening_port() {
  local pid="${1:-}"
  local port="${2:-}"
  local fd_path=""
  local target=""
  local socket_inode=""
  local inode=""
  local found_socket="no"
  local -A listening_inodes=()

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [[ "${port}" =~ ^[0-9]+$ ]] || return 1
  [ -d "/proc/${pid}/fd" ] || return 1

  while IFS= read -r inode; do
    [ -n "${inode}" ] || continue
    listening_inodes["${inode}"]="yes"
    found_socket="yes"
  done < <(proc_listening_socket_inodes "${port}")
  [ "${found_socket}" = "yes" ] || return 1

  for fd_path in "/proc/${pid}/fd/"*; do
    target="$(readlink "${fd_path}" 2>/dev/null || true)"
    case "${target}" in
      socket:\[*\])
        socket_inode="${target#socket:[}"
        socket_inode="${socket_inode%]}"
        ;;
      *)
        continue
        ;;
    esac
    if [ "${listening_inodes["${socket_inode}"]:-}" = "yes" ]; then
      return 0
    fi
  done
  return 1
}

port_is_owned_by_mdesk() {
  local port="${1:-${PORT}}"
  local pid_path=""
  local pid=""
  local fd_path=""
  local target=""
  local socket_inode=""
  local inode=""
  local found_socket="no"
  local -A listening_inodes=()

  while IFS= read -r inode; do
    [ -n "${inode}" ] || continue
    listening_inodes["${inode}"]="yes"
    found_socket="yes"
  done < <(proc_listening_socket_inodes "${port}")
  [ "${found_socket}" = "yes" ] || return 1

  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    process_is_mdesk_pid "${pid}" || continue

    for fd_path in "/proc/${pid}/fd/"*; do
      target="$(readlink "${fd_path}" 2>/dev/null || true)"
      case "${target}" in
        socket:\[*\])
          socket_inode="${target#socket:[}"
          socket_inode="${socket_inode%]}"
          ;;
        *)
          continue
          ;;
      esac
      case "${socket_inode}" in
        ''|*[!0-9]*) continue ;;
      esac
      if [ "${listening_inodes["${socket_inode}"]:-}" = "yes" ]; then
        return 0
      fi
    done
  done
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

start_background_process() {
  local pid=""
  local launch_dir="${INSTALL_DIR}"
  local -a launch_args=(-port "${PORT}" -data "${DATA_DIR}" -log "${LOG_FILE}")

  if service_is_active; then
    return 0
  fi
  if port_is_listening; then
    warn "端口 ${PORT} 已被占用，无法启动后台 M•Desk 进程。"
    return 1
  fi

  if [ "${DIRECT_RUN_DETECTED}" = "yes" ]; then
    launch_args=("${DIRECT_RUN_ARGS[@]}")
    [ -z "${DIRECT_RUN_CWD}" ] || launch_dir="${DIRECT_RUN_CWD}"
  fi
  [ -d "${launch_dir}" ] || launch_dir="${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "$(dirname "${PID_FILE}")"
  (
    cd "${launch_dir}"
    if [ "${#launch_args[@]}" -gt 0 ]; then
      nohup "${BINARY}" "${launch_args[@]}" >>"${CONSOLE_LOG}" 2>&1 &
    else
      nohup "${BINARY}" >>"${CONSOLE_LOG}" 2>&1 &
    fi
    printf '%s\n' "$!" >"${PID_FILE}"
  )
  sleep 1
  pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [ -n "${pid}" ] && process_is_mdesk_pid "${pid}"; then
    if [ "${DIRECT_RUN_DETECTED}" = "yes" ]; then
      DIRECT_RUN_PID="${pid}"
    fi
    return 0
  fi
  return 1
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

service_start() {
  if is_appcenter_managed; then
    start_appcenter_service
    return
  fi

  if [ "${SERVICE_MODE}" != "process" ] && ! service_is_active && port_is_listening; then
    warn "端口 ${PORT} 已被占用，无法启动 M•Desk 服务。"
    return 1
  fi

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
  if is_appcenter_managed; then
    stop_appcenter_service
    return
  fi

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

running_mdesk_pid() {
  local pid=""
  local pid_path=""
  local executable=""
  local candidate_pid=""
  local -a matching_pids=()

  if is_appcenter_managed; then
    if pid="$(appcenter_main_pid)"; then
      printf '%s' "${pid}"
      return 0
    fi
  fi

  case "${SERVICE_MODE}" in
    systemd)
      if command -v systemctl >/dev/null 2>&1; then
        pid="$(systemctl show "${SERVICE_NAME}" --property MainPID --value 2>/dev/null |
          head -n 1 || true)"
      fi
      ;;
    openrc|sysv|process)
      if [ -r "${PID_FILE}" ]; then
        pid="$(head -n 1 "${PID_FILE}" 2>/dev/null || true)"
      fi
      ;;
  esac

  if process_is_mdesk_pid "${pid}"; then
    printf '%s' "${pid}"
    return 0
  fi

  if refresh_direct_run_pid; then
    printf '%s' "${DIRECT_RUN_PID}"
    return 0
  fi

  [ -n "${BINARY:-}" ] || return 1
  for pid_path in /proc/[0-9]*; do
    [ -d "${pid_path}" ] || continue
    pid="${pid_path##*/}"
    [ "${pid}" = "$$" ] && continue
    executable="$(readlink "/proc/${pid}/exe" 2>/dev/null || true)"
    case "${executable}" in
      *" (deleted)") executable="${executable% (deleted)}" ;;
    esac
    [ "${executable}" = "${BINARY}" ] || continue
    matching_pids+=("${pid}")
  done
  [ "${#matching_pids[@]}" -gt 0 ] || return 1

  DIRECT_CANDIDATE_PIDS=("${matching_pids[@]}")
  DIRECT_CANDIDATE_PATHS=()
  DIRECT_CANDIDATE_VERSIONS=()
  for candidate_pid in "${matching_pids[@]}"; do
    DIRECT_CANDIDATE_PATHS+=("${BINARY}")
    DIRECT_CANDIDATE_VERSIONS+=("${INSTALLED_VERSION:-}")
  done
  filter_direct_mdesk_child_processes
  [ "${#DIRECT_CANDIDATE_PIDS[@]}" -gt 0 ] || return 1
  printf '%s' "${DIRECT_CANDIDATE_PIDS[0]}"
}

write_appcenter_app_pid() {
  local pid="$1"
  local pid_dir=""
  local temporary=""
  local owner=""
  local group=""
  local mode="644"

  pid_dir="$(dirname "${APPCENTER_APP_PID_FILE}")"
  mkdir -p "${pid_dir}" || return 1
  temporary="${APPCENTER_APP_PID_FILE}.tmp.$$"

  if [ -e "${APPCENTER_APP_PID_FILE}" ]; then
    owner="$(stat -c '%u' "${APPCENTER_APP_PID_FILE}" 2>/dev/null || true)"
    group="$(stat -c '%g' "${APPCENTER_APP_PID_FILE}" 2>/dev/null || true)"
    mode="$(stat -c '%a' "${APPCENTER_APP_PID_FILE}" 2>/dev/null || true)"
  fi
  owner="${owner:-$(stat -c '%u' "${pid_dir}" 2>/dev/null || true)}"
  group="${group:-$(stat -c '%g' "${pid_dir}" 2>/dev/null || true)}"
  owner="${owner:-$(id -u mdesk 2>/dev/null || true)}"
  group="${group:-$(id -g mdesk 2>/dev/null || true)}"
  mode="${mode:-644}"

  if ! printf '%s\n' "${pid}" >"${temporary}"; then
    rm -f -- "${temporary}"
    return 1
  fi
  if [ -n "${owner}" ] && [ -n "${group}" ] &&
     ! chown "${owner}:${group}" "${temporary}" 2>/dev/null; then
    rm -f -- "${temporary}"
    return 1
  fi
  if ! chmod "${mode}" "${temporary}" 2>/dev/null ||
     ! mv -f -- "${temporary}" "${APPCENTER_APP_PID_FILE}"; then
    rm -f -- "${temporary}"
    return 1
  fi
}

finish_successful_restart() {
  local message="$1"
  local pid=""

  if ! is_appcenter_managed; then
    success "${message}"
    return 0
  fi

  if pid="$(appcenter_main_pid)"; then
    success "${message}，飞牛应用中心托管进程 PID ${pid}。"
    return 0
  fi
  if ! pid="$(running_mdesk_pid)"; then
    warn "M•Desk 已重启，但搵唔到重启后嘅主进程 PID，未能更新 ${APPCENTER_APP_PID_FILE}。"
    return 1
  fi
  if ! write_appcenter_app_pid "${pid}"; then
    warn "M•Desk 已重启，但未能将 PID ${pid} 写入 ${APPCENTER_APP_PID_FILE}。"
    return 1
  fi
  success "${message}，飛牛應用中心未寫入有效 PID，已補寫 PID ${pid} 到 ${APPCENTER_APP_PID_FILE}。"
}

pid_has_stopped() {
  local pid="${1:-}"
  local state=""

  case "${pid}" in
    ''|*[!0-9]*) return 0 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 0
  state="$(sed -n 's/^State:[[:space:]]*//p' "/proc/${pid}/status" 2>/dev/null |
    head -n 1 || true)"
  [ "${state%% *}" = "Z" ]
}

wait_appcenter_service_stopped() {
  local old_pid="${1:-}"
  local deadline=$((SECONDS + 25))

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if ! appcenter_main_pid >/dev/null 2>&1 &&
       ! port_is_listening &&
       pid_has_stopped "${old_pid}"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_or_repair_appcenter_main_pid() {
  local pid=""

  if wait_appcenter_main_pid; then
    return 0
  fi
  pid="$(running_mdesk_pid || true)"
  [ -n "${pid}" ] || return 1
  info "飞牛应用中心未写入有效 PID，正在补写 PID ${pid} 到 ${APPCENTER_APP_PID_FILE}。"
  write_appcenter_app_pid "${pid}"
}

stop_appcenter_service() {
  local output=""
  local old_pid=""

  if [ ! -x "${APPCENTER_CLI}" ]; then
    warn "搵唔到飞牛应用中心命令 ${APPCENTER_CLI}，为避免进程失去托管，唔会改用脚本自行停止。"
    return 1
  fi

  old_pid="$(appcenter_main_pid || true)"
  info "正在通过飞牛应用中心停止 M•Desk..."
  if output="$("${APPCENTER_CLI}" stop "${APPCENTER_APP_NAME}" 2>&1)"; then
    [ -z "${output}" ] || info "${output}"
  else
    [ -z "${output}" ] || warn "${output}"
    if ! pid_has_stopped "${old_pid}" ||
       appcenter_main_pid >/dev/null 2>&1 ||
       port_is_listening; then
      warn "飞牛应用中心停止失败，M•Desk 仍然运行中，已中止后续操作。"
      return 1
    fi
    warn "停止命令返回失败，但当前未检测到 M•Desk 运行，继续执行。"
  fi

  if ! wait_appcenter_service_stopped "${old_pid}"; then
    warn "飞牛应用中心已执行停止，但 M•Desk 进程或端口 ${PORT} 仍未完全释放。"
    return 1
  fi
  success "M•Desk 已通过飞牛应用中心停止。"
  return 0
}

start_appcenter_service() {
  local output=""
  local pid=""

  if [ ! -x "${APPCENTER_CLI}" ]; then
    warn "搵唔到飞牛应用中心命令 ${APPCENTER_CLI}，为避免进程失去托管，唔会改用脚本自行启动。"
    return 1
  fi

  sleep 1
  info "正在通过飞牛应用中心启动 M•Desk..."
  if output="$("${APPCENTER_CLI}" start "${APPCENTER_APP_NAME}" 2>&1)"; then
    [ -z "${output}" ] || info "${output}"
  else
    [ -z "${output}" ] || warn "${output}"
    if ! wait_or_repair_appcenter_main_pid; then
      warn "飞牛应用中心启动 M•Desk 失败。"
      return 1
    fi
    warn "飞牛应用中心启动命令返回失败，但检测到进程已经启动，将继续进行健康检查。"
  fi

  if ! wait_or_repair_appcenter_main_pid; then
    warn "飞牛应用中心启动命令已完成，但未检测到有效的主进程 PID。"
    return 1
  fi
  pid="$(appcenter_main_pid || true)"
  [ -z "${pid}" ] || info "飞牛应用中心当前托管 PID：${pid}"
  return 0
}

restart_appcenter_service() {
  stop_appcenter_service || return 1
  start_appcenter_service
}

service_restart() {
  if is_appcenter_managed; then
    restart_appcenter_service
    return
  fi

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
      wait_port_released || return 1
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
        printf '%s 未运行：当前系统没有 systemctl。\n' "${APP_DISPLAY_NAME}"
        return 1
      fi
      systemctl status "${SERVICE_NAME}" --no-pager -l
      ;;
    openrc)
      if ! command -v rc-service >/dev/null 2>&1; then
        printf '%s 未运行：当前系统没有 rc-service。\n' "${APP_DISPLAY_NAME}"
        return 1
      fi
      rc-service "${SERVICE_NAME}" status
      ;;
    sysv)
      "${INIT_SCRIPT}" status
      ;;
    process)
      if service_is_active; then
        local pid=""
        if [ "${DIRECT_RUN_DETECTED}" = "yes" ] &&
           process_is_mdesk_pid "${DIRECT_RUN_PID}"; then
          pid="${DIRECT_RUN_PID}"
        else
          pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
        fi
        printf '%s 正在运行，PID %s\n' "${APP_DISPLAY_NAME}" "${pid}"
        return 0
      fi
      printf '%s 未运行\n' "${APP_DISPLAY_NAME}"
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

write_password_reset_status() {
  local state="$1"
  local message="$2"
  local pid="${3:-}"
  local temporary="${PASSWORD_RESET_STATUS_FILE}.tmp.$$"

  mkdir -p "${CONFIG_DIR}"
  {
    printf 'STATE=%s\n' "${state}"
    printf 'MESSAGE=%s\n' "${message}"
    printf 'PID=%s\n' "${pid}"
    printf 'UPDATED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    printf 'LOG=%s\n' "${PASSWORD_RESET_LOG}"
  } >"${temporary}"
  chmod 600 "${temporary}" 2>/dev/null || true
  mv -f "${temporary}" "${PASSWORD_RESET_STATUS_FILE}"
}

read_password_reset_value() {
  read_update_value "$1" "${PASSWORD_RESET_STATUS_FILE}"
}

pid_is_password_reset_worker() {
  local pid="${1:-}"
  local cmdline=""

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 1
  cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"
  case " ${cmdline} " in
    *" --password-reset-worker "*) return 0 ;;
  esac
  return 1
}

password_reset_in_progress() {
  local state=""
  local pid=""
  local updated_at=""
  local age=""

  state="$(read_password_reset_value STATE || true)"
  case "${state}" in
    starting|waiting|running) ;;
    *) return 1 ;;
  esac

  if command -v systemctl >/dev/null 2>&1 &&
     [ -f "${PASSWORD_RESET_UNIT_FILE}" ] &&
     systemctl is-active --quiet "${PASSWORD_RESET_UNIT}" 2>/dev/null; then
    return 0
  fi

  pid="$(read_password_reset_value PID || true)"
  if pid_is_password_reset_worker "${pid}"; then
    return 0
  fi

  if [ "${state}" = "starting" ]; then
    updated_at="$(read_password_reset_value UPDATED_AT || true)"
    age="$(status_age_seconds "${updated_at}" || true)"
    if [ -z "${age}" ] || [ "${age}" -lt 60 ]; then
      return 0
    fi
  fi
  return 1
}

prepare_password_reset_job() {
  local root="/run"

  if [ ! -d "${root}" ] || [ ! -w "${root}" ]; then
    root="${TMPDIR:-/var/tmp}"
    [ -d "${root}" ] || root="/tmp"
  fi
  PASSWORD_RESET_JOB_DIR="$(mktemp -d "${root%/}/mdesk-password-reset.XXXXXX")" ||
    return 1
  chmod 700 "${PASSWORD_RESET_JOB_DIR}"
}

write_password_reset_job() {
  local new_password="$1"
  local job_file="${PASSWORD_RESET_JOB_DIR}/password-reset.conf"

  {
    printf 'NEW_PASSWORD=%q\n' "${new_password}"
    printf 'PORT=%q\n' "${PORT}"
    printf 'INSTALL_DIR=%q\n' "${INSTALL_DIR}"
    printf 'BINARY=%q\n' "${BINARY}"
    printf 'DATA_DIR=%q\n' "${DATA_DIR}"
    printf 'LOG_FILE=%q\n' "${LOG_FILE}"
    printf 'CONSOLE_LOG=%q\n' "${CONSOLE_LOG}"
    printf 'SERVICE_MODE=%q\n' "${SERVICE_MODE}"
    write_direct_run_config
  } >"${job_file}"
  chmod 600 "${job_file}"
}

wait_password_reset_worker_ready() {
  local ready_file="${PASSWORD_RESET_JOB_DIR}/worker.ready"
  local deadline=$((SECONDS + 15))
  local pid=""
  local state=""

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if [ -r "${ready_file}" ]; then
      pid="$(head -n 1 "${ready_file}" 2>/dev/null || true)"
      if pid_is_password_reset_worker "${pid}"; then
        return 0
      fi
      state="$(read_password_reset_value STATE || true)"
      [ "${state}" = "failed" ] && return 1
    fi
    sleep 1
  done
  return 1
}

wait_password_reset_signal() {
  local signal_file="${PASSWORD_RESET_JOB_DIR}/start"
  local deadline=$((SECONDS + 60))

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    [ -f "${signal_file}" ] && return 0
    sleep 1
  done
  return 1
}

launch_detached_password_reset() {
  local unit_file="${PASSWORD_RESET_UNIT_FILE}"
  local pid=""

  PASSWORD_RESET_WORKER_LAUNCHED="no"
  write_password_reset_status "starting" "正在启动独立密码重置进程" "$$" || true

  if [ "${SERVICE_MODE}" = "systemd" ] &&
     command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    mkdir -p "$(dirname "${unit_file}")"
    cat >"${unit_file}" <<EOF
[Unit]
Description=MDesk password reset worker
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash "${INSTALLER_FILE}" --password-reset-worker "${PASSWORD_RESET_JOB_DIR}"
TimeoutStartSec=300
TimeoutStopSec=30
Nice=5
EOF
    if normalize_text_file "${unit_file}"; then
      chmod 644 "${unit_file}"
      if systemctl daemon-reload >/dev/null 2>&1; then
        systemctl reset-failed "${PASSWORD_RESET_UNIT}" >/dev/null 2>&1 || true
        if systemctl start --no-block "${PASSWORD_RESET_UNIT}"; then
          if wait_password_reset_worker_ready; then
            PASSWORD_RESET_WORKER_LAUNCHED="yes"
            info "已启动独立密码重置进程。"
            return 0
          fi
          systemctl stop "${PASSWORD_RESET_UNIT}" >/dev/null 2>&1 || true
          warn "独立密码重置进程未能就绪，正在尝试其他后台方式。"
        fi
      fi
    fi
    rm -f "${unit_file}"
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  if command -v setsid >/dev/null 2>&1; then
    nohup setsid /bin/bash "${INSTALLER_FILE}" --password-reset-worker "${PASSWORD_RESET_JOB_DIR}" \
      >>"${PASSWORD_RESET_LOG}" 2>&1 </dev/null &
    pid="$!"
  else
    nohup /bin/bash "${INSTALLER_FILE}" --password-reset-worker "${PASSWORD_RESET_JOB_DIR}" \
      >>"${PASSWORD_RESET_LOG}" 2>&1 </dev/null &
    pid="$!"
  fi
  disown "${pid}" 2>/dev/null || true

  if wait_password_reset_worker_ready; then
    PASSWORD_RESET_WORKER_LAUNCHED="yes"
    info "已启动独立密码重置进程（PID ${pid}）。"
    return 0
  fi

  kill "${pid}" 2>/dev/null || true
  return 1
}

run_password_reset_worker() {
  local job_dir="${1:-}"
  local job_file=""
  local ready_file=""

  PASSWORD_RESET_JOB_DIR="${job_dir}"
  PASSWORD_RESET_WORKER_LAUNCHED="yes"
  PASSWORD_RESET_WORKER_ACTIVE="yes"
  PASSWORD_RESET_WORKER_IS_CHILD="yes"
  mkdir -p "${CONFIG_DIR}"
  exec >>"${PASSWORD_RESET_LOG}" 2>&1
  printf '\n[%s] 独立密码重置进程启动（PID %s）\n' \
    "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)" "$$"

  job_file="${PASSWORD_RESET_JOB_DIR}/password-reset.conf"
  ready_file="${PASSWORD_RESET_JOB_DIR}/worker.ready"
  if [ -z "${PASSWORD_RESET_JOB_DIR}" ] || [ ! -r "${job_file}" ]; then
    write_password_reset_status "failed" "找不到密码重置任务配置" "$$" || true
    PASSWORD_RESET_WORKER_ACTIVE="no"
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
    return 1
  fi

  # shellcheck disable=SC1090
  . "${job_file}"
  restore_direct_run_args
  refresh_direct_run_pid || true
  if [ -z "${NEW_PASSWORD:-}" ]; then
    write_password_reset_status "failed" "密码重置任务缺少新密码" "$$" || true
    PASSWORD_RESET_WORKER_ACTIVE="no"
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
    return 1
  fi

  write_password_reset_status "waiting" "等待前台确认密码已经显示" "$$"
  printf '%s\n' "$$" >"${ready_file}"
  chmod 600 "${ready_file}"
  if ! wait_password_reset_signal; then
    write_password_reset_status "failed" "等待前台交接超时，服务未停止" "$$" || true
    PASSWORD_RESET_WORKER_ACTIVE="no"
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
    return 1
  fi

  info "已收到前台交接信号，开始停止服务并重置密码。"
  write_password_reset_status "running" "正在停止服务并重置管理密码" "$$"
  service_stop || true
  if ! wait_port_released; then
    warn "端口 ${PORT} 仍被占用，未执行密码重置。"
    action_start || warn "未能恢复原 M•Desk 服务，请检查服务状态。"
    write_password_reset_status "failed" "端口仍被占用，密码未修改" "$$" || true
    PASSWORD_RESET_WORKER_ACTIVE="no"
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
    return 1
  fi

  section "执行重置密码：${BINARY} -reset-password '密码'"
  if ! "${BINARY}" -reset-password "${NEW_PASSWORD}"; then
    warn "重置密码子程序执行失败。"
    action_start || warn "未能恢复原 M•Desk 服务，请检查服务状态。"
    write_password_reset_status "failed" "重置密码子程序执行失败，服务已尝试恢复" "$$" || true
    PASSWORD_RESET_WORKER_ACTIVE="no"
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
    return 1
  fi

  write_password_reset_status "running" "密码已重置，正在启动并检查 M•Desk" "$$"
  if action_start; then
    PASSWORD_RESET_WORKER_ACTIVE="no"
    PASSWORD_RESET_WORKER_SUCCEEDED="yes"
    write_password_reset_status "success" "M•Desk 密码已重置，服务已恢复并通过健康检查" "$$"
    success "M•Desk 密码已重置并重新启动。"
    rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
    return 0
  fi

  write_password_reset_status "failed" "密码已重置，但 M•Desk 启动失败" "$$" || true
  PASSWORD_RESET_WORKER_ACTIVE="no"
  rm -rf -- "${PASSWORD_RESET_JOB_DIR}"
  return 1
}

write_restart_status() {
  local state="$1"
  local message="$2"
  local pid="${3:-}"
  local temporary="${RESTART_STATUS_FILE}.tmp.$$"

  mkdir -p "${CONFIG_DIR}"
  {
    printf 'STATE=%s\n' "${state}"
    printf 'MESSAGE=%s\n' "${message}"
    printf 'PID=%s\n' "${pid}"
    printf 'UPDATED_AT=%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    printf 'LOG=%s\n' "${RESTART_LOG}"
  } >"${temporary}"
  chmod 600 "${temporary}" 2>/dev/null || true
  mv -f "${temporary}" "${RESTART_STATUS_FILE}"
}

read_restart_value() {
  read_update_value "$1" "${RESTART_STATUS_FILE}"
}

pid_is_restart_worker() {
  local pid="${1:-}"
  local cmdline=""

  case "${pid}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -0 "${pid}" 2>/dev/null || return 1
  cmdline="$(tr '\000' ' ' <"/proc/${pid}/cmdline" 2>/dev/null || true)"
  case " ${cmdline} " in
    *" --restart-worker "*) return 0 ;;
  esac
  return 1
}

restart_in_progress() {
  local state=""
  local pid=""
  local updated_at=""
  local age=""

  state="$(read_restart_value STATE || true)"
  case "${state}" in
    starting|waiting|running) ;;
    *) return 1 ;;
  esac

  if command -v systemctl >/dev/null 2>&1 &&
     [ -f "${RESTART_UNIT_FILE}" ] &&
     systemctl is-active --quiet "${RESTART_UNIT}" 2>/dev/null; then
    return 0
  fi

  pid="$(read_restart_value PID || true)"
  if pid_is_restart_worker "${pid}"; then
    return 0
  fi

  if [ "${state}" = "starting" ]; then
    updated_at="$(read_restart_value UPDATED_AT || true)"
    age="$(status_age_seconds "${updated_at}" || true)"
    if [ -z "${age}" ] || [ "${age}" -lt 60 ]; then
      return 0
    fi
  fi
  return 1
}

prepare_restart_job() {
  local root="/run"

  if [ ! -d "${root}" ] || [ ! -w "${root}" ]; then
    root="${TMPDIR:-/var/tmp}"
    [ -d "${root}" ] || root="/tmp"
  fi
  RESTART_JOB_DIR="$(mktemp -d "${root%/}/mdesk-restart.XXXXXX")" ||
    return 1
  chmod 700 "${RESTART_JOB_DIR}"
}

write_restart_job() {
  local job_file="${RESTART_JOB_DIR}/restart.conf"

  {
    printf 'PORT=%q\n' "${PORT}"
    printf 'INSTALL_DIR=%q\n' "${INSTALL_DIR}"
    printf 'BINARY=%q\n' "${BINARY}"
    printf 'DATA_DIR=%q\n' "${DATA_DIR}"
    printf 'LOG_FILE=%q\n' "${LOG_FILE}"
    printf 'CONSOLE_LOG=%q\n' "${CONSOLE_LOG}"
    printf 'SERVICE_MODE=%q\n' "${SERVICE_MODE}"
    printf 'INSTALLED_VERSION=%q\n' "${INSTALLED_VERSION}"
    write_direct_run_config
  } >"${job_file}"
  chmod 600 "${job_file}"
}

wait_restart_worker_ready() {
  local ready_file="${RESTART_JOB_DIR}/worker.ready"
  local deadline=$((SECONDS + 15))
  local pid=""
  local state=""

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if [ -r "${ready_file}" ]; then
      pid="$(head -n 1 "${ready_file}" 2>/dev/null || true)"
      if pid_is_restart_worker "${pid}"; then
        return 0
      fi
    fi
    state="$(read_restart_value STATE || true)"
    [ "${state}" = "failed" ] && return 1
    sleep 1
  done
  return 1
}

wait_restart_signal() {
  local signal_file="${RESTART_JOB_DIR}/start"
  local deadline=$((SECONDS + 60))

  while [ "${SECONDS}" -lt "${deadline}" ]; do
    [ -f "${signal_file}" ] && return 0
    sleep 1
  done
  return 1
}

signal_restart_worker() {
  local signal_file="${RESTART_JOB_DIR}/start"

  printf 'start\n' >"${signal_file}" || return 1
  chmod 600 "${signal_file}"
}

launch_detached_restart() {
  local unit_file="${RESTART_UNIT_FILE}"
  local pid=""

  RESTART_WORKER_LAUNCHED="no"
  write_restart_status "starting" "正在启动独立重启进程" "$$" || true

  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    mkdir -p "$(dirname "${unit_file}")"
    cat >"${unit_file}" <<EOF
[Unit]
Description=MDesk restart worker
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash "${INSTALLER_FILE}" --restart-worker "${RESTART_JOB_DIR}"
TimeoutStartSec=300
TimeoutStopSec=30
Nice=5
EOF
    if normalize_text_file "${unit_file}"; then
      chmod 644 "${unit_file}"
      if systemctl daemon-reload >/dev/null 2>&1; then
        systemctl reset-failed "${RESTART_UNIT}" >/dev/null 2>&1 || true
        if systemctl start --no-block "${RESTART_UNIT}"; then
          if wait_restart_worker_ready && signal_restart_worker; then
            RESTART_WORKER_LAUNCHED="yes"
            info "独立重启进程已就绪。"
            return 0
          fi
          systemctl stop "${RESTART_UNIT}" >/dev/null 2>&1 || true
          warn "独立重启进程未能就绪，正在尝试其他后台方式。"
        fi
      fi
    fi
    rm -f "${unit_file}"
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  if command -v setsid >/dev/null 2>&1; then
    nohup setsid /bin/bash "${INSTALLER_FILE}" --restart-worker "${RESTART_JOB_DIR}" \
      >>"${RESTART_LOG}" 2>&1 </dev/null &
    pid="$!"
  else
    nohup /bin/bash "${INSTALLER_FILE}" --restart-worker "${RESTART_JOB_DIR}" \
      >>"${RESTART_LOG}" 2>&1 </dev/null &
    pid="$!"
  fi
  disown "${pid}" 2>/dev/null || true

  if wait_restart_worker_ready && signal_restart_worker; then
    RESTART_WORKER_LAUNCHED="yes"
    info "独立重启进程已就绪（PID ${pid}）。"
    return 0
  fi

  kill "${pid}" 2>/dev/null || true
  return 1
}

run_restart_worker() {
  local job_dir="${1:-}"
  local job_file=""
  local ready_file=""

  RESTART_JOB_DIR="${job_dir}"
  RESTART_WORKER_LAUNCHED="yes"
  RESTART_WORKER_ACTIVE="yes"
  RESTART_WORKER_IS_CHILD="yes"
  mkdir -p "${CONFIG_DIR}"
  exec >>"${RESTART_LOG}" 2>&1
  printf '\n[%s] 独立重启进程启动（PID %s）\n' \
    "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)" "$$"

  job_file="${RESTART_JOB_DIR}/restart.conf"
  ready_file="${RESTART_JOB_DIR}/worker.ready"
  if [ -z "${RESTART_JOB_DIR}" ] || [ ! -r "${job_file}" ]; then
    write_restart_status "failed" "找不到重启任务配置" "$$" || true
    RESTART_WORKER_ACTIVE="no"
    rm -rf -- "${RESTART_JOB_DIR}"
    return 1
  fi

  # shellcheck disable=SC1090
  . "${job_file}"
  restore_direct_run_args
  refresh_direct_run_pid || true
  if is_appcenter_managed; then
    write_restart_status "failed" \
      "飞牛应用中心实例必须使用专用后台重启流程" "$$" || true
    RESTART_WORKER_ACTIVE="no"
    rm -rf -- "${RESTART_JOB_DIR}"
    return 1
  fi

  write_restart_status "waiting" "等待前台交接后开始重启" "$$"
  printf '%s\n' "$$" >"${ready_file}"
  chmod 600 "${ready_file}"
  if ! wait_restart_signal; then
    write_restart_status "failed" "等待前台交接超时，服务未停止" "$$" || true
    RESTART_WORKER_ACTIVE="no"
    rm -rf -- "${RESTART_JOB_DIR}"
    return 1
  fi

  # Give the foreground script time to exit before the old MDesk tree is stopped.
  sleep 1
  write_restart_status "running" "正在独立停止并重新启动 M•Desk" "$$"
  if service_restart && wait_http_ready; then
    RESTART_WORKER_ACTIVE="no"
    RESTART_WORKER_SUCCEEDED="yes"
    finish_successful_restart "M•Desk 已由独立后台进程重启并通过健康检查" || true
    write_restart_status "success" "M•Desk 已重启并通过健康检查" "$$"
    rm -rf -- "${RESTART_JOB_DIR}"
    return 0
  fi

  show_service_failure
  if fallback_to_process_service && wait_http_ready; then
    RESTART_WORKER_ACTIVE="no"
    RESTART_WORKER_SUCCEEDED="yes"
    finish_successful_restart \
      "M•Desk 已降级为独立后台进程重启并通过健康检查" || true
    write_restart_status "success" \
      "M•Desk 已降级为独立后台进程并重启成功" "$$"
    rm -rf -- "${RESTART_JOB_DIR}"
    return 0
  fi

  write_restart_status "failed" "M•Desk 重启失败，请检查重启日志" "$$" || true
  RESTART_WORKER_ACTIVE="no"
  rm -rf -- "${RESTART_JOB_DIR}"
  return 1
}

queue_detached_restart() {
  if is_appcenter_managed; then
    warn "飞牛应用中心实例必须使用专用后台重启流程。"
    return 1
  fi
  if restart_in_progress; then
    warn "已有 M•Desk 重启任务正在运行，请稍后查看状态。"
    return 1
  fi

  ensure_restart_installer ||
    die "无法保存支持独立重启的安装脚本。"
  prepare_restart_job ||
    die "无法创建独立重启任务目录。"
  if ! write_restart_job; then
    rm -rf -- "${RESTART_JOB_DIR}"
    RESTART_JOB_DIR=""
    die "无法写入独立重启任务配置。"
  fi

  info "正在将重启操作交给独立后台进程..."
  if ! launch_detached_restart; then
    RESTART_WORKER_LAUNCHED="no"
    write_restart_status "failed" "无法启动独立重启进程" "" || true
    rm -rf -- "${RESTART_JOB_DIR}"
    RESTART_JOB_DIR=""
    warn "无法启动独立重启进程。"
    return 1
  fi

  success "M•Desk 重启操作已交给独立后台进程继续执行。"
  printf '即使当前 M•Desk 终端断开，重启也会继续完成。\n'
  printf '重启日志：%s\n' "${RESTART_LOG}"
  printf '完成状态：sudo mdeskctl status\n'
  return 0
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
        warn "无法注册开机启动项，仍将继续启动 M•Desk 后台进程。"
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
    warn "端口 ${PORT} 仍被占用，无法启动后台 M•Desk 进程。"
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
INSTALLER_FILE="/etc/mdesk/install.sh"

if [ ! -r "${CONFIG_FILE}" ]; then
  echo "[错误] 未找到 M•Desk 安装配置：${CONFIG_FILE}" >&2
  exit 1
fi
if [ ! -r "${INSTALLER_FILE}" ]; then
  echo "[错误] 未找到 M•Desk 安装脚本：${INSTALLER_FILE}" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  set -- status
fi

exec /bin/bash "${INSTALLER_FILE}" "$@"
CONTROL_EOF
  normalize_text_file "${CONTROL_SCRIPT}" || return 1
  chmod 755 "${CONTROL_SCRIPT}"
  ln -sfn "${CONTROL_SCRIPT}" "${CONTROL_BIN}"
}

backup_service_files() {
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
  local old_data_dir="${DATA_DIR}"
  local old_log_file="${LOG_FILE}"
  local old_console_log="${CONSOLE_LOG}"
  local restored_version=""

  warn "安装未完成，正在恢复原安装。"
  service_stop || true
  disable_service_registration || true
  remove_all_service_files || true

  if [ "${OLD_INSTALL_EXISTS}" != "yes" ]; then
    rm -f "${BINARY}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp" "${CONTROL_BIN}" "${CONTROL_SCRIPT}" "${INSTALLER_FILE}"
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
    rmdir "${CONFIG_DIR}" 2>/dev/null || true
    return 0
  fi

  if [ ! -f "${old_binary}" ]; then
    warn "未找到升级前的二进制备份，无法恢复旧版本。"
    return 1
  fi
  if [ "${BINARY}" != "${old_binary_path}" ]; then
    rm -f "${BINARY}"
  fi
  mkdir -p "$(dirname "${old_binary_path}")"
  if ! install -m 0755 "${old_binary}" "${old_binary_path}"; then
    warn "无法恢复升级前的二进制文件。"
    return 1
  fi
  restored_version="$(detect_binary_version "${old_binary_path}" || true)"
  INSTALLED_VERSION="${restored_version}"

  INSTALL_DIR="${old_install_dir}"
  BINARY="${old_binary_path}"
  if [ "${DIRECT_RUN_DETECTED}" = "yes" ] && [ -n "${old_data_dir}" ]; then
    DATA_DIR="${old_data_dir}"
    LOG_FILE="${old_log_file}"
    CONSOLE_LOG="${old_console_log}"
  else
    DATA_DIR="${old_install_dir}/data"
    LOG_FILE="${old_install_dir}/mdesk.log"
    CONSOLE_LOG="${old_install_dir}/mdesk-console.log"
  fi
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
  if [ "${DIRECT_RUN_DETECTED}" = "yes" ]; then
    DIRECT_RUN_ARGS=("${OLD_DIRECT_RUN_ARGS[@]}")
    DIRECT_RUN_ARG_COUNT="${#DIRECT_RUN_ARGS[@]}"
  fi

  save_config || true
  restore_service_files || true
  write_controller || true

  if [ -n "${SERVICE_MODE}" ] &&
     register_service >/dev/null 2>&1 &&
     wait_http_ready; then
    [ "${DIRECT_RUN_DETECTED}" != "yes" ] || save_config || true
    success "原服务已恢复并通过健康检查。"
    return 0
  fi

  show_service_failure
  if fallback_to_process_service && wait_http_ready; then
    [ "${DIRECT_RUN_DETECTED}" != "yes" ] || save_config || true
    success "原版本已自动降级为后台进程并通过健康检查。"
    return 0
  fi

  warn "原版本恢复后仍未通过健康检查，请检查系统服务日志。"
  return 1
}

apply_prepared_install() {
  local previous_installed="${PREVIOUS_INSTALLED:-no}"
  local target_service_mode="${SERVICE_MODE}"
  local target_port="${PORT}"
  local old_port="${OLD_PORT:-${PORT}}"
  local detected_version=""

  if is_appcenter_managed; then
    reject_appcenter_script_upgrade
    return 1
  fi
  validate_binary "${TEMP_DIR}/MDesk.new" || {
    warn "待安装的 M•Desk 二进制校验失败。"
    return 1
  }
  detected_version="$(detect_binary_version "${TEMP_DIR}/MDesk.new" || true)"
  if [ -n "${detected_version}" ]; then
    TARGET_VERSION="${detected_version}"
  fi
  info "准备安装版本：$(version_display "${TARGET_VERSION}" "下载后确认")"
  mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "$(dirname "${PID_FILE}")"

  if [ "${previous_installed}" = "yes" ]; then
    info "正在停止旧服务。"
    SERVICE_MODE="${OLD_SERVICE_MODE:-${SERVICE_MODE}}"
    service_stop || true
    disable_service_registration || true
    remove_all_service_files || true

    PORT="${old_port}"
    if ! wait_port_released; then
      PORT="${target_port}"
      warn "旧服务停止后端口 ${old_port} 仍被占用，已取消本次安装。"
      rollback_install || true
      return 1
    fi
    PORT="${target_port}"
    if port_is_listening; then
      warn "目标端口 ${PORT} 已被其他程序占用，已取消本次安装。"
      rollback_install || true
      return 1
    fi
    SERVICE_MODE="${target_service_mode}"
  fi

  if ! install -m 0755 "${TEMP_DIR}/MDesk.new" "${BINARY}"; then
    warn "无法写入新的 M•Desk 二进制文件。"
    rollback_install || true
    return 1
  fi
  detected_version="$(detect_binary_version "${BINARY}" || true)"
  if [ -n "${detected_version}" ]; then
    TARGET_VERSION="${detected_version}"
    INSTALLED_VERSION="${detected_version}"
  elif [ -n "${TARGET_VERSION}" ]; then
    INSTALLED_VERSION="${TARGET_VERSION}"
  else
    INSTALLED_VERSION=""
  fi

  if ! save_config || ! write_controller; then
    warn "无法保存 M•Desk 服务配置或控制脚本。"
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
    warn "M•Desk 未能在预期时间内正常响应。"
    if fallback_to_process_service && wait_http_ready; then
      success "M•Desk 已降级为独立后台进程并通过健康检查。"
    else
      rollback_install || true
      return 1
    fi
  fi
  [ "${DIRECT_RUN_DETECTED}" != "yes" ] || save_config || true
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
  OLD_DIRECT_RUN_ARGS=("${DIRECT_RUN_ARGS[@]}")
  OLD_DIRECT_RUN_ARG_COUNT="${#OLD_DIRECT_RUN_ARGS[@]}"
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

prepare_appcenter_replacement() {
  local source_binary="$1"
  local owner=""
  local group=""
  local mode=""

  [ -f "${BINARY}" ] || {
    warn "找不到 App Center 当前使用的二进制文件：${BINARY}"
    return 1
  }
  APPCENTER_REAL_BINARY="$(readlink -f "${BINARY}" 2>/dev/null || true)"
  [ -n "${APPCENTER_REAL_BINARY}" ] || APPCENTER_REAL_BINARY="${BINARY}"
  [ -f "${APPCENTER_REAL_BINARY}" ] || {
    warn "无法解析 App Center 二进制的真实路径：${BINARY}"
    return 1
  }

  owner="$(stat -c '%u' "${APPCENTER_REAL_BINARY}" 2>/dev/null || true)"
  group="$(stat -c '%g' "${APPCENTER_REAL_BINARY}" 2>/dev/null || true)"
  mode="$(stat -c '%a' "${APPCENTER_REAL_BINARY}" 2>/dev/null || true)"
  if [ -z "${owner}" ] || [ -z "${group}" ] || [ -z "${mode}" ]; then
    warn "无法读取当前二进制文件的权限或拥有者。"
    return 1
  fi

  APPCENTER_UPGRADE_BACKUP="${APPCENTER_REAL_BINARY}.mdesk-backup.$$"
  APPCENTER_UPGRADE_STAGING="${APPCENTER_REAL_BINARY}.mdesk-new.$$"
  rm -f -- "${APPCENTER_UPGRADE_BACKUP}" "${APPCENTER_UPGRADE_STAGING}"

  if ! cp -p -- "${APPCENTER_REAL_BINARY}" "${APPCENTER_UPGRADE_BACKUP}"; then
    warn "无法在同目录创建旧二进制备份，已取消升级。"
    return 1
  fi
  if ! cp -p -- "${source_binary}" "${APPCENTER_UPGRADE_STAGING}" ||
     ! validate_binary "${APPCENTER_UPGRADE_STAGING}" ||
     ! chmod "${mode}" "${APPCENTER_UPGRADE_STAGING}" ||
     ! chown "${owner}:${group}" "${APPCENTER_UPGRADE_STAGING}"; then
    warn "无法准备同目录替换文件，已取消升级。"
    return 1
  fi

  info "替换目标：${APPCENTER_REAL_BINARY}"
  info "已保留原文件权限 ${mode}、UID ${owner}、GID ${group}。"
  return 0
}

restore_appcenter_binary() {
  local restore_staging=""

  [ -n "${APPCENTER_UPGRADE_BACKUP}" ] &&
    [ -f "${APPCENTER_UPGRADE_BACKUP}" ] &&
    [ -n "${APPCENTER_REAL_BINARY}" ] || return 1
  restore_staging="${APPCENTER_REAL_BINARY}.mdesk-restore.$$"
  rm -f -- "${restore_staging}"
  if ! cp -p -- "${APPCENTER_UPGRADE_BACKUP}" "${restore_staging}" ||
     ! mv -f -- "${restore_staging}" "${APPCENTER_REAL_BINARY}"; then
    rm -f -- "${restore_staging}"
    return 1
  fi
  return 0
}

rollback_appcenter_upgrade() {
  APPCENTER_UPGRADE_ACTIVE="yes"
  warn "正在还原 App Center 实例的旧二进制文件。"
  stop_appcenter_service || true
  if ! restore_appcenter_binary; then
    warn "旧二进制文件还原失败；备份保留于 ${APPCENTER_UPGRADE_BACKUP}。"
    return 1
  fi
  if start_appcenter_service && wait_http_ready; then
    APPCENTER_UPGRADE_ACTIVE="no"
    rm -f -- "${APPCENTER_UPGRADE_BACKUP}"
    APPCENTER_UPGRADE_BACKUP=""
    warn "升级未完成，已恢复旧版本并通过飞牛应用中心重新启动。"
    return 0
  fi
  warn "旧版本已还原，但飞牛应用中心仍未能恢复服务。"
  return 1
}

action_appcenter_upgrade() {
  local old_version=""
  local new_version=""

  is_appcenter_managed || {
    warn "当前实例不是飞牛应用 FPK 托管实例。"
    return 1
  }
  if appcenter_action_in_progress; then
    warn "已有飞牛应用中心操作正在进行中，请稍后查看状态后再试。"
    return 1
  fi
  prepare_install
  resolve_install_versions
  old_version="$(version_display "${INSTALLED_VERSION}" "未知")"
  info "本地已安装版本：${old_version}"
  info "准备安装版本：$(version_display "${TARGET_VERSION}" "下载后确认")"
  info "升级顺序：先下载、校验并准备替换文件，再交给独立后台 worker 通过飞牛应用中心停止、替换和启动。"

  if ! fetch_binary "${TEMP_DIR}/MDesk.new"; then
    warn "新版本下载或校验失败，当前 M•Desk 实例未被停止或修改。"
    return 1
  fi
  if ! validate_binary "${TEMP_DIR}/MDesk.new"; then
    warn "新版本二进制校验失败，当前 M•Desk 实例未被修改。"
    return 1
  fi
  new_version="$(detect_binary_version "${TEMP_DIR}/MDesk.new" || true)"
  if [ -z "${new_version}" ]; then
    warn "无法识别新版本号，为避免安装未知版本，当前 M•Desk 实例未被修改。"
    return 1
  fi
  TARGET_VERSION="${new_version}"
  success "新版本已下载并通过校验：$(version_display "${TARGET_VERSION}" "未知")"

  if ! prepare_appcenter_replacement "${TEMP_DIR}/MDesk.new"; then
    return 1
  fi
  success "新版本 $(version_display "${new_version}" "未知") 已下载、校验并完成替换准备。"
  queue_detached_appcenter_action "upgrade" "${new_version}" || return 1
  warn "飞牛应用中心套件资料可能仍显示旧 FPK 版本；本次只替换当前运行二进制。日后重新安装 FPK 可能覆盖此版本。"
  printf '管理地址：http://<服务器IP>:%s/@admin\n' "${PORT}"
  return 0
}

queue_detached_update() {
  if is_appcenter_managed; then
    reject_appcenter_script_upgrade
    return 1
  fi
  PREVIOUS_INSTALLED="yes"
  launch_detached_update ||
    die "无法启动独立升级进程，旧服务未被修改。"
  success "升级任务已在独立后台继续运行。"
  printf '即使当前 M•Desk 终端断开，升级也会继续完成并自动重启服务。\n'
  printf '升级日志：%s\n' "${UPDATE_LOG}"
  printf '完成状态：sudo mdeskctl status\n'
  printf '刷新地址：http://<服务器IP>:%s/@admin\n' "${PORT}"
}

choose_available_port() {
  local previous_installed="$1"
  local input=""
  local active_mode=""

  port_is_listening || return 0
  if [ "${previous_installed}" = "yes" ] && [ "${PORT}" = "${OLD_PORT}" ]; then
    active_mode="${SERVICE_MODE}"
    SERVICE_MODE="${OLD_SERVICE_MODE:-${SERVICE_MODE}}"
    if service_is_active; then
      SERVICE_MODE="${active_mode}"
      return 0
    fi
    SERVICE_MODE="${active_mode}"
    if port_is_owned_by_mdesk "${PORT}"; then
      info "端口 ${PORT} 正由现有 M•Desk 实例监听，将继续升级。"
      return 0
    fi
  fi

  warn "端口 ${PORT} 已被占用。"
  if [ ! -r /dev/tty ] && [ ! -t 0 ]; then
    warn "当前不是交互终端，无法自动更换端口。请使用 MDESK_SERVICE_MODE 或释放该端口后重试。"
    return 1
  fi

  while true; do
    prompt_read_into input "请输入新的监听端口（留空取消）: " || input=""
    input="$(trim "${input}")"
    [ -n "${input}" ] || return 1
    validate_port "${input}"
    PORT="${input}"
    if ! port_is_listening; then
      success "已选择可用端口 ${PORT}。"
      return 0
    fi
    warn "端口 ${PORT} 仍被占用，请换一个。"
  done
}

action_install() {
  if update_in_progress; then
    warn "升级任务正在进行中，完成后再安装或重装。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "密码重置任务正在进行中，完成后再安装或重装。"
    return 1
  fi
  if restart_in_progress; then
    warn "重启任务正在进行中，完成后再安装或重装。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "飞牛应用中心后台操作仍在进行中，请稍后查看状态。"
    return 1
  fi

  prepare_install

  local previous_installed="no"
  local default_port="${DEFAULT_PORT}"
  local default_dir="${DEFAULT_INSTALL_DIR}"
  local input=""
  local existing_direct_run="no"
  local existing_binary=""
  local existing_data_dir=""
  local existing_log_file=""
  local existing_console_log=""

  if is_installed; then
    previous_installed="yes"
    load_existing_config
    if is_appcenter_managed; then
      action_appcenter_upgrade
      return
    fi
    existing_direct_run="${DIRECT_RUN_DETECTED}"
    existing_binary="${BINARY}"
    existing_data_dir="${DATA_DIR}"
    existing_log_file="${LOG_FILE}"
    existing_console_log="${CONSOLE_LOG}"
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

  section "${APP_DISPLAY_NAME} 安装向导"
  resolve_install_versions
  print_version_summary "${previous_installed}"
  print_direct_run_summary
  prompt_read_into input "监听端口 [默认 ${default_port}]: " || input=""
  input="$(trim "${input}")"
  PORT="${input:-${default_port}}"
  validate_port "${PORT}"

  if [ "${existing_direct_run}" = "yes" ]; then
    INSTALL_DIR="${default_dir}"
    BINARY="${existing_binary}"
    DATA_DIR="${existing_data_dir}"
    LOG_FILE="${existing_log_file}"
    CONSOLE_LOG="${existing_console_log}"
    info "直接运行实例将固定覆盖原执行文件，安装路径不另作更改。"
  else
    prompt_read_into input "安装路径 [默认 ${default_dir}]: " || input=""
    input="$(trim "${input}")"
    INSTALL_DIR="$(normalize_install_dir "${input:-${default_dir}}")"
    if is_appcenter_managed; then
      reject_appcenter_script_upgrade
      return 1
    fi
    validate_install_dir "${INSTALL_DIR}"
    BINARY="${INSTALL_DIR}/MDesk"
    DATA_DIR="${INSTALL_DIR}/data"
    LOG_FILE="${INSTALL_DIR}/mdesk.log"
    CONSOLE_LOG="${INSTALL_DIR}/mdesk-console.log"
  fi
  if is_appcenter_managed; then
    reject_appcenter_script_upgrade
    return 1
  fi
  if [ "${existing_direct_run}" = "yes" ] && [ -z "${MDESK_SERVICE_MODE:-}" ]; then
    SERVICE_MODE="process"
  else
    SERVICE_MODE="$(detect_service_mode)"
  fi

  info "CPU 架构：${ARCH}"
  info "服务模式：$(service_mode_label "${SERVICE_MODE}")"
  info "安装路径：${INSTALL_DIR}"
  info "用户数据：${DATA_DIR}"
  info "监听端口：${PORT}"

  choose_available_port "${previous_installed}" ||
    die "端口 ${PORT} 被占用，已取消安装。"
  if [ "${existing_direct_run}" = "yes" ] && [ "${PORT}" != "${default_port}" ]; then
    set_direct_run_port_arg "${PORT}"
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

  success "${APP_DISPLAY_NAME} 已安装并启动。"
  printf '管理地址：http://<服务器IP>:%s/@admin\n' "${PORT}"
  printf '服务状态：sudo mdeskctl status\n'
  printf '卸载命令：sudo mdeskctl uninstall\n'
}

action_update() {
  if update_in_progress; then
    warn "已有升级任务正在进行中，请稍后再试。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "密码重置任务正在进行中，完成后再升级。"
    return 1
  fi
  if restart_in_progress; then
    warn "重启任务正在进行中，完成后再升级。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "飞牛应用中心后台操作仍在进行中，请稍后查看状态。"
    return 1
  fi

  prepare_install

  if ! is_installed; then
    die "未检测到 ${APP_DISPLAY_NAME} 安装。"
  fi
  load_existing_config
  if is_appcenter_managed; then
    action_appcenter_upgrade
    return
  fi
  capture_existing_install
  if [ "${DIRECT_RUN_DETECTED}" = "yes" ] && [ -z "${MDESK_SERVICE_MODE:-}" ]; then
    SERVICE_MODE="process"
  else
    SERVICE_MODE="$(detect_service_mode)"
  fi

  info "CPU 架构：${ARCH}"
  print_direct_run_summary
  info "服务模式：$(service_mode_label "${SERVICE_MODE}")"
  info "安装路径：${INSTALL_DIR}"
  info "用户数据：${DATA_DIR}"
  info "监听端口：${PORT}"
  resolve_install_versions
  print_version_summary "yes"

  queue_detached_update
}

action_start() {
  local appcenter_managed="no"
  local start_mode=""

  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
  if update_in_progress; then
    warn "升级任务正在进行中，暂不要启动服务，请稍后再试。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "密码重置任务正在进行中，完成后再启动服务。"
    return 1
  fi
  if restart_in_progress; then
    warn "重启任务正在进行中，请稍后查看状态后再启动。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "飞牛应用中心后台操作仍在进行中，请稍后查看状态。"
    return 1
  fi
  if is_appcenter_managed; then
    appcenter_managed="yes"
    start_mode="飞牛应用中心"
  else
    start_mode="$(service_mode_label "${SERVICE_MODE}")"
  fi
  info "正在启动 M•Desk（模式：${start_mode}）"
  if service_start && wait_http_ready; then
    finish_successful_restart "M•Desk 已启动并通过健康检查"
    return
  fi
  show_service_failure
  if [ "${appcenter_managed}" = "yes" ]; then
    warn "飞牛应用中心托管实例启动失败。请到飞牛应用中心手动启动 M•Desk，脚本唔会改用独立进程启动，以免失去托管。"
    return 1
  fi
  if fallback_to_process_service && wait_http_ready; then
    success "M•Desk 已降级为独立后台进程并通过健康检查。"
    return 0
  fi
  warn "M•Desk 启动失败。"
  return 1
}

action_stop() {
  local stop_mode=""

  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
  if update_in_progress; then
    warn "升级任务正在进行中，暂不要停止服务，请稍后再试。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "密码重置任务正在进行中，完成后再停止服务。"
    return 1
  fi
  if restart_in_progress; then
    warn "重启任务正在进行中，请稍后查看状态后再停止。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "飞牛应用中心后台操作仍在进行中，请稍后查看状态。"
    return 1
  fi
  if is_appcenter_managed; then
    stop_mode="飞牛应用中心"
  else
    stop_mode="$(service_mode_label "${SERVICE_MODE}")"
  fi
  info "正在停止 M•Desk（模式：${stop_mode}）"
  service_stop
  if wait_port_released; then
    success "M•Desk 已停止，端口 ${PORT} 已释放。"
    return 0
  fi
  warn "服务已停止，但端口 ${PORT} 仍被其他程序占用。"
  return 1
}

action_restart() {
  local restart_mode=""

  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
  if update_in_progress; then
    warn "升级任务正在进行中，暂不建议重启，请稍后再试。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "密码重置任务仍在进行中，请稍后再重启。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "已有飞牛应用中心操作正在进行中，请稍后查看状态后再试。"
    return 1
  fi
  if restart_in_progress; then
    warn "已有 M•Desk 重启任务正在进行中，请稍后查看状态后再试。"
    return 1
  fi
  if is_appcenter_managed; then
    restart_mode="飞牛应用中心"
    info "正在准备通过独立后台 worker 重启 M•Desk（模式：${restart_mode}）"
    queue_detached_appcenter_action "restart"
    return
  fi

  restart_mode="$(service_mode_label "${SERVICE_MODE}")"
  info "正在准备通过独立后台 worker 重启 M•Desk（模式：${restart_mode}）"
  queue_detached_restart
}

show_update_status() {
  local state=""
  local message=""
  local updated_at=""

  [ -r "${UPDATE_STATUS_FILE}" ] || return 0
  state="$(read_update_value STATE || true)"
  message="$(read_update_value MESSAGE || true)"
  updated_at="$(read_update_value UPDATED_AT || true)"
  printf '\n最近升级状态：%s\n' "${state:-未知}"
  [ -z "${message}" ] || printf '说明：%s\n' "${message}"
  [ -z "${updated_at}" ] || printf '更新时间：%s\n' "${updated_at}"
  printf '升级日志：%s\n' "${UPDATE_LOG}"
}

show_password_reset_status() {
  local state=""
  local message=""
  local updated_at=""

  [ -r "${PASSWORD_RESET_STATUS_FILE}" ] || return 0
  state="$(read_password_reset_value STATE || true)"
  message="$(read_password_reset_value MESSAGE || true)"
  updated_at="$(read_password_reset_value UPDATED_AT || true)"
  printf '\n最近密码重置状态：%s\n' "${state:-未知}"
  [ -z "${message}" ] || printf '说明：%s\n' "${message}"
  [ -z "${updated_at}" ] || printf '更新时间：%s\n' "${updated_at}"
  printf '重置日志：%s\n' "${PASSWORD_RESET_LOG}"
}

show_restart_status() {
  local state=""
  local message=""
  local updated_at=""

  [ -r "${RESTART_STATUS_FILE}" ] || return 0
  state="$(read_restart_value STATE || true)"
  message="$(read_restart_value MESSAGE || true)"
  updated_at="$(read_restart_value UPDATED_AT || true)"
  printf '\n最近重启状态：%s\n' "${state:-未知}"
  [ -z "${message}" ] || printf '说明：%s\n' "${message}"
  [ -z "${updated_at}" ] || printf '更新时间：%s\n' "${updated_at}"
  printf '重启日志：%s\n' "${RESTART_LOG}"
}

show_appcenter_action_status() {
  local state=""
  local message=""
  local action_type=""
  local target_version=""
  local updated_at=""

  [ -r "${APPCENTER_ACTION_STATUS_FILE}" ] || return 0
  state="$(read_appcenter_action_value STATE || true)"
  message="$(read_appcenter_action_value MESSAGE || true)"
  action_type="$(read_appcenter_action_value TYPE || true)"
  target_version="$(read_appcenter_action_value TARGET_VERSION || true)"
  updated_at="$(read_appcenter_action_value UPDATED_AT || true)"
  printf '\n最近飞牛应用中心操作：%s\n' "${action_type:-未知}"
  printf '状态：%s\n' "${state:-未知}"
  [ -z "${target_version}" ] ||
    printf '目标版本：%s\n' "$(version_display "${target_version}" "未知")"
  [ -z "${message}" ] || printf '说明：%s\n' "${message}"
  [ -z "${updated_at}" ] || printf '更新时间：%s\n' "${updated_at}"
  printf '操作日志：%s\n' "${APPCENTER_ACTION_LOG}"
}

action_reset_password() {
  local password_file=""

  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
  if update_in_progress; then
    warn "升级任务正在进行中，完成后再重置密码。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "已有密码重置任务正在运行，请稍后再试。"
    return 1
  fi
  if restart_in_progress; then
    warn "M•Desk 重启任务正在进行中，完成后再重置密码。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "飞牛应用中心后台操作仍在进行中，请稍后查看状态。"
    return 1
  fi
  [ -n "${DATA_DIR}" ] && [ "${DATA_DIR}" != "/" ] ||
    die "无法确定安全的用户数据目录，已取消重置密码。"

  password_file="${DATA_DIR%/}/pw.json"
  if [ -e "${password_file}" ] || [ -L "${password_file}" ]; then
    rm -f -- "${password_file}" ||
      die "无法删除密码配置文件：${password_file}"
  fi
  if [ -e "${password_file}" ] || [ -L "${password_file}" ]; then
    die "密码配置文件仍然存在，重置失败：${password_file}"
  fi

  success "密码配置已删除。"
  printf '请立即刷新 MDesk 管理页面，并按页面提示初始化新的管理密码。\n'
}
safe_remove_dir() {
  local path="$1"

  [ -n "${path}" ] || die "拒绝删除空路径。"
  validate_install_dir "${path}"
  [ -d "${path}" ] || return 0
  rm -rf -- "${path}"
}
action_uninstall() {
  local purge_mode="${1:-ask}"
  local delete_data="no"

  load_existing_config
  [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
  if update_in_progress; then
    warn "升级任务正在进行中，完成后再卸载。"
    return 1
  fi
  if password_reset_in_progress; then
    warn "密码重置任务正在进行中，完成后再卸载。"
    return 1
  fi
  if restart_in_progress; then
    warn "重启任务正在进行中，完成后再卸载。"
    return 1
  fi
  if appcenter_action_in_progress; then
    warn "飞牛应用中心后台操作仍在进行中，请稍后查看状态。"
    return 1
  fi

  section "${APP_DISPLAY_NAME} 卸载向导"
  info "安装路径：${INSTALL_DIR}"
  info "用户数据：${DATA_DIR}"
  case "${purge_mode}" in
    ask)
      if ! confirm "是否保留用户数据？" "y"; then
        delete_data="yes"
      fi
      ;;
    purge)
      delete_data="yes"
      ;;
    preserve)
      delete_data="no"
      ;;
    *)
      die "无效卸载模式：${purge_mode}"
      ;;
  esac

  if [ "${delete_data}" = "yes" ]; then
    validate_install_dir "${INSTALL_DIR}"
    if [ "${DATA_DIR}" != "${INSTALL_DIR}" ]; then
      validate_install_dir "${DATA_DIR}"
    fi
  fi

  info "正在停止服务并移除开机启动注册"
  service_stop || true
  disable_service_registration || true
  remove_all_service_files || true

  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop "${UPDATER_UNIT}" >/dev/null 2>&1 || true
    systemctl reset-failed "${UPDATER_UNIT}" >/dev/null 2>&1 || true
    systemctl stop "${PASSWORD_RESET_UNIT}" >/dev/null 2>&1 || true
    systemctl reset-failed "${PASSWORD_RESET_UNIT}" >/dev/null 2>&1 || true
    systemctl stop "${RESTART_UNIT}" >/dev/null 2>&1 || true
    systemctl reset-failed "${RESTART_UNIT}" >/dev/null 2>&1 || true
    systemctl stop "${APPCENTER_ACTION_UNIT}" >/dev/null 2>&1 || true
    systemctl reset-failed "${APPCENTER_ACTION_UNIT}" >/dev/null 2>&1 || true
  fi
  rm -f "${UPDATER_UNIT_FILE}"
  rm -f "${PASSWORD_RESET_UNIT_FILE}"
  rm -f "${RESTART_UNIT_FILE}"
  rm -f "${APPCENTER_ACTION_UNIT_FILE}"
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  info "正在删除程序文件"
  rm -f -- "${BINARY}" "${LOG_FILE}" "${CONSOLE_LOG}" "${PID_FILE}"
  if [ "${delete_data}" = "yes" ]; then
    if [ "${DATA_DIR}" != "${INSTALL_DIR}" ]; then
      safe_remove_dir "${DATA_DIR}"
    fi
    safe_remove_dir "${INSTALL_DIR}"
  else
    rmdir "${INSTALL_DIR}" 2>/dev/null || true
  fi

  rm -f -- "${CONTROL_BIN}" "${CONTROL_SCRIPT}" "${INSTALLER_FILE}" \
    "${UPDATE_STATUS_FILE}" "${UPDATE_LOG}" "${PASSWORD_RESET_STATUS_FILE}" \
    "${PASSWORD_RESET_LOG}" "${RESTART_STATUS_FILE}" "${RESTART_LOG}" \
    "${APPCENTER_ACTION_STATUS_FILE}" \
    "${APPCENTER_ACTION_LOG}" "${CONFIG_FILE}" "${CONFIG_FILE}.tmp"
  rmdir "${CONFIG_DIR}" 2>/dev/null || true

  if [ "${delete_data}" = "yes" ]; then
    success "卸载完成，用户数据目录 ${DATA_DIR} 已删除。"
  else
    success "卸载完成，用户数据目录 ${DATA_DIR} 已保留。"
  fi
}
action_guided() {
  print_banner
  require_root
  if is_installed; then
    OLD_INSTALL_EXISTS="yes"
    load_existing_config
    resolve_install_versions
    print_install_card
    print_menu
    local sel
    prompt_read_into sel ""
    sel="${sel:-1}"
    case "${sel}" in
      1)
        info "选择：重新安装 / 升级（保留数据）"
        action_install
        ;;
      2)
        info "选择：重启服务"
        action_restart
        ;;
      3)
        info "选择：重置管理密码"
        action_reset_password
        ;;
      4)
        info "选择：卸载"
        action_uninstall
        ;;
      5)
        info "退出"
        exit 0
        ;;
      *)
        die "无效选项"
        ;;
    esac
  else
    info "未检测到已安装实例，进入全新安装流程"
    OLD_INSTALL_EXISTS="no"
    SERVICE_MODE="$(detect_service_mode)"
    action_install
  fi
}
main() {
  local command="${1:-auto}"

  clear_screen

  case "${command}" in
      --password-reset-worker)
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        shift
        [ -n "${1:-}" ] || die "缺少密码重置任务目录。"
        if run_password_reset_worker "$1"; then
          exit 0
        else
          exit 1
        fi
        ;;
      --update-worker)
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        shift
        [ -n "${1:-}" ] || die "缺少升级任务目录。"
        if run_update_worker "$1"; then
          exit 0
        else
          exit 1
        fi
        ;;
      --restart-worker)
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        shift
        [ -n "${1:-}" ] || die "缺少重启任务目录。"
        if run_restart_worker "$1"; then
          exit 0
        else
          exit 1
        fi
        ;;
      --appcenter-action-worker)
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        shift
        [ -n "${1:-}" ] || die "缺少飞牛应用中心后台任务目录。"
        if run_appcenter_action_worker "$1"; then
          exit 0
        else
          exit 1
        fi
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      install)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        action_install
        ;;
      reinstall)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        action_install
        ;;
      update)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        action_update
        ;;
      uninstall)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        is_installed || die "未检测到 ${APP_DISPLAY_NAME} 安装。"
        case "${2:-ask}" in
          ask) action_uninstall "ask" ;;
          --preserve) action_uninstall "preserve" ;;
          --purge) action_uninstall "purge" ;;
          *) die "uninstall 仅支持 --preserve 或 --purge。" ;;
        esac
        ;;
      reset-password)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        if ! is_installed; then
          warn "找不到已安装的 M•Desk，无法重置密码"
          exit 1
        fi
        action_reset_password
        ;;
      status)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        if ! is_installed; then
          warn "未检测到 M•Desk 安装"
          exit 1
        fi
        load_existing_config
        [ -n "${SERVICE_MODE}" ] || SERVICE_MODE="$(detect_service_mode)"
        local status_rc=0
        service_status || status_rc=$?
        show_update_status
        show_password_reset_status
        show_restart_status
        show_appcenter_action_status
        exit "${status_rc}"
        ;;
      start)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        is_installed || die "未检测到 ${APP_DISPLAY_NAME} 安装。"
        action_start
        ;;
      stop)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        is_installed || die "未检测到 ${APP_DISPLAY_NAME} 安装。"
        action_stop
        ;;
      restart)
        print_banner
        require_root
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        is_installed || die "未检测到 ${APP_DISPLAY_NAME} 安装。"
        action_restart
        ;;
      auto)
        [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || die "此脚本仅支持 Linux。"
        action_guided
        ;;
      *)
        usage
        die "未知参数，运行 $0 --help 查看用法"
        ;;
  esac
}
main "$@"
