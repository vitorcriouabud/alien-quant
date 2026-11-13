# ALIEN R4.4 — Auditoria de stops pareados (13/11/2026)

**Fonte:** arquivo privado do usuário `ALIEN_R44_PAIR_20261113_103651.zip`, não publicado no GitHub.
**Status:** quatro hashes dos arquivos internos (HTML, preset, eventos, outcomes) conferidos com o manifesto. Hashes de MQ5/EX5 constam no manifesto mas esses binários não estão no ZIP para revalidação independente.

## Execução
MetaQuotes-Demo, XAUUSD M1, 21/10–07/11/2026; relatório MT5 indica 17.455 barras, 5.651.752 ticks e 100% de ticks reais. **0 operações enviadas**. Janela in-sample utilizada para construir as versões anteriores.

## Cobertura
- 61 sinais em 60 sweeps, sendo 61 stops controle M5.
- 28 sinais com pivô local M1 causal conforme algoritmo (45,9%); **33 sem pivô (54,1%)**.
- Dentro desses 28 pares: mesmo tick, mesma entrada e spread. M1 menor em 17, maior em 10 e igual em 1.
- Stop mediano no mesmo conjunto de 28 pares: M5 **403,5 pts**, M1 **334 pts**. Median M5 em todos os 61: 431 pts (denominador diferente, não usar como delta pareado).

## Funil

| Filtro | M5 (61) | Local M1 (28) |
|---|---:|---:|
| Stop 35–180 pts | 3 | 4 |
| Spread ≤25 pts | 16 | 9 |
| Espaço para TP 4R | 13 | 9 |
| Lot/risco | 60 | 28 |
| Dentro da sessão | 37 | 16 |
| **Todos simultaneamente** | **0** | **0** |

Três paradas locais passaram **stop + spread**, mas **nenhuma estava dentro da sessão permitida**; apenas uma tinha espaço simultaneamente para 4R.

## Desfechos hipotéticos, não execuções

| Resultado | M5 (n=61) | Local M1 (n=28) |
|---|---:|---:|
| TP | 6 | 5 |
| SL | 40 | 20 |
| TIMEOUT | 12 | 2 |
| GAP_TIMEOUT | 3 | 1 |

Nos mesmos 28 pares, diferença de retorno estimado local−M5 teve média **+0,102R** e mediana **−0,00476R**; local melhorou 12, piorou 15 e empatou 1. O desfecho inclui timeout/gap, stops sem viabilidade e custo estimado. **Não somar esses retornos como PnL, pois nenhum trade passaria todos os filtros**.

## Pontos de atenção
- O stop M5 chegou a **14.693 pontos** em um sinal fora dos parâmetros operacionais. Não aumentar limite para aceitar isso.
- Dez stops locais foram piores em distância que o M5: registrar `LOCAL_NAO_MELHORA` sem excluir o denominador dos próximos testes.
- Spread mediano observado nos sinais foi **33 pts**, contra teto 25. MetaQuotes-Demo não representa necessariamente os custos da mesa/corretora.
- A mesma janela foi reavaliada em R4.1–R4.4: risco de sobreajuste, sem holdout independente.

## Decisão
**R4.4 ainda NÃO deve operar.** Não criar R4.5 ajustando filtros nesta janela. Congelar regras e exigir teste em dados fora da amostra com custos da corretora/contrato de interesse antes de concluir sobre lucratividade. Manter riscos e stops bloqueados para ambiente real. O estudo atual é shadow-only e não fornece evidência de edge executável.

**Arquivos CSV e relatórios originais permanecem privados; este documento contém apenas agregados.**
