param(
    [string]$Proxy = "http://127.0.0.1:7897",
    [string]$Version = "v2.6.4"
)
$ErrorActionPreference = "Stop"
$out = Join-Path $PSScriptRoot "link-module"
$zip = Join-Path $env:TEMP "easytier-$Version-win64.zip"
New-Item -ItemType Directory -Force $out | Out-Null

$urls = @(
    "https://ghfast.top/https://github.com/EasyTier/EasyTier/releases/download/$Version/easytier-windows-x86_64-$Version.zip",
    "https://github.com/EasyTier/EasyTier/releases/download/$Version/easytier-windows-x86_64-$Version.zip"
)
if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 20MB) {
    foreach ($u in $urls) {
        Write-Host "下载 $u"
        curl.exe -x $Proxy -L -sS --max-time 900 -o $zip $u
        if ((Test-Path $zip) -and (Get-Item $zip).Length -gt 20MB) { break }
    }
}
if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 20MB) { throw "下载 EasyTier 失败：$zip" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = Join-Path $env:TEMP "easytier-extract"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
foreach ($f in @("easytier-core.exe", "easytier-cli.exe", "Packet.dll", "wintun.dll", "WinDivert64.sys")) {
    Copy-Item (Join-Path $src.FullName $f) $out -Force
}
Move-Item (Join-Path $out "easytier-core.exe") (Join-Path $out "联机模块.exe") -Force
Move-Item (Join-Path $out "easytier-cli.exe") (Join-Path $out "联机模块 CLI.exe") -Force

try {
    curl.exe -x $Proxy -L -sS --max-time 120 -o (Join-Path $out "LICENSE.txt") "https://raw.githubusercontent.com/EasyTier/EasyTier/$Version/LICENSE"
} catch {
    Write-Host "许可证下载失败，稍后手动补充" -ForegroundColor Yellow
}

Get-ChildItem $out | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 2) } } | Format-Table -AutoSize
Write-Host "模块准备完成：$out"