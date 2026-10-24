# SPCL

SPCL 是一个基于 Plain Craft Launcher 2.14.0.0 源码改编的 Minecraft Java 版启动器，当前版本 **1.0**。

> 本项目是第三方个人改编版，非 PCL 官方作品，与 PCL 官方及其开发者无隶属关系。

## 功能

- 启动、下载与管理 Minecraft Java 版版本
- 内置 BMCLAPI 等镜像源，支持 Forge、Fabric、NeoForge、OptiFine、LiteLoader 等加载器
- 实例管理、Mod 与整合包管理、资源下载与 Modrinth 搜索
- 离线登录、第三方皮肤站（authlib-injector）登录
- 崩溃分析与日志导出
- 单文件 exe，内嵌全部依赖，免安装

当前版本**不包含**：微软正版登录、CurseForge API 调用、自动更新。

## 下载

前往 [Releases](https://github.com/Super-Sunt/SPCL/releases) 下载最新的 `SPCL-1.0-win64.zip`，解压后直接运行 `SPCL.exe`。

## 运行要求

- Windows 10 / 11（x64）
- .NET Framework 4.8（Windows 10 1809+ 与 Windows 11 默认包含）
- 至少一个可用的 Java 运行时（启动器也会自动检测或下载）

建议单独放在一个目录，不要覆盖其它启动器的安装目录。

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

## 许可

本项目继续使用 PCL 的分发有限许可，详见 [LICENCE](LICENCE)。

如果要基于本项目公开发布，请遵守同一许可：使用以 `Plain Craft Launcher (PCL)` 开头的名称、保留原作者署名与赞助链接、公开源代码，并保留正版购买与赞助提示。