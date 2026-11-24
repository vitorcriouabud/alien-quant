# Auditoria do experimento ALIEN A/B — 23/11/2026

**Fonte primária:** `ENVIAR_ALIEN_AB_20261123_232716.zip` enviado pelo usuário, 12 arquivos: dois relatórios HTML do MT5, CSV dos trades e logs de telemetria para cada variante, arquivos de validação e hashes.

## Verificação do protocolo

- Mesmo EA `ALIEN_V12_1_LAB_AB_CANDLE` e mesmo executável nas duas variantes: EX5 SHA256 `2FB4E98902B9DE2F7FB49D555591ECE0446AEE33B6477A11B205FAC2A7D9E52B`.
- Preset A `RequireSweepCandleAlignment=false`, B `RequireSweepCandleAlignment=true`; demais parâmetros de segurança verificados por HTML: `EnableBreakRetest=false`, `AllowLiveRealTrading=false`, `EnableEntryObserver=true`, comissão configurada `RoundTurnCommissionPerLot=8.00`, lote 0,01, teto de 0,25% da equity por ordem.
- Período XAUUSD M1 de 02 a 12/11/2026; 11.000 barras e 3.756.392 ticks em ambos os HTML.
- **BLOQUEADOR FUNDAMENTAL:** os HTML reportam literalmente `Qualidade do histórico: 0% de ticks reais` em A e B. Os dois `RESULTADO_VALIDACAO.txt` mostram `100% de ticks reais reportados: False`, mais `AVISOS.txt`. Apesar de `Model=4` solicitado no arquivo .ini, os ticks reais NÃO foram confirmados pelo MT5. **Experimento NÃO aprovado** como evidência de lucratividade ou robustez de execução.

## Números reportados (apenas SIMULAÇÃO SEM TICKS REAIS)

| Métrica | A original | B veto candle contrário |
|---|---:|---:|
| Lucro líquido MT5 | +48,32 USD | +11,14 USD |
| Profit factor MT5 | 5,21 | 1,67 |
| Negociações completas | 78 | 43 |
| Posições lucrativas MT5 | 64 (82,05%) | 25 (58,14%) |
| Drawdown máximo equity | 2,28 USD (0,05%) | 9,24 USD (0,18%) |
| Vitórias líquidas CSV (taxas atribuídas à posição) | 63/78 | 24/43 |
| PF recomputado líquido por posição CSV | 6,40 | 1,71 |
| PnL do subconjunto p_candle=0 em A | +42,55 USD (56 trades) | não aplicável |

Os valores divergentes de PF MT5 e CSV devem-se à **base de agrupamento** e atribuição de custos por *deal* vs por *posição*: o lucro líquido final coincide (CSV soma igual ao HTML).

## Resultado por data (líquido, USD)

| Data | A | B |
|---|---:|---:|
| 02/11 | +14,22 | +14,28 |
| 03/11 | +7,75 | +0,82 |
| 04/11 | +3,95 | +0,73 |
| 05/11 | +9,07 | +0,12 |
| 06/11 | +5,27 | -1,60 |
| 09/11 | +5,47 | -0,74 |
| 10/11 | +2,00 | -2,05 |
| 11/11 | +0,59 | -0,42 |

No teste com **ticks não reais**, B diminuiu 35 operações e o lucro líquido em 37,18 USD; não forneceu vantagem nesse cenário. Em A, os 56 trades com `p_candle=0` somaram +42,55 USD, contraste com a associação negativa observada em novembro 13–22/11 com **100% ticks reais**. Como datas e qualidade de ticks são diferentes, não atribuir causalidade só ao tipo de tick.

## Próxima decisão

**Não promover A nem B para conta real; não mexer em stop, lote, risco, ou implementar outro filtro baseado nesses resultados.**

O pacote de teste foi reconfigurado para uma **comparação diagnóstica** na janela 13–22/11, onde um teste anterior do usuário informou 100% de ticks reais. É um período já utilizado na descoberta: serve para conferir a coerência do filtro com preço real, **não** para validação independente de edge. O script exige validação de qualidade e inclui aviso caso o resultado tenha menos de 100% de ticks reais.

Uma prova real exige janelas adicionais independentes de ticks reais, custos/slippage realistas, e consistência de resultados por mês.

**Status:** os números, validações e CSV foram inspecionados localmente. O novo pacote de 13–22/11 foi gerado e verificado estaticamente, mas ainda **não foi executado no computador Windows**; nenhuma ordem real ou merge realizado.
