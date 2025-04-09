# 🔐 Relatório de Status de MFA no Microsoft 365

Este repositório contém um script em PowerShell para listar todos os usuários licenciados do Microsoft 365 e verificar se eles possuem MFA (Autenticação Multifator) habilitado.

## 📄 Objetivo

O script `mfa_report.ps1` tem como objetivo gerar um relatório prático com os seguintes dados:

- Nome do usuário
- UPN (User Principal Name)
- Status do MFA: Habilitado ou Desabilitado

O resultado é exportado automaticamente em CSV para a área de trabalho do usuário.

## ✅ Requisitos

- PowerShell 5 (não funciona no PowerShell 7)  
  💡 *Recomenda-se o uso do PowerShell 5 **em console** (não ISE), especialmente se sua conta exigir MFA.*

- Módulo MSOnline instalado:

```powershell
Install-Module MSOnline -Scope CurrentUser
```

📌 Pode ser necessário executar:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🔌 Conexão com Microsoft 365

Antes de rodar o script, conecte-se ao tenant com:

```powershell
Connect-MsolService
```

Será aberta uma janela de login.

## ▶️ Como usar

1. Abra o PowerShell 5 como administrador.
2. Execute o script:

```powershell
.\mfa_report.ps1
```

3. O resultado será salvo como `mfa_report.csv` na sua área de trabalho.

## 🧪 Exemplo de saída no PowerShell

```
[1/3] Renata Souza <renata@empresa.com.br> - MFA: Habilitado
[2/3] Carlos Lima <carlos@empresa.com.br> - MFA: Desabilitado
[3/3] Julia Freitas <julia@empresa.com.br> - MFA: Habilitado
```

## 📁 Exemplo do arquivo CSV

| Nome         | UPN                    | MFA         |
|--------------|------------------------|-------------|
| Renata Souza | renata@empresa.com.br  | Habilitado  |
| Carlos Lima  | carlos@empresa.com.br  | Desabilitado|
| Julia Freitas| julia@empresa.com.br   | Habilitado  |

---

🚨 **Importante:**  
Este script utiliza o módulo **MSOnline**, que é legado. Embora ainda funcional, a Microsoft recomenda a migração futura para os módulos do Microsoft Graph.

Este relatório verifica o status de MFA baseado na propriedade StrongAuthenticationMethods, que indica se o MFA foi habilitado manualmente por usuário.
Ele não detecta MFA exigido por políticas de Acesso Condicional (Conditional Access).
Portanto, um usuário pode estar “Sem MFA” neste relatório, mas ainda assim ser obrigado a usá-lo no login por política global da empresa.
---

## 🛠️ Autor

**Paulo Henrique Rodrigues**  
📅 Março/2025

