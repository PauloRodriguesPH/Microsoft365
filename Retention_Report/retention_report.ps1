<#
    Script:     retention_report.ps1
    Autor:      Paulo Henrique Rodrigues
    Data:       03/04/2025
    Requisitos: PowerShell 7+ com módulo ExchangeOnlineManagement
    Objetivo:   Listar usuários licenciados e suas políticas de retenção no Exchange Online
#>

# Horário de início
$inicio = Get-Date
Write-Host "Início: $inicio"

# Conectar ao Exchange Online antes de executar
Connect-ExchangeOnline

# Lista de resultados
$resultado = @()

# Obtem todas as caixas do tipo UserMailbox (licenciadas)
$usuarios = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox

$total = $usuarios.Count
$contador = 0

foreach ($user in $usuarios) {
    $contador++
    $nome = $user.DisplayName
    $upn = $user.UserPrincipalName
    $retencao = $user.RetentionPolicy

    Write-Host "[$contador/$total] $nome <$upn> - Política: $retencao"

    $resultado += [PSCustomObject]@{
        Nome     = $nome
        UPN      = $upn
        Politica = $retencao
    }
}

# Exportar CSV
$caminho = "$env:USERPROFILE\Desktop\retention_report.csv"
$resultado | Export-Csv -Path $caminho -NoTypeInformation -Encoding UTF8

# Horário de fim
$fim = Get-Date
Write-Host ""
Write-Host "Relatório salvo em: $caminho"
Write-Host "Fim: $fim"
Write-Host "Tempo total: $([math]::Round(($fim - $inicio).TotalMinutes, 2)) minutos"
