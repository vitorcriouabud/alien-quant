# ALIEN Supervisor — conta USD 5.000 / GOAT 1% Floating

A regra informada pelo suporte e confirmada no FAQ oficial é um teto flutuante de 1%
do saldo inicial: USD 50 para a conta USD 5.000. Todas as posições são avaliadas em conjunto.
Fonte consultada em 11/11/2026: https://help.goatfundedtrader.com/2-step-goat.html
O supervisor é uma proteção operacional adicional, não substitui as demais regras da mesa.
Não reativa conta encerrada e não garante um preço ou teto exato de execução.

## O que está pronto

- `ALIEN_SUPERVISOR_5K.mq5`: EA independente. Não abre operações. Pode acompanhar seus trades
  manuais e posições de qualquer outro EA. Anexar a UM gráfico de um terminal da conta.
- `AccountFloatingGuard.mqh`: módulo compartilhado, obrigatório na pasta Include/AlienProfessor.
- `ALIEN_V12_3_SCALP_SUPERVISOR.mq5`: nova cópia experimental do ALIEN V12.2 com o mesmo
  supervisor integrado e verificação de orçamento de risco antes de entradas do próprio EA.
- Versões V12.2, V12.1 e V10.89 anteriores permanecem intactas.

Para supervisão de operações manuais, use o EA independente. Ele não depende de Node.js,
API, assinatura adicional ou do EA de entradas. Não é preciso instalar a V12.3 para isso.
Não rode as duas versões supervisoras simultaneamente na mesma conta/terminal.

## Valores padrão (moeda USD, validação rejeita outra moeda)

| Campo | Valor | Significado |
|---|---:|---|
| AGInitialBalance | 5000 | Tamanho original contratado; não é detectado pelo saldo atual |
| AGFloatingLimitPercent | 1 | Limite contratual = USD 50 |
| AGSafetyBufferMoney | 20 | Reserva antes do limite; gatilho de zeragem = USD 30 |
| AGWarningMoney | 20 | Alerta local, repetido no máximo a cada 60s enquanto na faixa |
| AGDeviationPoints | 25 | Desvio de execução em pontos, não pips; não garante preenchimento |

São valores escolhidos para a proteção, não regras extras impostas pela GOAT.
O valor observado é o maior entre (a) soma das perdas de cada posição, incluindo swap,
e (b) saldo menos equity enquanto existem posições. Lucros abertos não compensam perdas
na parcela (a): intencionalmente mais conservador que usar apenas o resultado líquido conjunto.
Não calcula teto diário ou drawdown total e não deve ser confundido com eles.

## Ao alcançar USD 30 de perda observada

1. Persiste uma trava por conta e servidor nas variáveis globais do terminal.
2. Tenta cancelar TODAS as pendentes da conta, de todos os símbolos e magics.
3. Tenta fechar TODAS as posições da conta, inclusive lucrativas, começando pelas mais negativas.
4. Reavalia em ticks, eventos de negociação e timer nominal de 250ms. Erros, rejeições e
   fechamentos parciais não liberam a trava: novas tentativas ocorrem enquanto continuar rodando.
5. Uma nova operação manual aberta após a trava também será alvo de fechamento.

Não impede o clique manual, não bloqueia o servidor da corretora e não consegue impedir
outro EA/terminal de enviar ordens. A versão integrada V12.3 bloqueia suas próprias entradas
quando travada. Retire os outros EAs de entrada após um acionamento para evitar reentradas.

A V12.3 também recusa suas próprias entradas se houver posição sem stop na conta,
pendentes com risco desconhecido, falha de cálculo ou risco estimado conjunto até os stops
(incluindo a candidata) >=USD 30. Sem compensar posições lucrativas. Swap negativo atual
entra no cálculo, mas comissões futuras de outras posições e slippage não são conhecidos.
As entradas pendentes de zonas ficam desligadas na V12.3 quando AGEnable=true.
Trades manuais não passam por essa checagem prévia.

A trava não reinicia à meia-noite, ao retirar/recolocar o EA ou ao voltar a ficar sem posições.
Para liberar conscientemente: parar todos os supervisores, conferir que a conta está sem
posições/pendentes, abrir F3 no MT5 e remover somente a variável AG_LIVE_<login>_<hashServidor>
exibida/identificável no terminal; recolocar o EA. Não é procedimento para recuperar conta violada.
A trava é local ao terminal: outro terminal ou uma pasta de dados diferente não a compartilha.
No Tester a trava é isolada e não fica persistida entre simulações.

## Instalação

1. No MT5: Arquivo > Abrir pasta de dados. Copiar a pasta MQL5 do pacote para essa pasta.
2. Abrir ALIEN_SUPERVISOR_5K.mq5 no MetaEditor e pressionar F7. A inclusão do módulo é obrigatória.
3. Testar primeiro numa conta DEMO USD com configuração 5000. Anexar o supervisor em um gráfico,
   permitir negociação algorítmica nas propriedades do EA e ativar o botão de Algo Trading.
4. Conferir o painel e a aba Experts: base 5000, teto 50, gatilho 30 e alerta 20.
5. Validar zeragem conjunta, cancelamento, erros de fechamento e persistência da trava em demo
   antes de utilizá-lo como proteção de uma conta de desafio.

O EA independente funciona em qualquer símbolo/timeframe do gráfico: a avaliação é da conta.
Somente um EA cabe em cada gráfico: se já houver outro EA, use um gráfico separado.
O terminal precisa permanecer conectado, com AutoTrading permitido e computador acordado.
Gaps, latência, mercados fechados, limites de execução, desconexões e negociações feitas de outro
terminal podem levar a perda além de USD 30 ou até além de USD 50 antes do fechamento.
O timer de 250ms é uma solicitação ao terminal, não garantia de latência máxima.

## Registros

MQL5/Files/ALIEN_SUPERVISOR_<login>.csv guarda inicialização, alertas, acionamento,
fechamentos confirmados e falhas/tentativas. Horário é o da corretora. Não envia dados para rede.
O monitor Node entregue anteriormente ainda não importa esse novo CSV: consulte a aba Experts
ou envie o arquivo do supervisor para auditoria. Nenhuma sincronização online foi adicionada.

## Validação desta entrega

`python tests/test_account_floating_guard.py`: lógica MQL real executada com terminal simulado
em C++ e verificações de integração. Cobre limites 20/30/50, episódio de -79.69, símbolos distintos,
ganhos sem compensação, persistência, reentradas, falha de fechamento/cancelamento com retry,
risco agregado, posição sem stop e isolamento do Tester.
Não equivale à compilação MetaEditor nem a teste com a corretora. EX5 não fornecido.
Compilação MQL5, timer/eventos reais e execução Windows/MT5 ainda pendentes.
