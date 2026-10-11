<p align="center">
  <img src="./mdesk/ICON.PNG" width="120" alt="M·Desk">
</p>

<h1 align="center">M·Desk</h1>

<p align="center">面向自托管场景的桌面系统</p>

<p align="center">
  <a href="https://github.com/IMGZCQ/MDesk/releases">下载</a>
  ·
  <a href="./MDesk%20使用手册.md">使用手册</a>
  ·
  <a href="https://github.com/IMGZCQ/MDesk/issues">问题反馈</a>
</p>

> [!NOTE]
> M·Desk 将服务路由、终端、文件、分享、静态网站、组网隧道、Docker 与系统状态收束到同一套桌面体验中，面向 NAS、家庭实验室、小型团队和重视数据自主的个人用户。

<p align="center"><strong>当前版本：2.5.38</strong></p>

<p align="center">
  <img src="./www/assets/poster.webp" alt="M·Desk 功能概览" width="100%">
</p>

## 桌面系统总览

<p align="center">
  <img src="./www/assets/desktop-overview.webp" alt="M·Desk 桌面系统总览" width="52%">
</p>

M·Desk 以桌面作为统一工作空间：侧栏组织服务路由、终端、文件、分享、静态网站、组网隧道、Docker 管理与系统状态；应用区集中呈现常用入口；任务栏承接窗口切换。模块之间共享一致的菜单、状态与反馈，让日常运维和内容流转保持连贯。

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
| **本地终端** | 浏览器中的多会话终端，支持后台保活、快捷命令与右键菜单操作。 |
| **文件管理** | 在线浏览、编辑、上传下载、压缩解压；支持右键菜单、框选和直接分享。 |
| **外链分享** | 为文件或目录生成分享链接，可设置访问密码、到期时间、启停状态。 |
| **静态网站** | 选择一个本地目录即可发布为静态网站，支持默认主页、目录浏览与域名绑定。 |
| **组网隧道** | 支持 FRPC、EasyTier 与 Cloudflare Tunnel；Cloudflare 支持命名隧道和快捷隧道。 |
| **Docker管理** | 管理容器、Compose 项目、本地镜像、镜像仓库、Docker 网络与镜像加速器，并支持重启 Docker 服务。 |
| **系统状态** | 集中展示系统与硬件信息、硬盘和 SMART 健康、网络接口与流量、CPU、内存、GPU 与资源趋势。 |

---

## 快速开始

### Linux 命令行

1. 从 [Releases](https://github.com/IMGZCQ/MDesk/releases) 下载匹配架构的 `MDesk-linux-amd64` 或 `MDesk-linux-arm64`。
2. 将文件放到可写目录，确保同级目录能够创建 `data` 数据目录。
3. 赋予执行权限并启动：

```bash
chmod +x ./MDesk-linux-amd64
./MDesk-linux-amd64
```

4. 默认监听 HTTP `19188` 端口，访问 `http://<设备地址>:19188/@admin`。
5. 首次访问时设置管理密码。

ARM64 设备请将文件名替换为 `MDesk-linux-arm64`。可通过启动参数调整访问协议、监听地址、数据目录、日志和组网配置，完整说明见 [MDesk 使用手册](./MDesk%20使用手册.md)。

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

### fnOS 安装包

1. 从 [Releases](https://github.com/IMGZCQ/MDesk/releases) 下载最新的 `mdesk_<版本>.fpk`。
2. 在 fnOS 应用中心手动安装。
3. 安装过程中可选择 HTTP 或 HTTPS，默认使用 HTTP 和 `19188` 端口。
4. 安装完成后访问 `http://<设备地址>:19188/@admin`，首次访问时设置管理密码。

服务路由、终端、文件管理、外链分享、静态网站、组网隧道、Docker 与系统状态的详细操作，请查看 [MDesk 使用手册](./MDesk%20使用手册.md)。

---

## 项目结构

```text
code/                  Go 服务端与内嵌前端源码
www/                   独立官网静态资源
mdesk/                 fnOS 应用包结构
output/                构建脚本与发布产物
MDesk 使用手册.md      用户使用、部署与参数说明
```

---

## 官网

官网源码位于 `www/`，可以直接部署为静态站点。页面包含项目介绍、核心能力、优势说明、部署概览与响应式布局，所有文案均在 `www/index.html` 中维护。

> [!CAUTION]
> M·Desk 的管理入口、终端与文件管理拥有较高权限。请使用强密码，优先通过 HTTPS、内网 ACL、VPN 或零信任网关访问，不要将管理入口直接暴露在不可信网络中。

## 更新日志

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
