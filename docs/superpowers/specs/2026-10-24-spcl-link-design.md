# SPCL 联机功能设计

> 状态：已评审（2026-10-24）
> 日期：2026-10-24
> 目标版本：SPCL 1.2
> 基线：SPCL 1.1（PCL 2.14.0.0 源码快照，VersionCode 411/412）

## 1. 背景与目标

PCL 2.14.0.0 源码中自带一套基于 **EasyTier** 的联机功能（虚拟局域网 + 端口转发 + 邀请码），但官方在开源版中把它隐藏了：标签页被强制折叠，且核心配置依赖官方服务器下发的 `ServerConfig("Link")`。

目标：在 SPCL 中放显「联机」标签页，并改用**自建 EasyTier 中继节点**，让不同局域网下的玩家进入同一虚拟局域网，可游玩房主「对局域网开放」的单人世界或房主自建的服务器。

## 2. 非目标（YAGNI）

- 房间大厅 / 房间列表 / 聊天 / 好友系统
- 与官方 PCL 或 HMCL 的房间互通
- 自动开服、自动进入游戏
- 多穿透后端（frp、樱花、蓝盾等）
- 中继流量统计面板、赞助/权限体系

## 3. 现状（改造前的关键事实）

| 事实 | 位置 |
| --- | --- |
| 联机页已完整实现：创建/加入、加载进度、失败页、完成页（邀请码、Ping、人数、端口、IP、复制邀请码、退出） | `Pages/PageLink/PageLinkMain.xaml(.vb)` |
| 进程管理已实现：下载解压、启动 `联机模块.exe`、解析日志、`联机模块 CLI` 查询节点/延迟 | 同上 `ProcessStart` / `RefreshPeer` |
| `InitConfig` 依赖官方服务器，开源版直接抛错 | `PageLinkMain.xaml.vb:427` |
| 配置字段全部来自 `ServerConfig("Link")` | `Argument`、`EasyTierVersion`、`Downloads`、`DiscoverPeer(Id)`、`Peers`、`PeersBlackList`、`RandomPeer`、`MandatoryPeers` |
| 标签页被强制折叠 | `PageSetupUI.xaml.vb:447`；`Settings.vb` 的 `UiHiddenPageLink/UiHiddenSetupLink` 默认隐藏列表 |
| 网络名生成规则：`P{端口十六进制4位}-{随机5位}`（固定 `P` 开头，共 11 字符） | `PageLinkMain.xaml.vb:104-113` |
| 邀请码格式：`{网络名}-{密码}-{版本2位}{发现节点3位}`，自带房间信息 | `GetInviteCode` / `JoinInternal` |
| 自定义节点通路已存在：设置 `LinkCustomPeer` 非空时完全绕过节点列表，房主的邀请码节点字段为 `000`，加入者据此进入自定义节点模式 | `InitLaunch` / `JoinInternal` |

### 3.1 EasyTier 模块兼容性实测（v2.6.4）

官方 `easytier-windows-x86_64-v2.6.4.zip`（31.1 MB）解压后包含：

```
easytier-core.exe    23.8 MB   ← 重命名为「联机模块.exe」
easytier-cli.exe      9.7 MB   ← 重命名为「联机模块 CLI.exe」
Packet.dll            215 KB   ← 必需（检查项）
wintun.dll            418 KB
WinDivert64.sys        92 KB
easytier-web*.exe     45 MB     ← 不需要
```

文件名与 PCL 既有逻辑完全一致，重命名逻辑无需修改。裁剪后需随发布包分发的文件约 34 MB（压缩后约 15–20 MB）。

## 4. 决策记录

| 决策 | 选择 | 理由 |
| --- | --- | --- |
| 中继方式 | **自建专属中继**（EasyTier 公共共享节点） | 稳定可控；EasyTier 中继轻量，1 核 1G + 500GB 流量足够 |
| 房间机制 | **沿用 PCL 邀请码格式**，节点固定为自建中继 | 改动最小，界面与校验逻辑全部复用 |
| 开放范围 | **仅自己与朋友**，发布包**不内置中继地址** | 与 Azure 的处理一致，避免他人占用带宽与滥用风险 |
| 模块交付 | **随发布包内置**（裁剪版） | 解压即用，无运行时下载失败点；GitHub 仓库本身不变大 |
| 实现路线 | **路线 A：最小改造**（复用现有页面与 EasyTier 逻辑） | 风险最低，UI 已完善；重写成本数倍 |

## 5. 架构与组件

```
启动器端
├─ ModLinkConfig.vb（新增）        本地联机配置（替代 ServerConfig("Link")）
│   ├─ EasyTierVersion 常量        与内置模块对应，用于跳过下载
│   ├─ BaseArguments 常量          EasyTier 基础启动参数
│   └─ FallbackDownloads 常量      内置模块缺失时的下载地址（可选）
├─ PageLinkMain.xaml.vb（改造）    InitConfig 改读本地配置；中继地址接入；内置模块复用；网络名前缀改 S
├─ PageSetupLink.xaml(.vb)（改造） 新增「中继服务器」输入框；隐藏依赖官方节点列表的「节点状态」区块
├─ PageSetupUI.xaml.vb / Settings.vb（改造）  放显联机标签页
└─ tools/package-spcl.ps1（新增）  打包时把联机模块放入 zip

中继端
└─ tools/relay/  systemd unit + docker compose + 部署说明
```

### 5.1 新增设置项

| 键 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `LinkRelayServer` | String | `""` | 中继地址，形如 `tcp://1.2.3.4:11010`。非空时优先级低于 `LinkCustomPeer` |

## 6. 数据流

**创建房间（房主）**

1. 输入 MC 局域网端口（1024–65535）
2. 生成网络名 `S{端口hex4}-{随机5}`、随机密码 `{随机5}`
3. 解压内置联机模块到 `%APPDATA%\SPCL\EasyTier\`（首次）
4. 启动 `联机模块.exe`：`--network-name` `--network-secret` `--listeners` `--rpc-portal` `--private-mode true` `-i 10.114.114.114 --hostname=... --tcp-whitelist={端口} --udp-whitelist={端口}` + `-p="tcp://<中继>:11010"`
5. 完成页显示邀请码与本机信息

**加入房间（加入者）**

1. 输入邀请码 → 解析网络名/密码/发现节点字段
2. 同样解压/启动内置模块，但参数为 `-d --hostname=... --tcp-whitelist=0 --udp-whitelist=0` + 四个 `--port-forward`（IPv6/IPv4 环回的 tcp/udp）把本地端口映射到 `10.114.114.114:{房主端口}`
3. 页面显示 `localhost:{本地端口}`，玩家把它填进 MC 的「直接连接」

**中继节点（你的 VPS）**

```ini
ExecStart=/opt/easytier/server/easytier-core \
  --relay-network-whitelist S* \
  --machine-id spcl-relay --hostname spcl-relay \
  -l tcp://0.0.0.0:11010 -l udp://0.0.0.0:11010
```

- 不写 `--network-name` / `--network-secret` / `-i`：中继不加入任何网络、不建 TUN，只转发
- **不要**在中继上加 `--private-mode`，访问控制交给白名单
- 必须同时放行 **TCP 与 UDP 11010**（UDP 决定能否 P2P 打洞，只开 TCP 会全部退化走中继）

## 7. 关键改动点

| 改动 | 说明 |
| --- | --- |
| `InitConfig` | 删除 `ServerLoader.WaitForExit` 与「开源版无法联网获取配置」的抛错；改为读 `ModLinkConfig`。保留 `MinVersionCode`/`DisableReason2` 的本地校验能力 |
| `InitPrepareDownload` | `ServerVersion` 改由 `ModLinkConfig.EasyTierVersion` 提供；新增「内置模块优先」分支：若发布包内 `联机模块\` 存在且目标目录缺失/过旧，直接复制，不产生下载任务 |
| `InitLaunch` | 有效节点 = `LinkCustomPeer`（非空优先）→ `LinkRelayServer`（非空）→ 否则 `Panic` 并提示去 设置 → 联机 填写 |
| 网络名 | `P` → `S` 前缀；`ValidateCodeFormat` 接受 `S` 开头，遇到 `P` 开头给出「本版本使用自建中继，无法加入官方 PCL 房间」的明确提示 |
| 标签页 | `PageSetupUI` 不再强制折叠 `BtnTitleSelect2`；`Settings.vb` 隐藏列表移除 `UiHiddenPageLink`/`UiHiddenSetupLink` |
| 打包 | 新增 `tools/package-spcl.ps1`：构建 → 组装 `dist\SPCL\`（exe + LICENCE + README + `联机模块\` + EasyTier LICENSE）→ 生成 `SPCL-<版本>-win64.zip` |

## 8. 错误处理

| 场景 | 行为 |
| --- | --- |
| 未填写中继地址 | 加载页 `Panic`，提示「请在 设置 → 联机 → 中继服务器 填写地址，例如 `tcp://1.2.3.4:11010`」 |
| 中继不可达 / 端口未放行 | 沿用现有超时判定，补充提示「检查安全组与防火墙的 TCP/UDP 11010」 |
| 网络名不在中继白名单 | 提示检查中继的 `--relay-network-whitelist`（含 `S*`） |
| 内置模块缺失或版本低于常量 | 回退到 `FallbackDownloads` 下载；仍失败则报「联机模块不可用」 |
| 收到 `P` 开头邀请码 | 明确提示不与官方 PCL 房间互通 |
| 退出 / 崩溃 | 沿用 `ProcessStop`，结束残留的「联机模块」「联机模块 CLI」进程 |

## 9. 验收标准

1. 顶部导航出现 **启动 下载 联机 设置 更多**；未配置中继时页面给出清晰提示且不崩溃
2. 配置中继后，两台处于不同网络的机器能完成「创建 → 加入」，`easytier-cli peer` 中可见 `p2p` 或 `relay` 连接
3. 加入方可通过页面显示的 `localhost:{端口}` 进入房主的局域网世界
4. 退出房间与强制结束启动器后，`联机模块` 进程无残留
5. 离线登录、第三方皮肤站登录、正版登录入口（提示路径）均不受影响
6. 现有 1.1 的构建流程与完整性级别修复仍然有效

## 10. 风险与限制

| 风险 | 应对 |
| --- | --- |
| EasyTier 升级导致参数变化 | 固定 v2.6.4；实现时用 `easytier-core --help` 核对 PCL 传入的参数是否仍受支持 |
| Windows 房主端需要创建虚拟网卡，可能要求管理员权限 | 验收时确认；若必须，则在加载页提示「请以管理员身份运行」 |
| 中继带宽成本与被滥用 | 中继用 `--relay-network-whitelist S*` 限定；可加 `--foreign-relay-bps-limit` 限速；发布包不内置地址 |
| 中继 IP 变更 | 你和朋友在设置里改一行即可，无需重新发布 |
| 模块体积使发布包从 2.5 MB 增到约 20 MB | 可接受；GitHub 仓库本身不新增二进制（打包产物在 `dist/`，已被忽略） |

## 11. 合规

随发布包分发 EasyTier 二进制需附其开源许可证（Apache-2.0），打包时复制 `LICENSE` 到 `联机模块\LICENSE.txt`。

## 12. 实测记录（2026-10-24）

| 项 | 结果 |
| --- | --- |
| EasyTier v2.6.4 参数兼容 | `easytier-core --help` 覆盖 PCL 拼接的全部参数（`--network-name`/`--network-secret`/`--listeners`/`--rpc-portal`/`--private-mode`/`-i`/`-d`/`-p`/`--hostname`/`--tcp-whitelist`/`--udp-whitelist`/`--port-forward`/`--latency-first`/`--relay-network-whitelist`），无需改动拼接逻辑 |
| CLI JSON 格式 | `联机模块 CLI.exe -o json -p 127.0.0.1:<port> peer` 返回含 `lat_ms`/`cost`/`nat_type`/`hostname`/`ipv4`/`id`/`version` 的 JSON，与 `Peer` 解析逻辑匹配 |
| 中继节点 | 本地以 `--relay-network-whitelist S*` 启动中继成功，端口 11010 TCP/UDP 正常监听 |
| **开源版缺失实现（已补回）** | `ModBase.StartProcessAndGetOutput` 在开源快照中被整体删除，导致 `RefreshPeer` 的 CLI 调用被注释、连接检测永远失败。已补回该辅助函数并恢复 CLI 调用，否则联机无法完成连接 |
| **管理员权限** | EasyTier 在 Windows 创建虚拟网卡（wintun）必须由管理员运行；非管理员时日志出现 `tun device error: Failed to create adapter` 与防火墙 `拒绝访问`。1.2 采用「报错时给出以管理员身份运行的提示」，一键提权重启留作后续优化（PCL 有单实例互斥，提权重启需要先释放互斥再启动，风险较高） |
| 端到端联机 | 受 DSH 沙箱受限令牌限制，无法在本机完成真实会话的 TUN 建卡；需在用户桌面会话中以管理员身份实测（步骤：配置中继地址 → 创建房间 → 加入者用邀请码加入） |