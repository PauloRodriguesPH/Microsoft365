# Microsoft 365 Assessment Toolkit

Toolkit para realizar um **assessment somente leitura** de um ambiente Microsoft 365, com foco em Entra ID, Exchange Online, identidade, licenciamento, autenticação, privilégios, grupos, dispositivos, aplicações e auditoria.

A solução separa o trabalho em duas etapas:

1. **PowerShell (`M365-Assessment.ps1`)**  
   Conecta ao Microsoft Graph e ao Exchange Online e coleta os dados em CSV.
2. **Python (`M365-Assessment-Report.py`)**  
   Lê os CSVs e gera os entregáveis em Excel, Word e PowerPoint.

> **Importante:** o toolkit foi projetado para coleta/avaliação. Ele não foi criado para alterar usuários, grupos, políticas, licenças ou configurações do tenant.

## Estrutura

```text
M365-Assessment-Toolkit/
├── README.md
├── LICENSE
├── requirements.txt
├── setup.ps1
├── run.ps1
├── .gitignore
├── scripts/
│   ├── M365-Assessment.ps1
│   └── M365-Assessment-Report.py
├── output/
│   ├── raw/
│   └── reports/
├── examples/
│   ├── raw/
│   └── reports/
└── docs/
    └── METODOLOGIA.md
```

## Pré-requisitos

### Windows

Recomendado:

- Windows 10/11 ou Windows Server compatível com os módulos utilizados.
- **PowerShell 7+** (`pwsh`) recomendado.
- Python 3.x.
- Acesso à Internet durante a instalação e durante a coleta.
- Conta com permissões suficientes para os escopos Microsoft Graph solicitados e acesso ao Exchange Online.
- VS Code é **opcional**. Pode ser usado para editar/visualizar os scripts, mas não é necessário para executar o toolkit.

### Microsoft PowerShell modules

O collector utiliza:

- `Microsoft.Graph`
- `ExchangeOnlineManagement`

### Bibliotecas Python

O gerador utiliza:

- `pandas`
- `openpyxl`
- `python-docx`
- `python-pptx`

## Instalação

### 1. Instalar PowerShell 7

Baixe o PowerShell 7 pelo site oficial da Microsoft.

Depois confirme:

```powershell
pwsh --version
```

Também é possível executar o script a partir do PowerShell 7 aberto normalmente.

### 2. Instalar Python

Instale Python 3.x pelo site oficial do Python.

Durante a instalação no Windows, marque:

```text
Add Python to PATH
```

Confirme:

```powershell
python --version
python -m pip --version
```

### 3. VS Code (opcional)

O Visual Studio Code é recomendado para estudar/editar os scripts, mas não é requisito de execução.

### 4. Instalar os pré-requisitos do projeto

Na raiz do projeto:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\setup.ps1
```

O `setup.ps1` instala os módulos PowerShell e as bibliotecas Python.

## Execução

### Coleta completa

A partir da raiz:

```powershell
.\run.ps1
```

Ou diretamente:

```powershell
.\scripts\M365-Assessment.ps1
```

O script solicitará autenticação por código de dispositivo quando necessário.

### Gerar relatórios novamente sem nova coleta

Se os CSVs já estiverem em `output\raw`, rode:

```powershell
python .\scripts\M365-Assessment-Report.py
```

Isso é útil para ajustar o relatório sem consultar novamente o tenant.

## Fluxo

```text
Microsoft 365
     │
     ▼
M365-Assessment.ps1
     │
     ├── Entra ID / Graph
     ├── Exchange Online
     └── CSVs
          │
          ▼
     output/raw
          │
          ▼
M365-Assessment-Report.py
          │
          ├── Excel
          ├── Word
          └── PowerPoint
          │
          ▼
     output/reports
```

## O que é coletado

Entre os conjuntos avaliados:

- Usuários e status das contas
- Último login disponível no Entra ID
- Licenças por usuário
- SKUs e consumo
- Mailboxes
- Estatísticas de mailbox
- Shared/Room/Discovery mailboxes
- MFA / métodos de autenticação identificáveis
- Security Defaults
- Conditional Access
- Directory Roles e privilégios
- Grupos, membros e owners
- Teams
- OneDrive
- Dispositivos
- App Registrations
- Enterprise Applications / service principals
- Sign-ins
- Directory Audit
- Usuários ativos sem licença
- Usuários ativos sem sign-in

## Entregáveis

O relatório gera:

### Excel

Dashboard executivo e abas detalhadas para investigação técnica.

### Word

Resumo executivo com:

- panorama
- principais achados
- pontos que precisam de validação
- recomendações iniciais
- metodologia/entregáveis

### PowerPoint

Apresentação executiva resumindo:

- panorama
- segurança
- privilégios
- governança
- dispositivos/aplicações
- prioridades

## Segurança e privacidade

O conteúdo de `output/raw` pode conter informações do tenant, usuários, UPNs, IDs e outros dados administrativos.

**Não faça commit dos dados reais do cliente.**

Por isso o `.gitignore` bloqueia:

```text
/output/raw/*
/output/reports/*
```

Os arquivos dentro de `examples/` são dados sintéticos destinados apenas a demonstração.

## Observações importantes

- A presença de um método MFA-capable não significa, sozinha, que MFA esteja sendo exigido.
- A ausência de um método identificado não prova que MFA não seja aplicado por outro mecanismo.
- Enterprise Applications / service principals não equivalem à quantidade de aplicações de negócio.
- Usuários sem licença precisam ser classificados antes de qualquer decisão de otimização.
- Usuários bloqueados não devem ser excluídos automaticamente.
- Dados de Exchange e Entra podem ter campos de atividade com significados diferentes.
- O custo financeiro das assinaturas não deve ser inferido somente a partir do consumo de SKU; valide no Microsoft 365 Admin Center/faturamento.

## Exemplo de saída

Consulte:

```text
examples/reports/
```

Os relatórios de exemplo foram gerados a partir de **dados sintéticos**, não de um tenant real.

## Licença

MIT. Veja `LICENSE`.

## Contribuições

Pull requests e melhorias são bem-vindos. Antes de adicionar novos coletores, mantenha o princípio de **read-only por padrão** e documente os novos escopos/permissões.
