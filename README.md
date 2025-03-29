Gere um relatório completo das caixas de correio do Exchange Online com informações sobre:

Nome e UPN do usuário

Tamanho da Inbox e do Arquivo Morto (Archive)

Data de criação da caixa

Data do último acesso

Licenças atribuídas (com nome comercial!)

✉️ Ideal para quem quer fazer uma auditoria de uso, otimizar licenças e reduzir custos no Microsoft 365.

🚀 Pré-requisitos

Antes de rodar o script, instale e configure:

1. PowerShell 7+

Baixe aqui: https://github.com/PowerShell/PowerShell

2. Instale os módulos necessários:

Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module Microsoft.Graph -Scope CurrentUser

3. Conecte-se ao Microsoft 365:

# Conectar ao Exchange Online
Connect-ExchangeOnline

# Conectar ao Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All"

🛠️ Como usar

Clone este repositório ou copie o script Mailbox_Report.ps1

Execute o script após realizar a conexão com os serviços

O resultado será salvo na sua área de trabalho como Mailbox_Report.csv

📁 Arquivo gerado

O script gera um arquivo .csv compatível com Excel, ideal para análise, BI ou auditoria.

Local padrão de saída: C:\Users\<seu_usuario>\Desktop\Mailbox_Report.csv


