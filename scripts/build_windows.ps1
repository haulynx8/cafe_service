# Windows Release Build & Packaging Script for Cafe Service
$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
Set-Location $rootDir

if (-not (Test-Path '.env')) {
    Write-Error "Missing .env file. Copy .env.example to .env and configure Supabase keys."
    exit 1
}

Write-Host "==> Loading environment variables from .env..."
Get-Content '.env' | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_PUBLISHABLE_KEY) {
    Write-Error "SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY is not defined in .env"
    exit 1
}

Write-Host "==> Building Flutter Windows release..."
flutter build windows --release `
    "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" `
    "--dart-define=SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"

$sourceDir = Join-Path $rootDir "build\windows\x64\runner\Release"
if (-not (Test-Path $sourceDir)) {
    Write-Error "Build output directory not found at $sourceDir"
    exit 1
}

$distDir = Join-Path $rootDir "dist"
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

$outputAppDir = Join-Path $distDir "cafe-service-windows-x64"
if (Test-Path $outputAppDir) {
    Remove-Item -Recurse -Force $outputAppDir
}

Write-Host "==> Staging Windows release package..."
Copy-Item -Recurse -Path $sourceDir -Destination $outputAppDir

$zipFile = Join-Path $distDir "cafe-service-windows-x64.zip"
if (Test-Path $zipFile) {
    Remove-Item -Force $zipFile
}

Write-Host "==> Creating portable ZIP: $zipFile..."
Compress-Archive -Path "$outputAppDir\*" -DestinationPath $zipFile -Force

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "✓ Windows Build & Packaging Complete!" -ForegroundColor Green
Write-Host "Portable Folder: $outputAppDir" -ForegroundColor Green
Write-Host "Portable ZIP:    $zipFile" -ForegroundColor Green
Write-Host "To run: Double-click cafe_service.exe inside the folder or extracted ZIP." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Green
