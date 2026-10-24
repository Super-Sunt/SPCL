# SPCL 身份层改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 PCL 2.14 源码上产出一个可运行、显示身份为 SPCL 的 Windows 单 exe 启动器，保留启动、下载、实例、Mod、离线/第三方登录等原有功能。

**Architecture:** 不改启动引擎，只在 VB.NET/WPF 主工程上做身份层替换。M0 先原样构建验证环境；M1 改标题、图标、关于页、路径隔离和启动清理；M2 可选地把程序集/exe 改名为 SPCL。

**Tech Stack:** VB.NET、WPF、.NET Framework 4.8、C#（PCLCS）、MSBuild、Python + Pillow（生成图标）、PowerShell。

---

## 执行约定

- 所有命令默认在 `E:\project\MC` 下执行。
- 主工程构建产物：`Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe`。
- 这个工程没有单元测试框架，且改动集中在 WPF 资源和启动路径。**不要为身份层改动硬造单元测试**；每个任务用“构建 + 静态 grep + 实际启动冒烟”验证。
- 当前 DSH 会话的沙箱中 NuGet TLS 会失败（`SEC_E_NO_CREDENTIALS`）。M0 的还原/构建需在正常桌面网络下执行，或把该命令提升到 `danger-full-access` 后重试；这是环境问题，不要靠改源码绕过。
- 本机 VS 17.11.5 的 Roslyn 4.11 不支持 `LangVersion 13.0`（会报 `CS1617`）。下面的构建命令统一加了 `/p:LangVersion=12.0` 覆盖；如果升级到 VS 17.12+，可以去掉这个参数。若加了这个参数仍报 C# 语法错误，说明依赖用到了 C# 13 语法，此时升级 VS，不要改依赖源码。
- 每个任务结束都提交一次；M2 单独提交，便于回滚。
- 每次运行新构建前先退出已在运行的 SPCL/PCL 实例，否则单实例逻辑会聚焦旧窗口，看不到新标题/图标。
- 提交信息使用 `feat:` / `chore:` 前缀。

---

### Task 0: 建立版本控制基线

**Files:**
- Modify: `.gitignore`（仅在需要忽略分析产物时）
- Create: `.git/`（仓库元数据）

- [ ] **Step 0.1: 清理分析过程产生的临时文件**

```powershell
Set-Location E:\project\MC
Remove-Item -Force build-debug.log, restore-diag.log, restore-diag2.log -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .dotnet-home, .nuget-packages -ErrorAction SilentlyContinue
```

Expected: 无输出，`Get-ChildItem` 中不再出现这些文件/目录。

- [ ] **Step 0.2: 初始化仓库并暂存全部源码**

```powershell
git init
git add .gitmodules
git add .
git status --short | Select-Object -First 20
```

Expected: 大量 `A` 开头的文件；`MeloongCore` 作为子模块出现，而不是几百个文件。

- [ ] **Step 0.3: 确认 MeloongCore 以子模块形式暂存**

```powershell
git ls-files -s MeloongCore
```

Expected: 输出以 `160000` 开头，提交为 `98157d65c7627721c816c02e8be96ac4fe61d615`，例如：

```
160000 98157d65c7627721c816c02e8be96ac4fe61d615 0	MeloongCore
```

如果输出不是 `160000`，执行：

```powershell
git rm -r --cached MeloongCore
git add MeloongCore
git ls-files -s MeloongCore
```

- [ ] **Step 0.4: 提交基线**

```powershell
git commit -m "chore: baseline PCL 2.14 source and SPCL design spec"
git log --oneline -1
```

Expected: 生成一个 commit，工作区干净（`git status --short` 无输出）。

- [ ] **Step 0.5: 记录基线提交号**

```powershell
git rev-parse HEAD
```

把输出记在本文档末尾的“执行记录”里；后续任何回滚都以它或各任务 commit 为准。

---

### Task 1: M0 原样构建并跑通

**Files:**
- No source changes.

- [ ] **Step 1.1: 还原 NuGet**

```powershell
Set-Location E:\project\MC
dotnet restore PCLCS\PCLCS.csproj
```

Expected: 退出码 0，末尾出现“已成功还原”或 `Restored`。

如果报 `NU1301` / TLS / 证书错误：不要在源码里改包引用；换到正常桌面网络，或提升沙箱权限后重试本命令。

- [ ] **Step 1.2: 构建 Release**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
Write-Host "MSBuild: $msbuild"
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
```

Expected: 退出码 0，末尾出现“生成成功”/`Build succeeded`，并生成 exe。

- [ ] **Step 1.3: 确认产物存在**

```powershell
Get-Item "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe" | Select-Object FullName, Length, LastWriteTime
```

Expected: 文件存在，大小约 5–8 MB（PCL 会把依赖 DLL 内嵌进 exe）。

- [ ] **Step 1.4: 启动冒烟**

手动执行：

1. 双击 `Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe`。
2. 选择“离线登录”，输入任意用户名。
3. 选择一个已安装的 Minecraft 版本，点击启动。
4. 确认游戏窗口出现，且启动器日志没有致命错误。

如果机器上没有已安装版本，先用启动器下载一个原版（如 1.20.1），再执行第 3 步。

Expected: 启动器不崩溃，游戏能进入主菜单。

- [ ] **Step 1.5: 打基线标签**

```powershell
git tag m0-baseline
git tag --list "m0-*"
```

Expected: 输出 `m0-baseline`。

---

### Task 2: 改产品名、窗口标题、单实例与版本文案

**Files:**
- Modify: `Plain Craft Launcher 2\My Project\AssemblyInfo.vb`
- Modify: `Plain Craft Launcher 2\FormMain.xaml`
- Modify: `Plain Craft Launcher 2\Application.xaml.vb`
- Modify: `Plain Craft Launcher 2\Modules\Base\ModBase.vb`
- Modify: `Plain Craft Launcher 2\Modules\Minecraft\ModLaunch.vb`
- Modify: `Plain Craft Launcher 2\Modules\Minecraft\ModModpack.vb`

- [ ] **Step 2.1: 修改程序集元数据**

`Plain Craft Launcher 2\My Project\AssemblyInfo.vb`，把：

```vb
<Assembly: AssemblyTitle("Plain Craft Launcher 启动器")>
<Assembly: AssemblyDescription("Minecraft 启动器")>
<Assembly: AssemblyCompany("")>
<Assembly: AssemblyProduct("Plain Craft Launcher")>
<Assembly: AssemblyCopyright("Copyright © 成都瓜皮龙科技有限公司")>
<Assembly: AssemblyConfiguration("PCL2 Config Mark")>
```

改为：

```vb
<Assembly: AssemblyTitle("SPCL 启动器")>
<Assembly: AssemblyDescription("Minecraft 启动器（基于 PCL 的第三方个人修改版）")>
<Assembly: AssemblyCompany("")>
<Assembly: AssemblyProduct("SPCL")>
<Assembly: AssemblyCopyright("Copyright © 成都瓜皮龙科技有限公司；SPCL 修改版")>
<Assembly: AssemblyConfiguration("PCL2 Config Mark")>
```

`AssemblyConfiguration` 保持 `PCL2 Config Mark` 不动，避免影响更新/识别逻辑。

- [ ] **Step 2.2: 修改窗口标题**

`Plain Craft Launcher 2\FormMain.xaml`，把：

```xml
Title="Plain Craft Launcher　"
```

改为：

```xml
Title="SPCL　"
```

注意 `　` 是全角空格，必须保留。

- [ ] **Step 2.3: 修改单实例互斥体与窗口查找**

`Plain Craft Launcher 2\Application.xaml.vb`，把：

```vb
PclMutex = New Mutex(True, "PCL_SingletonMutex", MutexCreatedNew)
```

改为：

```vb
PclMutex = New Mutex(True, "SPCL_SingletonMutex", MutexCreatedNew)
```

把：

```vb
Logger.Warn("已有一个 PCL 实例正在运行")
```

改为：

```vb
Logger.Warn("已有一个 SPCL 实例正在运行")
```

把：

```vb
Dim WindowHwnd As IntPtr = FindWindow(Nothing, "Plain Craft Launcher　")
If WindowHwnd = IntPtr.Zero Then WindowHwnd = FindWindow(Nothing, "Plain Craft Launcher 2　")
```

改为：

```vb
Dim WindowHwnd As IntPtr = FindWindow(Nothing, "SPCL　")
```

不要保留旧 PCL 标题的回退查找，否则 SPCL 会误聚焦官方 PCL 的窗口。

- [ ] **Step 2.4: 修改版本显示**

`Plain Craft Launcher 2\Modules\Base\ModBase.vb`，把：

```vb
Public Const VersionDisplay As String = BuildTypeDisplay & " " & VersionBaseName
```

改为：

```vb
Public Const VersionDisplay As String = "SPCL " & BuildTypeDisplay & " " & VersionBaseName
```

- [ ] **Step 2.5: 修改启动日志文案**

`Plain Craft Launcher 2\Modules\Minecraft\ModLaunch.vb`，把：

```vb
McLaunchLog("PCL 版本：" & VersionDisplay & " (" & VersionCode & ")")
```

改为：

```vb
McLaunchLog("SPCL 版本：" & VersionDisplay & " (" & VersionCode & ")")
```

- [ ] **Step 2.6: 让整合包识别 SPCL**

`Plain Craft Launcher 2\Modules\Minecraft\ModModpack.vb`，把：

```vb
If Info.ProductName = "Plain Craft Launcher" Then
```

改为：

```vb
If Info.ProductName = "Plain Craft Launcher" OrElse Info.ProductName = "SPCL" Then
```

这样整合包里附带的 SPCL.exe 仍会被当作启动器识别。

- [ ] **Step 2.7: 构建**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
```

Expected: 构建成功，无新增错误。

- [ ] **Step 2.8: 验证文件属性**

```powershell
$exe = "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"
(Get-Item $exe).VersionInfo | Select-Object ProductName, FileDescription, FileVersion
```

Expected:

```
ProductName       : SPCL
FileDescription   : Minecraft 启动器（基于 PCL 的第三方个人修改版）
FileVersion       : 2.14.0.0
```

- [ ] **Step 2.9: 验证窗口标题与单实例**

启动 exe，等待主窗口出现：

```powershell
$p = Start-Process "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe" -PassThru
Start-Sleep -Seconds 10
Get-Process -Id $p.Id | Select-Object ProcessName, MainWindowTitle
```

Expected: `MainWindowTitle` 为 `SPCL　`（末尾是全角空格，显示上可能看不明显）。

再启动第二个实例：

```powershell
Start-Process "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"
Start-Sleep -Seconds 3
(Get-Process -Name "Plain Craft Launcher 2").Count
```

Expected: 输出 `1`，第二个实例聚焦第一个窗口后退出，且没有和官方 PCL 抢互斥体。

- [ ] **Step 2.10: 提交**

```powershell
git add "Plain Craft Launcher 2\My Project\AssemblyInfo.vb" `
        "Plain Craft Launcher 2\FormMain.xaml" `
        "Plain Craft Launcher 2\Application.xaml.vb" `
        "Plain Craft Launcher 2\Modules\Base\ModBase.vb" `
        "Plain Craft Launcher 2\Modules\Minecraft\ModLaunch.vb" `
        "Plain Craft Launcher 2\Modules\Minecraft\ModModpack.vb"
git commit -m "feat: rebrand launcher identity to SPCL"
```

---

### Task 3: 生成并替换 SPCL 图标/Logo

**Files:**
- Create: `tools\make_spcl_icon.py`
- Modify: `Plain Craft Launcher 2\Images\icon.ico`（二进制替换）
- Modify: `Plain Craft Launcher 2\Images\Heads\Logo.png`（二进制替换）

- [ ] **Step 3.1: 写图标生成脚本**

创建 `tools\make_spcl_icon.py`：

```python
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "Plain Craft Launcher 2" / "Images"
SIZE = 1024


def load_font(size: int):
    for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
        path = Path("C:/Windows/Fonts") / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 蓝色纵向渐变，色相保持在蓝色区间
for y in range(SIZE):
    t = y / (SIZE - 1)
    draw.line(
        [(0, y), (SIZE, y)],
        fill=(
            round(19 + (72 - 19) * t),
            round(112 + (144 - 112) * t),
            round(243 + (245 - 243) * t),
            255,
        ),
    )

# 圆角遮罩
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=220, fill=255)
img.putalpha(mask)

# 白色 S
draw = ImageDraw.Draw(img)
font = load_font(620)
text = "S"
bbox = draw.textbbox((0, 0), text, font=font)
x = (SIZE - (bbox[2] - bbox[0])) / 2 - bbox[0]
y = (SIZE - (bbox[3] - bbox[1])) / 2 - bbox[1]
draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))

(IMAGES / "Heads").mkdir(parents=True, exist_ok=True)
img.resize((256, 256), Image.LANCZOS).save(IMAGES / "Heads" / "Logo.png")
img.save(
    IMAGES / "icon.ico",
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
print("wrote", IMAGES / "icon.ico")
print("wrote", IMAGES / "Heads" / "Logo.png")
```

- [ ] **Step 3.2: 运行脚本**

```powershell
$py = "C:\Users\惠普电脑\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
& $py tools\make_spcl_icon.py
```

Expected: 输出两行 `wrote ...`。

如果本机没有这个 Python 路径，用任意装有 Pillow 的 Python：

```powershell
python tools\make_spcl_icon.py
```

- [ ] **Step 3.3: 验证 ICO 尺寸**

```powershell
& $py -c "from PIL import Image; im=Image.open(r'Plain Craft Launcher 2\Images\icon.ico'); print(sorted(im.info['sizes']))"
```

Expected:

```
[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
```

- [ ] **Step 3.4: 构建并目视验证**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
Start-Process "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"
```

Expected: 窗口左上角、任务栏、启动画面均为蓝色 S 图标；高分屏下不模糊。

- [ ] **Step 3.5: 提交**

```powershell
git add tools\make_spcl_icon.py "Plain Craft Launcher 2\Images\icon.ico" "Plain Craft Launcher 2\Images\Heads\Logo.png"
git commit -m "feat: add SPCL icon and logo"
```

---

### Task 4: 关于页与更新按钮

**Files:**
- Modify: `Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml`
- Modify: `Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml.vb`

- [ ] **Step 4.1: 调整关于卡片，加入 SPCL 行**

`Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml`，把第 10–43 行的 `<Grid Margin="21,40,21,16"> ... </Grid>` 整块替换为：

```xml
                <Grid Margin="21,40,21,16">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="45" />
                        <RowDefinition Height="45" />
                        <RowDefinition Height="45" />
                        <RowDefinition Height="45" />
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="40" />
                        <ColumnDefinition />
                        <ColumnDefinition Width="150" />
                    </Grid.ColumnDefinitions>
                    <local:MyListItem IsHitTestVisible="False" Title="龙腾猫跃" Margin="-5,0,15,0" Info="Plain Craft Launcher 的开发者！" Grid.Row="0" Grid.Column="1" />
                    <local:MyListItem IsHitTestVisible="False" Title="SPCL" Margin="-5,0,15,0" Info="基于 Plain Craft Launcher 的第三方个人修改版" Grid.Row="1" Grid.Column="1" />
                    <local:MyListItem IsHitTestVisible="False" Title="HerobrineXia" Margin="-5,0,15,0" Info="Plain Craft Launcher 的协力开发者！" Grid.Row="2" Grid.Column="1" />
                    <local:MyListItem IsHitTestVisible="False" Title="SPCL 版本" Margin="-5,0,15,0" Info="当前版本：%VERSION%（%VERSIONCODE%.%BRANCH%）" Grid.Row="3" Grid.Column="1" x:Name="ItemAboutPcl" />
                    <Image Source="/Plain Craft Launcher 2;component/Images/Heads/LTCat.jpg" Grid.Row="0" Margin="3">
                        <Image.Clip>
                            <EllipseGeometry Center="17 17" RadiusX="17" RadiusY="17" />
                        </Image.Clip>
                    </Image>
                    <Image Source="/Plain Craft Launcher 2;component/Images/Heads/Logo.png" Grid.Row="1" Margin="3">
                        <Image.Clip>
                            <EllipseGeometry Center="17 17" RadiusX="17" RadiusY="17" />
                        </Image.Clip>
                    </Image>
                    <Image Source="/Plain Craft Launcher 2;component/Images/Heads/HerobrineXia.png" Grid.Row="2" Margin="3">
                        <Image.Clip>
                            <EllipseGeometry Center="17 17" RadiusX="17" RadiusY="17" />
                        </Image.Clip>
                    </Image>
                    <Image Source="/Plain Craft Launcher 2;component/Images/Heads/Logo.png" Grid.Row="3" Margin="3">
                        <Image.Clip>
                            <EllipseGeometry Center="17 17" RadiusX="17" RadiusY="17" />
                        </Image.Clip>
                    </Image>
                    <local:MyButton Text="赞助 PCL !" Grid.Column="2" Grid.Row="0" Height="35" ColorType="Highlight"
                                    local:CustomEventService.EventType="打开网页" local:CustomEventService.EventData="https://meloong.com/afd/a/LTCat" />
                    <local:MyButton Text="原项目" Grid.Column="2" Grid.Row="1" Height="35"
                                    local:CustomEventService.EventType="打开网页" local:CustomEventService.EventData="https://github.com/Meloong-Git/PCL" />
                    <local:MyButton Text="检查更新" Grid.Column="2" Grid.Row="3" Height="35"
                                    x:Name="BtnAboutUpdate" />
                </Grid>
```

要点：龙腾猫跃仍是第 0 行（关于页第一位），SPCL 行紧随其后，HerobrineXia 与版本行下移。

- [ ] **Step 4.2: 增加“关于 SPCL”说明卡片**

在同一文件中，把：

```xml
            </local:MyCard>
            <local:MyCard Margin="0,0,0,15" Title="特别鸣谢">
```

替换为：

```xml
            </local:MyCard>
            <local:MyCard Margin="0,0,0,15" Title="关于 SPCL">
                <StackPanel Margin="25,40,19,20">
                    <TextBlock TextWrapping="Wrap" LineHeight="22"
                               Text="SPCL 是基于 Plain Craft Launcher 的第三方个人修改版，非 PCL 官方作品。本版本不包含微软正版登录、CurseForge API 调用与自动更新。原项目：https://github.com/Meloong-Git/PCL" />
                </StackPanel>
            </local:MyCard>
            <local:MyCard Margin="0,0,0,15" Title="特别鸣谢">
```

- [ ] **Step 4.3: 修改“检查更新”按钮行为**

`Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml.vb`，把：

```vb
    Private Sub BtnAboutUpdate_Click(sender As Object, e As MouseButtonEventArgs) Handles BtnAboutUpdate.Click
        UpdateCheckByButton()
    End Sub
```

改为：

```vb
    Private Sub BtnAboutUpdate_Click(sender As Object, e As MouseButtonEventArgs) Handles BtnAboutUpdate.Click
        Hint("个人修改版暂不提供自动更新。", HintType.Blue)
    End Sub
```

- [ ] **Step 4.4: 构建并验证关于页**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
Start-Process "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"
```

打开“设置 → 关于”，确认：

- 龙腾猫跃仍在第一位，赞助按钮可用。
- 第二行是 SPCL，第三行是 HerobrineXia，第四行是 SPCL 版本。
- 下方出现“关于 SPCL”说明卡片，包含原项目链接。
- 点击“检查更新”弹出“个人修改版暂不提供自动更新”。

- [ ] **Step 4.5: 静态确认署名顺序**

```powershell
Select-String -Path "Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml" -Pattern 'Title="龙腾猫跃"|Title="SPCL"|Title="HerobrineXia"|Title="SPCL 版本"' | ForEach-Object { "L$($_.LineNumber): $($_.Line.Trim())" }
```

Expected: `龙腾猫跃` 的行号最小，`SPCL` 紧随其后。

- [ ] **Step 4.6: 提交**

```powershell
git add "Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml" "Plain Craft Launcher 2\Pages\PageOther\PageOtherAbout.xaml.vb"
git commit -m "feat: add SPCL about page and update notice"
```

---

### Task 5: 路径隔离与启动清理

**Files:**
- Modify: `Plain Craft Launcher 2\Modules\Base\ModBase.vb`
- Modify: `Plain Craft Launcher 2\Application.xaml.vb`
- Modify: `Plain Craft Launcher 2\FormMain.xaml.vb`

- [ ] **Step 5.1: 临时目录改为 SPCL**

`Plain Craft Launcher 2\Modules\Base\ModBase.vb`，把：

```vb
Public PathTemp As String = PathUtils.AddSlashSuffix(If(Settings.Get(Of String)("SystemSystemCache") = "", Path.GetTempPath() & "PCL\", Settings.Get(Of String)("SystemSystemCache")).Replace("/", "\"))
```

改为：

```vb
Public PathTemp As String = PathUtils.AddSlashSuffix(If(Settings.Get(Of String)("SystemSystemCache") = "", Path.GetTempPath() & "SPCL\", Settings.Get(Of String)("SystemSystemCache")).Replace("/", "\"))
```

- [ ] **Step 5.2: 隔离 AppData 目录，同时保留日志位置**

`Plain Craft Launcher 2\Application.xaml.vb`，把：

```vb
MeloongCore.Main.Init("PCL")
```

改为：

```vb
MeloongCore.Main.Init("SPCL")
```

把：

```vb
Logger.Instance = New PclLogger With {.logFolder = Paths.BaseThenName, .MinLevel = If(ModeDebug, LogLevel.Trace, LogLevel.Info)}
```

改为：

```vb
Logger.Instance = New PclLogger With {.logFolder = Paths.Base & "PCL\", .MinLevel = If(ModeDebug, LogLevel.Trace, LogLevel.Info)}
```

说明：`Main.Init("SPCL")` 会把 `%APPDATA%\PCL\` 切到 `%APPDATA%\SPCL\`（CustomSkin、EasyTier 等）；日志仍写进 exe 同级 `PCL\`，避免多出一个 `SPCL\` 日志目录。

- [ ] **Step 5.3: 删除启动时的开源版限制弹窗**

`Plain Craft Launcher 2\FormMain.xaml.vb`，把：

```vb
            '开源版本提示
            If VersionBranchMain = "OpenSource" Then
                MyMsgBox($"该版本中无法使用以下特性：{vbCrLf}- CurseForge API 调用：需要自行申请 API Key，然后添加到 ModSecret.vb 的开头{vbCrLf}- 正版登录：需要自行向微软申请 Client ID，然后添加到 ModSecret.vb 的开头{vbCrLf}- 更新与联网通知：避免滥用隐患{vbCrLf}- 主题切换：这是需要赞助解锁的纪念性质的功能，别让赞助者太伤心啦……{vbCrLf}- 百宝箱：开发早期往里面塞了些开发工具，整理起来太麻烦了……", "开源版本说明")
            End If
```

改为：

```vb
            'SPCL：开源版限制说明已移至关于页
```

- [ ] **Step 5.4: 构建并验证**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
```

先静态确认 `PathTemp` 已改：

```powershell
Select-String -Path "Plain Craft Launcher 2\Modules\Base\ModBase.vb" -Pattern 'Path.GetTempPath\(\) & "SPCL\\"'
```

Expected: 命中一行，包含 `Path.GetTempPath() & "SPCL\"`。

再启动并做一次会用到临时目录的操作（例如打开下载页开始一个下载/安装）：

```powershell
Remove-Item -Recurse -Force "$env:TEMP\SPCL" -ErrorAction SilentlyContinue
Start-Process "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"
```

下载开始后检查：

```powershell
Test-Path "$env:TEMP\SPCL"
```

Expected: `True`。只启动而不触发下载时，该目录可能尚未创建，这是正常的；不要把它当成失败。同时确认启动时不再出现“开源版本说明”弹窗。

检查日志仍在 `PCL\`：

```powershell
Get-ChildItem "Plain Craft Launcher 2\bin\PCL" -Filter "Log*.txt" -ErrorAction SilentlyContinue | Select-Object Name, Length
```

Expected: 出现 `Log1.txt` 等启动器日志（MeloongCore 的 `FileLogger` 默认前缀是 `Log`），且不是写在 `bin\SPCL\`。

- [ ] **Step 5.5: 提交**

```powershell
git add "Plain Craft Launcher 2\Modules\Base\ModBase.vb" "Plain Craft Launcher 2\Application.xaml.vb" "Plain Craft Launcher 2\FormMain.xaml.vb"
git commit -m "chore: isolate SPCL paths and remove open-source startup notice"
```

---

### Task 6: M1 验收与打包

**Files:**
- Create: `README-SPCL.txt`（提交到仓库，再复制进分发目录）
- Create: `dist\SPCL\README.txt`（从 `README-SPCL.txt` 复制）
- Create: `dist\SPCL\LICENCE`（复制根目录文件）
- Create: `dist\SPCL-2.14.0.0-win64.zip`

- [ ] **Step 6.1: 干净构建 Release**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /t:Rebuild /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
```

Expected: 构建成功，无错误。

- [ ] **Step 6.2: 准备分发目录**

先把本地打包产物排除出版本控制：

```powershell
Add-Content .gitignore "`n# SPCL local distribution`ndist/"
git add .gitignore
```

然后：

```powershell
New-Item -ItemType Directory -Force dist\SPCL | Out-Null
Copy-Item "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe" "dist\SPCL\Plain Craft Launcher 2.exe" -Force
Copy-Item "LICENCE" "dist\SPCL\LICENCE" -Force
```

- [ ] **Step 6.3: 写 README**

创建 `README-SPCL.txt`（放在仓库根目录，便于提交；打包时再复制进 `dist\SPCL\README.txt`）：

```text
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
- 如果你之前用官方 PCL 设置过离线皮肤，可把 `%APPDATA%\PCL\CustomSkin.png` 复制到 `%APPDATA%\SPCL\`

授权：
- 本软件继续使用 PCL 的分发有限许可，详见 LICENCE
- 如果要公开发布，必须改名为 PCL 开头的第三方修改版，并保留署名与赞助链接
```

复制进分发目录：

```powershell
Copy-Item "README-SPCL.txt" "dist\SPCL\README.txt" -Force
```

- [ ] **Step 6.4: 打包**

```powershell
Compress-Archive -Path "dist\SPCL\*" -DestinationPath "dist\SPCL-2.14.0.0-win64.zip" -Force
Get-ChildItem dist\SPCL | Select-Object Name, Length
Get-Item dist\SPCL-2.14.0.0-win64.zip | Select-Object FullName, Length
```

Expected: zip 内包含 `Plain Craft Launcher 2.exe`、`LICENCE`、`README.txt`。

- [ ] **Step 6.5: 跑完整验收清单**

逐项确认：

- [ ] Release exe 能启动，无崩溃。
- [ ] 离线登录成功，能启动一个已安装版本。
- [ ] 窗口标题、任务栏、图标均为 SPCL。
- [ ] 关于页龙腾猫跃在第一位，赞助按钮可用；SPCL 行在其后。
- [ ] 启动无“开源版本说明”弹窗，无“快照版”提示。
- [ ] `%TEMP%\SPCL\` 生效，`%TEMP%\PCL\` 不被写入。
- [ ] 与官方 PCL 同时运行：不抢互斥体，不误聚焦官方窗口。
- [ ] 离线皮肤资源包能正常生成（Logo 替换后无异常）。
- [ ] 下载、Modrinth 搜索、实例管理冒烟通过。
- [ ] 默认主题仍为蓝色：`Select-String -Path "Plain Craft Launcher 2\Modules\ModSecret.vb" -Pattern 'ColorHue = 210|ColorSat = 85'` 两条都能匹配。
- [ ] 正版/赞助提示仍保留：`Select-String -Path "Plain Craft Launcher 2\Modules\Minecraft\ModLaunch.vb" -Pattern 'McLaunchPrecheck'` 能命中，且函数体没有被删除或弱化。
- [ ] 旧窗口标题已清除：`Select-String -Path "Plain Craft Launcher 2\FormMain.xaml","Plain Craft Launcher 2\Application.xaml.vb" -Pattern 'Plain Craft Launcher　'` 无输出。
- [ ] 互斥体与注册表隔离正确：`Select-String -Path "Plain Craft Launcher 2\Application.xaml.vb" -Pattern 'SPCL_SingletonMutex'` 命中；`Select-String -Path "Plain Craft Launcher 2\Modules\ModSecret.vb" -Pattern 'RegFolder As String = "PCLDebug"'` 命中。

- [ ] **Step 6.6: 提交并打标签**

```powershell
git add .gitignore README-SPCL.txt
git commit -m "chore: add SPCL M1 package readme"
git tag m1-spcl-identity
git log --oneline -3
```

---

### Task 7: M2（可选）改程序集名与 exe 名

**前置条件：** 只有你明确决定要 `SPCL.exe` 时才执行。否则跳过整个 Task 7，M1 已可交付。

**Files:**
- Modify: `Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj`
- Modify: 所有含 `Plain Craft Launcher 2;component` 的 `.vb` / `.xaml`
- Modify: `Plain Craft Launcher 2\Pages\PageInstance\PageInstanceExport.xaml.vb`
- Modify: `Plain Craft Launcher 2\FormMain.xaml.vb`

- [ ] **Step 7.1: 创建 M2 分支**

```powershell
git switch -c m2-rename-spcl
```

Expected: 切换到新分支。

- [ ] **Step 7.2: 修改程序集名**

`Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj`，把：

```xml
<AssemblyName>Plain Craft Launcher 2</AssemblyName>
```

改为：

```xml
<AssemblyName>SPCL</AssemblyName>
```

- [ ] **Step 7.3: 替换显式程序集引用**

创建并运行一次性脚本（不要提交这个脚本）：

```powershell
@'
from pathlib import Path

root = Path("Plain Craft Launcher 2")
replacements = {
    "Plain Craft Launcher 2;component": "SPCL;component",
    "assembly=Plain Craft Launcher 2": "assembly=SPCL",
}
counts = {old: 0 for old in replacements}
for p in root.rglob("*"):
    if p.suffix.lower() not in {".vb", ".xaml"}:
        continue
    with open(p, "r", encoding="utf-8-sig", newline="") as f:
        text = f.read()
    changed = False
    for old, new in replacements.items():
        if old in text:
            counts[old] += text.count(old)
            text = text.replace(old, new)
            changed = True
    if changed:
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(text)
print("component:", counts["Plain Craft Launcher 2;component"])
print("assembly:", counts["assembly=Plain Craft Launcher 2"])
'@ | Set-Content -Encoding utf8 tools\replace_pack_uri.py
$py = "C:\Users\惠普电脑\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe"
& $py tools\replace_pack_uri.py
Remove-Item tools\replace_pack_uri.py
```

Expected:

```
component: 16
assembly: 10
```

（M1 前是 15；M1 的关于页新增了 1 个 `PCL2.png` 引用，所以 M2 时是 16。）

脚本只写入确实发生替换的文件，并用 `newline=""` 保留源码的 LF 行尾，避免出现“全文件换行”噪声 diff。

相对 URI `pack://application:,,,/images/...` 不要动；它们会自动解析到新的入口程序集。

- [ ] **Step 7.4: 更新导出与清理路径**

`Plain Craft Launcher 2\Pages\PageInstance\PageInstanceExport.xaml.vb`，把：

```vb
If BuildType = BuildTypes.Release AndAlso IncludePCL Then FileUtils.Copy(PathExe, CacheFolder & "Plain Craft Launcher.exe")
```

改为：

```vb
If BuildType = BuildTypes.Release AndAlso IncludePCL Then FileUtils.Copy(PathExe, CacheFolder & "SPCL.exe")
```

`Plain Craft Launcher 2\FormMain.xaml.vb`，把：

```vb
FileUtils.Delete(Paths.Base & "PCL\Plain Craft Launcher 2.exe")
```

改为：

```vb
FileUtils.Delete(Paths.Base & "PCL\SPCL.exe")
```

- [ ] **Step 7.5: 构建并确认产物**

```powershell
$msbuild = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /t:Rebuild /p:Configuration=Release /p:LangVersion=12.0 /m /v:minimal
Get-Item "Plain Craft Launcher 2\bin\SPCL.exe" | Select-Object FullName, Length
```

Expected: 生成 `SPCL.exe`。

- [ ] **Step 7.6: 静态确认没有旧程序集名**

```powershell
Get-ChildItem "Plain Craft Launcher 2" -Recurse -Include *.vb,*.xaml | Select-String -Pattern "Plain Craft Launcher 2;component|assembly=Plain Craft Launcher 2"
```

Expected: 无输出。

- [ ] **Step 7.7: 运行验证**

启动 `SPCL.exe`，确认：

- 图标、启动画面、关于页图片都正常（没有 XAML 资源加载异常）。
- 单实例正常。
- 关于页 SPCL 行、赞助按钮、原项目链接正常。
- 离线登录 + 启动游戏正常。
- 整合包导出时，启动器文件名为 `SPCL.exe`。

- [ ] **Step 7.8: 提交**

```powershell
git add "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" `
        "Plain Craft Launcher 2\Pages\PageInstance\PageInstanceExport.xaml.vb" `
        "Plain Craft Launcher 2\FormMain.xaml.vb" `
        "Plain Craft Launcher 2"
git commit -m "feat: rename launcher assembly and executable to SPCL"
```

注意：`git add "Plain Craft Launcher 2"` 会把 16 处 component URI 和 10 处 `assembly=` 修改一并加入；提交前用 `git status` 确认没有把构建产物加入。

- [ ] **Step 7.9: 打标签**

```powershell
git tag m2-spcl-exe
```

---

## 执行记录

执行时用 `git log --oneline --decorate` 查看各任务 commit；把 M0 构建/冒烟结果、M1 验收结果和已知问题补在任务对应的勾选框旁，不要回填到本计划正文里。

## 回滚方式

- 整体回到基线：`git reset --hard <基线 commit>`（会丢弃未提交改动，执行前确认）。
- 回滚单个任务：`git revert <该任务 commit>`。
- 只回滚图标：`git checkout <基线 commit> -- "Plain Craft Launcher 2\Images\icon.ico" "Plain Craft Launcher 2\Images\Heads\Logo.png"`。
- M2 出问题：`git switch -` 回到上一个分支（通常是 `master`），删除 `m2-rename-spcl` 分支，M1 不受影响。

