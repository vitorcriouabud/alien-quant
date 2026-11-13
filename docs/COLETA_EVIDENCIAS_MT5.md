# ALIEN LAB — Coleta de CSV e evidencias MT5

## Objetivo

Coletar sem instalar servicos extras os CSVs do ALIEN Observer, o
EXPERIMENTOS.csv do runner e relatorios HTML do Strategy Tester.
Os arquivos sao colocados em um unico ZIP com inventario e SHA256 para
analise posterior. **Nenhum arquivo e enviado automaticamente ao ChatGPT
ou ao GitHub.** O assistente nao pode receber anexos por iniciativa do
programa local sem um canal de upload autorizado.

## Uso em Windows

1. Abra a pasta clonada do projeto \`alien-quant\`.
2. Execute duas vezes \`tools\COLETAR_CSV_MT5.cmd\`.
3. Procure \`PACOTES_MT5\ALIEN_EVIDENCIAS_AAAAMMDD_HHMMSS.zip\`.
4. Revise os dados (conta/corretora podem aparecer nos arquivos).
5. Anexe o ZIP no ChatGPT e solicite a auditoria do experimento.

O arquivo .cmd usa o Python 3 ja instalado e **nao abre MT5, nao executa
robos, nao modifica parametros nem coloca ordens**.

Exemplos no prompt do Windows:

\`\`\`bat
tools\COLETAR_CSV_MT5.cmd --days 0
tools\COLETAR_CSV_MT5.cmd --source "C:\ALIEN_TEST_MT5\Tester" --days 0
tools\COLETAR_CSV_MT5.cmd --source "C:\Pasta\Relatorios" --include-logs
\`\`\`

Sem \`--source\`, o coletor tenta encontrar:
- \`results/\`, \`REPORTS/\`, \`EXPERIMENTOS.csv\` no repositorio;
- diretorio legado \`ALIEN_LAB\` no notebook;
- \`%APPDATA%\MetaQuotes\Terminal\*\MQL5\Files\` e \`Tester\`;
- \`%APPDATA%\MetaQuotes\Tester\` (agentes);
- instalacao portatil \`C:\ALIEN_TEST_MT5\`.

Padrao: arquivos alterados nos ultimos 30 dias; ate 800 arquivos,
250 MB por arquivo. O ZIP e criado localmente com \`manifest.json\`,
\`INVENTARIO.csv\` e arquivos originais. \`--days 0\` inclui todos,
e \`--include-logs\` inclui logs, opcionalmente.

## Como relacionar coleta com um experimento

O projeto ja possui \`tools/Run-Backtest.ps1\` e
\`tools/parse_and_record_results.py\`. Eles executam/interpretam relatorios,
mas dependem de caminhos e configuracoes do notebook. O coletor **nao
substitui** esses mecanismos: somente empacota o que de fato existe no disco.

Cada teste deve registrar: EXP_ID, commit/arquivo .mq5, hash SHA256,
arquivo .set, simbolo, corretora, periodo, timezone servidor, modelo de
ticks, spread, comissao, slippage, deposito, lote, e arquivos originais.
Nao aceitar "PF", "lucro" ou "taxa de acerto" escritos em README sem
o HTML/CSV primario correspondente. Se o resultado contiver zero trades,
registrar explicitamente como zero.

## Segurança

O repositorio \`alien-quant\` e PUBLICO. Nao subir ZIPs, CSVs crus, dados
de conta nem logs sem examinar. \`.gitignore\` ja ignora \`*.csv\` e
\`*.zip\`; mantenha pacotes privados no notebook. Nao executar o EA SMC
em conta real antes de validacao de risco, compilacao e testes controlados.

Para eu ler resultados automaticamente **a partir do GitHub**, sera
necessario configurar uma publicacao seletiva/autorizada de evidencias
sanitizadas para o repositorio. Esta entrega **nao** ativa publicacao
automaticamente para evitar vazamento de dados financeiros.
