# 构建 SPCL。
# 背景：VS 17.11 的 Roslyn 4.11 不支持 C# 项目的 LangVersion 13.0，
# 但 LangVersion 是全局 MSBuild 属性，直接传给主 VB 工程会把它当成 VB 12.0（2013 语法），
# 导致内插字符串、元组等报 BC36716。
# 因此：先只对三个 C# 项目加 LangVersion=12.0 构建，再用 BuildProjectReferences=false 构建主 VB 工程。

param(
    [string]$Configuration = "Release",
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw "找不到 vswhere.exe：$vswhere"
}

$msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" |
    Select-Object -First 1
if (-not $msbuild) {
    throw "找不到 MSBuild.exe，请确认已安装 Visual Studio 2022 的 .NET 桌面开发工作负载。"
}

$commonArgs = @(
    "/p:Configuration=$Configuration",
    "/m:1",
    "/nodeReuse:false",
    "/v:minimal",
    "/nologo"
)
if ($Rebuild) {
    $commonArgs = @("/t:Rebuild") + $commonArgs
}

$csharpProjects = @(
    "MeloongCore\Shared\MeloongCore.csproj",
    "MeloongCore\Wpf\MeloongCore.Wpf.csproj",
    "PCLCS\PCLCS.csproj"
)

foreach ($project in $csharpProjects) {
    Write-Host "=== $project ($Configuration) ==="
    & $msbuild $project /p:LangVersion=12.0 @commonArgs
    if ($LASTEXITCODE -ne 0) {
        throw "构建失败：$project（退出码 $LASTEXITCODE）"
    }
}

Write-Host "=== Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj ($Configuration) ==="
& $msbuild "Plain Craft Launcher 2\Plain Craft Launcher 2.vbproj" /p:BuildProjectReferences=false @commonArgs
if ($LASTEXITCODE -ne 0) {
    throw "构建失败：主 VB 工程（退出码 $LASTEXITCODE）"
}

Write-Host "构建完成：Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"

# DSH 沙箱工作区里的文件会继承 Low 完整性标签，导致 ShellExecute/双击启动被系统拒绝。
# 构建后把 exe 显式设回 Medium，保证本机双击可运行。
$exe = "Plain Craft Launcher 2\bin\Plain Craft Launcher 2.exe"
if (Test-Path $exe) {
    icacls $exe /setintegritylevel Medium | Out-Null
    Write-Host "已将 $exe 的完整性级别设为 Medium"
}