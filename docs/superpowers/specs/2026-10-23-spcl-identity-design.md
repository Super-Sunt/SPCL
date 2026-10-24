# SPCL 身份层改造设计

> 状态：已评审（2026-10-23）
> 日期：2026-10-23
> 基线：PCL 源码快照 2.14.0.0（VersionCode 412）
> 依赖：MeloongCore 固定提交 `98157d65c7627721c816c02e8be96ac4fe61d615`
> 目标产物：Windows 单 exe 的 SPCL 启动器（个人/小圈子自用，后续可能发布）

## 1. 背景

当前目录是从 GitHub 获取的 `Meloong-Git/PCL` 源码快照，包含 PCL 的大部分源代码：启动、下载、实例管理、登录、Mod 管理、崩溃分析等。工程为 VB.NET + WPF + .NET Framework 4.8，Windows 专用。

用户希望在这份源码基础上做出一个“自己的、可用的”启动器，第一阶段定位为个人/小圈子自用，后续可能发布。改造重点限定为**外观与品牌身份**，功能全部保留，先跑通再迭代。

## 2. 目标与成功标准

### 2.1 目标

1. 在现有源码上构建出可运行的 Release 版本，保留 PCL 的启动、下载、实例、Mod、离线/第三方登录等全部现有功能。
2. 完成身份层改造：SPCL 名称、图标、启动画面、关于页、默认蓝色主题。
3. 不改变主要页面布局和交互结构。
4. 与官方 PCL 在同一台机器上可共存，启动器级配置、临时文件和单实例互不干扰。

### 2.2 成功标准

- Release 构建产物能启动，离线登录后成功启动一个已安装的 Minecraft 版本。
- 窗口标题、任务栏、图标、关于页均显示 SPCL。
- 启动时不再出现“该版本中无法使用以下特性……”开源版弹窗，也不再出现快照版欢迎提示。
- 关于页仍以龙腾猫跃署名和赞助链接开头，并新增“基于 PCL 的第三方修改版”说明。
- 与官方 PCL 放在不同目录同时运行时，各自的启动器数据、临时文件、互斥体和单实例窗口查找互不影响。

## 3. 非目标

第一版明确不做：

- 不重写启动引擎，不替换 PCLCS / MeloongCore。
- 不做跨平台（Linux/macOS）。
- 不重做页面布局、动画体系或交互结构。
- 不接入微软正版登录（需要自建 Azure 应用并配置 ClientId）。
- 不接入 CurseForge API（需要自行申请 API Key）；Modrinth 搜索不受影响。
- 不实现自动更新、联网通知、赞助解锁；不新做主题切换或主题解锁。
- 不删除 PCL 现有功能，不绕过正版购买提示和赞助提示。

## 4. 前提与约束

### 4.1 授权约束

代码受《PCL 分发有限许可》和《PCL 存储库合理使用指南》约束。基于本仓库修改属于“重度使用”。个人阶段可以自由命名，但**一旦公开发布**必须满足：

1. 明确表示是第三方基于 PCL 独立二次创作的产物。
2. 名称以 `Plain Craft Launcher (PCL)` 开头，并加足以表现第三方修改的后缀，例如 `PCL SPCL修改版`。
3. 关于页首位给出龙腾猫跃署名及赞助链接，公开源代码，并继续使用同一许可文件。
4. 若包含 Minecraft 启动功能，应实现与 `McLaunchPrecheck` 一致或更激进的正版购买劝导与赞助劝导。
5. Windows 上运行时不得有类似 PCL 赞助解锁的功能或表现；界面主要色相必须为蓝色。

因此本设计在 M1 就保留蓝色主题、署名和正版/赞助提示，避免将来发布时返工。

### 4.2 技术约束

- 主工程是旧式 VB.NET WPF 项目，目标 `.NET Framework 4.8`，不是 .NET 8。
- 启动时通过 `AppDomain.AssemblyResolve` 从内嵌资源加载 MeloongCore、PCLCS 和第三方 DLL，因此分发形态是单 exe。
- 程序集名 `Plain Craft Launcher 2` 被 **15 处显式 `Plain Craft Launcher 2;component` URI**（M1 关于页新增 1 个 Logo 引用后为 16 处）和 **10 处 `assembly=Plain Craft Launcher 2` 的 XAML 命名空间**引用；其余 `pack://application:,,,/images/...` 是相对入口程序集的写法，改名后不需要动。M1 不改程序集名正是为了避开这批改动。
- `ModSecret.vb` 中官方删除了微软 OAuth ClientId、CurseForge API Key、更新、统计、赞助等实现，部分功能以空桩或提示代替。

### 4.3 环境约束

- 需要 Visual Studio 2022（含 .NET 桌面开发工作负载）和 .NET Framework 4.8 目标包。
- 需要能访问 NuGet（`api.nuget.org`）还原 MeloongCore/PCLCS 的包。
- 本机 VS 17.11.5 自带 Roslyn 4.11，不支持 C# 项目的 `LangVersion 13.0`，会报 `CS1617`。**不能用 `/p:LangVersion=12.0` 全局覆盖**：该属性会同时作用于 VB 主工程，而 VB 12.0 是 2013 年语法版本，会让内插字符串、元组等全部报 `BC36716`。正确做法是先单独构建三个 C# 项目（MeloongCore、MeloongCore.Wpf、PCLCS）并只对它们加 `LangVersion=12.0`，再用 `/p:BuildProjectReferences=false` 构建主 VB 工程；或者升级到 VS 17.12+。
- DSH 沙箱工作区内创建的 exe 会继承 `Low` 完整性标签。`Low` 标签会让 ShellExecute/双击启动被系统拒绝（报“操作已被用户取消”），但用 `UseShellExecute=false` 直接 CreateProcess 仍可启动。这是沙箱产物属性，不是源码问题；打包成 zip 让用户解压到普通目录，或对 exe 执行 `icacls <exe> /setintegritylevel Medium`，即可解决。
- `workspace-write` 模式下 Schannel 会导致 NuGet TLS 失败（`SEC_E_NO_CREDENTIALS`）；`danger-full-access` 模式下 `dotnet restore` 正常。

## 5. 现有架构

```
Plain Craft Launcher 2.sln
├─ Plain Craft Launcher 2\        VB.NET WPF 主工程（net48，单 exe）
│  ├─ Modules\                    启动/下载/实例/登录/Mod/网络等
│  ├─ Pages\                      UI 页面
│  ├─ Controls\                   自绘控件与动画
│  ├─ Images\                     图标、Logo、主题图
│  ├─ My Project\                 AssemblyInfo、Resources.resx（内嵌 DLL）
│  └─ Resources\                  Help.zip、第三方 DLL、jar
├─ PCLCS\                         C# 库（net48）：Java、版本 JSON、启动参数
└─ MeloongCore\                   子模块：Shared（netstandard2.0）+ Wpf（net48）
```

关键数据路径：

- 配置与实例：exe 同级 `PCL\`（`Setup.ini`、实例 `PCL\Setup.ini`）。
- 临时文件：`%TEMP%\PCL\`。
- 注册表：`PCLDebug`（源码中的开源分支隔离名）。
- 内嵌图片路径：`pack://application:,,,/Plain Craft Launcher 2;component/Images/`。

## 6. 里程碑

| 里程碑 | 内容 | 产出 | 是否必需 |
| --- | --- | --- | --- |
| M0 | 原样编译并跑通 | 可运行的 Release 基线 | 必需 |
| M1 | 身份层改造 | SPCL 显示身份 + 隔离 + 清理 | 必需 |
| M2 | 程序集/exe 改名 | `SPCL.exe` | 可选，M1 稳定后再决定 |
| M3 | 发布准备 | 合规改名、文档、打包 | 仅将来公开发布时 |

## 7. M0：先原样跑通

### 7.1 步骤

1. 确认 MeloongCore 在固定提交：
   `git -C MeloongCore log -1 --format=%H` 应为 `98157d65c7627721c816c02e8be96ac4fe61d615`。
2. 还原 NuGet：
   `dotnet restore PCLCS\PCLCS.csproj`
3. 构建主工程（Release）：
   `msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release`
   或在 VS 2022 打开解决方案，选择 Release 生成。
4. 产物：`Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe`。

### 7.2 验收

- exe 能启动，界面无崩溃。
- 离线登录能进入。
- 选择一个已安装版本，能启动游戏。
- 保存构建日志；记录所有警告，区分“源码既有”与“环境导致”。

### 7.3 本阶段不改任何源码

M0 失败时先修环境/依赖，不靠改业务代码绕过。只有确认是源码与 MeloongCore 提交不匹配时，才做最小适配。

## 8. M1：身份层改造

### 8.1 名称与版本

| 位置 | 现状 | 改为 |
| --- | --- | --- |
| `My Project\AssemblyInfo.vb` | `AssemblyTitle("Plain Craft Launcher 启动器")` | `SPCL 启动器` |
| 同上 | `AssemblyProduct("Plain Craft Launcher")` | `SPCL` |
| 同上 | `AssemblyDescription("Minecraft 启动器")` | `Minecraft 启动器（基于 PCL 的第三方个人修改版）` |
| 同上 | `AssemblyCopyright("Copyright © 成都瓜皮龙科技有限公司")` | 保留原版权，追加 `; SPCL 修改版` |
| `FormMain.xaml` | `Title="Plain Craft Launcher　"` | `Title="SPCL　"` |
| `Application.xaml.vb` | `FindWindow(..., "Plain Craft Launcher　")` 及旧标题回退 | 只查找 `SPCL　`；移除旧 PCL 标题回退，避免误聚焦官方 PCL |
| `Application.xaml.vb` | 互斥体名 `PCL_SingletonMutex` | `SPCL_SingletonMutex` |
| `ModBase.vb` | `VersionDisplay = BuildTypeDisplay & " " & VersionBaseName` | `"SPCL " & BuildTypeDisplay & " " & VersionBaseName` |
| `ModBase.vb` / `ModLaunch.vb` | 日志“PCL 版本” | “SPCL 版本” |
| `PageOtherAbout.xaml` | `Title="Plain Craft Launcher 2"` | `SPCL`，并新增“基于 Plain Craft Launcher 2.14.0.0 修改” |

注意：

- 窗口标题中的全角空格 `　` 必须保留，且与 `FindWindow` 完全一致，否则单实例检测失效。
- `VersionBranchMain` 保持 `OpenSource`，避免改变 `PageLinkMain`、`PageLaunchRight` 的分支判断。
- 网络请求 UA 暂保持 `PCL2/...`，避免影响 BMCLAPI 等既有源；后续需要再单独评估。

### 8.2 图标与启动画面

- 生成多尺寸 `Images\icon.ico`：16/24/32/48/64/128/256。视觉为蓝色圆角底 + 白色 `S`，不使用 Minecraft 官方素材。
- 用同一图形替换 `Images\Heads\Logo.png`，它被离线皮肤资源包用作图标。
- 启动画面 `Application.xaml.vb` 的 `New SplashScreen("Images\icon.ico")` 自动跟随新图标。
- `Images\Heads\PCL2.png` 保留：它出现在关于页的 PCL 署名区域，属于 attribution。

### 8.3 关于页与授权

- 保留 `PageOtherAbout.xaml` 中“龙腾猫跃”为关于页第一位，保留“赞助 PCL !”按钮与链接。
- 在 LTCat 行之后增加 SPCL 行，内容为“本软件为基于 Plain Craft Launcher 的第三方个人修改版”，附原仓库链接。
- 在关于页补充一段“本版本不包含微软登录、CurseForge API 调用、自动更新”的说明，替代启动时被移除的开源版弹窗。
- 保留 HerobrineXia 及全部特别鸣谢，不删除任何 PCL 贡献者。
- 关于页的“检查更新”按钮改为提示“个人修改版暂不提供自动更新”，不再调用空的更新桩。
- 发布包附带 `LICENCE` 文件；README 中注明基于 PCL 的哪个版本、做了哪些修改。

### 8.4 主题

- 保持 `ModSecret.vb` 中 `ColorHue = 210`、`ColorSat = 85` 的默认蓝色，不调色相。
- 不修改主题解锁/切换逻辑，保持源码现状；不实现赞助解锁。
- 这样既符合个人审美，也满足将来发布时的“主色相必须为蓝色”。

### 8.5 数据与路径隔离

- `ModBase.vb` 的 `PathTemp`：`%TEMP%\PCL\` → `%TEMP%\SPCL\`。
- `Application.xaml.vb` 的 `MeloongCore.Main.Init("PCL")` → `Init("SPCL")`，让 `%APPDATA%\PCL\`（CustomSkin、EasyTier 等）变为 `%APPDATA%\SPCL\`。
- 同步把 `PclLogger` 的 `logFolder` 从 `Paths.BaseThenName` 改为 `Paths.Base & "PCL\"`，让日志仍和 `PCL\` 数据目录放在一起，避免多出一个 `SPCL\` 日志目录。
- 版本独立设置仍使用 `PCL\Setup.ini`：它同时被 ModMinecraft、ModModpack、实例页等处读写，改成 `SPCL\Setup.ini` 会破坏 PCL 格式整合包的导入/导出兼容性，M1 不动。
- 如果与官方 PCL 共用同一个 `.minecraft`，版本级设置会共享；需要完全隔离时使用独立的 `.minecraft` 目录。
- 数据目录仍为 exe 同级 `PCL\`；只要 SPCL 单独放一个目录，就与官方 PCL 隔离。
- 注册表保持 `PCLDebug`，不要改成官方 PCL 使用的键。
- 单实例互斥体改为 `SPCL_SingletonMutex`，避免与官方 PCL 抢同一个互斥体。
- 文档中明确：不要把 `SPCL.exe` 放进官方 PCL 的目录。

### 8.6 启动清理

- 删除 `FormMain.xaml.vb` 启动阶段弹出的“该版本中无法使用以下特性……”开源版说明块。
- 用 Release 构建，避开“欢迎使用 PCL 快照版”提示。
- `FormMain.xaml.vb` 清理旧更新文件 `PCL\Plain Craft Launcher 2.exe` 的逻辑可保留，M2 改名时再同步。
- 保留 `McLaunchPrecheck` 的正版购买提示与赞助提示，不删除、不弱化。

### 8.7 明确不改的内容

- 页面布局、动画、控件结构。
- 下载、启动、实例、Mod、整合包、崩溃分析逻辑。
- 首页内容源（新闻、音乐、百宝箱等）；即使部分源失效，也不在 M1 处理。
- PCLCS、MeloongCore、第三方 DLL。
- 程序集名、RootNamespace、项目文件名。

### 8.8 M1 涉及文件清单

- `Plain Craft Launcher 2\My Project\AssemblyInfo.vb`
- `Plain Craft Launcher 2\FormMain.xaml`
- `Plain Craft Launcher 2\FormMain.xaml.vb`
- `Plain Craft Launcher 2\Application.xaml.vb`
- `Plain Craft Launcher 2\Modules\Base\ModBase.vb`
- `Plain Craft Launcher 2\Modules\Minecraft\ModLaunch.vb`（日志文案）
- `Plain Craft Launcher 2\Modules\Minecraft\ModModpack.vb`（ProductName 自检）
- `Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml`
- `Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml.vb`（如按钮行为需要）
- `Plain Craft Launcher 2\Images\icon.ico`
- `Plain Craft Launcher 2\Images\Heads\Logo.png`

## 9. M2：可选彻底改名

仅当 M1 稳定、且确实需要 `SPCL.exe` 时执行。

### 9.1 改动

1. `Plain Craft Launcher 2.vbproj` 的 `<AssemblyName>` 改为 `SPCL`。
2. 替换 15 处（M1 后 16 处）`Plain Craft Launcher 2;component` 为 `SPCL;component`，覆盖：
   - `ModBase.vb` 的 `PathImage`
   - `FormMain.xaml` 的 `Icon`
   - 关于页的 13 处（M1 后 14 处）图片 URI
3. 替换 10 处 `assembly=Plain Craft Launcher 2` 为 `assembly=SPCL`，覆盖 `PageLaunchRight`、`PageOtherHelpDetail`、`PageSelectLeft`、`PageSpeedLeft` 里的运行时 XAML 字符串，以及 `Custom.xaml` 的示例。
4. 同步修改：
   - `ModModpack.vb` 的 ProductName 判断，接受 `SPCL`
   - `PageInstanceExport.xaml.vb` 中写死的 `Plain Craft Launcher.exe`
   - `FormMain.xaml.vb` 的旧更新文件清理路径
   - 崩溃日志识别名（可选）
5. 工程文件名、解决方案名、RootNamespace 不改。
6. `pack://application:,,,/images/...` 这类相对 URI 不动；它们解析到入口程序集，改名后自动跟随。

### 9.2 验收

- 产物为 `SPCL.exe`，文件属性中产品名为 SPCL。
- 所有图片、图标、启动画面正常加载。
- 单实例检测正常（开第二个实例会聚焦第一个）。
- 整合包导出、自带启动器识别正常。
- 全局搜索 `Plain Craft Launcher 2;component` 和 `assembly=Plain Craft Launcher 2` 结果都为 0。

### 9.3 风险

- 16 处 component URI 或 10 处 `assembly=` 命名空间漏改，会导致启动时 XAML 资源/自定义内容解析异常，必须全局验证。
- 程序集改名后，任何按程序集名反射或查找的代码都可能受影响，需要额外 grep。
- 建议 M2 单独提交，便于回滚。

## 10. 构建与分发

### 10.1 构建

```powershell
dotnet restore PCLCS\PCLCS.csproj

# 1) 只对 C# 依赖加 LangVersion=12.0（绕开 VS 17.11 Roslyn 不支持 C# 13）
msbuild MeloongCore\Shared\MeloongCore.csproj /p:Configuration=Release /p:LangVersion=12.0
msbuild MeloongCore\Wpf\MeloongCore.Wpf.csproj /p:Configuration=Release /p:LangVersion=12.0
msbuild PCLCS\PCLCS.csproj /p:Configuration=Release /p:LangVersion=12.0

# 2) 主 VB 工程不加 LangVersion，并跳过重复构建依赖
msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release /p:BuildProjectReferences=false
```

- 主 VB 工程绝不能收到 `LangVersion=12.0`，否则会被当成 VB 12.0（2013 语法）而报 `BC36716`。
- 升级到 VS 17.12+ 后，C# 依赖可去掉 `LangVersion=12.0`。
- Debug 仅用于开发自测；Release 用于分发。
- 若 `msbuild` 不在 PATH，使用 VS 2022 的 Developer PowerShell，或直接调用 VS 目录下的 `MSBuild.exe`。

### 10.2 分发

第一版采用 zip：

```
SPCL\
├─ SPCL.exe              （M1 阶段仍是 Plain Craft Launcher 2.exe）
├─ LICENCE
└─ README.txt
```

- 不做安装器、不做自动更新。
- 在 DSH 沙箱工作区里构建出的 exe 会带 `Low` 完整性标签，直接双击可能报“操作已被用户取消”。发布时用 zip 分发，用户解压到普通目录后即为 Medium；如需保留裸 exe，打包时执行 `icacls <exe> /setintegritylevel Medium`。
- exe 未签名，Windows SmartScreen 可能提示，属预期。
- 目标机器只需 .NET Framework 4.8（Windows 10 1809+ / Windows 11 默认包含）。

## 11. 验收清单

- [ ] M0：Release 构建成功，exe 启动无崩溃。
- [ ] M0：离线登录成功，能启动一个已安装版本。
- [ ] M1：窗口标题、任务栏、图标均为 SPCL。
- [ ] M1：关于页显示 SPCL，且龙腾猫跃署名与赞助链接仍在首位。
- [ ] M1：启动无开源版弹窗、无快照版提示。
- [ ] M1：`%TEMP%\SPCL\` 生效，官方 PCL 的 `%TEMP%\PCL\` 不被写入。
- [ ] M1：与官方 PCL 同时运行时，不抢互斥体、不误聚焦官方窗口，临时目录各自独立。
- [ ] M1：离线皮肤资源包使用的 Logo 已替换且能正常生成。
- [ ] M1：下载、Mod 搜索（Modrinth）、实例管理冒烟通过。
- [ ] M2（如做）：`SPCL.exe` 启动、图片、单实例、导出全部正常。

## 12. 风险与缓解

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 源码快照与 MeloongCore 提交不匹配 | 编译失败 | 固定提交；仅做最小适配；不回退到“拉最新” |
| NuGet 网络不可达 | M0 无法构建 | 在正常桌面网络执行；或用 VS 离线包/手动放包 |
| `FindWindow` 标题不一致 | 单实例失效、双开 | 逐字符同步，含全角空格；实测双开 |
| 互斥体仍用 `PCL_SingletonMutex` | 与官方 PCL 抢单实例，SPCL 直接退出 | 改为 `SPCL_SingletonMutex` 并实测同时运行 |
| `Main.Init("SPCL")` 改变 AppData 路径 | 皮肤/EasyTier 旧数据不再被读取 | 迁移说明；或将旧 `%APPDATA%\PCL` 复制为 `%APPDATA%\SPCL` |
| `AssemblyProduct` 改动 | 整合包识别不到自带启动器 | 同步修改 `ModModpack.vb` 判断 |
| 图标尺寸不全 | 任务栏/高分屏模糊 | 生成完整 16–256 多尺寸 ico |
| `ModSecret.vb` 删除的鉴权代码 | 第三方登录/皮肤站异常 | M1 用离线登录验收；第三方登录单独实测 |
| 未签名 exe | SmartScreen/杀软误报 | 个人使用加白名单；公开发布再评估签名 |
| 发布时名称不合规 | 授权风险 | 发布前改为 `PCL SPCL修改版`，补齐署名/开源/许可 |

## 13. 回滚策略

- M1 前先备份原始源码目录（或初始化 git 并提交基线）。
- M1 的身份层改动集中在少量文件，可按文件回滚。
- M2 单独提交；若 URI 替换出问题，直接回滚该提交。
- 配置数据在 `PCL\`，不涉及数据库迁移；回滚代码不会破坏存档。

## 14. 开放问题

1. 图标最终视觉是否就用“蓝底白 S”，还是后续再设计。
2. M2 是否执行，取决于 M1 跑起来后对 exe 名称的在意程度。
3. 将来发布时是否愿意公开源码并改用 `PCL SPCL修改版` 名称。
4. 是否需要给朋友分发 zip，还是只在本人机器使用。
5. 是否需要在 M1 就替换首页的 PCL 内容源（当前默认不替换）。

## 15. 后续（不在本规格内）

- 微软正版登录：注册 Azure 应用，填 `OAuthClientId`。
- CurseForge 搜索：申请 API Key，填 `CurseForgeAPIKey`。
- 自建更新通道：替换 `ModSecret.vb` 中的更新桩。
- 首页/启动画面定制：进入路线 C。
- 公开仓库与合规改名：M3。
