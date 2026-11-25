# ALIEN V12.1 — reconciliação somente leitura e gates de validação

**Branch:** lab/alien-deals-reconciliation-20261125  
**Base:** main (commit 90cdaed30e82c4292120f90ba0e0eeccafa6b56f)  
**Escopo desta branch:** ferramentas de auditoria somente leitura. Nenhum EA, preset ou EX5 de execução foi substituído. Nenhum teste MT5 ou ordem foi iniciado.

## 1. Por que esta é a próxima tarefa

A coleta DEMO de 24/11 contém 65 posições únicas e soma CSV de +US$ 14,95. As 18 posições incrementais acrescentaram somente +US$ 0,24 (PF 1,02). O painel/relatório do EA indicou +US$ 17,60, diferença de US$ 2,65. O diário registra 63 DEAL_EXIT e 65 CLOSED_POSITION; duas posições FECHAMENTO_EXTERNO somam -US$ 2,73, com US$ 0,08 em taxas de entrada que podem explicar a diferença restante. A reconciliação aritmética é consistente, mas ainda falta exportação primária completa dos deals MT5 para confirmar os valores e os magics dos fechamentos externos.

A auditoria anterior das 47 posições também encontrou +US$ 14,71 no CSV e a mesma diferença de US$ 2,65 no valor diário do EA. Não tratar o saldo global da conta como resultado exclusivo do ALIEN: outros EAs compartilharam a conta DEMO.

## 2. Ferramentas adicionadas

### MQL5/Scripts/ALIEN_EXPORT_DEALS_READONLY.mq5

- Lê o histórico da conta com HistorySelect.
- Exporta deals do símbolo selecionado (padrão XAUUSD) para MQL5/Files.
- Exporta **todos os magics** do símbolo, não apenas 802092. Isso permite localizar um fechamento cujo deal de saída tenha outro magic, mas pertença à mesma Position ID aberta pelo ALIEN.
- Inclui ticket do deal, order ticket, Position ID, horário do servidor, horário em milissegundos, símbolo, magic, entry, type, reason, volume, preço, profit, commission, swap, fee e comment.
- Não importa Trade.mqh e não contém chamadas de envio, alteração, cancelamento ou fechamento de ordens/posições.

Parâmetros padrão: símbolo XAUUSD, últimos 90 dias, Magic ALIEN 802092 (usado apenas no resumo, não como filtro). Se o broker usar sufixo no símbolo, ajustar InpSymbolFilter para o nome exato.

### tools/audit_alien_deals.py

Aceita CSVs separados ou um ZIP com:
- CSV de posições do EA (position_id + liquido_conta);
- CSV de deals MT5 (position_id + magic + profit + commission; swap e fee opcionais);
- CSV opcional de eventos do EA.

A associação é feita pela Position ID. Quando encontra uma entrada do Magic ALIEN, soma profit + commission + swap + fee de **todos** os deals dessa Position ID, inclusive os que tenham outro magic. O programa sinaliza IDs ausentes, duplicatas conflitantes, diferenças acima da tolerância e fechamentos com magic externo. Não atribui o fechamento a um EA específico sem evidência.

O ZIP é lido sem extração. Os arquivos de origem não são modificados.

## 3. Procedimento de coleta

1. No MT5 da conta DEMO que contém o histórico a auditar, abra o MetaEditor e compile ALIEN_EXPORT_DEALS_READONLY.mq5.
2. Exija 0 erros. A compilação do MQL5 ainda precisa ser realizada no MetaEditor do usuário; não foi executada nesta branch.
3. No MT5, execute o script pelo Navegador > Scripts. Confirme que o símbolo é exatamente XAUUSD (ou ajuste o input se houver sufixo).
4. O arquivo ALIEN_DEALS_READONLY_*.csv será criado em MQL5/Files. O script exporta todos os magics daquele símbolo.
5. Coloque no mesmo ZIP o CSV de deals exportado, o CSV de trades ALIEN_V1089_TRADES_*.csv e, se disponível, o CSV de eventos ALIEN_V1089_EVENTS_*.csv. Não inclua login, senha, tokens ou dados de acesso.
6. Execute o auditor Python:

   python tools/audit_alien_deals.py --bundle ENVIAR_ALIEN_RECONCILIACAO.zip --symbol XAUUSD --magic 802092 --output RELATORIO_RECONCILIACAO.md

Se o ZIP tiver mais de um CSV candidato para trades ou deals, o auditor escolhe o maior por quantidade de linhas e registra a fonte. Para eliminar ambiguidade, informe --trades-member e --deals-member com os nomes exatos dentro do ZIP.

## 4. Critérios para considerar a reconciliação concluída

- Mesmo símbolo, conta e janela temporal entre CSVs.
- Cada Position ID fechada do EA deve ter deals correspondentes no histórico, salvo explicação documentada (posição ainda aberta ou histórico incompleto).
- Comparação líquida por posição: soma de DEAL_PROFIT + DEAL_COMMISSION + DEAL_SWAP + DEAL_FEE contra liquido_conta.
- Diferenças acima de US$ 0,01 precisam ser explicadas por dados primários; não ajustar números manualmente.
- Fechamentos com outro magic devem permanecer visíveis na análise, mas não ser atribuídos automaticamente a outro robô.
- A soma das posições do ALIEN não é a mesma coisa que o P&L global da conta se houver outros EAs, depósitos, retiradas ou posições alheias.

## 5. Estratégia: congelar C e preservar o holdout

O candidato C continua sendo apenas uma hipótese de laboratório: 18–23/11, 120 operações, +US$ 14,75 líquido, PF 1,25 e drawdown máximo de equity reportado de 0,24%. Foram quatro pregões; dois foram negativos. As três maiores vencedoras somaram +US$ 17,27; sem elas, o total aritmético seria -US$ 2,52. A margem líquida média foi US$ 0,1229 por operação, sensível a custos adicionais.

- Não instalar C automaticamente na DEMO ativa nem em conta real.
- Não alterar os presets B/C congelados durante a janela externa.
- Janela planejada: 25/11 a 09/12/2026; executar a comparação somente a partir de 10/12, após os dados estarem disponíveis.
- Rodar B e C no mesmo período, com o mesmo EX5, custos e condições. Confirmar candles e ticks > 0 em ambos antes de comparar.
- Manter a correção P0 de segurança como frente separada. Não misturar correção de risco com a comparação de estratégia.
- O preset a.set observado em uma coleta anterior tinha disjuntores acumulados desativados; não assumir que as proteções do candidato C estejam ativas na DEMO em execução.

## 6. Estado de validação desta branch

- Criada em branch nova a partir de main.
- Exportador MQL5 e auditor Python adicionados.
- Testes automatizados Python adicionados em tests/test_audit_alien_deals.py.
- **Ainda não compilado no MetaEditor e não executado no MT5.**
- Nenhuma ordem, posição, conta, preset ou EX5 foi alterado.
- Nenhuma alteração foi mesclada em main ou em qualquer branch existente.
