# Executa a coleta PowerShell e, ao final, o gerador Python.
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $ProjectRoot "scripts\M365-Assessment.ps1")
