# ============================================================
# Microsoft 365 Assessment
# Ambiente: Microsoft 365 / Entra ID / Exchange Online
# Objetivo: Coleta somente leitura do ambiente Microsoft 365
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# CONFIGURACAO
# ------------------------------------------------------------

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputRaw     = Join-Path $ProjectRoot "output\raw"
$OutputReports = Join-Path $ProjectRoot "output\reports"

if (-not (Test-Path $OutputRaw)) {
    New-Item -Path $OutputRaw -ItemType Directory -Force | Out-Null
}

if (-not (Test-Path $OutputReports)) {
    New-Item -Path $OutputReports -ItemType Directory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Microsoft 365 Assessment" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Inicio da coleta: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Host ""

# ------------------------------------------------------------
# CONEXAO MICROSOFT GRAPH
# ------------------------------------------------------------

Write-Host "Conectando ao Microsoft Graph..." -ForegroundColor Yellow

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

Connect-MgGraph `
    -Scopes `
        "User.Read.All",
        "Directory.Read.All",
        "Group.Read.All",
        "Organization.Read.All",
        "AuditLog.Read.All",
        "Policy.Read.All",
        "RoleManagement.Read.Directory",
        "UserAuthenticationMethod.Read.All",
        "IdentityProvider.Read.All",
        "Reports.Read.All",
        "Sites.Read.All",
        "Team.ReadBasic.All",
        "Device.Read.All",
        "Application.Read.All" `
    -UseDeviceCode `
    -NoWelcome

Write-Host "Microsoft Graph conectado." -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# CONEXAO EXCHANGE ONLINE
# ------------------------------------------------------------

Write-Host "Conectando ao Exchange Online..." -ForegroundColor Yellow

Connect-ExchangeOnline `
    -Device `
    -ShowBanner:$false

Write-Host "Exchange Online conectado." -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# INFORMACOES DA SESSAO
# ------------------------------------------------------------

$Context = Get-MgContext

$SessionInfo = [PSCustomObject]@{
    TenantId    = $Context.TenantId
    Account     = $Context.Account
    Scopes      = ($Context.Scopes -join ", ")
    CollectedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$SessionInfo |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Assessment-Session-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Sessao registrada." -ForegroundColor Green
Write-Host ""

# ============================================================
# MODULO 01 - IDENTIDADE
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 01 - IDENTIDADE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Coletando usuarios do tenant..." -ForegroundColor Yellow

$Users = Get-MgUser -All `
    -Property `
        "Id",
        "DisplayName",
        "UserPrincipalName",
        "AccountEnabled",
        "UserType",
        "CreatedDateTime",
        "Mail",
        "JobTitle",
        "Department",
        "AssignedLicenses",
        "SignInActivity"

Write-Host "Usuarios coletados: $($Users.Count)" -ForegroundColor Green
Write-Host ""

# Inventario principal
$IdentityReport = foreach ($User in $Users) {

    [PSCustomObject]@{
        Id                          = $User.Id
        DisplayName                 = $User.DisplayName
        UserPrincipalName           = $User.UserPrincipalName
        Mail                        = $User.Mail
        UserType                    = $User.UserType
        AccountEnabled              = $User.AccountEnabled
        CreatedDateTime             = $User.CreatedDateTime
        LastSignInDateTime          = $User.SignInActivity.LastSignInDateTime
        LastNonInteractiveSignIn    = $User.SignInActivity.LastNonInteractiveSignInDateTime
        JobTitle                    = $User.JobTitle
        Department                  = $User.Department
        LicenseCount                = @($User.AssignedLicenses).Count
    }
}

$IdentityReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Identity-Inventory-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# Usuarios
$Users |
    Select-Object `
        Id,
        DisplayName,
        UserPrincipalName,
        AccountEnabled,
        UserType,
        CreatedDateTime,
        @{Name="LastSignInDateTime";Expression={$_.SignInActivity.LastSignInDateTime}},
        @{Name="LastNonInteractiveSignInDateTime";Expression={$_.SignInActivity.LastNonInteractiveSignInDateTime}},
        Mail,
        JobTitle,
        Department,
        @{Name="AssignedLicenseCount";Expression={@($_.AssignedLicenses).Count}} |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Users-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# Resumo
$IdentitySummary = [PSCustomObject]@{
    TotalIdentidades = $Users.Count
    ContasAtivas     = @($Users | Where-Object {$_.AccountEnabled -eq $true}).Count
    ContasBloqueadas = @($Users | Where-Object {$_.AccountEnabled -eq $false}).Count
    UsuariosMember   = @($Users | Where-Object {$_.UserType -eq "Member"}).Count
    UsuariosGuest    = @($Users | Where-Object {$_.UserType -eq "Guest"}).Count
    ComLicenca       = @($Users | Where-Object {@($_.AssignedLicenses).Count -gt 0}).Count
    SemLicenca       = @($Users | Where-Object {@($_.AssignedLicenses).Count -eq 0}).Count
}

$IdentitySummary |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Identity-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# Analise
$IdentityAnalysis = foreach ($User in $Users) {

    $LicenseStatus = if (@($User.AssignedLicenses).Count -gt 0) {
        "Com licenca"
    } else {
        "Sem licenca"
    }

    $AccountStatus = if ($User.AccountEnabled) {
        "Ativa"
    } else {
        "Bloqueada"
    }

    [PSCustomObject]@{
        DisplayName              = $User.DisplayName
        UserPrincipalName        = $User.UserPrincipalName
        UserType                 = $User.UserType
        AccountStatus            = $AccountStatus
        LicenseStatus            = $LicenseStatus
        LicenseCount             = @($User.AssignedLicenses).Count
        Mail                     = $User.Mail
        JobTitle                 = $User.JobTitle
        Department               = $User.Department
        CreatedDateTime          = $User.CreatedDateTime
        LastSignInDateTime       = $User.SignInActivity.LastSignInDateTime
        LastNonInteractiveSignIn = $User.SignInActivity.LastNonInteractiveSignInDateTime
    }
}

$IdentityAnalysis |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Identity-Analysis-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$ActiveWithoutLicense = $IdentityAnalysis |
    Where-Object {
        $_.AccountStatus -eq "Ativa" -and
        $_.LicenseStatus -eq "Sem licenca"
    }

$ActiveWithoutLicense |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Active-Without-License-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$ActiveWithoutRecentSignIn = $IdentityAnalysis |
    Where-Object {
        $_.AccountStatus -eq "Ativa" -and
        [string]::IsNullOrWhiteSpace([string]$_.LastSignInDateTime)
    }

$ActiveWithoutRecentSignIn |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Active-Without-SignIn-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Identidade concluida." -ForegroundColor Green
Write-Host "  Total             : $($IdentitySummary.TotalIdentidades)"
Write-Host "  Ativas            : $($IdentitySummary.ContasAtivas)"
Write-Host "  Bloqueadas        : $($IdentitySummary.ContasBloqueadas)"
Write-Host "  Members           : $($IdentitySummary.UsuariosMember)"
Write-Host "  Guests             : $($IdentitySummary.UsuariosGuest)"
Write-Host "  Com licenca       : $($IdentitySummary.ComLicenca)"
Write-Host "  Sem licenca       : $($IdentitySummary.SemLicenca)"
Write-Host ""

# ============================================================
# MODULO 02 - LICENCIAMENTO
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 02 - LICENCIAMENTO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Coletando licencas dos usuarios..." -ForegroundColor Yellow

$LicenseReport = foreach ($User in $Users) {

    $Licenses = @(Get-MgUserLicenseDetail -UserId $User.Id)

    if ($Licenses.Count -eq 0) {

        [PSCustomObject]@{
            UserId            = $User.Id
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            AccountEnabled    = $User.AccountEnabled
            LicenseName       = "SEM LICENCA"
            SkuPartNumber     = ""
        }

    } else {

        foreach ($License in $Licenses) {

            [PSCustomObject]@{
                UserId            = $User.Id
                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                AccountEnabled    = $User.AccountEnabled
                LicenseName       = $License.SkuPartNumber
                SkuPartNumber     = $License.SkuPartNumber
            }
        }
    }
}

$LicenseReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "User-Licenses-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Registros de licencas: $($LicenseReport.Count)" -ForegroundColor Green

Write-Host ""
Write-Host "Coletando catalogo de licencas do tenant..." -ForegroundColor Yellow

$SubscribedSkus = Get-MgSubscribedSku -All

$SkuReport = $SubscribedSkus |
    Select-Object `
        Id,
        SkuPartNumber,
        @{Name="DisplayName";Expression={$_.SkuPartNumber}},
        @{Name="TotalLicenses";Expression={$_.PrepaidUnits.Enabled}},
        @{Name="ConsumedLicenses";Expression={$_.ConsumedUnits}},
        @{Name="AvailableLicenses";Expression={
            $_.PrepaidUnits.Enabled - $_.ConsumedUnits
        }}

$SkuReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "License-SKUs-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "SKUs encontrados: $($SkuReport.Count)" -ForegroundColor Green
Write-Host ""

$SkuReport |
    Format-Table SkuPartNumber,TotalLicenses,ConsumedLicenses,AvailableLicenses -AutoSize

# ============================================================
# MODULO 03 - EXCHANGE ONLINE
# ============================================================

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 03 - EXCHANGE ONLINE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Coletando mailboxes..." -ForegroundColor Yellow

$Mailboxes = Get-EXOMailbox -ResultSize Unlimited |
    Select-Object `
        Id,
        DisplayName,
        UserPrincipalName,
        RecipientTypeDetails,
        PrimarySmtpAddress,
        ArchiveStatus,
        LitigationHoldEnabled

$Mailboxes |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Mailboxes-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$MailboxSummary = $Mailboxes |
    Group-Object RecipientTypeDetails |
    Select-Object Name,Count

$MailboxSummary |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Mailbox-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Mailboxes encontradas: $($Mailboxes.Count)" -ForegroundColor Green
$MailboxSummary | Format-Table -AutoSize

Write-Host ""
Write-Host "Coletando estatisticas das mailboxes..." -ForegroundColor Yellow

$MailboxStatistics = $Mailboxes |
    Get-EXOMailboxStatistics |
    Select-Object `
        DisplayName,
        TotalItemSize,
        ItemCount,
        LastLogonTime

$MailboxStatistics |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Mailbox-Statistics-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$SharedMailboxes = $Mailboxes |
    Where-Object {$_.RecipientTypeDetails -eq "SharedMailbox"}

$SharedMailboxes |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Shared-Mailboxes-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$UserMailboxes = $Mailboxes |
    Where-Object {$_.RecipientTypeDetails -eq "UserMailbox"}

$UserMailboxes |
    Export-Csv `
        -Path (Join-Path $OutputRaw "User-Mailboxes-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$MailboxesWithArchive = $Mailboxes |
    Where-Object {$_.ArchiveStatus -eq "Active"}

$MailboxesWithArchive |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Mailboxes-With-Archive-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Exchange concluido." -ForegroundColor Green
Write-Host "  Mailboxes        : $($Mailboxes.Count)"
Write-Host "  User Mailboxes   : $($UserMailboxes.Count)"
Write-Host "  Shared Mailboxes : $($SharedMailboxes.Count)"
Write-Host "  Com Archive      : $($MailboxesWithArchive.Count)"
Write-Host ""

# ============================================================
# MODULO 04 - MFA E SEGURANCA
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 04 - MFA E SEGURANCA" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Consultando Security Defaults..." -ForegroundColor Yellow

$SecurityDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy |
    Select-Object IsEnabled

$SecurityDefaults |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Security-Defaults-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Security Defaults: $($SecurityDefaults.IsEnabled)" -ForegroundColor Green

Write-Host ""
Write-Host "Consultando Conditional Access..." -ForegroundColor Yellow

$ConditionalAccess = Get-MgIdentityConditionalAccessPolicy -All |
    Select-Object `
        Id,
        DisplayName,
        State,
        CreatedDateTime,
        ModifiedDateTime

$ConditionalAccess |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Conditional-Access-Policies-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Politicas Conditional Access: $($ConditionalAccess.Count)" -ForegroundColor Green

Write-Host ""
Write-Host "Coletando metodos de autenticacao..." -ForegroundColor Yellow

$MfaReport = foreach ($User in $Users) {

    try {

        $Methods = @(Get-MgUserAuthenticationMethod `
            -UserId $User.Id `
            -ErrorAction Stop)

        $MethodNames = foreach ($Method in $Methods) {

            $Type = $Method.AdditionalProperties.'@odata.type'

            switch ($Type) {

                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    "Microsoft Authenticator"
                }

                "#microsoft.graph.phoneAuthenticationMethod" {
                    "Telefone"
                }

                "#microsoft.graph.fido2AuthenticationMethod" {
                    "FIDO2"
                }

                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    "Windows Hello"
                }

                "#microsoft.graph.emailAuthenticationMethod" {
                    "Email"
                }

                "#microsoft.graph.passwordAuthenticationMethod" {
                    "Senha"
                }

                default {
                    $Type
                }
            }
        }

        $MfaCapableMethods = @(
            $MethodNames | Where-Object {
                $_ -in @(
                    "Microsoft Authenticator",
                    "Telefone",
                    "FIDO2"
                )
            }
        )

        [PSCustomObject]@{
            DisplayName            = $User.DisplayName
            UserPrincipalName      = $User.UserPrincipalName
            AccountEnabled         = $User.AccountEnabled
            AuthenticationMethods  = ($MethodNames -join "; ")
            MethodCount            = $MethodNames.Count
            MfaCapableMethodCount  = $MfaCapableMethods.Count
            MfaMethodStatus        = if ($MfaCapableMethods.Count -gt 0) {
                "Possui metodo MFA"
            } else {
                "Sem metodo MFA identificado"
            }
        }
    }
    catch {

        [PSCustomObject]@{
            DisplayName            = $User.DisplayName
            UserPrincipalName      = $User.UserPrincipalName
            AccountEnabled         = $User.AccountEnabled
            AuthenticationMethods  = "ERRO AO CONSULTAR"
            MethodCount            = 0
            MfaCapableMethodCount  = 0
            MfaMethodStatus        = "Erro na consulta"
        }
    }
}

$MfaReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "MFA-Inventory-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$MfaMethodSummary = foreach ($Method in (
    $MfaReport.AuthenticationMethods |
    ForEach-Object {
        if ($_ -and $_ -ne "ERRO AO CONSULTAR") {
            $_ -split "; "
        }
    }
)) {
    [PSCustomObject]@{
        AuthenticationMethod = $Method
    }
}

$MfaMethodSummary |
    Group-Object AuthenticationMethod |
    Select-Object Name,Count |
    Export-Csv `
        -Path (Join-Path $OutputRaw "MFA-Method-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$MfaSummary = [PSCustomObject]@{
    TotalUsuarios              = $MfaReport.Count
    ComMetodoMFA               = @($MfaReport | Where-Object {$_.MfaCapableMethodCount -gt 0}).Count
    SemMetodoMFAIdentificado   = @($MfaReport | Where-Object {$_.MfaCapableMethodCount -eq 0}).Count
    ErroConsulta               = @($MfaReport | Where-Object {$_.MfaMethodStatus -eq "Erro na consulta"}).Count
}

$MfaSummary |
    Export-Csv `
        -Path (Join-Path $OutputRaw "MFA-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "MFA e Seguranca concluido." -ForegroundColor Green
Write-Host "  Security Defaults : $($SecurityDefaults.IsEnabled)"
Write-Host "  Conditional Access: $($ConditionalAccess.Count)"
Write-Host "  Usuarios com MFA  : $($MfaSummary.ComMetodoMFA)"
Write-Host "  Sem MFA identificado: $($MfaSummary.SemMetodoMFAIdentificado)"
Write-Host ""

# ============================================================
# MODULO 05 - PRIVILEGED ACCESS / DIRECTORY ROLES
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 05 - PRIVILEGED ACCESS / DIRECTORY ROLES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Consultando Directory Roles..." -ForegroundColor Yellow

$DirectoryRoles = Get-MgDirectoryRole -All

$RoleReport = foreach ($Role in $DirectoryRoles) {

    Write-Host "Analisando role: $($Role.DisplayName)" -ForegroundColor DarkGray

    $Members = Get-MgDirectoryRoleMember `
        -DirectoryRoleId $Role.Id `
        -All

    foreach ($Member in $Members) {

        # Cruza o MemberId com o inventario de usuarios do Modulo 01.
        # Isso evita depender de Get-MgDirectoryRoleMemberAsUser,
        # que pode nao resolver o objeto corretamente em alguns tenants.
        $User = $Users |
            Where-Object { $_.Id -eq $Member.Id } |
            Select-Object -First 1

        if ($User) {

            [PSCustomObject]@{
                RoleName          = $Role.DisplayName
                RoleId            = $Role.Id
                MemberId          = $Member.Id
                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                AccountEnabled    = $User.AccountEnabled
                UserType          = $User.UserType
                LicenseCount      = @($User.AssignedLicenses).Count
            }
        }
        else {

            # Mantem o registro mesmo quando o membro nao for um usuario
            # ou nao estiver presente no inventario de usuarios.
            [PSCustomObject]@{
                RoleName          = $Role.DisplayName
                RoleId            = $Role.Id
                MemberId          = $Member.Id
                DisplayName       = ""
                UserPrincipalName = ""
                AccountEnabled    = ""
                UserType          = ""
                LicenseCount      = ""
            }
        }
    }
}

$RoleReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Directory-Role-Members-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$RoleSummary = $RoleReport |
    Group-Object RoleName |
    Select-Object `
        @{Name="RoleName";Expression={$_.Name}},
        @{Name="MemberCount";Expression={$_.Count}} |
    Sort-Object RoleName

$RoleSummary |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Directory-Roles-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# Roles que serao tratados como privilegiados no diagnostico.
# O script apenas identifica e reporta; nenhuma alteracao e realizada.
$PrivilegedRoleNames = @(
    "Global Administrator",
    "Global Reader",
    "Security Administrator",
    "SharePoint Administrator",
    "Exchange Administrator",
    "User Administrator",
    "Helpdesk Administrator",
    "Authentication Administrator",
    "Privileged Role Administrator",
    "Application Administrator",
    "Cloud Application Administrator",
    "Intune Administrator",
    "Billing Administrator",
    "Password Administrator"
)

$PrivilegedMembers = $RoleReport |
    Where-Object {
        $_.RoleName -in $PrivilegedRoleNames
    }

$GlobalAdministrators = $RoleReport |
    Where-Object {
        $_.RoleName -eq "Global Administrator"
    }

$PrivilegedSummary = [PSCustomObject]@{
    TotalActiveDirectoryRoles     = $DirectoryRoles.Count
    TotalRoleAssignments          = $RoleReport.Count
    TotalPrivilegedAssignments    = $PrivilegedMembers.Count
    GlobalAdministratorCount      = $GlobalAdministrators.Count
    PrivilegedUsersBlocked        = @(
        $PrivilegedMembers |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    ).Count
    PrivilegedUsersWithoutLicense = @(
        $PrivilegedMembers |
        Where-Object {
            $_.LicenseCount -eq 0
        }
    ).Count
}

$PrivilegedSummary |
    Export-Csv `
        -Path (Join-Path $OutputReports "Privileged-Access-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Roles encontrados: $($DirectoryRoles.Count)" -ForegroundColor Green
Write-Host "Assignments encontrados: $($RoleReport.Count)" -ForegroundColor Green
Write-Host "Global Administrators: $($GlobalAdministrators.Count)" -ForegroundColor Yellow
Write-Host ""

$RoleSummary | Format-Table -AutoSize

Write-Host "Modulo 05 concluido." -ForegroundColor Green
Write-Host ""


# ============================================================
# MODULO 06 - GRUPOS / TEAMS / SHAREPOINT / ONEDRIVE
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 06 - GRUPOS / TEAMS / SHAREPOINT / ONEDRIVE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 06.1 - GRUPOS
# ------------------------------------------------------------

Write-Host "Coletando grupos do Microsoft Entra ID..." -ForegroundColor Yellow

$Groups = Get-MgGroup -All `
    -Property `
        "Id",
        "DisplayName",
        "Description",
        "Mail",
        "MailEnabled",
        "MailNickname",
        "SecurityEnabled",
        "GroupTypes",
        "Visibility",
        "CreatedDateTime",
        "MembershipRule",
        "MembershipRuleProcessingState",
        "OnPremisesSyncEnabled",
        "ResourceProvisioningOptions"

$GroupReport = foreach ($Group in $Groups) {

    $Members = @(
        Get-MgGroupMember `
            -GroupId $Group.Id `
            -All `
            -ErrorAction SilentlyContinue
    )

    $Owners = @(
        Get-MgGroupOwner `
            -GroupId $Group.Id `
            -All `
            -ErrorAction SilentlyContinue
    )

    $IsMicrosoft365Group = $Group.GroupTypes -contains "Unified"
    $IsDynamic = $Group.GroupTypes -contains "DynamicMembership"
    $IsTeam = $Group.ResourceProvisioningOptions -contains "Team"

    [PSCustomObject]@{
        Id                          = $Group.Id
        DisplayName                 = $Group.DisplayName
        Description                 = $Group.Description
        Mail                        = $Group.Mail
        MailNickname                = $Group.MailNickname
        MailEnabled                 = $Group.MailEnabled
        SecurityEnabled             = $Group.SecurityEnabled
        GroupTypes                  = ($Group.GroupTypes -join "; ")
        Visibility                  = $Group.Visibility
        CreatedDateTime             = $Group.CreatedDateTime
        IsMicrosoft365Group         = $IsMicrosoft365Group
        IsDynamic                   = $IsDynamic
        IsTeam                      = $IsTeam
        MemberCount                 = $Members.Count
        OwnerCount                  = $Owners.Count
        HasMembers                  = ($Members.Count -gt 0)
        HasOwners                   = ($Owners.Count -gt 0)
        OnPremisesSyncEnabled       = $Group.OnPremisesSyncEnabled
        MembershipRule              = $Group.MembershipRule
        MembershipRuleProcessingState = $Group.MembershipRuleProcessingState
    }
}

$GroupReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Groups-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# 06.2 - MEMBROS E PROPRIETARIOS DOS GRUPOS
# ------------------------------------------------------------

Write-Host "Coletando membros e proprietarios dos grupos..." -ForegroundColor Yellow

$GroupMemberReport = foreach ($Group in $Groups) {

    $Members = @(
        Get-MgGroupMember `
            -GroupId $Group.Id `
            -All `
            -ErrorAction SilentlyContinue
    )

    foreach ($Member in $Members) {

        $User = $Users |
            Where-Object { $_.Id -eq $Member.Id } |
            Select-Object -First 1

        [PSCustomObject]@{
            GroupId           = $Group.Id
            GroupDisplayName  = $Group.DisplayName
            MemberId          = $Member.Id
            MemberDisplayName = if ($User) { $User.DisplayName } else { "" }
            UserPrincipalName = if ($User) { $User.UserPrincipalName } else { "" }
            UserType          = if ($User) { $User.UserType } else { "" }
            AccountEnabled    = if ($User) { $User.AccountEnabled } else { "" }
        }
    }
}

$GroupMemberReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Group-Members-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$GroupOwnerReport = foreach ($Group in $Groups) {

    $Owners = @(
        Get-MgGroupOwner `
            -GroupId $Group.Id `
            -All `
            -ErrorAction SilentlyContinue
    )

    foreach ($Owner in $Owners) {

        $User = $Users |
            Where-Object { $_.Id -eq $Owner.Id } |
            Select-Object -First 1

        [PSCustomObject]@{
            GroupId           = $Group.Id
            GroupDisplayName  = $Group.DisplayName
            OwnerId           = $Owner.Id
            OwnerDisplayName  = if ($User) { $User.DisplayName } else { "" }
            UserPrincipalName = if ($User) { $User.UserPrincipalName } else { "" }
            UserType          = if ($User) { $User.UserType } else { "" }
            AccountEnabled    = if ($User) { $User.AccountEnabled } else { "" }
        }
    }
}

$GroupOwnerReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "Group-Owners-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# 06.3 - TEAMS
# ------------------------------------------------------------

Write-Host "Consultando Microsoft Teams..." -ForegroundColor Yellow

$Teams = @()

try {
    $Teams = @(Get-MgTeam -All -ErrorAction Stop)

    $Teams |
        Select-Object `
            Id,
            DisplayName,
            Description,
            Visibility,
            WebUrl,
            CreatedDateTime,
            Classification |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Teams-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Teams encontrados: $($Teams.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Nao foi possivel consultar Teams diretamente: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "O script continuara com os dados de grupos." -ForegroundColor Yellow

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Teams-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

# ------------------------------------------------------------
# 06.4 - SHAREPOINT / SITES
# ------------------------------------------------------------

Write-Host "Consultando sites do SharePoint..." -ForegroundColor Yellow

$SharePointSites = @()

try {

    $SharePointSites = @(
        Get-MgSite `
            -Search "*" `
            -All `
            -ErrorAction Stop
    )

    $SharePointSites |
        Select-Object `
            Id,
            DisplayName,
            Name,
            WebUrl,
            CreatedDateTime,
            LastModifiedDateTime |
        Export-Csv `
            -Path (Join-Path $OutputRaw "SharePoint-Sites-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Sites SharePoint encontrados: $($SharePointSites.Count)" -ForegroundColor Green
}
catch {

    Write-Host "Nao foi possivel consultar SharePoint: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "O script continuara." -ForegroundColor Yellow

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "SharePoint-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

# ------------------------------------------------------------
# 06.5 - ONEDRIVE / DRIVES
# ------------------------------------------------------------

Write-Host "Consultando OneDrive dos usuarios..." -ForegroundColor Yellow

$OneDriveReport = foreach ($User in $Users) {

    try {

        $Drive = Get-MgUserDrive `
            -UserId $User.Id `
            -ErrorAction Stop

        if ($Drive) {

            [PSCustomObject]@{
                UserId            = $User.Id
                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                DriveId           = $Drive.Id
                DriveType         = $Drive.DriveType
                DriveWebUrl       = $Drive.WebUrl
                QuotaTotal        = $Drive.Quota.Total
                QuotaUsed         = $Drive.Quota.Used
            }
        }
    }
    catch {

        [PSCustomObject]@{
            UserId            = $User.Id
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            DriveId           = ""
            DriveType         = ""
            DriveWebUrl       = ""
            QuotaTotal        = ""
            QuotaUsed         = ""
        }
    }
}

$OneDriveReport |
    Export-Csv `
        -Path (Join-Path $OutputRaw "OneDrive-Inventory-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

# ------------------------------------------------------------
# 06.6 - RESUMO
# ------------------------------------------------------------

$GroupSummary = [PSCustomObject]@{
    TotalGroups             = $GroupReport.Count
    Microsoft365Groups      = @($GroupReport | Where-Object {$_.IsMicrosoft365Group}).Count
    SecurityGroups          = @(
        $GroupReport |
        Where-Object {
            $_.SecurityEnabled -eq $true
        }
    ).Count
    DynamicGroups           = @($GroupReport | Where-Object {$_.IsDynamic}).Count
    TeamsDetected           = @($GroupReport | Where-Object {$_.IsTeam}).Count
    GroupsWithoutMembers    = @(
        $GroupReport |
        Where-Object {
            $_.MemberCount -eq 0
        }
    ).Count
    GroupsWithoutOwners     = @(
        $GroupReport |
        Where-Object {
            $_.OwnerCount -eq 0
        }
    ).Count
    GroupsWithSingleOwner   = @(
        $GroupReport |
        Where-Object {
            $_.OwnerCount -eq 1
        }
    ).Count
    SharePointSites         = $SharePointSites.Count
    OneDriveUsersWithDrive  = @(
        $OneDriveReport |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.DriveId)
        }
    ).Count
}

$GroupSummary |
    Export-Csv `
        -Path (Join-Path $OutputReports "Collaboration-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "Modulo 06 concluido." -ForegroundColor Green
Write-Host "  Grupos                  : $($GroupSummary.TotalGroups)"
Write-Host "  Grupos Microsoft 365    : $($GroupSummary.Microsoft365Groups)"
Write-Host "  Grupos de seguranca     : $($GroupSummary.SecurityGroups)"
Write-Host "  Grupos dinamicos        : $($GroupSummary.DynamicGroups)"
Write-Host "  Teams detectados        : $($GroupSummary.TeamsDetected)"
Write-Host "  Grupos sem membros      : $($GroupSummary.GroupsWithoutMembers)"
Write-Host "  Grupos sem proprietario : $($GroupSummary.GroupsWithoutOwners)"
Write-Host "  Sites SharePoint        : $($GroupSummary.SharePointSites)"
Write-Host "  OneDrive com Drive      : $($GroupSummary.OneDriveUsersWithDrive)"
Write-Host ""


# ============================================================
# MODULO 07 - DISPOSITIVOS / ENTRA REGISTERED & JOINED
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 07 - DISPOSITIVOS / ENTRA ID" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$Devices = @()

try {
    Write-Host "Coletando dispositivos registrados no Entra ID..." -ForegroundColor Yellow

    $Devices = @(
        Get-MgDevice -All `
            -Property `
                "Id",
                "DisplayName",
                "DeviceId",
                "AccountEnabled",
                "ApproximateLastSignInDateTime",
                "DeviceOSType",
                "DeviceOSVersion",
                "IsCompliant",
                "IsManaged",
                "TrustType",
                "ProfileType",
                "RegistrationDateTime" `
            -ErrorAction Stop
    )

    $DeviceReport = $Devices | ForEach-Object {

        [PSCustomObject]@{
            Id                           = $_.Id
            DisplayName                  = $_.DisplayName
            DeviceId                     = $_.DeviceId
            AccountEnabled               = $_.AccountEnabled
            ApproximateLastSignInDateTime = $_.ApproximateLastSignInDateTime
            DeviceOSType                 = $_.DeviceOSType
            DeviceOSVersion              = $_.DeviceOSVersion
            IsCompliant                  = $_.IsCompliant
            IsManaged                    = $_.IsManaged
            TrustType                    = $_.TrustType
            ProfileType                  = $_.ProfileType
            RegistrationDateTime         = $_.RegistrationDateTime
        }
    }

    $DeviceReport |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Devices-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Dispositivos encontrados: $($DeviceReport.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao consultar dispositivos: $($_.Exception.Message)" -ForegroundColor Yellow

    $DeviceReport = @()

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Devices-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

$DeviceSummary = [PSCustomObject]@{
    TotalDevices       = $DeviceReport.Count
    EnabledDevices     = @($DeviceReport | Where-Object {$_.AccountEnabled -eq $true}).Count
    DisabledDevices    = @($DeviceReport | Where-Object {$_.AccountEnabled -eq $false}).Count
    ManagedDevices     = @($DeviceReport | Where-Object {$_.IsManaged -eq $true}).Count
    CompliantDevices   = @($DeviceReport | Where-Object {$_.IsCompliant -eq $true}).Count
    NonCompliantDevices = @($DeviceReport | Where-Object {$_.IsCompliant -eq $false}).Count
    WindowsDevices     = @($DeviceReport | Where-Object {$_.DeviceOSType -match "Windows"}).Count
    AndroidDevices     = @($DeviceReport | Where-Object {$_.DeviceOSType -match "Android"}).Count
    IOSDevices         = @($DeviceReport | Where-Object {$_.DeviceOSType -match "iOS|iPhone|iPad"}).Count
}

$DeviceSummary |
    Export-Csv `
        -Path (Join-Path $OutputReports "Device-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Modulo 07 concluido." -ForegroundColor Green
Write-Host ""


# ============================================================
# MODULO 08 - ENTERPRISE APPLICATIONS / APP REGISTRATIONS
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 08 - APLICACOES E APP REGISTRATIONS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$Applications = @()
$ServicePrincipals = @()

try {
    Write-Host "Coletando App Registrations..." -ForegroundColor Yellow

    $Applications = @(
        Get-MgApplication -All `
            -Property `
                "Id",
                "AppId",
                "DisplayName",
                "CreatedDateTime",
                "SignInAudience",
                "PublisherDomain",
                "RequiredResourceAccess",
                "PasswordCredentials",
                "KeyCredentials" `
            -ErrorAction Stop
    )

    $ApplicationReport = $Applications | ForEach-Object {

        [PSCustomObject]@{
            Id                    = $_.Id
            AppId                 = $_.AppId
            DisplayName           = $_.DisplayName
            CreatedDateTime       = $_.CreatedDateTime
            SignInAudience        = $_.SignInAudience
            PublisherDomain       = $_.PublisherDomain
            PasswordCredentialCount = @($_.PasswordCredentials).Count
            KeyCredentialCount      = @($_.KeyCredentials).Count
            HasCredentials          = ((@($_.PasswordCredentials).Count + @($_.KeyCredentials).Count) -gt 0)
            CredentialExpirationDates = @(
                @($_.PasswordCredentials | ForEach-Object {$_.EndDateTime})
                @($_.KeyCredentials | ForEach-Object {$_.EndDateTime})
            ) -join "; "
        }
    }

    $ApplicationReport |
        Export-Csv `
            -Path (Join-Path $OutputRaw "App-Registrations-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "App Registrations encontrados: $($ApplicationReport.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao consultar App Registrations: $($_.Exception.Message)" -ForegroundColor Yellow
    $ApplicationReport = @()

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "App-Registrations-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

try {
    Write-Host "Coletando Enterprise Applications / Service Principals..." -ForegroundColor Yellow

    $ServicePrincipals = @(
        Get-MgServicePrincipal -All `
            -Property `
                "Id",
                "AppId",
                "DisplayName",
                "ServicePrincipalType",
                "AccountEnabled",
                "AppRoleAssignmentRequired",
                "Homepage",
                "PublisherName",
                "CreatedDateTime",
                "SignInAudience" `
            -ErrorAction Stop
    )

    $ServicePrincipalReport = $ServicePrincipals | ForEach-Object {

        [PSCustomObject]@{
            Id                       = $_.Id
            AppId                    = $_.AppId
            DisplayName              = $_.DisplayName
            ServicePrincipalType     = $_.ServicePrincipalType
            AccountEnabled           = $_.AccountEnabled
            AppRoleAssignmentRequired = $_.AppRoleAssignmentRequired
            Homepage                 = $_.Homepage
            PublisherName            = $_.PublisherName
            CreatedDateTime          = $_.CreatedDateTime
            SignInAudience           = $_.SignInAudience
        }
    }

    $ServicePrincipalReport |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Enterprise-Applications-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Enterprise Applications encontrados: $($ServicePrincipalReport.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao consultar Enterprise Applications: $($_.Exception.Message)" -ForegroundColor Yellow
    $ServicePrincipalReport = @()

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Enterprise-Applications-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

$ApplicationSummary = [PSCustomObject]@{
    AppRegistrations       = $ApplicationReport.Count
    EnterpriseApplications = $ServicePrincipalReport.Count
    AppsWithCredentials    = @(
        $ApplicationReport |
        Where-Object {$_.HasCredentials -eq $true}
    ).Count
    EnterpriseAppsDisabled = @(
        $ServicePrincipalReport |
        Where-Object {$_.AccountEnabled -eq $false}
    ).Count
    AssignmentRequiredApps = @(
        $ServicePrincipalReport |
        Where-Object {$_.AppRoleAssignmentRequired -eq $true}
    ).Count
}

$ApplicationSummary |
    Export-Csv `
        -Path (Join-Path $OutputReports "Application-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Modulo 08 concluido." -ForegroundColor Green
Write-Host ""


# ============================================================
# MODULO 09 - AUDITORIA / LOGS / ATIVIDADES
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 09 - AUDITORIA / LOGS / ATIVIDADES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# IMPORTANTE:
# Este modulo coleta uma amostra recente dos logs disponiveis
# no Microsoft Graph. Ele NAO altera configuracoes de auditoria.
# A disponibilidade/retencao depende da licenca e configuracao do tenant.

$AuditSignIns = @()
$AuditDirectory = @()

try {
    Write-Host "Coletando sign-ins recentes..." -ForegroundColor Yellow

    $AuditSignIns = @(
        Get-MgAuditLogSignIn `
            -Top 1000 `
            -ErrorAction Stop
    )

    $SignInReport = $AuditSignIns | ForEach-Object {

        [PSCustomObject]@{
            Id                   = $_.Id
            CreatedDateTime      = $_.CreatedDateTime
            UserDisplayName      = $_.UserDisplayName
            UserPrincipalName    = $_.UserPrincipalName
            UserId               = $_.UserId
            AppDisplayName       = $_.AppDisplayName
            ClientAppUsed        = $_.ClientAppUsed
            IpAddress            = $_.IpAddress
            ResourceDisplayName  = $_.ResourceDisplayName
            ConditionalAccessStatus = $_.ConditionalAccessStatus
            IsInteractive        = $_.IsInteractive
            RiskDetail           = $_.RiskDetail
            RiskLevelAggregated  = $_.RiskLevelAggregated
            RiskLevelDuringSignIn = $_.RiskLevelDuringSignIn
            StatusErrorCode      = $_.Status.ErrorCode
            StatusFailureReason  = $_.Status.FailureReason
            City                 = $_.Location.City
            State                = $_.Location.State
            Country              = $_.Location.CountryOrRegion
        }
    }

    $SignInReport |
        Export-Csv `
            -Path (Join-Path $OutputRaw "SignIns-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Sign-ins coletados: $($SignInReport.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao consultar sign-ins: $($_.Exception.Message)" -ForegroundColor Yellow
    $SignInReport = @()

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "SignIns-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

try {
    Write-Host "Coletando auditoria de diretorio recente..." -ForegroundColor Yellow

    $AuditDirectory = @(
        Get-MgAuditLogDirectoryAudit `
            -Top 1000 `
            -ErrorAction Stop
    )

    $DirectoryAuditReport = $AuditDirectory | ForEach-Object {

        [PSCustomObject]@{
            Id                = $_.Id
            ActivityDateTime  = $_.ActivityDateTime
            ActivityDisplayName = $_.ActivityDisplayName
            Category          = $_.Category
            Result            = $_.Result
            ResultReason      = $_.ResultReason
            InitiatedByUser   = $_.InitiatedBy.User.UserPrincipalName
            InitiatedByApp    = $_.InitiatedBy.App.DisplayName
            TargetCount       = @($_.TargetResources).Count
        }
    }

    $DirectoryAuditReport |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Directory-Audit-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host "Eventos de auditoria coletados: $($DirectoryAuditReport.Count)" -ForegroundColor Green
}
catch {
    Write-Host "Erro ao consultar auditoria de diretorio: $($_.Exception.Message)" -ForegroundColor Yellow
    $DirectoryAuditReport = @()

    [PSCustomObject]@{
        Status  = "Erro na consulta"
        Message = $_.Exception.Message
    } |
        Export-Csv `
            -Path (Join-Path $OutputRaw "Directory-Audit-Query-Error-$Timestamp.csv") `
            -NoTypeInformation `
            -Encoding UTF8
}

$AuditSummary = [PSCustomObject]@{
    SignInsCollected          = $SignInReport.Count
    FailedSignIns             = @(
        $SignInReport |
        Where-Object {$_.StatusErrorCode -ne 0}
    ).Count
    InteractiveSignIns        = @(
        $SignInReport |
        Where-Object {$_.IsInteractive -eq $true}
    ).Count
    NonInteractiveSignIns     = @(
        $SignInReport |
        Where-Object {$_.IsInteractive -eq $false}
    ).Count
    DirectoryAuditEvents      = $DirectoryAuditReport.Count
    SignInsWithRisk           = @(
        $SignInReport |
        Where-Object {
            $_.RiskLevelAggregated -and
            $_.RiskLevelAggregated -ne "none"
        }
    ).Count
}

$AuditSummary |
    Export-Csv `
        -Path (Join-Path $OutputReports "Audit-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Modulo 09 concluido." -ForegroundColor Green
Write-Host ""



# ------------------------------------------------------------
# ALIASES PARA CONSOLIDACAO
# ------------------------------------------------------------
# Mantemos nomes simples para o diagnostico final, sem alterar
# os dados coletados pelos modulos anteriores.

$ActiveUserCount = @($Users | Where-Object {$_.AccountEnabled -eq $true}).Count
$BlockedUserCount = @($Users | Where-Object {$_.AccountEnabled -eq $false}).Count
$LicensedUserCount = @($Users | Where-Object {@($_.AssignedLicenses).Count -gt 0}).Count
$UnlicensedUserCount = @($Users | Where-Object {@($_.AssignedLicenses).Count -eq 0}).Count

if (-not $PSBoundParameters.ContainsKey("TenantName")) {
    if (-not $TenantName) {
        try {
            $TenantName = (Get-MgOrganization -All | Select-Object -First 1).DisplayName
        }
        catch {
            $TenantName = "Tenant Microsoft 365"
        }
    }
}


if (-not $MfaCapableUserCount) {
    $MfaCapableUserCount = 0
    if ($MfaReport) {
        $MfaCapableUserCount = @(
            $MfaReport |
            Where-Object {$_.MfaCapableMethodCount -gt 0}
        ).Count
    }
}

# ============================================================
# MODULO 10 - CONSOLIDACAO DO DIAGNOSTICO
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 10 - CONSOLIDACAO DO DIAGNOSTICO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Este modulo nao "decide" sozinho o que e vulnerabilidade.
# Ele organiza indicadores objetivos para facilitar a analise.

$DiagnosticFindings = @()

function Add-DiagnosticFinding {
    param(
        [string]$Area,
        [string]$Severity,
        [string]$Finding,
        [string]$Evidence,
        [string]$Recommendation
    )

    $script:DiagnosticFindings += [PSCustomObject]@{
        Area           = $Area
        Severity       = $Severity
        Finding        = $Finding
        Evidence       = $Evidence
        Recommendation = $Recommendation
    }
}

# MFA / Security
if ($SecurityDefaultsEnabled -eq $false -and $ConditionalAccessPolicies.Count -eq 0) {

    Add-DiagnosticFinding `
        -Area "MFA / Identidade" `
        -Severity "Alto" `
        -Finding "Nao foi identificada uma politica de Conditional Access e Security Defaults esta desabilitado." `
        -Evidence "Security Defaults: False; Conditional Access policies: 0." `
        -Recommendation "Avaliar uma politica de MFA baseada em risco e perfil de usuario, considerando o porte e as necessidades da empresa."
}

# Global Administrators
if ($GlobalAdministrators.Count -gt 2) {

    Add-DiagnosticFinding `
        -Area "Privileged Access" `
        -Severity "Alto" `
        -Finding "Existem mais de dois Global Administrators." `
        -Evidence "Global Administrators encontrados: $($GlobalAdministrators.Count)." `
        -Recommendation "Revisar necessidade de cada conta e aplicar principio do menor privilegio."
}

# Users without license
if ($ActiveWithoutLicense.Count -gt 0) {

    Add-DiagnosticFinding `
        -Area "Licenciamento" `
        -Severity "Medio" `
        -Finding "Existem usuarios ativos sem licenca atribuida." `
        -Evidence "Usuarios ativos sem licenca identificados: $($ActiveWithoutLicense.Count)." `
        -Recommendation "Validar se sao contas de servico, caixas funcionais, convidados ou usuarios que realmente precisam de licenca."
}

# Mailboxes without archive
if ($ArchiveCount -eq 0 -and $UserMailboxCount -gt 0) {

    Add-DiagnosticFinding `
        -Area "Exchange Online" `
        -Severity "Baixo" `
        -Finding "Nenhuma caixa de usuario possui archive ativo." `
        -Evidence "User mailboxes: $UserMailboxCount; archives: $ArchiveCount." `
        -Recommendation "Avaliar necessidade de archive somente para usuarios com crescimento relevante de mailbox ou requisito de retencao."
}

# Groups without owners
if ($GroupSummary.GroupsWithoutOwners -gt 0) {

    Add-DiagnosticFinding `
        -Area "Colaboracao" `
        -Severity "Medio" `
        -Finding "Existem grupos sem proprietario identificado." `
        -Evidence "Grupos sem proprietario: $($GroupSummary.GroupsWithoutOwners)." `
        -Recommendation "Revisar grupos sem owner e definir responsavel antes de utilizacao operacional."
}

# Devices
if ($DeviceSummary.TotalDevices -gt 0 -and $DeviceSummary.ManagedDevices -eq 0) {

    Add-DiagnosticFinding `
        -Area "Dispositivos" `
        -Severity "Medio" `
        -Finding "Nao foram identificados dispositivos marcados como gerenciados pelo Entra ID." `
        -Evidence "Dispositivos: $($DeviceSummary.TotalDevices); gerenciados: $($DeviceSummary.ManagedDevices)." `
        -Recommendation "Validar como os computadores sao administrados atualmente e se existe necessidade de gerenciamento centralizado."
}

# Applications
if ($ApplicationSummary.AppsWithCredentials -gt 0) {

    Add-DiagnosticFinding `
        -Area "Aplicacoes" `
        -Severity "Baixo" `
        -Finding "Existem App Registrations com credenciais configuradas." `
        -Evidence "App Registrations com credenciais: $($ApplicationSummary.AppsWithCredentials)." `
        -Recommendation "Revisar credenciais, proprietarios e datas de expiracao para evitar credenciais esquecidas ou vencidas."
}

# Audit
if ($AuditSummary.SignInsCollected -eq 0) {

    Add-DiagnosticFinding `
        -Area "Auditoria" `
        -Severity "Medio" `
        -Finding "Nao foi possivel coletar sign-ins no momento da avaliacao." `
        -Evidence "Quantidade coletada: 0." `
        -Recommendation "Validar disponibilidade, permissao e retencao dos logs de sign-in."
}

$DiagnosticFindings |
    Export-Csv `
        -Path (Join-Path $OutputReports "Diagnostic-Findings-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

$DiagnosticSummary = $DiagnosticFindings |
    Group-Object Severity |
    Select-Object `
        @{Name="Severity";Expression={$_.Name}},
        @{Name="Count";Expression={$_.Count}} |
    Sort-Object Severity

$DiagnosticSummary |
    Export-Csv `
        -Path (Join-Path $OutputReports "Diagnostic-Summary-$Timestamp.csv") `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host "Achados identificados: $($DiagnosticFindings.Count)" -ForegroundColor Green
Write-Host ""


# ============================================================
# MODULO 11 - RELATORIO EXECUTIVO
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "MODULO 11 - RELATORIO EXECUTIVO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# O objetivo deste modulo e criar um resumo textual inicial.
# O relatorio visual/profissional sera refinado posteriormente
# com base nos dados reais encontrados no assessment.

$ExecutiveReportPath = Join-Path $OutputReports "Executive-Report-$Timestamp.txt"

$ExecutiveLines = @()

$ExecutiveLines += "============================================================"
$ExecutiveLines += "MICROSOFT 365 - ASSESSMENT EXECUTIVO"
$ExecutiveLines += "============================================================"
$ExecutiveLines += ""
$ExecutiveLines += "Tenant : $TenantName"
$ExecutiveLines += "Data   : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "IDENTIDADE"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "Usuarios totais       : $($Users.Count)"
$ExecutiveLines += "Usuarios ativos       : $ActiveUserCount"
$ExecutiveLines += "Usuarios bloqueados   : $BlockedUserCount"
$ExecutiveLines += "Usuarios licenciados  : $LicensedUserCount"
$ExecutiveLines += "Usuarios sem licenca  : $UnlicensedUserCount"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "LICENCIAMENTO"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "SKUs encontrados      : $($SkuReport.Count)"
$ExecutiveLines += "Registros de licenca  : $($UserLicenseDetails.Count)"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "EXCHANGE"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "User Mailboxes        : $UserMailboxCount"
$ExecutiveLines += "Shared Mailboxes      : $SharedMailboxCount"
$ExecutiveLines += "Room Mailboxes        : $RoomMailboxCount"
$ExecutiveLines += "Discovery Mailboxes   : $DiscoveryMailboxCount"
$ExecutiveLines += "Archives ativos       : $ArchiveCount"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "SEGURANCA"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "Security Defaults     : $SecurityDefaultsEnabled"
$ExecutiveLines += "Conditional Access    : $($ConditionalAccessPolicies.Count)"
$ExecutiveLines += "MFA-capable identificado: $MfaCapableUserCount"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "PRIVILEGED ACCESS"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "Directory Roles       : $($DirectoryRoles.Count)"
$ExecutiveLines += "Assignments           : $($RoleReport.Count)"
$ExecutiveLines += "Global Administrators : $($GlobalAdministrators.Count)"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "COLABORACAO"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "Grupos                : $($GroupSummary.TotalGroups)"
$ExecutiveLines += "Microsoft 365 Groups  : $($GroupSummary.Microsoft365Groups)"
$ExecutiveLines += "Teams detectados      : $($GroupSummary.TeamsDetected)"
$ExecutiveLines += "Sites SharePoint      : $($GroupSummary.SharePointSites)"
$ExecutiveLines += "OneDrive com Drive    : $($GroupSummary.OneDriveUsersWithDrive)"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "DISPOSITIVOS"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "Dispositivos          : $($DeviceSummary.TotalDevices)"
$ExecutiveLines += "Gerenciados           : $($DeviceSummary.ManagedDevices)"
$ExecutiveLines += "Compliant             : $($DeviceSummary.CompliantDevices)"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "APLICACOES"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "App Registrations     : $($ApplicationSummary.AppRegistrations)"
$ExecutiveLines += "Enterprise Apps       : $($ApplicationSummary.EnterpriseApplications)"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "AUDITORIA"
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "Sign-ins coletados    : $($AuditSummary.SignInsCollected)"
$ExecutiveLines += "Falhas de login       : $($AuditSummary.FailedSignIns)"
$ExecutiveLines += "Eventos de diretorio  : $($AuditSummary.DirectoryAuditEvents)"
$ExecutiveLines += ""
$ExecutiveLines += "------------------------------------------------------------"
$ExecutiveLines += "ACHADOS"
$ExecutiveLines += "------------------------------------------------------------"

if ($DiagnosticFindings.Count -eq 0) {
    $ExecutiveLines += "Nenhum achado automatico foi identificado."
}
else {
    foreach ($Finding in $DiagnosticFindings) {
        $ExecutiveLines += "[$($Finding.Severity)] $($Finding.Area) - $($Finding.Finding)"
        $ExecutiveLines += "  Evidencia: $($Finding.Evidence)"
        $ExecutiveLines += "  Recomendacao: $($Finding.Recommendation)"
        $ExecutiveLines += ""
    }
}

$ExecutiveLines |
    Set-Content `
        -Path $ExecutiveReportPath `
        -Encoding UTF8

Write-Host "Relatorio executivo criado:" -ForegroundColor Green
Write-Host "$ExecutiveReportPath" -ForegroundColor DarkGray
Write-Host ""
Write-Host "TODOS OS 11 MODULOS FORAM EXECUTADOS." -ForegroundColor Green
Write-Host ""



# ============================================================
# GERACAO DOS ENTREGAVEIS
# ============================================================
# O PowerShell coleta os dados.
# O Python transforma os CSVs em Excel + Word + PowerPoint.
# Nenhuma chamada abaixo altera o tenant.

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " GERANDO ENTREGAVEIS EXECUTIVOS" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$PythonCommand = Get-Command python -ErrorAction SilentlyContinue

if ($PythonCommand) {

    $ReportScript = Join-Path $PSScriptRoot "M365-Assessment-Report.py"

    if (Test-Path $ReportScript) {

        Write-Host "Chamando gerador Python..." -ForegroundColor Yellow

        & $PythonCommand.Source $ReportScript `
            --project-root $ProjectRoot

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Excel, Word e PowerPoint gerados com sucesso." -ForegroundColor Green
        }
        else {
            Write-Host ""
            Write-Host "ATENCAO: a coleta terminou, mas o gerador de relatorios retornou erro." -ForegroundColor Yellow
            Write-Host "Os CSVs em output\raw continuam disponiveis." -ForegroundColor Yellow
        }

    }
    else {
        Write-Host "Gerador Python nao encontrado: $ReportScript" -ForegroundColor Yellow
    }

}
else {

    Write-Host ""
    Write-Host "ATENCAO: Python nao foi encontrado no PATH." -ForegroundColor Yellow
    Write-Host "A coleta foi concluida e os CSVs continuam disponiveis." -ForegroundColor Yellow
    Write-Host "Instale Python e execute M365-Assessment-Report.py para gerar os entregaveis." -ForegroundColor Yellow
}


# ============================================================
# RESUMO FINAL
# ============================================================

$EnabledUsers  = @($Users | Where-Object {$_.AccountEnabled -eq $true}).Count
$DisabledUsers = @($Users | Where-Object {$_.AccountEnabled -eq $false}).Count

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " RESUMO FINAL" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total de usuarios : $($Users.Count)"
Write-Host "Contas ativas     : $EnabledUsers"
Write-Host "Contas bloqueadas : $DisabledUsers"
Write-Host "Mailboxes         : $($Mailboxes.Count)"
Write-Host "User Mailboxes    : $($UserMailboxes.Count)"
Write-Host "Shared Mailboxes  : $($SharedMailboxes.Count)"
Write-Host "SKUs              : $($SkuReport.Count)"
Write-Host ""

Write-Host "Coleta concluida." -ForegroundColor Green
Write-Host "Nenhuma alteracao foi realizada no tenant." -ForegroundColor Green
Write-Host ""
