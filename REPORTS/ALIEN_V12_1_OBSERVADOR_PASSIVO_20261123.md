# ALIEN V12.1 — Observador passivo (laboratório)

**Status em 23/11/2026: código registrado no GitHub, conferência estática feita; compilação MQL5 e backtest deste commit AINDA NÃO foram executados pelo assistente.** Esta branch nasceu de `audit/v12-1-risk-guards-20261123-gpt6`; a `main` e o laboratório anterior foram preservados.

## Por que

No backtest MT5 **Sweep-only**, 13–22/11/2026, 100% ticks reais reportados, 49 trades, -USD 9,73, PF 0,60. 19 trades fecharam em até dez segundos e perderam USD 6,98. Uma regra baseada em tempo de permanência futuro seria *lookahead*; o objetivo é estudar características da **entrada** e a trajetória observada depois dela.

## Adição de código (sem trocar a estratégia)

- Input `EnableEntryObserver=true` (liga/desliga somente telemetria).
- Salva no CSV TRADES: preço cotado na solicitação, preço efetivo de execução, SL e TP iniciais, risco monetário estimado, quantidade de alterações favoráveis do SL, número de ticks observados.
- Salva excursões MFE (favorável) e MAE (adversa) **em pontos do símbolo**, do momento da entrada ao fechamento, além das janelas **até** 5, 10, 30 e 60 segundos. Para compra mede o Bid; para venda mede o Ask; inclui fill de saída se disponível.
- Mantém os contadores de motivos de espera, ampliados em resumo TXT por grupos, **até uma amostra por segundo**, sem chamar isso de número de oportunidades independentes.
- **Não muda os algoritmos** de selecionar entrada, calcular risco, enviar ordem, modificar SL/TP, gerenciar disjuntores ou fechar posições. Há apenas leitura de estados e escrita de arquivos no testador.
- 162 linhas adicionais de código em relação ao pai; arquivo no branch `MQL5/Experts/ALIEN_V12_1_INSTITUTIONAL.mq5`.

## Preset isolado e automação

O ZIP entregue ao usuário contém `ABRIR_ALIEN_OBSERVADOR.cmd`, `ALIEN_AUTO_TESTE_OBSERVADOR.ps1`, `ALIEN_OBSERVADOR_5K_SWEEP_ONLY.set` e `LEIA_PRIMEIRO.txt`.

A automação deve:
1. Detectar MT5 instalado e exigir que o terminal esteja fechado; **não desliga o MT5 à força**.
2. Baixar código por URL de commit imutável e comparar SHA1 do blob Git `924f9a50468621ae4160233f2371eaad7f1609f2`.
3. Compilar cópia isolada em `MQL5/Experts/ALIEN_LAB_OBSERVADOR/`, sem alterar o EA de produção.
4. Carregar automaticamente preset `FixedLot=0.01`, `MaxRiskPercentEquity=0.25`, `RiskStopMoney=12.50`, `RoundTurnCommissionPerLot=8.00` (estimativa observada), `EnableBreakRetest=false`, `EnableLiquiditySweep=true`, `AllowLiveRealTrading=false`, `EnableEntryObserver=true`.
5. Iniciar XAUUSD M1, 5.000 USD demo no Strategy Tester, modelo `Model=4` (ticks reais), período 13–22/11/2026, sem otimização, sem nuvem.
6. Salvar HTML, hash SHA256 do EX5, e tentar incluir CSV e TXT atualizados do agente local em um ZIP na Área de Trabalho.
7. Se não localizar CSV, ainda produzir ZIP com HTML e validação parcial. Nada é enviado automaticamente.

## Critérios de aceitação

- MetaEditor retorna 0 erros, sem mensagens de identificadores desconhecidos; enviar log se falhar.
- HTML identifica EA LAB_OBSERVADOR e contém `EnableBreakRetest=false`, `EnableEntryObserver=true`, `RoundTurnCommissionPerLot=8.00`, e declara 100% ticks reais.
- CSV tem 49 operações, se execução e dados forem equivalentes ao teste de controle. **Não prometer resultado idêntico:** versão do terminal, histórico e efeitos de temporização podem diferir.
- Colunas `mfe5_pts`/ `mae5_pts`, etc., estão presentes e plausíveis; nas operações de duração curta, as janelas maiores representam apenas ticks realmente observados ATÉ a saída.
- Se quantidade de operações ou P&L mudar consideravelmente, tratar como possível efeito da instrumentação (desempenho/temporização) ou histórico, e não usar métricas de MFE antes de diagnosticar.
- Nenhum resultado desse período define vantagem estatística, pois ele já foi usado para orientar as hipóteses. É necessária outra janela de ticks reais fora da amostra.

**Nenhuma ordem real, merge ou liberação de negociação real foi feita.**