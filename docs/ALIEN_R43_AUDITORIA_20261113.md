# Auditoria do ALIEN R4.3 — 13/11/2026

**Fonte:** ZIP privado enviado pelo usuario em 13/11/2026 (`ALIEN_R43_AB_20261113_050459.zip`). Esta nota agrega somente estatisticas, sem CSVs, IDs de conta ou relatórios brutos.

## Integridade e parametros
- A e B, MT5 MetaQuotes-Demo, XAUUSD M1, 21/10–07/11/2026.
- 17.455 barras, 5.651.752 ticks, "100% de ticks reais" segundo cada HTML.
- Ambos reportam 0 ordens executadas; estudos SHADOW hipoteticos.
- Os 8 hashes SHA256 dos dois HTML, dois presets e quatro CSV conferem com o MANIFESTO.
- Manifesto declara mesmos SHA256 do MQ5/EX5 em A e B, mas os binarios nao estao no ZIP para verificacao independente.
- Os unicos campos de preset distintos: `UseEarlyMicroBreak` (false vs true) e os nomes dos CSVs.

## Resultado de candidatos diretos

|Metrica|A: deslocamento|B: microbreak de 3 barras|
|---|---:|---:|
|Candidatos diretos|60|60|
|TP hipoteticos|6|4|
|SL hipoteticos|39|39|
|TIMEOUT|12|14|
|GAP_TIMEOUT|3|3|
|Media net_R (todas as linhas diretas)|-0,1503|-0,1786|
|Media excluindo GAP_TIMEOUT|-0,1877|-0,2298|
|Stop mediano (pts)|433|447,5|
|Spread mediano (pts)|33|33,5|
|Stops admissiveis 35–180 pts|3|0|
|Stop + spread + espaco 4R simultaneos|**0**|**0**|

**Ressalva:** net_R e hipotetico, com custo estimado; TIMEOUT/GAP_TIMEOUT nao provam fill e esses candidatos podem sobrepor-se. Nao somar como PnL de carteira.

## Comparacao pareada
- 49 sweep_id com candidato direto tanto em A quanto em B.
- 37 pares tiveram entradas e resultados identicos; B foi 1–3 min antes em seis, 1–2 min depois em seis.
- Media pareada de B-A = -0,1741R, mediana 0R; impacto fortemente dependente de dois casos.
- Em `SWEEP_1793209200_-1` (28/10) e `SWEEP_1793268300_-1` (29/10), A alcançou TP e B sofreu SL, com entrada um minuto mais tarde e stop mais longo.
- 11 sinais diretos apenas em A, 11 apenas em B (o novo gatilho também altera a selecao).
- A regra B nao conseguiu antecipar de maneira consistente.
- Dentro da sessao: ambos 37 sinais diretos; A media +0,2109R e B -0,1324R. Ainda nao tradaveis pois **0** passam todos os filtros, e a janela foi reutilizada no desenvolvimento.
- Dois/um retestes adicionais em B/A tiveram apenas SL (A 1 reteste, B 2).

## Diagnostico e decisao
O limitante primario continua sendo **geometria da operacao**: o SL ancorado no extremo da varredura M5 gera distancias grandes; os poucos stops curtos nao passam os custos/filtros. O rompimento de tres candles M1 nao resolveu isso e nao demonstra edge.

**Nao promover B, nao afrouxar SL ou spread, nao habilitar ordens.** Preservar R4.1/R4.2/R4.3. Antes de criar R4.4, desenhar um estudo causal de reteste/proximidade da invalidaçao usando preco M1 disponivel na hora do sinal, estimativa spread/SL, espaco para 4R e janela de sessao. Validar com dados de corretora/contrato de interesse e num periodo fora da amostra. Nao confundir melhor classificacao de sinal com lucro demonstrado.

**Status de validacao:** A/B primario validado; estrategia lucrativa **nao validada**.
