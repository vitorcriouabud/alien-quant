# ALIEN QUANT — Laboratorio de evidencias para XAUUSD/MT5

> **Status:** desenvolvimento e pesquisa. Nenhum EA e declarado lucrativo ou aprovado para operacao real por este README.

## Onde encontrar cada coisa

| Diretorio/arquivo | Funcao |
|---|---|
| `MQL5/Experts/` | Versoes operacionais de pesquisa; **nao editar sem experimento** |
| `MQL5/Experts/preservados/` | V10.89 e outras referencias historicas |
| `MQL5/Indicators/ALIEN_Observer.mq5` | Sinais e CSV em modo observacao |
| `tools/Run-Backtest.ps1` | Runner do Strategy Tester; requer MT5 no Windows configurado |
| `tools/parse_and_record_results.py` | Parser do HTML de testes ja existente |
| `tools/COLETAR_CSV_MT5.cmd` | **Um clique:** empacota CSV/HTML do MT5 num ZIP local |
| `tools/collect_mt5_evidence.py` | Coletor com `manifest.json` e SHA256 de cada arquivo |
| `docs/COLETA_EVIDENCIAS_MT5.md` | Como gerar e compartilhar evidencias com ChatGPT |
| `docs/SMC_LIQUIDITY_AUDITORIA_2026-11-13.md` | Comparacao estatica do SMC Liquidity com ALIEN V12.1 |
| `ESTADO_ATUAL.md` | **Historico narrativo** — nao substitui arquivos MT5 primarios |
| `DECISOES.md` | Decisoes ja documentadas, sujeitas a verificacao no codigo |

## Fluxo de pesquisa

1. Congelar codigo, preset e custo de execucao para cada `EXP_ID`.
2. Rodar Strategy Tester MT5 isolado, sem mexer no terminal real.
3. Executar `tools/COLETAR_CSV_MT5.cmd` e guardar o ZIP.
4. Conferir relatorio HTML + CSV + hashes; se faltarem, resultado nao e validado.
5. Comparar somente experimentos em mesmas condicoes e **fora da amostra**.
6. Abrir PR para implementar mudancas de estrategia; nao mexer em versoes preservadas.

**Privacidade:** este repositorio e publico. O coletor nao faz upload automatico de arquivos de conta/corretora.

## Auditoria automatica de evidencias MT5

Execute `tools/COLETAR_E_ANALISAR_MT5.cmd` no Windows com Python 3 instalado. O programa coleta CSV e HTML de backtest, confere SHA256, gera resumo HTML/Markdown/JSON/CSV e identifica divergencias de resultados em `RELATORIOS_MT5/`. Nao realiza ordens ou upload. Consulte [`docs/ANALISE_AUTOMATICA_MT5.md`](docs/ANALISE_AUTOMATICA_MT5.md). Relatorios brutos e pacotes nao devem ser publicados no repositorio publico.
