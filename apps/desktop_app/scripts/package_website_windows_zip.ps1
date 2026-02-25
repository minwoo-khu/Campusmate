param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptRoot '..')
$repoRoot = Resolve-Path (Join-Path $projectRoot '..\..')
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$exeName = 'CampusMate.exe'
$zipOut = Join-Path $repoRoot 'services\website\assets\downloads\CampusMate-Windows.zip'
$stageDir = Join-Path $env:TEMP 'CampusMate-Windows-Package'

if (-not $SkipBuild) {
  Write-Host "[1/4] Building Windows release..."
  Push-Location $projectRoot
  try {
    flutter build windows --release
  } finally {
    Pop-Location
  }
}

$sourceExe = Join-Path $releaseDir $exeName
if (-not (Test-Path $sourceExe)) {
  throw "Release executable not found: $sourceExe"
}

Write-Host "[2/4] Preparing package stage: $stageDir"
if (Test-Path $stageDir) {
  Remove-Item -Recurse -Force $stageDir
}
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

Write-Host "[3/4] Copying runtime files..."
$robocopyArgs = @(
  "`"$releaseDir`"",
  "`"$stageDir`"",
  '/E',
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

Get-ChildItem $stageDir -Filter 'desktop_app.*' -File -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem $stageDir -Filter '*.msix' -File -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction SilentlyContinue

$runGuide = @'
CampusMate (Windows)

1) Unzip this archive.
2) Run CampusMate.exe.
'@
Set-Content -Path (Join-Path $stageDir 'README_RUN.txt') -Value $runGuide -Encoding UTF8

Write-Host "[4/4] Writing zip: $zipOut"
if (Test-Path $zipOut) {
  Remove-Item -Force $zipOut
}
Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipOut -Force

Write-Host ""
Write-Host "Done."
Write-Host "Output: $zipOut"
