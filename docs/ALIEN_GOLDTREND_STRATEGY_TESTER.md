# ALIEN — GoldTrendM1 Tester v1.10 (apenas demo/testador)

**Arquivo original GoldTrendM1.mq5 preservado.** Esta versao implementa somente uma janela por teste e nao deve ser tratada como desempenho comprovado. Codigo-fonte foi revisado estaticamente, **nao compilado neste ambiente**.

## Como instalar sem conflito
1. No MetaTrader 5 aperte F4 (MetaEditor).
2. Arquivo > Abrir e abra `ALIEN_GoldTrendM1_TESTER_v1_10.mq5` (salve em `MQL5/Experts` do terminal aberto).
3. Aperte F7. Precisa mostrar **0 erros**; se nao, salve o log de compilacao e envie ao chat.
4. Volte ao MT5. Aperte **Ctrl+R** para abrir o Strategy Tester.
5. Selecione o EA `ALIEN_GoldTrendM1_TESTER_v1_10`, simbolo **XAUUSD**, periodo **M1**.
6. Modo: **Cada tick baseado em ticks reais**. Deposito simulado: **US$ 100.000** inicialmente **apenas para avaliar a logica** (nao e dinheiro real). Por que: o stop de 3x ATR no ouro pode fazer o lote minimo 0,01 arriscar mais que 0,25% de US$ 5.000, produzindo **zero operacoes por design**. Depois execute outro teste com **US$ 5.000** para avaliar a viabilidade da banca pequena, sem afrouxar o limite de risco. Alavancagem conforme sua demo.
7. Datas: **01/01/2020 a 31/12/2023** primeiro; depois **01/01/2024 a 31/12/2025**; por fim **01/01/2026 a 17/11/2026**. Nao otimize os parametros nessa sequencia.
8. Na aba Inputs, use **Carregar/Load** e escolha `Presets/GoldTrendM1_JANELA_720_H1.set` (ou selecione manualmente os parametros se o terminal nao reconhecer o .set). Primeiro teste 720 e verifique: `InpDonchianH1=720`, `InpAllowShort=true`, `InpRiskPercent=0.25`, `InpStopATR=3`, `InpTrailATR=7`, `InpCommissionLotRT=0` (ajustar apenas se souber a comissao real).
9. Clique Iniciar. No fim, na area de relatorio, use **Salvar relatorio** (HTML ou XML, conforme o MT5) e envie o arquivo. Envie tambem Journal se houver recusas ou erros. Na conta DEMO, nao ha necessidade de usar modo real.
10. Depois de 720, repita com os presets 480/288/192 e periodos identicos para comparar. **Uma janela por teste, sem otimizar ate aparecer lucro**.

## Diferencas em relacao ao GoldTrendM1 original

- Somente uma janela, para teste isolado; suporta conta netting e hedging sem somar quatro riscos correlacionados.
- Exige ATR H1 de candle fechado, Donchian H1 de barras fechadas e gatilho no fechamento M1.
- Mantem SL 3x ATR e trailing 7x ATR fixado na entrada, atualizado no M1; sem take-profit.
- Risco: usa `OrderCalcProfit` no stop incluindo spread do preco da entrada; **nunca** aumenta lote minimo alem do orcamento. `InpCommissionLotRT` opcional.
- Checa retorno de execucao e identifica saídas via transacoes.
- Limite diario, pico da equity, cooldown e distancia trailing persistidos por conta/simbolo/magic.
- Conta REAL bloqueada no inicio e nos ticks. Pode operar demo em forward, mas a finalidade imediata e **Strategy Tester**.
- O DD de 10% e perda diaria de 3% **pausam novas entradas**; nao encerram posicoes ja abertas, nao garantem limite maximo de perda.
- Resultados da pesquisa H1 **nao sao validacao desta implementacao M1**.

## Checklist para avaliar resultado

Relatorio do MT5 por periodo; numero de ordens e negocios; lucro liquido; fator de lucro; max drawdown **absoluto e percentual**; retorno esperado por trade; maior perda/gap; tempo de posicao; custo de spread e comissao; quantos pedidos recusados. Examinar especialmente 2021, 2022, volatilidade de 2024–2026, comparacao buys versus sells.

**Seguranca:** versao inicial de laboratorio; exige F7 e Strategy Tester antes de usar em demo forward. Nenhuma promessa de lucro.

## Aviso sobre tamanho de lote no XAUUSD

Se o jornal disser `SEM ORDEM: lote minimo ultrapassa risco`, isso **nao e erro de compilacao nem sinal ausente**: o EA se recusou a exceder o orcamento de perda. Em muitas corretoras 0,01 lote de ouro equivale a 1 onca; stop de 3x ATR(H1) pode ter valor de perda incompatível com 0,25% de uma banca de US$ 5 mil. O EA usa especificacoes **reais do simbolo** via `OrderCalcProfit`, e nao pressupoe tamanho de contrato.

O historico de candles do usuario NAO contem fluxo Bid/Ask de ticks reais. Se o testador nao encontrar ticks reais para os anos escolhidos, informe a qualidade/modelagem indicada no relatorio. Nao substitua silenciosamente por OHLC e chame de teste realista.
