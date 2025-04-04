# 📋 Retention Report – Exchange Online

Este script PowerShell gera um relatório com todos os usuários licenciados do Exchange Online e exibe qual política de retenção de MRM está aplicada em cada caixa de correio.

## ✅ Objetivo
Listar os usuários do tipo `UserMailbox` (com licença) e retornar a política de retenção atribuída, exportando para um CSV.

## 📎 Requisitos

- PowerShell 7 (obrigatório) → [https://aka.ms/powershell](https://aka.ms/powershell)
- Módulo ExchangeOnlineManagement instalado:
  ```powershell
  Install-Module ExchangeOnlineManagement
  ```
- .NET Runtime 6.0 ou superior instalado (requisito do PowerShell 7)

## 🔐 Conexão necessária
Antes de executar o script, conecte ao Exchange Online:
```powershell
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline
```

## 🚀 Como usar

1. Clone ou baixe este repositório.
2. Execute o script `retention_report.ps1` com o PowerShell 7.
3. O resultado será salvo automaticamente na sua Área de Trabalho como:
   ```
   retention_report.csv
   ```

## 📄 Exemplo de saída
| Nome          | UPN                    | Política                         |
|---------------|------------------------|----------------------------------|
| Renata Souza  | renata@empresa.com.br  | Default 6 month move to archive |
| Carlos Silva  | carlos@empresa.com.br  | Personal 1 year delete           |
| Marina Alves  | marina@empresa.com.br  |                                  |

---

## 🛠️ Autor

**Paulo Henrique Rodrigues**  
📅 Março/2025

