# Metodologia

## Princípio

O assessment segue o modelo:

**Coletar → Preservar evidência → Cruzar dados → Identificar riscos → Recomendar**

A coleta é somente leitura.

## Componentes

### PowerShell

Responsável pela coleta no Microsoft Graph e Exchange Online e pela gravação dos CSVs em `output/raw`.

### Python

Responsável por:

- carregar os CSVs;
- cruzar usuários, licenças, MFA, mailbox e privilégios;
- gerar indicadores;
- gerar Excel, Word e PowerPoint.

## Evidência

Os CSVs originais são preservados em `output/raw`.

O timestamp da coleta faz parte do nome dos arquivos e permite relacionar os conjuntos de dados de uma mesma execução.

## Interpretação

O relatório separa fatos coletados de conclusões que precisam de validação. Em especial:

- MFA identificado ≠ MFA necessariamente exigido;
- service principal ≠ aplicação de negócio;
- usuário sem licença ≠ usuário que deve ser excluído;
- conta bloqueada ≠ conta que deve ser imediatamente removida.

## Boas práticas

1. Rodar primeiro em modo read-only.
2. Validar achados com o responsável pelo ambiente.
3. Não executar limpeza automática baseada apenas nos números do relatório.
4. Classificar objetos antes de excluir ou alterar.
5. Guardar os RAW de cada assessment em local protegido.
