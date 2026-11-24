# GMG SMC visual do TradingView para MetaTrader 5

## Estado em 24/11/2026
O arquivo **`MQL5/Indicators/ALIEN_GMG_SMC_VISUAL_V1.mq5`** foi criado nesta **branch experimental**, sem alterar a `main` nem o `ALIEN_V12_1_INSTITUTIONAL.mq5`. SHA1 do blob Git `c87494e66ce926db1c4342cf1a55f01bf894c1e2`.

**Verificações feitas:** inspecionado o Pine Script fornecido, estrutura básica de MQL5 comparada à documentação oficial, checados fechamentos de chaves e parênteses, Git blob local e remoto idênticos, e inexistência de `CTrade`, `OrderSend`, `trade.Buy`, `trade.Sell`. **Não há compilação no MetaEditor, screenshot do indicador funcionando ou backtest.**

## Marcadores implementados
- Triângulos de swing high e swing low somente depois de `InpFractal` candles **fechados** do lado direito; desenhados retroativamente sobre a vela do pivô, como o Pine revisado. Empates de máxima/mínima usam condição estrita, podendo divergir nos casos de preços iguais.
- OB alta e baixa: exatamente a heurística de engolfo do Pine (candle de reversão que rompe extremos da vela anterior). **Não** confundir com Order Block institucional validado.
- FVG alta: `low[i] > high[i+2]`; FVG baixa: `high[i] < low[i+2]`. Cada gap é desenhado como caixa retangular, sem sinais de entrada.
- Sessões: faixas *personalizadas*, Ásia 20–00, Londres 08–11, NY 13–16 **no fuso alvo**. Horários não são necessariamente sessões oficiais. O MQL5 usa **offset fixo** do servidor informado pelo operador (padrão +120 minutos) e alvo -180 minutos (Brasília sem DST); não consegue replicar automaticamente o fuso histórico dinâmico `America/Sao_Paulo` do TradingView. Conferir DST da corretora.
- Limite de `InpMaxZones` caixas de OB/FVG e de `InpScanBars` candles fechados. Recria os desenhos no início de cada nova vela; cores simples de MT5, não a mesma transparência alpha do Pine.

## Instalação
Pode-se baixar o MQ5 em `MQL5/Indicators`, compilar no MetaEditor com F7 e anexar ao gráfico XAUUSD M1, ou utilizar o pacote local `ALIEN_GMG_SMC_VISUAL_INSTALAR_UM_CLIQUE.zip`: o CMD usa PowerShell para localizar a pasta de dados do MT5, escolher uma instalação se houver mais de uma, **copiar apenas o indicador** e tentar compilar com MetaEditor /compile /log. O instalador não abre o terminal, não ativa AutoTrading e não envia ordens. Se a compilação não for comprovada, gera relatório e pede compilação manual.

## Próximos passos de pesquisa
Antes de integrar qualquer regra ao ALIEN EA, comparar pelo menos três comportamentos: (a) sweep + FVG, (b) sweep + rompimento de estrutura confirmado, (c) sweep sem confluências extras, avaliados por condições observáveis **antes da entrada** e com simulação/forward demo, custo e risco iguais. Não tratar FVG/OB visual como prova de vantagem estatística.

**Não autoriza negociação real, merge ou alteração do fluxo de execução do EA.**
