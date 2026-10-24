# SPCL

SPCL 是一个基于 Plain Craft Launcher 2.14.0.0 源码改编的 Minecraft Java 版启动器，当前版本 **1.1**。

> 本项目是第三方个人改编版，非 PCL 官方作品，与 PCL 官方及其开发者无隶属关系。

## 功能

- 启动、下载与管理 Minecraft Java 版版本
- 内置 BMCLAPI 等镜像源，支持 Forge、Fabric、NeoForge、OptiFine、LiteLoader 等加载器
- 实例管理、Mod 与整合包管理、资源下载与 Modrinth 搜索
- 离线登录、第三方皮肤站（authlib-injector）登录
- 微软正版登录（功能保留，但受微软应用审核限制，**当前无法登录成功**，详见下文）
- 崩溃分析与日志导出
- 单文件 exe，内嵌全部依赖，免安装

当前版本**不包含**：CurseForge API 调用、自动更新。

## 下载

前往 [Releases](https://github.com/Super-Sunt/SPCL/releases) 下载最新的 `SPCL-1.1-win64.zip`，解压后直接运行 `SPCL.exe`。

## 运行要求

- Windows 10 / 11（x64）
- .NET Framework 4.8（Windows 10 1809+ 与 Windows 11 默认包含）
- 至少一个可用的 Java 运行时（启动器也会自动检测或下载）

建议单独放在一个目录，不要覆盖其它启动器的安装目录。

## 微软正版登录

> **当前状态：功能已实现，但无法登录成功。** 微软要求调用 Minecraft 服务的 Azure 应用**单独申请授权**。新建的应用即使配置完全正确，登录也会在第 4 步（`api.minecraftservices.com/authentication/login_with_xbox`）返回：
>
> ```json
> { "path": "/authentication/login_with_xbox",
>   "errorMessage": "Invalid app registration, see https://aka.ms/AppRegInfo for more information" }
> ```
>
> 申请入口是 [aka.ms/mce-reviewappid](https://aka.ms/mce-reviewappid)（Microsoft Forms 问卷）；个人/爱好者项目通常会被引导去参加 Xbox 开发者计划（ID@Xbox），是否放行由微软决定，社区中有大量提交后长期没有回音的情况。
>
> 因此本版本**保留该功能但不再做扩展**。日常游玩请使用离线登录或第三方皮肤站登录，两者不受影响。下面保留完整的配置说明，供将来应用获批后使用。

正版登录使用微软官方的设备代码流（device code flow）：启动器申请设备代码 → 你在浏览器输入并登录 → 启动器轮询拿到令牌 → 依次通过 Xbox Live、XSTS、Minecraft Services 完成验证。整条链路已经内置，但需要一个**你自己的 Azure 应用**提供 Client ID（PCL 官方版自带，本改编版不含）。

> **本项目不提供共享的 Client ID。** 每位使用者都需要自己注册应用；而且**新建的 Azure 应用默认没有 Minecraft API 权限**，必须再向微软提交审核表单（[aka.ms/mce-reviewappid](https://aka.ms/mce-reviewappid)）并通过，才能完成正版登录 —— 否则第 4 步会返回 `403 Invalid app registration`。应用注册免费、微软也不按登录次数收费，但审核只对符合条件的应用放行，所以作者的构建里不会内置 Client ID。

注册 Azure 应用（免费，约两分钟）：

1. 打开 [Azure 门户](https://portal.azure.com) → **Microsoft Entra ID** → **应用注册** → **新注册**
2. 名称随意（如 `SPCL`）；受支持的帐户类型选 **仅个人 Microsoft 帐户**
3. 注册完成后复制 **应用程序(客户端) ID**
4. 进入该应用的 **身份验证 / Authentication** 页 → **添加平台** → **移动和桌面应用程序**（勾选 `https://login.microsoftonline.com/common/oauth2/nativeclient`），并把 **允许公共客户端流** 设为 **是** → 保存
5. **（必需）申请 Minecraft API 权限**：打开 [aka.ms/mce-reviewappid](https://aka.ms/mce-reviewappid)，按表单要求填写你的客户端 ID 并提交，等待微软审核放行

然后在启动器里填写 Client ID（任选其一）：

- 设置 → 启动 → 高级选项 → **微软登录 Client ID**
- 环境变量 `PCL_MS_CLIENT_ID`

之后在主页切到「正版」并登录，按弹窗提示在浏览器输入设备代码即可。设备代码流**不需要客户端密码**。

> 审核通过前，登录会在第 4 步（`login_with_xbox`）失败，启动器会提示「需要申请应用授权」并给出申请表单；等待期间可以用离线登录或第三方皮肤站登录。
> 登录的微软账号必须已购买 Minecraft，启动器会检查游戏所有权。

## 构建

需要 Visual Studio 2022（含 .NET 桌面开发工作负载）和 .NET Framework 4.8 目标包。

```powershell
git clone https://github.com/Super-Sunt/SPCL.git
cd SPCL
dotnet restore PCLCS\PCLCS.csproj
pwsh -File tools\build-spcl.ps1
```

产物：`Plain Craft Launcher 2\bin\SPCL.exe`。

`tools/build-spcl.ps1` 会自动处理这些细节：

- C# 依赖项目使用 C# 12 编译（兼容 VS 17.11 的 Roslyn）
- 主 VB 工程不接收 `LangVersion` 覆盖，避免被当成 VB 12.0
- 构建完成后把 exe 的完整性级别设为 Medium，保证双击可运行

## 项目结构

```
Plain Craft Launcher 2/   VB.NET + WPF 主工程（.NET Framework 4.8）
PCLCS/                    C# 启动、Java 检测与版本工具库
MeloongCore/              内置通用库（Shared netstandard2.0 + Wpf net48，Apache-2.0）
tools/                    构建脚本与图标生成脚本
docs/                     设计与实施文档
```

## 第三方组件

- MeloongCore（Apache-2.0）：位于 `MeloongCore/`，许可证见 `MeloongCore/LICENSE.txt`

## 版本历史

- **1.1**：正版登录补充准确的应用审核提示（`Invalid app registration`），README 写明正版登录当前不可用的原因；复核离线与第三方皮肤站登录正常；其余功能与 1.0 相同
- **1.0**：首个版本，基于 PCL 2.14.0.0 的身份层改造（名称、图标、关于页、路径隔离），保留启动、下载、实例、Mod、离线与第三方登录

## 许可

本项目继续使用 PCL 的分发有限许可，详见 [LICENCE](LICENCE)。

如果要基于本项目公开发布，请遵守同一许可：使用以 `Plain Craft Launcher (PCL)` 开头的名称、保留原作者署名与赞助链接、公开源代码，并保留正版购买与赞助提示。