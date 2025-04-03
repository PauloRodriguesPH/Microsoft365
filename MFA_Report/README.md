📋 Relatório de Status de MFA no Microsoft 365

Este repositório contém um script em PowerShell para listar todos os usuários licenciados do Microsoft 365 e verificar se eles possuem MFA (Autenticação Multifator) habilitado.

🧾 Objetivo

O script mfa_status_report.ps1 tem como objetivo gerar um relatório prático e rápido com os seguintes dados:

Nome do usuário

UPN (User Principal Name)

Status do MFA: Habilitado ou Desabilitado

O resultado é exportado automaticamente em CSV para a área de trabalho do usuário.

✅ Requisitos

PowerShell 5 ou superiorRecomenda-se o uso do PowerShell 5 com ISE para melhor compatibilidade com o módulo MSOnline.

Módulo MSOnline instalado:

Install-Module MSOnline -Scope CurrentUser

Obs: Pode ser necessário executar Set-ExecutionPolicy RemoteSigned -Scope CurrentUser para permitir a execução de scripts.

🔌 Conexão com Microsoft 365

Antes de rodar o script, é necessário autenticar-se:

Connect-MsolService

▶️ Como usar

Clone ou baixe este repositório

Execute o script mfa_status_report.ps1 no PowerShell 5

O resultado será salvo automaticamente na sua área de trabalho com o nome:

Usuarios_MFA_Status.csv

💡 Exemplo de saída (PowerShell)

[1/150] Renata Souza <renata@empresa.com.br> - MFA: Habilitado
[2/150] Carlos Lima <carlos@empresa.com.br> - MFA: Desabilitado
[3/150] Juliana Castro <juliana@empresa.com.br> - MFA: Habilitado

📄 Exemplo do CSV gerado

Nome

UPN

MFA

Renata Souza

renata@empresa.com.br

Habilitado

Carlos Lima

carlos@empresa.com.br

Desabilitado

Juliana Castro

juliana@empresa.com.br

Habilitado


📁 Arquivos

mfa_status_report.ps1: script principal

Usuarios_MFA_Status_Exemplo.csv: exemplo de saída

🛡️ Aviso

O módulo MSOnline é considerado legado pela Microsoft, mas ainda é o mais confiável para verificação de MFA em escala. Para futuras versões, recomenda-se migrar para Microsoft Graph.

🛠️ Autor
Paulo Henrique Rodrigues
📅 Março/2025

