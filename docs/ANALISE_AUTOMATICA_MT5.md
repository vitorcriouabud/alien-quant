# ALIEN LAB — Análise automática a cada coleta MT5

Este laboratório **não executa ordens, não modifica EAs e não envia arquivos para a internet**.
O repositório é público: mantenha CSVs/HTML/ZIP de contas **apenas no notebook**.

## Uso com um clique (Windows)

1. Mantenha o repositório em uma pasta local, com Python 3 disponível.
2. Execute `tools\COLETAR_E_ANALISAR_MT5.cmd`.
3. O coletor descobre arquivos CSV/HTML do MT5, gera `PACOTES_MT5\ALIEN_EVIDENCIAS_*.zip` com `manifest.json` e SHA256.
4. O analisador verifica cada hash e gera uma pasta nova em `RELATORIOS_MT5\ALIEN_EVIDENCIAS_AAAAMMDD_HHMMSS\`.
5. Abra o relatório HTML gerado e anexe o ZIP bruto nesta conversa se quiser uma investigação detalhada dos negócios.

Saídas: `ALIEN_AUDITORIA.html`, `ALIEN_AUDITORIA.md`, `ALIEN_AUDITORIA.json` e `ALIEN_COMPARATIVO.csv`.

Para todas as datas, execute `tools\COLETAR_E_ANALISAR_MT5.cmd --days 0`.

## Sem execução de backtests

Este automatizador **analisa relatórios que já existem**. Ele não roda Strategy Tester. O runner existente é `tools/Run-Backtest.ps1`, que exige MT5 instalado e caminhos configurados no notebook. O CSV e o HTML do Tester devem sempre ser preservados.

## O que é comparado

- Métricas oficiais do HTML MT5: lucro líquido, PF, DD de equity, número de negociações, período, corretora, expert e símbolo.
- ID de experimento no nome do arquivo versus `EXPERIMENTOS.csv`.
- SHA256 do material coletado; nomes de relatórios iguais ou ID reutilizado.
- Impressão digital de parâmetros registrados no HTML, inclusive comparação ignorando parâmetros de painel/visual.
- CSV do observador **somente XAUUSD**, separadamente de AUDCAD, e principais motivos de `ABSTER`.
- CSV TURBO de bloqueios versus envios registrados. **Tentativas não são negócios comprovados**.
- Arquivos V10.89 de trades vazios (só cabeçalho).

## Limitações

- Se os inputs de negociação parecem iguais e o resultado difere, o alerta é de **não reprodutibilidade**, não de fraude nem de lucro garantido.
- O HTML do MT5 não documenta necessariamente o hash do `.ex5`, estado de `GlobalVariable`, ticks distribuídos, comissões reais e intermediários.
- Somente comparar lucro/PF de testes na **mesma janela, conta-modelo, broker, ativo, custos e código**, identificando divergências.
- Não incluir contas/números pessoais ou caminhos locais nos relatórios que forem publicados.
- `--latest` escolhe o último ZIP da pasta; não monitora o MT5 em tempo real. Para cada rodada, execute o `.cmd` novamente.

## Validação sem MetaEditor

```bat
python -m unittest discover -s tests -p test_analyze_mt5_evidence.py -v
```

Compilação do EA e testes MT5 continuam sendo atividades separadas no notebook.
