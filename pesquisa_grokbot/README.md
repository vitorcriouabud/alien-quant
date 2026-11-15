# Pesquisa Grok Bot — 14–15/11/2026

Esta pasta reúne a pesquisa quantitativa feita no box do Grok Bot (código, relatórios em português e resumos CSV), o robô de índices `ALIEN_INDICES_V1` e o kit de teste em um clique da V11.

**Branch:** `pesquisa-grokbot-20261115` (PR em rascunho). Nada disto foi mesclado na `main`. Os arquivos da V11 que já estão na `main` **não foram alterados**.

## Resultado em uma página

- Cerca de **2.350 tentativas** em ouro, câmbio, índices, petróleo e prata. Quase todas reprovadas depois do custo real.
- A **V11 com ticks reais não tem vantagem**. O lucro que aparece com ticks gerados pelo testador não se confirma. Cinco correções (F1–F5) também foram reprovadas. Ver `alien-research/REAL_TICKS_V11.md` e `DIAGNOSTICO_V11.md`.
- A única regra que passou é a **cesta de índices** (RSI2 + IBS em US500, Nasdaq e DAX). Um **bug no cálculo do swap** (cerca de 1.000 vezes menor que o real) fazia a pesquisa parecer ~6,2% ao ano. Com o swap real da RoboForex, o testador do MT5 deu cerca de **3,8% ao ano**, queda máxima ~7–8%. O swap comeu quase 40% do lucro bruto. 2025 e 2026 ficaram praticamente no zero. Ver `alien-indices/TESTE.md`.
- Revisão de todos os repositórios GitHub da conta: `alien-research/REVISAO_REPOS.md`.

## O que tem aqui

- `alien-research/` — relatórios `.md`, código Python/MQL de pesquisa, scripts e CSVs-resumo.
- `alien-indices/` — EA `ALIEN_INDICES_V1.mq5`, `.set`, README e ferramentas de análise. Relatórios enormes do MT5 ficaram de fora (só a análise está no `TESTE.md`).
- `kit_teste_1clique/` — kit Windows para rodar o teste da V11 com ticks reais (não opera na conta).

## O que ficou de fora (de propósito)

- Pasta `data/` e qualquer `.parquet` / `.pkl` (ticks, barras Dukascopy, trades brutos).
- Relatórios HTML/PNG grandes do testador, logs e CSVs de fita de trades.
- `.ex5` compilados, `.venv`, `__pycache__`.
- Senhas (a senha da demo **nunca** entra aqui). Login da demo foi retirado do script `run_mt5_test.sh`. Arquivos com o número da conta no nome ou no conteúdo foram excluídos.
- Arquivos conhecidos com token de Telegram em texto puro (`telegram_alien_bot.py`, `send_demo_chart.py`, `KIT_CLONE_YURI/alien_sync_engine.py`, `alien_neural_bridge.py`) — não estão nesta pasta. Alguns deles **já existem na `main` pública**; esta PR não os toca.

## Como reproduzir (pesquisa)

No box, com os dados locais (não versionados):

```
cd alien-research
# ver cada relatório .md; os scripts estão em code/
```

O robô de índices: copiar `alien-indices/ALIEN_INDICES_V1.mq5` e o `.set` para o MT5, em conta **demo** Pro/ECN (a ProCent não tem índices).
