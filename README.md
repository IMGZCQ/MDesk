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
| **服务路由** | 统一管理多个服务入口，支持域名绑定与快速切换，各服务保持原有访问路径。 |
| **fnOS 应用接入** | 扫描 fnOS 应用中心，将端口、Unix Socket 与 CGI 应用接入桌面，支持应用图标、版本、访问入口与安全路径校验。 |
| **本地终端** | 浏览器中的多会话终端，支持后台保活、快捷命令与右键菜单操作；常见 POSIX 环境优先使用 Bash，同时保留 Zsh 等显式 shell 选择。 |
| **文件管理** | 在线浏览、编辑、上传下载、压缩解压；支持右键菜单、框选、直接分享，以及图片、音视频和文本预览。目录链接、文件链接、失效链接与 Windows junction 会被明确标记。 |
| **外链分享** | 为文件或目录生成分享链接，可设置访问密码、常用到期时间与启停状态；访问页面支持图片、音视频和只读文本预览。 |
| **静态网站** | 选择一个本地目录即可发布为静态网站，支持默认主页、目录浏览与域名绑定；站点中的图片、音视频和文本资源可直接预览。 |
| **组网隧道** | 支持 FRPC、EasyTier 与 Cloudflare Tunnel，并可分别管理多个实例；Cloudflare 提供命名隧道与快捷隧道两种模式。 |
| **Docker 管理** | 管理容器、Compose 项目、本地镜像、镜像仓库、Docker 网络与镜像加速器；支持按镜像、Compose 服务或容器逐项检测更新、拉取新镜像并重建服务，也支持重启 Docker 服务。 |
| **进程管理** | 查看真实进程列表、PID、用户、状态、CPU、内存、启动时间与可执行路径；支持搜索、端口反查、排序筛选、详情与安全结束进程。 |
| **系统状态** | 集中展示系统与硬件信息、硬盘和 SMART 健康、网络接口与流量、CPU、内存、GPU 与资源趋势；后台统一采样记录 CPU、内存、GPU、网络和磁盘读写趋势，Linux 补充网卡链路速率读取并优化磁盘拓扑呈现。 |

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
| fnOS | `MDesk_2.7.91.fpk` | 支持 amd64 与 arm64 |

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

### Linux 一键安装（systemd）

一键安装会自动识别 `amd64`、`arm64` 或 `armv7`。脚本会优先从 `https://fndesk.imcq.top/FPK/MDesk/` 下载对应二进制文件；如果该镜像不可用，再回退到 GitHub Release 的多个加速地址中选择可用且响应较快的线路。

```bash
curl -fsSL https://raw.githubusercontent.com/IMGZCQ/MDesk/main/mdesk.sh | sudo bash
```

再次运行同一命令时，脚本会先检测系统是否已经安装 MDesk：

- 未安装时，直接进入安装向导。
- 已安装时，显示管理菜单，可选择重新安装/升级、卸载或取消。

也可以使用显式命令强制安装或卸载：

```bash
sudo bash mdesk.sh install
sudo bash mdesk.sh uninstall
```

安装向导会依次询问：

1. 服务端口，直接回车使用默认值 `19188`
2. 安装目录，直接回车使用默认值 `/opt/MDesk`

安装目录建议使用不含空格和特殊字符的路径，例如 `/opt/MDesk`。

安装完成后会注册并启动 `mdesk.service`，同时设置为开机自动启动。管理后台地址为：

```text
http://<设备地址>:<端口>/@admin
```

卸载命令：

```bash
sudo mdeskctl uninstall
```

也可以使用本地脚本卸载：`sudo bash mdesk.sh uninstall`。

卸载向导会询问是否删除用户数据。默认保留数据；选择删除后，会清理安装目录中的数据。

如需指定 GitHub 加速地址，可使用英文逗号分隔，并支持 `{url}` 占位符：

```bash
curl -fsSL https://raw.githubusercontent.com/IMGZCQ/MDesk/main/mdesk.sh |
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
    network_mode: host
    restart: always
    command: ["-port", "19188"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/usr/local/bin/data
```

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

仓库 Actions secrets 需要配置 `DOCKERHUB_TOKEN`，建议使用 Docker Hub 的 Read & Write access token。Release 发布会推送 `latest`、版本号和完整标签；也可以通过 `workflow_dispatch` 手动补发指定版本，版本号填写 `2.7.91` 或 `v2.7.91` 均可。

### fnOS 安装包

1. 从 [Releases](https://github.com/IMGZCQ/MDesk/releases) 下载最新的 `MDesk_2.7.91.fpk`。
2. 在 fnOS 应用中心手动安装。
3. 安装过程中可选择 HTTP 或 HTTPS，默认使用 HTTP 和 `19188` 端口。
4. 安装完成后访问 `http://<设备地址>:19188/@admin`，首次访问时设置管理密码。

服务路由、终端、文件管理、外链分享、静态网站、组网隧道、Docker、进程管理与系统状态的详细操作，请查看 [MDesk 使用手册](./MDesk%20使用手册.md)。

---

## 项目结构

```text
.github/workflows/     Docker Hub 多架构发布流程
app/                   fnOS 应用运行文件与双架构二进制
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
