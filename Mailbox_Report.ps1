# Requer conexão prévia com Microsoft Graph e Exchange Online

# Horario de inicio
$inicio = Get-Date
Write-Host "Inicio: $inicio"

# Inicializa lista de resultados
$lista = @()

# Mapeamento SKU técnico → nome comercial
$skuMap = @{
    "EXCHANGEENTERPRISE"            = "Exchange Online (Plan 2)"
    "EXCHANGEARCHIVE_ADDON"         = "Exchange Online Archiving for Exchange Online"
    "INTUNE_A"                      = "Intune"
    "O365_BUSINESS_ESSENTIALS"      = "Microsoft 365 Business Basic"
    "O365_BUSINESS_PREMIUM"         = "Microsoft 365 Business Standard"
    "MICROSOFT_365_COPILOT"         = "Microsoft 365 Copilot"
    "MICROSOFT_COPILOT_STUDIO_VIRAL_TRIAL" = "Microsoft Copilot Studio Viral Trial"
    "MICROSOFTFABRIC_FREE"          = "Microsoft Fabric (Free)"
    "POWERAPPS_DEV"                 = "Microsoft Power Apps for Developer"
    "FLOW_FREE"                     = "Microsoft Power Automate Free"
    "PBI_PREMIUM_PER_USER"          = "Power BI Premium Per User"
    "POWER_BI_PRO"                  = "Power BI Pro"
	"POWER_BI_STANDARD"             = "Power BI (Standard)"
    "POWER_PAGES_VIRAL"             = "Power Pages vTrial for Makers"
    "TEAMS_PREMIUM_FOR_DEPARTMENTS" = "Teams Premium (for Departments)"
    "DYN365_CI_SELF_SERVICE"        = "Dynamics 365 Customer Insights Self-Service"
}

# Obtem todos os usuarios ativos via Graph
$usuarios = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled | Where-Object { $_.AccountEnabled -eq $true }

# Filtra apenas os que têm licenças atribuídas
$usuariosComLicenca = @()

foreach ($u in $usuarios) {
    $licencas = Get-MgUserLicenseDetail -UserId $u.Id -ErrorAction SilentlyContinue
    if ($licencas) {
        # Anexa as licenças brutas no próprio objeto do usuário
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

        # Tamanho da inbox
        $inboxSize = if ($stats.TotalItemSize) {
            $stats.TotalItemSize.ToString()
        } else {
            "N/A"
        }

        # Arquivo morto
        try {
            $archiveStats = Get-EXOMailboxStatistics -Identity $upn -Archive -ErrorAction Stop
            $archiveSize = if ($archiveStats -and $archiveStats.TotalItemSize) {
                $archiveStats.TotalItemSize.ToString()
            } else {
                "Vazio"
            }
        } catch {
            $archiveSize = "Desabilitado"
        }

        # Data de criação
        $dataCriacao = if ($mbLegacy.WhenCreated) {
            $mbLegacy.WhenCreated.ToString("yyyy-MM-dd HH:mm")
        } else {
            "Indefinido"
        }

        # Ultimo acesso
        $ultimoLogon = if ($stats.LastLogonTime) {
            $stats.LastLogonTime.ToString("yyyy-MM-dd HH:mm")
        } else {
            "Sem registro"
        }

        # Licenças - traduzidas
        $licencas = $user.LicencasBrutas.SkuPartNumber
        $licencasTraduzidas = $licencas | ForEach-Object {
            if ($skuMap.ContainsKey($_)) { $skuMap[$_] } else { $_ }
        }
        $licencasTexto = if ($licencasTraduzidas) { $licencasTraduzidas -join "; " } else { "Nenhuma" }

        Write-Host "  Inbox: $inboxSize | Archive: $archiveSize | Criado em: $dataCriacao | Último acesso: $ultimoLogon | Licenças: $licencasTexto"

        # Adiciona ao resultado
        $lista += [PSCustomObject]@{
            Nome         = $mb.DisplayName
            UPN          = $upn
            Inbox        = $inboxSize
            Archive      = $archiveSize
            CriadoEm     = $dataCriacao
            UltimoAcesso = $ultimoLogon
            Licencas     = $licencasTexto
        }
    }
}

# Exporta CSV
$arquivo = "$env:USERPROFILE\Desktop\Mailbox_Report.csv"
$lista | Export-Csv -Path $arquivo -NoTypeInformation -Encoding UTF8

# Horario de fim
$fim = Get-Date
Write-Host ""
Write-Host "Relatório salvo em: $arquivo"
Write-Host "Fim: $fim"
Write-Host "Tempo total: $([math]::Round(($fim - $inicio).TotalMinutes,2)) minutos"
