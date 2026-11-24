# ALIEN — forward observador passivo (DEMO)

## Objetivo

Coletar o fluxo **recebido ao vivo** da corretora e estudar XAUUSD M1 sem depender de histórico de ticks mais antigo. O coletor **não executa nem simula negociações**; é um arquivo de evidências para futura avaliação, não um EA lucrativo.

## Arquivos

- `MQL5/Experts/ALIEN_FORWARD_OBSERVADOR_V1.mq5`: EA independente, sem biblioteca de operações, executado somente em conta DEMO, sem comandos de Buy/Sell, modificações ou fechamento de posição.
- CSV diário dentro de `MQL5/Files/ALIEN_FORWARD_XAUUSD_AAAAMMDD.csv` (nome inclui símbolo real se houver sufixo de corretora).

## Comportamento exato

1. No gráfico XAUUSD com conta MT5 do tipo **DEMO**, compila e anexa o `ALIEN_FORWARD_OBSERVADOR_V1`. Se a conta não for DEMO, `OnInit` rejeita e não inicia.
2. `OnTick` escreve `horario_servidor,time_msc,simbolo,bid,ask,last,volume,volume_real,flags,spread_pts` em CSV delimitado por ponto-e-vírgula. Datas refletem o servidor da corretora, não necessariamente o horário de Brasília.
3. Arquivo separado a cada dia. Desliga gravação daquele dia se chegar a 64 MB; reinicia no próximo dia. Flush periódico, mas travamento do computador ainda pode perder os últimos registros.
4. Ao reiniciar no mesmo dia o arquivo é retomado em append; evento duplicado em reinicialização não é automaticamente deduplicado.
5. Logs registram quantidades **recebidas por OnTick**, não número comprovadamente completo de ticks da corretora.

**Limitação crítica:** MetaTrader 5 pode coalescer eventos `NewTick` enquanto o manipulador anterior está em execução. Portanto o CSV representa cotações **efetivamente recebidas pelo EA**, não um arquivo certificado de 100% dos ticks originais. Não vender esse CSV como backtest de ticks completos. Para auditar integridade de todos os ticks, será necessário mecanismo `CopyTicksRange` com paginação/controle de duplicações, dados da própria corretora ou provedor auditado.

## Instalação manual, uma única vez

1. Abra MT5 em **conta demo** e no gráfico XAUUSD M1.
2. No MT5, escolha **Arquivo > Abrir pasta de dados**; dentro de `MQL5/Experts` coloque `ALIEN_FORWARD_OBSERVADOR_V1.mq5` desta branch.
3. Abra pelo MetaEditor e compile com **F7**, confirmando que não há erros. Esta compilação **ainda não foi executada pelo assistente**.
4. No Navegador do MT5 atualize a lista de Expert Advisors e arraste `ALIEN_FORWARD_OBSERVADOR_V1` para o gráfico XAUUSD M1. Não é necessário ativar negociação algorítmica para o coletor passivo.
5. Após receber cotações, verifique o Diário por `ALIEN FORWARD: registrando em MQL5/Files/...`. Em **Arquivo > Abrir pasta de dados > MQL5 > Files** confira o CSV do dia.
6. Deixe MT5 **aberto e conectado** enquanto quiser coletar. Computador desligado/hibernando, conexão caída, e ausência de ticks de mercado interrompem a captura.

## Próxima verificação

Quando houver 3–5 pregões consecutivos com CSVs não vazios, examinar buracos temporais, spread, sessões, mudanças na base Bid/Ask, e estimar qualidade/volume antes de promover qualquer hipótese de trade. Se precisar estudar a estratégia, rodar EA **separado** em outra instância/conta DEMO e arquivar todas as operações; não chamar o coletor de robô autônomo de trade.

## Proibições e preservação

Não modificar `main` ou branches anteriores, não executar trades reais, não fazer merge sem pedido explícito. O coletor não faz nenhuma chamada a APIs de ordem. `EnableEntryObserver` do EA V12.1 é um projeto distinto e deve permanecer separado.

**Status:** commit de código e documentação apenas. **Não foi compilado no MetaEditor nem testado em demo pelo assistente.**
