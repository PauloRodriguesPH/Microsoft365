<#
    Script:     Mailbox_Report.ps1
    Autor:      Paulo Henrique Rodrigues
    Data:       29/03/2025
    Requisitos: PowerShell 7, módulos ExchangeOnlineManagement e Microsoft.Graph
    Objetivo:   Gerar relatório de caixas do Exchange Online
#>

# Requer conexão prévia com Microsoft Graph e Exchange Online

# Horario de início
$inicio = Get-Date
Write-Host "Inicio: $inicio"

# Inicializa lista de resultados
$lista = @()

# Mapeamento SKU técnico → nome comercial (licenças)
$skuMap = @{
    "EXCHANGEENTERPRISE"                  = "Exchange Online (Plan 2)"
    "EXCHANGEARCHIVE_ADDON"               = "Exchange Online Archiving for Exchange Online"
    "INTUNE_A"                            = "Intune"
    "O365_BUSINESS_ESSENTIALS"            = "Microsoft 365 Business Basic"
    "O365_BUSINESS_PREMIUM"               = "Microsoft 365 Business Standard"
    "MICROSOFT_365_COPILOT"               = "Microsoft 365 Copilot"
    "MICROSOFT_COPILOT_STUDIO_VIRAL_TRIAL"= "Microsoft Copilot Studio Viral Trial"
    "MICROSOFTFABRIC_FREE"                = "Microsoft Fabric (Free)"
    "POWERAPPS_DEV"                       = "Microsoft Power Apps for Developer"
    "FLOW_FREE"                           = "Microsoft Power Automate Free"
    "PBI_PREMIUM_PER_USER"                = "Power BI Premium Per User"
    "POWER_BI_PRO"                        = "Power BI Pro"
    "POWER_BI_STANDARD"                   = "Power BI (Standard)"
    "POWER_PAGES_VIRAL"                   = "Power Pages vTrial for Makers"
    "TEAMS_PREMIUM_FOR_DEPARTMENTS"       = "Teams Premium (for Departments)"
    "DYN365_CI_SELF_SERVICE"              = "Dynamics 365 Customer Insights Self-Service"
}

# Mapeamento nome comercial → custo mensal (R$)
$custoMap = @{
    "Microsoft 365 Business Basic"                    = 29.80
    "Microsoft 365 Business Standard"                 = 83.50
    "Exchange Online (Plan 2)"                        = 53.40
    "Exchange Online Archiving for Exchange Online"   = 17.90
    "Microsoft 365 Copilot"                           = 152.00
    "Power BI Pro"                                    = 59.50
    "Power BI Premium Per User"                       = 119.00
}

# Obtem todos os usuários ativos
$usuarios = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled |
    Where-Object { $_.AccountEnabled -eq $true }

# Filtra apenas os que têm licenças atribuídas
$usuariosComLicenca = @()
foreach ($u in $usuarios) {
    $licencas = Get-MgUserLicenseDetail -UserId $u.Id -ErrorAction SilentlyContinue
    if ($licencas) {
        $u | Add-Member -NotePropertyName LicencasBrutas -NotePropertyValue $licencas
        $usuariosComLicenca += $u
    }
}

$total = $usuariosComLicenca.Count
$contador = 0

foreach ($user in $usuariosComLicenca) {
    $contador++
    $upn = $user.UserPrincipalName
    $nome = $user.DisplayName

    $mb = Get-EXOMailbox -Identity $upn -ErrorAction SilentlyContinue
    $mbLegacy = Get-Mailbox -Identity $upn -ErrorAction SilentlyContinue
    $stats = Get-MailboxStatistics -Identity $upn -ErrorAction SilentlyContinue

    if ($mb -and $mbLegacy -and $stats) {
        Write-Host "[$contador/$total] Processando: $nome <$upn>"

        $inboxSize = if ($stats.TotalItemSize) { $stats.TotalItemSize.ToString() } else { "N/A" }

        try {
            $archiveStats = Get-EXOMailboxStatistics -Identity $upn -Archive -ErrorAction Stop
            $archiveSize = if ($archiveStats.TotalItemSize) { $archiveStats.TotalItemSize.ToString() } else { "Vazio" }
        } catch {
            $archiveSize = "Desabilitado"
        }

        $dataCriacao = if ($mbLegacy.WhenCreated) { $mbLegacy.WhenCreated.ToString("yyyy-MM-dd HH:mm") } else { "Indefinido" }
        $ultimoLogon = if ($stats.LastLogonTime) { $stats.LastLogonTime.ToString("yyyy-MM-dd HH:mm") } else { "Sem registro" }

        $licencas = $user.LicencasBrutas.SkuPartNumber
        $licencasTraduzidas = $licencas | ForEach-Object { if ($skuMap.ContainsKey($_)) { $skuMap[$_] } else { $_ } }
        $licencasTexto = if ($licencasTraduzidas) { $licencasTraduzidas -join " | " } else { "Nenhuma" }

        # Soma dos custos
        $totalCusto = 0
        foreach ($lic in $licencasTraduzidas) {
            if ($custoMap.ContainsKey($lic)) {
                $totalCusto += $custoMap[$lic]
            }
        }

        Write-Host "  Inbox: $inboxSize | Archive: $archiveSize | Criado em: $dataCriacao | Último acesso: $ultimoLogon"
        Write-Host "  Licenças: $licencasTexto"
        Write-Host ("  Custo total: R$ {0:N2}" -f $totalCusto)

        $lista += [PSCustomObject]@{
            Nome         = $mb.DisplayName
            UPN          = $upn
            Inbox        = $inboxSize
            Archive      = $archiveSize
            CriadoEm     = $dataCriacao
            UltimoAcesso = $ultimoLogon
            Licencas     = $licencasTexto
            CustoMensal  = ("R$ {0:N2}" -f $totalCusto)
        }
    }
}

# Exporta resultado
$arquivo = "$env:USERPROFILE\Desktop\Mailbox_Report.csv"
$lista | Export-Csv -Path $arquivo -NoTypeInformation -Encoding UTF8

$fim = Get-Date
Write-Host ""
Write-Host "Relatório salvo em: $arquivo"
Write-Host "Fim: $fim"
Write-Host "Tempo total: $([math]::Round(($fim - $inicio).TotalMinutes,2)) minutos"
