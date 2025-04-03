# Script: mfa_report.ps1
# Autor: Paulo Henrique Rodrigues
# Data: 30/03/2025
# Requisitos: PowerShell 5+, módulo MSOnline instalado
# Objetivo: Listar todos os usuários licenciados e exibir se possuem MFA habilitado

# Horário de início
$inicio = Get-Date
Write-Host "Inicio: $inicio"

# Conecta ao MSOnline (será solicitado login)
Connect-MsolService

# Lista todos os usuários com licença atribuída e habilitados
$usuarios = Get-MsolUser -All | Where-Object {
    $_.isLicensed -eq $true -and $_.BlockCredential -eq $false
}

$total = $usuarios.Count
$contador = 0

# Lista de saída
$resultado = @()

foreach ($user in $usuarios) {
    $contador++
    $statusMFA = "Desabilitado"

    if ($user.StrongAuthenticationRequirements.Count -gt 0) {
        $statusMFA = "Habilitado"
    }

    Write-Host "[$contador/$total] $($user.DisplayName) <$($user.UserPrincipalName)> - MFA: $statusMFA"

    $resultado += [PSCustomObject]@{
        Nome   = $user.DisplayName
        UPN    = $user.UserPrincipalName
        MFA    = $statusMFA
    }
}

# Exporta CSV
$caminho = "$env:USERPROFILE\Desktop\mfa_report.csv"
$resultado | Export-Csv -Path $caminho -NoTypeInformation -Encoding UTF8

# Fim
$fim = Get-Date
Write-Host ""
Write-Host "Relatório salvo em: $caminho"
Write-Host "Fim: $fim"
Write-Host "Tempo total: $([math]::Round(($fim - $inicio).TotalMinutes,2)) minutos"
