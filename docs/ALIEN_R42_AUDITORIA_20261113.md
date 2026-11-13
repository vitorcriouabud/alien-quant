# AUDITORIA R4.2 SHADOW - 2026-11-13

## Evidencia primaria
Pacote privado do usuario: ALIEN_R42_SHADOW_20261113_044339.zip. O pacote NAO foi publicado no GitHub.
MetaQuotes-Demo XAUUSD M1, 2026-10-21 a 2026-11-07: 17.455 barras, 5.651.752 ticks, relatorio informando 100% ticks reais.
Hashes de HTML, preset e dois CSVs conferem com o manifesto (4/4). Hashes MQ5/EX5 declarados no manifesto nao foram revalidados (esses arquivos nao estao no ZIP).

## Funil observado
CSV de eventos: 1.025 linhas de log. VETO_H1=219, VETO_POI=62, ARMADO=123, AGUARDAR_M1=389 (repeticoes), EXPIRADO=108, VETO_SPREAD=61, RET_ARMADO=15, RET_CONFIRMADO=1, RET_INVALIDADO=7, RET_EXPIRADO=7.
CSV shadow: 61 OPEN, 61 desfechos, sem candidato sem fechamento.
60 deslocamentos: 6 TP, 39 SL, 15 TIMEOUT; media hipotetica net_R = -0,1654R.
1 reteste: 1 SL, -1,0293R. 0 ordens reais ou demo por construcao: EnableDemoOrders=false.

## Gargalo mensuravel
Candidatos com stop de 35 a 180 pontos: 3/61. Spread <=25 pontos: 16/61. Espaco para 4R: 13/61. Calculo de lote: 60/61. Intersecao stop + spread + espaco: **0/61**.
Medianas: stop 431 pts, spread 33 pts, razao spread/stop 5,72%.
Nos tres stops de ate 180 pts, spread/stop = 23,4%, 46,6%, 31,4%; todos falharam no spread e tiveram 2 SL/1 TP hipoteticos. Nao justifica relaxar filtro.
24/61 candidatos surgiram fora da sessao configurada de 07:00 a 20:00 (hora do servidor).

## Reteste comparavel por MESMO sweep_id
Apenas 1 sweep com as duas fases em 2026-11-03: deslocamento 20:47, stop 235 pts, spread 13, SL -1,035R; reteste 20:48, stop 283 pts, spread 13, SL -1,029R. Ambos fora de sessao. O reteste piorou a distancia do stop em 48 pts nesse exemplo; amostra insuficiente para inferir regra geral.

## Problemas do simulador de desfechos
O timeout de 90 minutos foi excedido em 3 registros: 7.260 s, 11.160 s e 176.640 s (49,07h, atravessou fim de semana). A rotina de simulacao usa primeiro tick disponivel apos limite; nao equivale a saida em 90 min. Necessario separar GAP_TIMEOUT / sem cotacao e TIMEOUT normal.
Um candidato teve stop 14.693 pts, muito acima do limite; revisar a geometria e o contexto.
Nao existe aqui spread real de negociacao, fills da corretora, slippage real, BE/trailing ou capital operado: os desfechos sao CONTRAFACTUAIS, na referencia 0,01 lote e comissao estimada em US$8,30 round-trip/lote. Nao somar net_R como lucro de carteira.

## Decisao
Nao ativar entrada nem aumentar SL/spread para forcar operacoes. O conjunto nao demonstra edge. Proximo estudo isolado, ainda sem ordem: registrar sessao e gaps; comparar **entrada antecipada objetiva apos sweep M5 e microestrutura CHoCH/reteste M1** contra deslocamento tardio, mesmas varreduras, mesmo periodo e cotacoes. Fixar risco, custo e stop; testar em holdout posterior. Sem prova fora da amostra nao promover para conta real.

*Analise originada exclusivamente dos arquivos submetidos; os arquivos brutos ficam privados.*
