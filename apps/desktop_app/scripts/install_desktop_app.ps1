param(
  [switch]$NoDesktopShortcut
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptRoot '..')
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$exeName = 'desktop_app.exe'
$sourceExe = Join-Path $releaseDir $exeName

if (-not (Test-Path $sourceExe)) {
  Write-Host "[1/3] Release build not found. Building desktop release..."
  Push-Location $projectRoot
  try {
    flutter build windows --release
  } finally {
    Pop-Location
  }
}

if (-not (Test-Path $sourceExe)) {
  throw "Release executable not found at: $sourceExe"
}

$installDir = Join-Path $env:LOCALAPPDATA 'Programs\CampusMate'
$targetExe = Join-Path $installDir 'CampusMate.exe'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\CampusMate'
$startMenuShortcut = Join-Path $startMenuDir 'CampusMate.lnk'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'CampusMate.lnk'

Write-Host "[2/3] Installing to: $installDir"
if (Test-Path $installDir) {
  Remove-Item -Recurse -Force $installDir
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

$robocopyArgs = @(
  "`"$releaseDir`"",
  "`"$installDir`"",
  '/MIR',
  '/R:1',
  '/W:1',
  '/NFL',
  '/NDL',
  '/NJH',
  '/NJS',
  '/NC',
  '/NS'
)

& robocopy @robocopyArgs | Out-Null

if (-not (Test-Path (Join-Path $installDir $exeName))) {
  throw "Install copy failed: missing $exeName in $installDir"
}

Rename-Item -Path (Join-Path $installDir $exeName) -NewName 'CampusMate.exe' -Force

if (-not (Test-Path $startMenuDir)) {
  New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
}

Write-Host "[3/3] Creating shortcuts"
$wsh = New-Object -ComObject WScript.Shell

$startShortcutObj = $wsh.CreateShortcut($startMenuShortcut)
$startShortcutObj.TargetPath = $targetExe
$startShortcutObj.WorkingDirectory = $installDir
$startShortcutObj.IconLocation = "$targetExe,0"
$startShortcutObj.Save()

if (-not $NoDesktopShortcut) {
  $desktopShortcutObj = $wsh.CreateShortcut($desktopShortcut)
  $desktopShortcutObj.TargetPath = $targetExe
  $desktopShortcutObj.WorkingDirectory = $installDir
  $desktopShortcutObj.IconLocation = "$targetExe,0"
  $desktopShortcutObj.Save()
}

$uninstallScript = @'
$ErrorActionPreference = "Stop"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\CampusMate"
$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\CampusMate"
$desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "CampusMate.lnk"
if (Test-Path $desktopShortcut) { Remove-Item -Force $desktopShortcut }
if (Test-Path $startMenuDir) { Remove-Item -Recurse -Force $startMenuDir }
if (Test-Path $installDir) { Remove-Item -Recurse -Force $installDir }
Write-Host "CampusMate removed."
'@

Set-Content -Path (Join-Path $installDir 'uninstall.ps1') -Value $uninstallScript -Encoding UTF8

Write-Host ""
Write-Host "Install completed."
Write-Host "Run: $targetExe"
Write-Host "Uninstall: $installDir\uninstall.ps1"
