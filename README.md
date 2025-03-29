# 📊 Relatório de Caixas Exchange Online com Licenciamento M365

Este script PowerShell permite gerar um relatório completo de caixas do Exchange Online, incluindo:

- Nome do usuário
- UPN
- Tamanho da inbox
- Tamanho do arquivo morto (archive)
- Data de criação da caixa
- Último acesso
- Licenças atribuídas (com nomes comerciais)

---

## ⚙️ Pré-requisitos

- PowerShell 7
  → Baixar: [https://aka.ms/powershell](https://aka.ms/powershell)
- Módulo `ExchangeOnlineManagement`
- Módulo `Microsoft.Graph.Users`

---

### 📥 Instalação dos módulos (executar apenas uma vez)

```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
Install-Module -Name Microsoft.Graph -Scope CurrentUser
