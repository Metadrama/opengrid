# OpenGrid Build Script - WASM + Flutter Web (PowerShell)
# Usage: .\scripts\build.ps1 [-Mode dev|release]

param(
    [ValidateSet("dev", "release")]
    [string]$Mode = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host "🎮 OpenGrid Build - Mode: $Mode" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# Check for Rust/cargo
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Rust not found. Install from https://rustup.rs/" -ForegroundColor Red
    exit 1
}

# Check for wasm-pack
if (-not (Get-Command wasm-pack -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing wasm-pack..." -ForegroundColor Yellow
    cargo install wasm-pack
}

# Build WASM
Write-Host ""
Write-Host "🦀 Building WASM module..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\wasm"

if ($Mode -eq "release") {
    wasm-pack build --target web --out-dir ..\client\web\assets --release
} else {
    wasm-pack build --target web --out-dir ..\client\web\assets --dev
}

Write-Host "✅ WASM build complete" -ForegroundColor Green

# Build Flutter
Write-Host ""
Write-Host "🎯 Building Flutter Web..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\client"

if ($Mode -eq "release") {
    flutter build web --release
} else {
    flutter build web --profile
}

Write-Host ""
Write-Host "🚀 Build complete!" -ForegroundColor Green
Write-Host "   Output: client\build\web\"
Write-Host ""
Write-Host "To run locally:" -ForegroundColor Cyan
Write-Host "   cd client; flutter run -d chrome"

Set-Location $ProjectRoot
