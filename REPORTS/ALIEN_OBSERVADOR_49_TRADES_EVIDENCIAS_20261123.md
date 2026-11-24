# ALIEN V12.1 Observador: auditoria de 49 trades, 100% ticks reais

**Fonte primária**: ZIP recebido `ENVIAR_ALIEN_OBSERVADOR_20261123_231129.zip`, com HTML de backtest, CSV original de 49 negociações, TXT do Professor, journal, validação da versão, hash de `.ex5`.

**Proveniência validada dentro do pacote:**
- EA MT5: `ALIEN_V12_1_LAB_OBSERVADOR`; `EnableEntryObserver=true`; `EnableBreakRetest=false`; `AllowLiveRealTrading=false`; `RoundTurnCommissionPerLot=8.00`.
- Período 13–22/11/2026, XAUUSD M1, RoboForex-ECN, USD 5.000, 8.250 barras, 3.323.422 ticks, relatório MT5 declara **100% de ticks reais**.
- Git commit fonte `e302d1bf822ce3bbef789a32ed0ea9f75172c1b2`, blob Git SHA1 `924f9a50468621ae4160233f2371eaad7f1609f2`. EX5 SHA256 `BB498D20D7FC2BD4ABD5950FDCD5FF94F26B4E8241022C0728D2E0EF578D124E`; essas cadeias aparecem em `VALIDACAO_E_VERSAO.txt` do pacote, não foram obtidas independentemente no terminal Windows.
- Histórico MT5: 49 posições, lucro líquido **-USD 9,73**, PF **0,60**, max DD equity **USD 13,37 / 0,27%**. Todos 49 constam do CSV Observador com 52 colunas. CSV líquido soma -USD 9,73.

## Resultados principais do novo CSV Observador

| Segmento (retrospectivo) | N | P&L líquido |
|---|---:|---:|
| Stop sem movimento favorável observado `qtde_moves_sl=0` | 27 | -22,18 |
| Stop movido pelo menos uma vez `qtde_moves_sl>0` | 22 | +12,45 |
| Pontuação do fator candle `p_candle=0` no instante da entrada | 42 | -13,04 |
| `p_candle>0` | 7 | +3,31 |
| Fechadas até 10 s | 19 | -6,98 |
| Fechadas em mais de 10 s | 30 | -2,75 |
| Sessão Londres | 24 | -0,85 |
| Sessão Nova York | 25 | -8,88 |
| Score 64–74 | 17 | -7,03 |
| Score 75–100 | 32 | -2,70 |

**Excursões de cinco segundos, medidas em pontos de XAUUSD (bid liquida BUY, ask liquida SELL):**
- 15 posições com retorno líquido >0: MFE5 mediano **+22**, MAE5 mediano **-7**.
- 32 posições com retorno líquido <0: MFE5 mediano **+9,5**, MAE5 mediano **-22,5**.
- Duas posições com retorno líquido 0 não fazem parte dessas duas distribuições.
- Os 49 registros contêm pelo menos uma observação dentro de cinco segundos, mas janelas de 10/30/60 s estão **censuradas no fechamento**: trade de 5 s não informa movimento futuro até 60 s. Não comparar como se todos ficassem abertos 60 s.

**Execução e custos:**
- 42 saídas identificadas como `STOP_LOSS`, -20,24; 7 como `TAKE_PROFIT`, +10,51.
- Comissões totais registradas no HTML -3,92; movimento do preço -5,81. PF 0,60 é MT5; PF recomputado sobre **P&L líquido por posição, com comissões alocadas** é 0,58, não é contradição.
- Todos os 49 pares de preço solicitado vs preço de abertura efetiva no CSV coincidem. Isso não significa ausência de slippage de stop/saída. Não há garantia de sem slippage/gaps.

## Semântica exata do fator `p_candle` (conferido no código MQL5)

`ScoreSignal(..., candleMove)` calcula `alignedBar = candleMove * direction`. Se `alignedBar >= max(1, MinImpulsePoints)` atribui **15 pontos**; se `alignedBar >= 0` atribui **7 pontos**; caso contrário atribui **0**. O `candleMove` é observado no candle M1 ainda **em formação**; portanto, `p_candle>0` representa alinhamento/deslocamento intrabar naquele instante, **não é uma confirmação por candle fechado**. Também não é uma probabilidade de acerto.

## Interpretação

O **primeiro candidato a hipótese de mudança** é testar o alinhamento/deslocamento intrabar M1 em relação à direção do Sweep antes de aceitar a entrada (e, separadamente, comparar confirmação por candle FECHADO, que seria outra hipótese), porque 42/49 entradas receberam pontuação zero no fator candle. **NÃO ATIVAR DIRETAMENTE** no sistema principal: apenas 7 observações têm pontuação não zero; pós-seleção nos seis pregões causa alto risco de overfitting. Da mesma forma, não inferir que trailing é solução pelo fato de posições com SL movido terem ganho: mover SL e sobrevivência são estados POSTERIORES à entrada e estão associados ao movimento favorável.

A janela NY também não se pode declarar inferior de modo generalizável com apenas seis pregões.

## Decisão próxima etapa

1. Preservar `main`, a branch de risco auditada, e a branch Observador existente.
2. Especificar uma candidata isolada **com confirmação de candle pré-entrada, sem olhar velas futuras**, junto de um controle intacto.
3. Validar em dias/períodos **não usados para escolher essa hipótese** (outubro, setembro ou outra janela inédita com 100% ticks reais e comissão), com execução automática de ambos, mesma versão de histórico, custos e limites.
4. Se um filtro for candidato sério, exigir melhora de retorno líquido, drawdown, sensibilidade por sessão, quantidade de trades, spread/slippage, robustez por mês. Não equiparar P&L hipotético de um subconjunto à execução real da estratégia alterada, que muda cooldowns e próximos sinais.
5. Não liberar negociação real. O pacote enviado comprova teste, não vantagem estatística.

**Status**: auditoria calculada sobre CSV real, sem alteração do EA; próxima candidata ainda não codificada, compilada ou testada.
