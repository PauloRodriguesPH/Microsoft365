# Instala os pré-requisitos do toolkit.
# Execute em PowerShell 7 (pwsh) com acesso à Internet e permissão para instalar módulos.

$ErrorActionPreference = "Stop"

Write-Host "== Microsoft 365 Assessment - Setup ==" -ForegroundColor Cyan

if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Host "Aviso: PowerShell 7 (pwsh) não foi localizado. Recomenda-se instalar PowerShell 7 antes de continuar." -ForegroundColor Yellow
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: Python não foi encontrado no PATH." -ForegroundColor Red
    Write-Host "Instale Python 3 e marque 'Add Python to PATH' durante a instalação." -ForegroundColor Yellow
    exit 1
}

Write-Host "Python encontrado: $((python --version) -join ' ')" -ForegroundColor Green

Write-Host "Instalando módulos PowerShell..." -ForegroundColor Yellow
Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber

Write-Host "Instalando bibliotecas Python..." -ForegroundColor Yellow
python -m pip install --upgrade pip
python -m pip install -r (Join-Path $PSScriptRoot "requirements.txt")

Write-Host ""
Write-Host "Pré-requisitos instalados." -ForegroundColor Green
Write-Host "Próximo passo: executar .\scripts\M365-Assessment.ps1" -ForegroundColor Cyan
