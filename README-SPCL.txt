SPCL 1.0（基于 PCL 2.14.0.0 改编）

本软件改编自 Plain Craft Launcher（PCL）2.14.0.0 源码，非 PCL 官方作品。

当前版本：
- 版本号：SPCL 1.0（改编自 PCL 2.14.0.0）
- 仅改动身份层：名称、图标、关于页、路径隔离、启动提示
- 保留 PCL 的启动、下载、实例、Mod、离线/第三方登录等功能
- 支持微软正版登录（设备代码流，需要自备 Azure 应用 Client ID）
- 不包含 CurseForge API 调用、自动更新

使用要求：
- Windows 10/11，.NET Framework 4.8
- 请单独放在一个目录，不要覆盖官方 PCL
- 首次启动会在 exe 同级创建 PCL 数据目录
- 如果你之前用官方 PCL 设置过离线皮肤，可把 %APPDATA%\PCL\CustomSkin.png 复制到 %APPDATA%\SPCL\
- 微软正版登录：本发布包**不内置 Client ID**，每位使用者都需要自行注册一个 Azure 应用（免费），
  再把应用程序(客户端) ID 填到 设置 → 启动 → 高级选项 → 微软登录 Client ID，或设置环境变量 PCL_MS_CLIENT_ID
  （应用需选“仅个人 Microsoft 帐户”，并允许公共客户端流）

项目与下载：
- https://github.com/Super-Sunt/SPCL

授权：
- 本软件继续使用 PCL 的分发有限许可，详见 LICENCE
- 如果要公开发布，必须改名为 PCL 开头的第三方修改版（例如 PCL SPCL修改版），并保留署名与赞助链接