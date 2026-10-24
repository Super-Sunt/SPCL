param(
    [string]$Version = "1.2"
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

& "$PSScriptRoot\build-spcl.ps1"
if ($LASTEXITCODE -ne 0) { throw "构建失败：$LASTEXITCODE" }

$stage = Join-Path $root "dist\SPCL"
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null

Copy-Item "Plain Craft Launcher 2\bin\SPCL.exe" $stage -Force
Copy-Item "LICENCE" $stage -Force
Copy-Item "README-SPCL.txt" (Join-Path $stage "README.txt") -Force
icacls (Join-Path $stage "SPCL.exe") /setintegritylevel Medium | Out-Null

$moduleSrc = Join-Path $PSScriptRoot "link-module"
if (-not (Test-Path (Join-Path $moduleSrc "联机模块.exe"))) {
    throw "缺少联机模块，请先运行 tools\prepare-link-module.ps1"
}
$moduleDst = Join-Path $stage "联机模块"
New-Item -ItemType Directory -Force $moduleDst | Out-Null
Copy-Item (Join-Path $moduleSrc "*") $moduleDst -Force

$zip = Join-Path $root "dist\SPCL-$Version-win64.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::OpenRead($zip).Entries | Select-Object FullName, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 2) } } | Format-Table -AutoSize
Get-Item $zip | Select-Object FullName, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 2) } } | Format-List