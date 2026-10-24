SPCL（基于 PCL 2.14.0.0 的个人修改版）

本软件基于 Plain Craft Launcher（PCL）2.14.0.0 源码修改，非 PCL 官方作品。
原项目：https://github.com/Meloong-Git/PCL

当前版本：
- 仅改动身份层：名称、图标、关于页、路径隔离、启动提示
- 保留 PCL 的启动、下载、实例、Mod、离线/第三方登录等功能
- 不包含微软正版登录、CurseForge API 调用、自动更新

使用要求：
- Windows 10/11，.NET Framework 4.8
- 请单独放在一个目录，不要覆盖官方 PCL
- 首次启动会在 exe 同级创建 PCL 数据目录
- 如果你之前用官方 PCL 设置过离线皮肤，可把 %APPDATA%\PCL\CustomSkin.png 复制到 %APPDATA%\SPCL\

授权：
- 本软件继续使用 PCL 的分发有限许可，详见 LICENCE
- 如果要公开发布，必须改名为 PCL 开头的第三方修改版，并保留署名与赞助链接