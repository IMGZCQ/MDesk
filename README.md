<p align="center">
  <img src="https://raw.githubusercontent.com/IMGZCQ/MDesk/main/ICON.PNG" width="120" alt="M·Desk">
</p>

<h1 align="center">M·Desk</h1>

<p align="center">高效轻便的服务器运维桌面系统</p>

<p align="center">
  <a href="https://github.com/IMGZCQ/MDesk/releases">下载</a>
  ·
  <a href="./MDesk%20使用手册.md">使用手册</a>
  ·
  <a href="https://github.com/IMGZCQ/MDesk/issues">问题反馈</a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/IMGZCQ/MDesk/main/poster.webp" alt="M·Desk 功能概览" width="100%">
</p>

## 桌面系统总览

<p align="center">
  <img src="https://raw.githubusercontent.com/IMGZCQ/MDesk/main/desktop-overview.webp" alt="M·Desk 桌面系统总览" width="52%">
</p>

<p align="center">
  <img src="./desktop-overview-light.webp" alt="M·Desk 浅色主题桌面界面" width="49%">
  <img src="./desktop-overview-dark.webp" alt="M·Desk 深色主题桌面界面" width="49%">
</p>

M·Desk 一个高效轻便的服务器运维桌面系统；集结反代服务、本地终端、组网穿透、外链分享、静态网站、文件和 Docker 管理等服务；所有服务都基于单一端口实现，享受极致的管理体验！

## 快速入口

| 入口 | 说明 |
| --- | --- |
| [下载最新版本](https://github.com/IMGZCQ/MDesk/releases) | 获取对应平台安装包与可执行文件 |
| [完整使用手册](./MDesk%20使用手册.md) | 模块操作、部署方式与启动参数 |
| [问题反馈](https://github.com/IMGZCQ/MDesk/issues) | 提交问题、建议与使用反馈 |

---

## 核心能力

| 模块 | 说明 |
| --- | --- |
| **服务路由** | 统一管理多个服务入口，支持域名绑定与快速切换，各服务保持原有访问路径；桌面图标可从 Web Manifest、`srcset`、JSON-LD 与页面图像中自动识别，并支持桌面资源上传与安全校验。 |
| **应用中心与 fnOS 接入** | 应用中心按 M·Desk 原生应用、1Panel 源与 CasaOS 源清晰分区，安装或卸载应用时同步桌面图标；扫描 fnOS 应用中心，将端口、Unix Socket 与 CGI 应用接入桌面，支持应用图标、版本、访问入口与安全路径校验。持续完善 MPK 应用包规范，让元数据、资源与运行描述保持一致。MPK 运行层兼容标准 Linux 基础工具集，非 fnOS 环境同样可以正常启动。 |
| **本地终端** | 浏览器中的多会话终端，支持后台保活、快捷命令与右键菜单操作；常见 POSIX 环境优先使用 Bash，同时保留 Zsh 等显式 shell 选择。 |
| **文件管理** | 在线浏览、编辑、上传下载、压缩解压；小文件支持批量上传，可一次带入嵌套目录与空文件。支持多窗口与同目录窗口复用，每个窗口独立保存路径、选择、排序和视图状态，文件操作仅刷新受影响窗口，`F5` 刷新当前激活窗口。复制、移动和上传冲突支持跳过、覆盖或保留两者；目录冲突递归合并，跨分区移动会先校验副本再删除源文件。编辑器支持多文件独立编辑与未保存内容确认。上传、下载、复制和移动任务集中进入统一任务中心；支持右键菜单、框选、直接分享，以及图片、音视频和文本预览。目录链接、文件链接、失效链接与 Windows junction 会被明确标记。 |
| **外链分享** | 为文件或目录生成分享链接，可设置访问密码、常用到期时间与启停状态；访问页面支持图片、音视频和只读文本预览。 |
| **静态网站** | 选择一个本地目录即可发布为静态网站，支持默认主页、目录浏览与域名绑定；站点中的图片、音视频和文本资源可直接预览。 |
| **组网隧道** | 支持 FRPC、EasyTier 与 Cloudflare Tunnel，并可分别管理多个实例；Cloudflare 提供命名隧道与快捷隧道两种模式。 |
| **Docker 管理** | 管理容器、Compose 项目、本地镜像、镜像仓库、Docker 网络与镜像加速器；支持按镜像、Compose 服务或容器逐项检测更新、拉取新镜像并重建服务，也支持重启 Docker 服务。 |
| **进程管理** | 查看真实进程列表、PID、用户、状态、CPU、内存、启动时间与可执行路径；支持搜索、端口反查、排序筛选、详情与安全结束进程。进程、服务与端口长列表支持在空白区域拖动滚动，同时保留按钮、下拉选择与右键菜单操作。 |
| **系统状态** | 集中展示系统与硬件信息、硬盘和 SMART 健康、网络接口与流量、CPU、内存、GPU 与资源趋势；后台统一采样记录 CPU、内存、GPU、网络和磁盘读写趋势。新增系统服务管理，可查看 systemd 与 Windows 服务的运行状态和启动类型，支持搜索、筛选、排序、详情、启停、重启及开机启动调整，并对并发操作、权限限制和平台不支持项提供明确反馈。Linux 支持 Swap 路径、类型、容量与使用率查看，并支持安全启停和单个 Swap 文件容量调整。Linux 补充网卡链路速率读取并优化磁盘拓扑呈现。 |
| **系统设置与个性化** | 提供六套应用图标套装，可切换桌面图标单击或双击打开；支持指定独立壁纸目录，自动检测目录变化并刷新缩略图。窗口支持边缘与四角吸附、顶部最大化及拖拽恢复，窗口焦点、吸附状态和后台刷新策略会随桌面操作平滑调整；应用中心安装或卸载应用时自动同步桌面图标。 |

---

## 快速开始

### 发布文件

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Windows 服务版 | `MDesk-Windows-Service.exe` | 在后台提供管理服务，适合长期运行 |
| Windows 桌面版 | `MDesk-Windows-Desktop.exe` | 使用桌面窗口承载管理界面 |
| Linux amd64 | `MDesk-linux-amd64` | 适用于常见 x86_64 设备 |
| Linux arm64 | `MDesk-linux-arm64` | 适用于 ARM64 设备 |
| Linux armv7 | `MDesk-linux-armv7` | 适用于 32 位 ARMv7 设备 |
| fnOS | `MDesk_2.7.109.fpk` | 支持 amd64、arm64 与 armv7 |

### Linux 命令行

1. 从 [Releases](https://github.com/IMGZCQ/MDesk/releases) 下载匹配架构的 `MDesk-linux-amd64`、`MDesk-linux-arm64` 或 `MDesk-linux-armv7`。
2. 将文件放到可写目录，确保同级目录能够创建 `data` 数据目录。
3. 赋予执行权限并启动：

```bash
chmod +x ./MDesk-linux-amd64
./MDesk-linux-amd64
```

4. 默认监听 HTTP `19188` 端口，访问 `http://<设备地址>:19188/@admin`。
5. 首次访问时设置管理密码。

ARM64 设备请将文件名替换为 `MDesk-linux-arm64`，32 位 ARMv7 设备请使用 `MDesk-linux-armv7`。可通过启动参数调整访问协议、监听地址、数据目录、日志和组网配置，完整说明见 [MDesk 使用手册](./MDesk%20使用手册.md)。

### Linux 一键安装（systemd / OpenRC / SysV）

一键安装会自动识别 `amd64`、`arm64` 或 `armv7`。脚本会优先从 `https://fndesk.imcq.top/FPK/MDesk/` 下载对应二进制文件；如果该镜像不可用，再回退到 GitHub Release 的多个加速地址中选择可用且响应较快的线路。安装时会优先使用 systemd，并兼容 OpenRC、SysV；所选服务管理器注册、启动或健康检查失败时，会自动降级为独立后台进程。后台模式会在 cron 可用时注册 `@reboot` 启动；若系统同时没有 cron，后台进程仍可正常使用，但系统重启后需要手动执行 `sudo mdeskctl start`，这是缺少 init/服务管理器时的系统限制。

```bash
curl -fsSL https://raw.githubusercontent.com/IMGZCQ/MDesk/main/install.sh | sudo bash
```

再次运行同一命令时，脚本会先检测系统是否已经安装 MDesk：

- 未安装时，直接进入安装向导。
- 已安装时，显示管理菜单，可选择重新安装/升级、卸载或取消。

也可以使用显式命令强制安装或卸载：

```bash
sudo bash install.sh install
sudo bash install.sh uninstall
```

安装向导会依次询问：

1. 服务端口，直接回车使用默认值 `19188`
2. 安装目录，直接回车使用默认值 `/opt/MDesk`

安装目录建议使用不含空格和特殊字符的路径，例如 `/opt/MDesk`。

安装完成后会按当前环境注册并启动服务，并在服务管理器或 cron 可用时设置为开机自动启动。管理后台地址为：

```text
http://<设备地址>:<端口>/@admin
```

如需强制使用某个服务模式，可设置 `MDESK_SERVICE_MODE`：

```bash
sudo env MDESK_SERVICE_MODE=systemd bash install.sh
sudo env MDESK_SERVICE_MODE=openrc bash install.sh
sudo env MDESK_SERVICE_MODE=sysv bash install.sh
sudo env MDESK_SERVICE_MODE=process bash install.sh
```

升级或重新安装会交给独立后台任务执行，因此即使 MDesk 内置终端、SSH 会话或发起命令的终端断开，更新仍会继续。任务会下载并校验新二进制、重启服务并执行 HTTP 健康检查；失败时会恢复旧二进制和配置，如果原服务管理器仍无法启动，则会自动用后台进程恢复旧版本。可使用以下命令发起或查看更新：

```bash
sudo bash install.sh update
sudo mdeskctl update
sudo mdeskctl status
```

更新日志和最近状态分别保存在 `/etc/mdesk/update.log` 与 `/etc/mdesk/update.status`。

卸载命令：

```bash
sudo mdeskctl uninstall
```

也可以使用本地脚本卸载：`sudo bash install.sh uninstall`。

卸载向导会询问是否删除用户数据。默认保留数据；选择删除后，会清理安装目录中的数据。

如需指定 GitHub 加速地址，可使用英文逗号分隔，并支持 `{url}` 占位符：

```bash
curl -fsSL https://raw.githubusercontent.com/IMGZCQ/MDesk/main/install.sh |
  sudo env MDESK_GITHUB_PROXY='https://gh-proxy.com/,https://ghfast.top/' bash
```

### 常用启动参数

| 参数 | 说明 |
| --- | --- |
| `-scheme` | 设置 HTTP 或 HTTPS，默认 `http` |
| `-addr` | 设置完整监听地址，例如 `127.0.0.1:8080` 或 `:8080`；与 `-port` 二选一，`-addr` 优先 |
| `-port` | 设置监听端口，默认 `19188` |
| `-data` | 设置数据目录，默认使用程序所在目录下的 `data` |
| `-log` | 设置运行日志文件；按 5MB 轮转并保留 3 份 |
| `-reset-password` | 重置管理密码后退出程序 |
| `-frpc-config` | 首次导入 FRPC 配置文件，支持本地路径或 HTTP(S) URL |
| `-easytier-config` | 首次导入 EasyTier 配置文件，支持本地路径或 HTTP(S) URL |
| `-cf-token` | 首次导入 Cloudflare 命名隧道 Token |
| `-force` | 强制使用命令行中的组网隧道配置覆盖已有模块配置 |

Docker 管理建议在 Docker 所在 Linux 宿主机上运行，并确保 M·Desk 进程拥有 Docker Socket 的读写权限。

### 可选环境变量

| 环境变量 | 说明 |
| --- | --- |
| `MDESK_GITHUB_PROXY` | 组网工具下载代理，多个地址使用英文逗号分隔；设置后会替换内置代理列表，并支持 `{url}` 占位符 |
| `MDESK_GITHUB_TOKEN` | 可选的 GitHub Token，优先于 `GITHUB_TOKEN`，用于提高 GitHub API 和下载请求限额 |
| `GITHUB_TOKEN` | `MDESK_GITHUB_TOKEN` 未设置时使用 |
| `DOCKER_SOCKET` | 自定义 Docker Unix Socket 路径 |
| `DOCKER_HOST` | 仅支持 `unix://...` 形式，暂不支持 TCP 连接 |
| `DOCKER_DAEMON_CONFIG` | 自定义 Docker daemon 配置文件路径，默认 `/etc/docker/daemon.json` |

### Docker 镜像

GitHub Actions 会在发布 Release 时自动读取该 Release 的 `MDesk-linux-amd64`、`MDesk-linux-arm64` 与 `MDesk-linux-armv7` 资产，构建并推送 `linux/amd64`、`linux/arm64` 与 `linux/arm/v7` 多架构镜像到 Docker Hub：

#### Docker Compose

创建 `compose.yaml`：

```yaml
services:
  MDesk:
    container_name: MDesk
    image: imgzcq/mdesk
    network_mode: host                              # 网络类型
    restart: always                                 # 自动启动
    command: ["-port", "19188"]                     # 自定义端口
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock   # Docker管理
      - ./data:/usr/local/bin/data                  # 应用数据持久化
      #- /var/apps:/var/apps                        # 接入飞牛应用
      #- /vol1:/vol1                                # 接入飞牛应用
```

> 提示：飞牛应用相关挂载默认注释，非飞牛系统保持注释即可。在 fnOS 中使用应用接入时，取消这两行注释，并将 `/vol1` 调整为应用实际所在的存储卷；存在多个存储卷时分别挂载对应的 `/volX`。

> 提示：`command` 会覆盖镜像默认的 `-data /data` 参数，程序因此使用可执行文件所在目录下的 `data`，即 `/usr/local/bin/data`。请保持 `volumes` 挂载路径为 `./data:/usr/local/bin/data`，确保配置、账号与图标等数据持久化。

启动：

```bash
docker compose up -d
```

`/var/run/docker.sock` 用于 M·Desk 的 Docker 管理功能。不需要该功能时可以移除这一行，但容器、Compose、镜像与网络页面将无法连接宿主机 Docker。

> [!CAUTION]
> 挂载 Docker Socket 后，M·Desk 将拥有较高的宿主机控制权限。请只运行可信镜像，限制管理入口的访问范围，并妥善保护管理密码与访问链路。

#### Docker Run

```bash
docker pull imgzcq/mdesk:latest

docker run -d \
  --name mdesk \
  --restart unless-stopped \
  -p 19188:19188 \
  -v mdesk-data:/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  imgzcq/mdesk:latest
```

Docker 管理需要挂载 Docker Socket。文件管理与终端默认只看到容器内文件，如需管理宿主机目录，请额外挂载对应卷。

仓库 Actions secrets 需要配置 `DOCKERHUB_TOKEN`，建议使用 Docker Hub 的 Read & Write access token。Release 发布会推送 `latest`、版本号和完整标签；也可以通过 `workflow_dispatch` 手动补发指定版本，版本号填写 `2.7.109` 或 `v2.7.109` 均可。

### fnOS 安装包

1. 从 [Releases](https://github.com/IMGZCQ/MDesk/releases) 下载最新的 `MDesk_2.7.109.fpk`。
2. 在 fnOS 应用中心手动安装。
3. 安装过程中可选择 HTTP 或 HTTPS，默认使用 HTTP 和 `19188` 端口。
4. 安装完成后访问 `http://<设备地址>:19188/@admin`，首次访问时设置管理密码。

服务路由、终端、文件管理、外链分享、静态网站、组网隧道、Docker、进程管理与系统状态的详细操作，请查看 [MDesk 使用手册](./MDesk%20使用手册.md)。

---

## 项目结构

```text
.github/workflows/     Docker Hub 多架构发布流程
app/                   fnOS 应用运行文件与三架构二进制
cmd/                   fnOS 安装、启动、升级与卸载脚本
config/                fnOS 权限与资源声明
wizard/                fnOS 安装向导配置
Dockerfile             Docker Hub 多架构镜像构建文件
manifest               fnOS 应用清单
MDesk 使用手册.md      用户使用、部署与参数说明
```

---

## 官网

官网源码由本地 `www/` 目录维护，可以直接部署为静态站点。页面包含项目介绍、核心能力、优势说明、部署概览与响应式布局，所有文案均在 `www/index.html` 中维护；发布仓库不包含该目录。

> [!CAUTION]
> M·Desk 的管理入口、终端与文件管理拥有较高权限。请使用强密码，优先通过 HTTPS、内网 ACL、VPN 或零信任网关访问，不要将管理入口直接暴露在不可信网络中。

## 更新日志

### 2.7.109

- 服务路由新增 Authorization 请求头桥接：M·Desk 部署在会覆写 `Authorization` 的上层网关或沙箱之后时可启用，认证头经 `X-MDesk-Authorization` 转存后由代理还原，上游登录态不再丢失；脚本按同源注入并兼容 CSP nonce，跳过 JSON 与压缩响应。
- 桌面“肥牛应用”入口与肥牛应用窗口改用飞牛 fnOS 官方图标。
- 优化 MPK 应用启动诊断：应用在就绪前退出或启动超时时附带日志尾部，自动脱敏数据目录、过滤终端控制字符，并限制为最近 12 行、最多 4000 字符。
- 优化服务识别中的 HTTP Basic 判定：支持多段 `WWW-Authenticate` 挑战并忽略引号内逗号，减少误判。
- 修复仅启用 Authorization 请求头桥接时未被识别为高级兼容配置的问题；修复小文件批量上传同名冲突后选择“覆盖”或“保留两者”可能失败的问题。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.109`，重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.108

- 新增系统服务管理：集中查看 systemd 与 Windows 服务的运行状态和启动类型，支持搜索、筛选、排序、详情、启动、停止、重启及开机启动调整，并对并发操作、权限限制和平台不支持项提供明确反馈。
- 优化进程、服务与端口长列表交互：支持在列表空白区域拖动滚动，同时保留按钮、下拉选择和右键菜单操作。
- 文件管理新增小文件批量上传：嵌套目录和空文件可一次上传，同名冲突继续支持跳过、覆盖或保留两者。
- 优化通用对话框焦点：打开后自动聚焦首个可编辑控件，并完善显式焦点、键盘确认和关闭后的焦点恢复。
- 系统图标套装扩展至六套，完善图标切换、加载回退和设置持久化，桌面、标题栏、开始菜单与任务栏同步更新。
- 重整系统状态磁盘导航与磁盘卡片布局，改善桌面和窄屏下的信息密度与可读性。
- 更新内置 Chromium MPK 至 1.0.25，完善 Linux amd64 启动、重启和地址栏搜索。
- 明确应用中心“M·Desk 原生应用”等分区标题，优化桌面与移动端显示。

### 2.7.107

- Linux 一键安装脚本新增独立后台升级：`install.sh update` 与 `mdeskctl update` 可在 SSH 或内置终端断开后继续执行，并提供下载校验、服务重启、健康检查、失败回滚及升级状态与日志。
- 完善 fnOS 应用接入：支持嵌套应用条目、多语言应用名与嵌套 CGI，正确转发登录会话、Cookie、重定向和错误页，并加强应用路径与脚本执行边界校验。
- 优化端口服务识别与图标匹配：覆盖域名路由、虚拟主机、Docker 容器名、HTTP/HTTPS 回退及 IPv4/IPv6，并改进受限页面探测和身份匹配准确性。
- 新增 Basic Auth 登录中转页，可直接在 M·Desk 内完成受保护服务认证，并校验登录后的跳转地址。
- 优化分享与静态目录浏览：长文件名不再撑破表格；管理页、分享页和状态页使用带版本号的应用图标，减少旧图标缓存。
- 调整桌面窗口交互：改进最大化拖拽还原、标题栏边缘拖动和最小化操作边界，窗口状态恢复更稳定。

### 2.7.106

- 系统状态新增 Linux Swap 管理，可查看路径、类型、容量与使用情况，并安全启停或调整单个 Swap 文件容量；分区或多重 Swap 配置会自动采用更稳妥的启停策略。
- 桌面窗口支持拖至屏幕边缘或四角分屏、拖至顶部最大化，并可从最大化状态拖拽恢复；吸附状态与恢复位置会随桌面布局保存。
- 端口管理增强服务识别、图标匹配与右键操作，可快速查看详情、复制信息、发送到桌面、打开服务或创建路由。
- 系统设置新增第五套应用图标，继续支持桌面图标单击或双击打开。
- 应用中心安装或卸载应用时自动同步桌面图标，CasaOS 在线应用源同样适用。
- Linux 安装脚本新增 OpenRC、SysV 与独立后台进程运行支持，并在 cron 可用时注册开机启动；同时补齐失败回滚、健康检查与 `mdeskctl` 服务管理。
- 完善管理路径结尾斜杠处理，并在后端不可用时显示更友好的 HTML 状态页；同主机多实例的 Cookie 相互隔离，避免登录状态串扰。
- 修复 Chromium MPK 在缺少 `flock`、`seq` 的 Linux 环境无法启动的问题，并增强异常退出诊断；修复应用中心页面 `global is not defined` 错误，继续推进应用中心、MPK 规范与主题细节。
- 用户壁纸支持指定独立目录，自动检测目录变化，并优化缩略图缓存与扫描刷新。
- 文件管理器支持表头排序并记忆排序偏好，收藏夹保存流程更加稳定。
- 视频播放支持长按临时 2x 播放，同时优化播放器控制栏显示。
- 完善 Docker Compose 管理，支持按 YAML 重构项目、删除项目配置，并保护托管项目。
- 外部链接无法在应用内打开时，提供更清晰的提示、重试和浏览器打开入口。
- 优化窗口焦点恢复、任务栏显示，以及任务中心和隧道页面的后台刷新策略。
- 修复旧版提示缓存覆盖新版默认提示的问题。

### 2.7.103

- 系统设置新增四套应用图标套装，并支持切换桌面图标单击或双击打开。
- 用户壁纸支持指定独立目录，自动检测目录变化，并优化缩略图缓存与扫描刷新。
- 文件管理器支持表头排序并记忆排序偏好，收藏夹保存流程更加稳定。
- 视频播放支持长按临时 2x 播放，同时优化播放器控制栏显示。
- 完善 Docker Compose 管理，支持按 YAML 重构项目、删除项目配置，并保护托管项目。
- 外部链接无法在应用内打开时，提供更清晰的提示、重试和浏览器打开入口。
- 优化窗口焦点恢复、任务栏显示，以及任务中心和隧道页面的后台刷新策略。
- 修复旧版提示缓存覆盖新版默认提示的问题。

### 2.7.100

- Linux 一键安装与服务升级转入后台执行，新增健康检查、失败回滚、升级日志和状态查询，远程升级更稳妥。
- 系统监控改为后台持续采样，CPU、内存、GPU、网络及磁盘读写趋势打开即可查看，数据展示更连贯。
- 系统设置支持修改设备名称，并针对不同平台补充权限、格式校验及重启提示。
- 文件复制、移动和上传完善冲突处理，支持跳过、覆盖与保留两者，目录合并、跨分区移动及失败保护更加可靠。
- 桌面资源支持上传，并增加文件类型、大小、SVG 安全和未引用资源清理机制。
- 桌面图标可自动识别站点 Manifest、响应式图片、JSON-LD 及页面图像，站点入口呈现更加准确。
- 优化系统端口图标识别与详情布局，完善 IPv4/IPv6、HTTPS/HTTP 回退，同时改进桌面窗口和主题显示细节。

### 2.7.98

- 文件管理支持多窗口与同目录窗口复用，各窗口独立保存当前路径、选择、排序和视图；文件操作完成后仅刷新受影响窗口，`F5` 刷新当前激活窗口。
- 优化目录合并、覆盖与上传冲突处理：目录与同名目录递归合并，同名文件安全覆盖，并修复同级目录被文件替换等异常。
- 文件编辑器支持多文件独立编辑和同路径窗口复用；关闭未保存文件时可选择“取消 / 不保存 / 保存”，保存后仅精确刷新相关文件。
- 通用对话框不再通过点击遮罩关闭，支持 `Escape` 关闭最上层对话框；局部、嵌套及延迟创建的 Dialog 同步适配。
- 完善移动端桌面图标与文件夹触摸拖动，并优化插入位置判断。
- 后端尚未配置或不可用时，浏览器访问返回友好的 HTML 状态页，API 请求仍保持 JSON 错误响应。
- 文件任务中心补充复制、移动任务类型及图标，操作状态更加清晰。
- 修复 fnOS 代理、隐藏文件展示和代理错误页相关稳定性问题。

### 2.7.95

- 新增统一后台任务中心：上传、下载等任务集中展示进度、状态与历史记录，可随时查看、取消和清理，切换页面后仍可继续跟踪。
- 完善窗口总览与任务栏交互：支持总览、悬停选择、双击返回、Escape 退出，并优化内嵌页面窗口、任务切换、最小化与恢复。
- 优化窗口总览退出动画：选择或取消退出时平滑恢复窗口阴影，减少视觉跳变和残留。
- 新增每日提示：每个浏览器每天最多展示一次，优先使用国内来源，GitHub 作为回退，并在本地缓存减少重复请求。
- 图片文件统一使用日落渐变图标，覆盖 PNG、JPG、JPEG、GIF、WebP、SVG、BMP，文件管理与分享页面视觉保持一致。
- 完善 Windows 原生桌面端与桌面窗口细节，提升窗口显示、应用启动和代理页面使用体验。
- 静态界面版本改为构建时注入，登录页、设置页和主界面版本信息随构建同步更新。

### 2.7.93

- 分享与静态网站公开预览进一步完善，支持带 `#` 的文件名、嵌套目录和多路径分享，浏览与下载入口更加稳定。
- 新增 HEIC/HEIF 图片识别与预览，可正确展示扩展名不规范但实际为 HEIC 的图片。
- 优化预览资源加载与浏览器安全策略，修复音频波形、HEIC 解码等预览场景可能被拦截的问题；已转换图片会在当前页面内复用，连续浏览时无需重复转码。

### 2.7.92

- 外链分享与静态网站统一公开预览窗口，图片、音视频和文本内容可直接在线查看。
- 视频预览支持分段加载与进度拖动，音频提供波形和播放控制，大文本采用只读编辑器展示。
- 分享目录与静态网站目录新增预览、下载入口，并完善目录浏览、默认首页与安全访问控制。
- Linux 安装脚本统一为 `install.sh`，恢复国内镜像优先下载，失败后自动回退 GitHub Release 加速线路。
- 完善公开预览、静态网站访问、路径安全与媒体响应头相关测试。

### 2.7.91

- 外链分享与静态网站新增内置预览，图片、音视频支持播放列表，文本可直接只读查看，预览同样受密码、有效期和目录边界保护。
- 完善文件管理中的符号链接与 Windows junction 识别，正确标记目录链接、文件链接和失效链接，并加强静态网站访问的逃逸防护。
- 优化分享设置体验，支持常用到期时间快捷选择，密码、到期状态和链接管理更加清晰。
- 本地终端在基础 POSIX shell 环境下优先使用 Bash，避免只显示简单提示符，同时保留用户明确指定的 Zsh 等 shell。
- 完善桌面任务栏与自动排列，支持应用固定、窗口切换、最小化恢复、任务栏右键操作和桌面布局持久化。
- 新增 Linux 一键安装与 systemd 管理脚本，自动识别 `amd64`、`arm64` 与 `armv7`，支持安装、升级、卸载、服务自启以及下载加速回退。
- 修正 Docker Compose 部署示例的持久化路径，避免自定义启动参数后数据写入未挂载目录；容器重建后配置、账号与图标可以保留。
- 完善主题、目录选择、系统状态与 Docker 管理界面细节，并调整 Docker 更新检测的触发方式。

### 2.7.86

- Docker 管理新增镜像更新检测：本地镜像、Compose 服务与容器，支持拉取新镜像、重建容器或 Compose 服务。
- 系统监控改为后台统一采样，集中记录 CPU、内存、GPU、网络和磁盘读写趋势，打开监控面板即可查看连续数据，减少重复采集。
- 完善桌面任务栏与开始菜单：支持应用固定与取消固定、窗口切换、最小化与恢复，以及任务栏右键操作，多窗口使用更加连贯。
- 增强 Linux 网络与磁盘信息展示：补充网卡链路速率读取，并优化磁盘拓扑识别与呈现。
- 增加对 32 位 ARMv7 架构的设备支持（仅增加编译与发布，暂未在实体设备上验证）。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.86`，重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64、Linux armv7 与 fnOS 安装包。

### 2.7.73

- 优化文件管理框选性能：拖动开始时缓存文件行几何信息，按动画帧合并命中计算，并批量更新选择状态，减少大量文件下的布局抖动和卡顿。
- 保持列表视图与网格视图的框选、全选、反选和状态栏联动一致，避免框选误触打开文件。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.73`，重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.72

- 桌面配置升级到 v8，扩展图标尺寸选项，持久化系统应用隐藏状态，并完善监控开关默认值与旧配置迁移。
- 壁纸库支持缩略图缓存与复用、缺失或损坏重建、源图删除后的清理、内置壁纸回退和用户壁纸自动轮换。
- fnOS CGI 应用接入补齐运行环境变量、应用目录和共享目录信息，兼容新的入口路径，并修复快速输出截断、错误页与重定向问题。
- Linux 磁盘识别支持 holders/slaves 逻辑设备关系与 Btrfs 成员设备，优化 dm、RAID、分区到挂载点的映射和展示。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.72`，重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.69

- 增加内置主题样式和壁纸，桌面配色、背景与窗口视觉可以按使用习惯直接调整。
- 修复 Windows 端系统信息读取时的中文乱码问题，统一 PowerShell 与命令输出的 UTF-8 处理，并增强临时文件读取的兼容性。
- 调整硬盘信息加载逻辑，文件系统、物理硬盘与磁盘计数器改为并行采集，并增加短期缓存复用，让硬盘面板打开更快、刷新更稳定。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.69`，重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.68

- 新增 fnOS 应用中心接入，扫描 `/var/apps` 并读取应用名称、版本、图标与访问方式。
- 支持端口、Unix Socket 与 CGI 应用代理，提供 `/app/...`、`/cgi/...` 入口，并兼容 Cookie、Session Token、Location、错误页和路径重写。
- 增加路径穿越、符号链接逃逸与应用边界校验，提升 fnOS 应用接入的安全性。
- 新增域名直连路由：精确 Host 优先，反代服务与静态站点均可直接绑定域名，并增加域名冲突校验。
- 桌面配置升级到 v7，持久化窗口位置、尺寸、最大化与吸附状态，以及图标、链接、文件系统快捷方式和 fnOS 应用绑定。
- 系统状态显示当前构建版本，并支持与 GitHub Releases 最新版本比较和手动重新检测。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.68`，重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.63

- 新增进程管理，支持进程、端口和资源状态查询，以及经过身份校验的安全操作。
- 新增 Windows 桌面版，与服务版并列发布；桌面版使用独立桌面窗口承载管理界面。
- 同步官网、README、使用手册与 fnOS 清单到 `2.7.63`。
- 重新构建 Windows 服务版、Windows 桌面版、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.59

- 统一产品定位为“高效轻便的服务器运维桌面系统”，同步网站、README、使用手册与 fnOS 清单。
- 更新官网首页 Dashboard 展示图，完善桌面系统的视觉呈现。
- 校准 Cloudflare 隧道说明：命名隧道用于固定入口，快捷隧道由 Cloudflare 分配临时 `*.trycloudflare.com` 公开地址，适合快速验证。
- 重新构建 Windows、Linux amd64、Linux arm64 与 fnOS 安装包。

### 2.7.58

- 完善主题与壁纸体系：支持深色、浅色、跟随系统，以及粉色、蓝色、Miku、Cyan 等主题；图表、对话框、提示、终端与对比度同步适配。
- 增强桌面个性化与视觉细节：支持内置壁纸、用户壁纸、缩略图缓存、目录变化扫描、删除恢复与自动轮换，并优化桌面图标、文件夹、任务栏、窗口和壁纸表现。
- 完善系统状态与关于面板：集中展示项目图标、名称、版本、磁盘卡片与表格、SMART、网络、CPU、内存、GPU 和资源趋势。
- 强化 Docker 管理：补充可用性检测与降级界面，集中管理容器、Compose、镜像、镜像仓库、网络、Docker 服务重启与镜像加速器。
- 保持 FRPC、EasyTier、Cloudflare Tunnel 多实例管理，覆盖 Cloudflare 命名隧道与快捷隧道；GitHub Releases 更新检测仅提示版本，不自动下载或替换程序。

### 2.6.57

- 更新桌面内置应用图标与四套壁纸素材，统一整体视觉风格与资源清晰度。
- 同步应用、官网、README、使用手册与 fnOS 清单版本到 `2.6.57`。
- 重新构建 Windows、Linux amd64、Linux arm64 与 fnOS 安装包，确保发布产物包含最新素材。

### 2.6.56

- 统一应用内“关于”、官网、README 与使用手册的产品定位：M·Desk 是面向 NAS、家庭实验室与小型团队的自托管桌面系统。
- 重新整理官网与文档的能力介绍，完整覆盖服务路由、终端、文件与媒体、外链分享、静态网站、FRPC / EasyTier / Cloudflare Tunnel、Docker 管理与系统状态。
- 补充 Docker Socket 挂载、Compose 示例、GitHub Releases 更新检测与安全提示，并让仓库文档图片使用 GitHub 绝对地址。
- 重新构建 Windows、Linux amd64、Linux arm64 与 fnOS 安装包，确保发布产物包含最新文案与文档同步内容。

### 2.6.55

- 新增 GitHub Releases 更新检测，打开系统状态时自动检查，并支持手动重新检测；检测结果只展示版本与发布入口，不会自动下载、安装或替换文件。
- Docker Compose 部署补充 `/var/run/docker.sock:/var/run/docker.sock` 挂载说明，并增加宿主机权限与访问控制安全提示。
- 同步网站、README、使用手册、fnOS 清单与发布信息到 `2.6.55`。

### 2.6.53

- 新增桌面主题与壁纸配置，支持深色、浅色、跟随系统，以及多套内置壁纸。
- 新增图片预览、音视频播放器与播放列表，文件管理中的媒体文件可直接在桌面窗口中打开。
- 组网隧道支持按类型管理多个实例，FRPC、EasyTier 与 Cloudflare Tunnel 可独立配置、启停和查看日志。
- 优化服务路由、桌面窗口与响应式布局，改善多窗口切换、窄屏显示和常用操作体验。
- 系统状态支持桌面监控与资源趋势采样，折叠、展开和存储分别采用独立的刷新节奏。

### 2.6.42

- 桌面系统完成侧栏、应用区、任务栏与多窗口体验整合，常用运维能力在同一工作空间内切换。
- 组网隧道完善 FRPC、EasyTier 与 Cloudflare Tunnel，覆盖命名隧道与快捷隧道。
- 完善 Docker 管理，集中管理容器、Compose 项目、本地镜像、镜像仓库、Docker 网络与镜像加速器，并支持重启 Docker 服务。
- 完善系统状态，补充硬盘与 SMART、网络接口与流量、CPU、内存、GPU 和资源趋势，并支持桌面监控。
- 完善文件管理，支持右键菜单、框选、快捷键、在线编辑、压缩解压和直接分享；分享链接支持密码与到期时间。
- 静态网站支持默认主页、目录浏览与域名绑定。
- 默认监听端口调整为 `19188`，fnOS 安装、升级与服务入口保持统一。

### 2.5.38

- 文件管理支持按 `Ctrl+A` 在“全选/不选”之间切换。
- 文件编辑器支持按 `Ctrl+S` 快速保存当前文件。

### 2.5.35

- 文件管理支持选中单个文件或文件夹后按 `Enter` 打开或进入。
- 文件管理支持按 `Backspace` 返回上级目录。
- 文件管理状态栏在选中单个文件时显示文件大小，多选时保持显示选中数量。

### 2.5.34

- 文件管理右键菜单为常用操作增加快捷键提示。
- 修复 `F2` 重命名快捷键，支持对当前焦点文件直接触发重命名。
- 空白区域右键菜单在存在可粘贴内容时显示“粘贴”，并提示 `Ctrl+V`。
