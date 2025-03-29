# 📬 Relatório de Caixas Exchange Online com Custo de Licenciamento M365

Este script PowerShell gera um relatório completo de caixas do Exchange Online, com informações úteis de uso e licenciamento para auxiliar em decisões de otimização e economia de licenças Microsoft 365.

## ✨ Informações geradas por usuário

- Nome
- UPN (User Principal Name)
- Tamanho da caixa (Inbox)
- Tamanho do arquivo morto (Archive)
- Data de criação
- Último acesso
- Licenças atribuídas (nomes comerciais)
- Custo mensal estimado

---

## ✅ Pré-requisitos

- PowerShell 7 (obrigatório) → [https://aka.ms/powershell](https://aka.ms/powershell)
- Módulos instalados:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
```

- Importação dos módulos (necessário sempre na primeira execução do PowerShell):

```powershell
Import-Module ExchangeOnlineManagement
Import-Module Microsoft.Graph.Users
```

---

## 🔌 Conexão antes de rodar

```powershell
Connect-ExchangeOnline
Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All"
```

---

## ▶️ Como usar

1. Clone este repositório ou baixe o arquivo `mailbox_report.ps1`
2. Execute no PowerShell 7 após realizar as conexões acima
3. O arquivo será salvo automaticamente na área de trabalho como:

```
Mailbox_Report.csv
```

---

## 🛠️ Autor

**Paulo Henrique Rodrigues**  
📅 Março/2025
