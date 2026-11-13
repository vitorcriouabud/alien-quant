# ALIEN TURBO V0.121 — Auditoria do pacote de 13/11/2026

**Fonte:** ZIP privado do usuário `ALIEN_TURBO_DISCOVERY_20261113_133322.zip`. Não publicar arquivos brutos dos seus testes ou informações da conta.

## Integridade da evidência
- MetaQuotes-Demo MT5 Strategy Tester, XAUUSD M1, 21/10–12/11/2026, USD 5.000, histórico informado: 6.617.831 ticks reais e 21.415 barras.
- A–G concluídos (7/9). H_RR3 e I_RISKSIZED ainda não executados.
- **35/35 hashes** verificados: HTML, SET, TRADES, CANDIDATES, OUTCOMES para cada um dos 7 cenários. MQ5 e EX5 também coincidem com os hashes do manifesto. O EX5 hash é idêntico nos 7 testes.
- Compilação MetaEditor: **0 erros, 1 warning** sobre formato de versão `0.121` no MQL5 Market. Esse warning não invalidou a execução do testador.
- **Todos os 7 cenários perderam dinheiro e tiveram PF menor que 1** antes de comissão adicional. O teste no servidor MetaQuotes-Demo não prova condições da Goat.

## Resultado MT5 primário

| Variante | Operações | Líquido MT5 (USD) | PF | DD máx. equity | Líquido após taxa adicional HIPOTÉTICA USD5/lote |
|---|---:|---:|---:|---:|---:|
| A_BASE | 96 | -87,34 | 0,62 | 2,22% | -96,94 |
| B_FREQUENCY | 373 | -285,04 | 0,67 | 6,73% | -322,34 |
| C_ALLDAY | 547 | -400,19 | 0,70 | 8,79% | -454,89 |
| D_MULTI5 | 773 | -397,50 | 0,76 | 8,80% | -474,80 |
| E_H1M15 | 287 | -400,95 | 0,50 | 8,38% | -429,65 |
| F_M5SWEEP | 55 | -18,20 | 0,84 | 0,72% | -23,70 |
| G_M15FVG | 127 | -15,32 | 0,94 | 1,40% | -28,02 |

Taxa adicional: cenário de US$5 por lote por operação completa, aplicado aos lotes de entradas simuladas pelo MT5. Nenhuma comissão adicional foi debitada nessa amostra; preço/spread já entram nos preços de execução do tester. Esta hipótese NÃO equivale à comissão verificada da Goat.

## Coorte de observação (dados iguais entre os cenários)
**9.011 sinais M1 por cenário**, 4.328 BUY e 4.683 SELL. Todos os 9.011 IDs e atributos de mercado (Bid, Ask, spread, stop, H1/M15, M5/FVG) coincidiram entre os 7 arquivos de sinais.

Contagens dentro dessa população:
- 1.364 com stop 35–180 pontos E spread <=45 pontos, antes de restrições de carteira;
- 2.282 H1/M15 alinhados;
- 514 com sweep M5;
- 954 com FVG M15.
Contagens se sobrepõem; não representam 1.364 trades aprovados nem execução de todas as oportunidades.

Os 7 CSVs de desfechos estimados por candles M1 tinham o mesmo hash: **9.000 desfechos classificados e 11 ambiguidades (SL+TP na mesma vela)**. Modelagem SELL estimou Ask com spread fixo da entrada: **não confundir com tick-a-tick ou execução MT5**, sobretudo para gaps e spreads variáveis.

## Decisões de pesquisa
- Mais frequência (B), operar dia completo (C) e até 5 posições (D) elevaram negócios e perdas, sem evidência de vantagem. D atingiu 8,80% de drawdown da equity.
- O filtro E_H1M15 piorou o PF de D (0,76 para 0,50).
- F_M5SWEEP e G_M15FVG reduziram quantidade de operações; G é o PF mais próximo de 1 (0,94) mas **ainda é perdedor antes e depois de comissão**.
- Edição in-sample após ver 7 cenários não comprova edge. Não escolher G para operar na Goat, não ampliar lotagem para recuperar perdas.

## Interrupção e recuperação
O `MANIFESTO.json` contém `success:false` e `failure:"MT5 portatil nao encerrou. RoboForex principal nao foi tocado."`. O log `DIAGNOSTICO_FATAL.txt` identifica H_RR3 como a próxima etapa. Logs mostram G_M15FVG concluído e parada do terminal; o guard de processos continuou encontrando MT5 isolado e abortou. H e I **não geraram negócios**, portanto não podem ser avaliados.

Correção: `tools/RETOMAR_ALIEN_TURBO_H_I.ps1` retoma somente H e I, valida todos os 35 hashes anteriores e o EX5, espera encerramento do MT5 portátil (exatamente pelo caminho do executável) e gera ZIP final separado; não repete A–G.

**Amostra já conhecida e desenvolvida; precisa de holdout não usado, regras/custos Goat confirmados e verificações de risco antes de qualquer envio de ordens fora do Strategy Tester.**
