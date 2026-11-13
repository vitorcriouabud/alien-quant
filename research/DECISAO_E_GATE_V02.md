# ALIEN — decisao de pesquisa e gate de evidencias (12/11/2026)

**Status:** RESEARCH ONLY / NO LIVE TRADING / NO AUTOMATIC ORDER SENDING.

Este documento e uma proposta de decisao tecnica. **Nao altera nenhum EA,
parametro do MT5, conta, ordem ou arquivo de mercado.** A pesquisa aprofundada
externa ainda nao estava disponivel para verificacao nesta revisao; este registro
usa apenas os resultados ja apresentados e os arquivos do repositorio GitHub.

## 1. Inventario das evidencias e o que elas permitem concluir

| Experimento | Evidencia observada | Interpretacao permitida | Estado |
|---|---|---|---|
| Confluencia v0.2, XAUUSD | 93 trades; -0,336 R bruto/trade; -0,364 R liquido proxy/trade; PF liquido proxy 0,537; curva ~-34 R; 7 pontos de spread round-trip + 2 de slippage assumidos; negativo com 30/120 min e cap 23 | Nao ha justificativa para usar **esta regra** como sinal operacional; simulacao OHLC e custos proxy nao certificam fills | **REJEITAR v0.2 para operacao** |
| LAB breakout/reteste historico | 2.203 sinais; 2.155 oportunidades pareadas; a 40 pontos de custo, entrada imediata -65,265 pts/oportunidade e politica de reteste -47,020 pts/oportunidade; nos 1.387 retestes observados, entrada atrasada foi pior que imediata | Ambas as politicas negativas. Diferenca por oportunidade reflete menos exposicao; nao e edge. Reteste futuro nao pode ser conhecido no rompimento | **REJEITAR como edge demonstrado** |
| SHADOW V0 (sign15/30min) | Observador prospectivo sem ordens; poucos outcomes completos em execucoes diferentes; snapshots de OnTick, nao fita integral | Nao ha amostra suficiente para afirmar lucro/prejuizo esperado | **MANTER FROZEN, DEMO, OBSERVACAO** |
| V11/V12 no repositorio antigo | Relatorios historicos heterogeneos, inclusive semanas positivas, negativas e ajustes in-sample | Resultado de janela curta ou Sharpe extremo nao prova vantagem transferivel. Precisa reconciliar deals, custos e parametros | **ARQUIVAR como exploracao** |
| Gap semanal | 41 trades, PF 1,677 exploratorio, dependente de poucos outliers e meses especificos | Evidencia fragil, nao validada | **NAO PROMOVER** |

**Limitacoes de proveniencia:** o pacote local `ALIEN_QUANT_ENTREGA.zip`,
`ROBUSTEZ/replay_confluencia_v02.py` e o CSV `trades_replay.csv` NAO
estavam presentes no repositorio GitHub inspecionado. Os numeros da v0.2
acima foram comunicados na conversa; o codigo e os trades individuais da v0.2
**nao foram reexecutados nem auditados aqui**.

## 2. Diagnostico tecnico principal

1. **Sem edge confirmado.** Resultados positivos selecionados a posteriori
   nao compensam resultados negativos fora de amostra.
2. **Atrito domina scalping.** Um teto de spread nao equivale a custo de
   round-trip executavel: usar Bid para venda, Ask para compra, comissao por
   lado, slippage e eventual swap, de acordo com contrato da conta.
3. **Dados historicos contaminados.** O mesmo intervalo ja foi usado para
   selecionar e refinar hipoteses. Nao e holdout novo.
4. **Dados incompletos.** Spreads zerados, fuso do servidor nao verificado,
   timestamps misturados e lacunas de ticks impedem validacao forte.
5. **Infraestrutura legada pode negociar.** O repositorio inclui scripts
   `tools/patch_allow_real.py` e `tools/patch_real_account.py` que tentam
   habilitar conta real, e `tools/alien_living_core.py` contem `mt5.order_send`.
   Nao executar esses scripts como parte da pesquisa. O arquivo
   `MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5` atualmente tem
   `AllowLiveRealTrading=false` por padrao, mas isso NAO transforma o EA
   em observador passivo. O SHADOW e um projeto separado.

## 3. O que fazer agora — em ordem

**P0 — Preservacao (hoje):**
- Congele a regra, codigo, parametros e periodo da Confluencia v0.2.
- Nao ajuste spread cap, horarios, stops ou tempo de saida nesse mesmo
  historico para escolher a versao vencedora.
- Mantenha o SHADOW V0 no MT5 DEMO, sem ordens, sem alteracao de protocolo.
- Nao execute patch de conta real nem EA legado de trading por este fluxo.

**P1 — Auditoria reprodutivel (primeira tarefa tecnica):**
- Copiar o CSV da v0.2, o codigo do replay e o relatorio para um diretorio
  de pesquisa; preservar SHA-256 e origem. Nao publicar dados pessoais.
- Rodar `research/audit_replay_v02.py` sobre o CSV e comparar N=93,
  media R=-0,364 e PF=0,537. Se nomes de coluna divergirem, mapear com
  `--r-col`, `--time-col` e `--id-col`; **nao adivinhar campos**.
- Inspecionar manualmente no replay: horario exato do sinal; ultima barra
  fechada; primeira cotacao negociavel; regras de desempate de SL/TP na
  mesma barra; exposicao sobreposta; sinais SKIP; gaps; censura.
- Se dados faltarem, registrar FALHA DE PROVENIENCIA, nao preencher com
  numeros simulados apresentados como reais.

**P2 — Custo e feed (antes de nova hipotese):**
- Registrar no MT5 DEMO: simbolo exato, digits, point, tick size/value,
  contract size, volume min/step, spread Bid/Ask em timestamps e comissao
  confirmada no extrato da conta. Validar horario servidor vs UTC/DST.
- Calcular custo completo em R e em pontos de preco. Custo 7+2 pontos
  e apenas cenario hipotetico ate confirmacao.
- Nunca converter OHLC Bid em preenchimento Ask sem cotacao correspondente.

**P3 — Estudo prospectivo (sem alterar SHADOW):**
- Escolher NO MAXIMO uma hipotese nova e um controle pre-registrados.
  Um candidato util e a pergunta: 'um filtro de spread/volatilidade
  previamente fixado melhora a expectativa liquida versus controle
  no mesmo conjunto de oportunidades?' O filtro nao deve ser escolhido
  por maximizar o historico ja usado.
- Registrar TODAS as oportunidades, inclusive abstencoes, motivos, spread,
  latencia, Bid/Ask, desfecho censurado e run_id. O novo estudo, se criado,
  deve ser observador separado, nao injecao no SHADOW congelado.

## 4. Gate de promocao (pre-registrar antes da coleta)

**Gate A — Integridade:** fonte identificada, contrato/custos verificaveis,
sem duplicatas, cronologia valida, sinais e abstencoes auditaveis,
simulador causal, codigo congelado, periodo nunca usado para tuning.

**Gate B — Cobertura minima de triagem:** como regra operacional conservadora,
coletar >=100 datas elegiveis, >=1.000 oportunidades e >=200 outcomes completos
para a politica, mais controle pareado. Esses numeros sao **minimos
administrativos**, nao demonstram poder estatistico nem significancia.
SHADOW V0 ja usa esses limites; nao os altere retroativamente.

**Gate C — Evidencia:** expectativa liquida positiva e robusta sob custos
verificados e cenarios de estresse; intervalo de incerteza por blocos
(dia/semana conforme dependencia) sem contradizer a tese; efeito versus
controle com pareamento por oportunidade; ganhos nao dominados por 1-3
outliers; estabilidade por meses/regimes; sem selecao ex post.
Se o IC incluir zero, classificar como INCONCLUSIVO, nao APROVADO.

**Gate D — Risco/execucao:** limites de exposicao, margem, lote minimo,
gaps, perda diaria e semanal coerentes com o capital real e possibilidade
de slippage alem do stop. Backtest e observacao DEMO nao garantem limite
absoluto de perda.

**Gate E — Escalada:** so considerar DEMO com ordens apos A-D e revisao
do codigo, autorizacao explicita e verificacao do MT5. Conta REAL fica
fora do escopo deste trabalho. O resultado valido pode ser **nao operar**.

## 5. Cronograma enxuto

| Prazo | Entrega verificavel | Bloqueio |
|---|---|---|
| 0–7 dias | CSV v0.2 auditado, hash, relatorio de discrepancias; regras congeladas | Sem CSV/codigo, nao declarar replay validado |
| 8–30 dias | Dicionario de dados XAUUSD, fuso e custos verificados com DEMO, gaps quantificados | Sem Bid/Ask e comissao, nao promover sinal |
| 31–60 dias | Um protocolo causal e um observador novo opcional, independente do SHADOW; teste sintetico e auditoria de logs | Sem codigo congelado, nao usar janela futura como holdout |
| 61–90+ dias | Coleta prospectiva e revisao de cobertura; comparacao pareada; decisao continuar/rejeitar | Nao apressar a amostra minima por calendario |

## 6. Condutas proibidas neste ciclo

- Nao declarar 'setup matador', 'lucro garantido', 'IA preditiva' ou 'edge
  comprovado' por uma unica curva positiva.
- Nao aumentar alavancagem para recuperar perdas.
- Nao confundir AIBOTFX, EAs V11/V12 e SHADOW; historicos sao separados.
- Nao alterar o SHADOW V0 ou fazer trading automatico por esta PR.
- Nao afirmar compilacao/teste MT5 ou replay v0.2 que nao ocorreram.

**Proxima decisao objetiva:** auditar o CSV real da v0.2 e a reconstrucao
de custos; se a reproducao falhar, corrigir a medicao, nao a estrategia.
