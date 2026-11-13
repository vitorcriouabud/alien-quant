# ALIEN GOAT5K — A/B de contexto H1/M15 com execuções no Strategy Tester

## Diagnóstico motivador
Entre 21/10 e 12/11/2026, o benchmark M1 registrou 96 operações
simuladas, US$−87,34, PF 0,62, 23 TP e 73 SL, sem cobrança de
comissão pelo MetaQuotes-Demo. Não comprovou vantagem.

## Hipótese única
Com o MESMO código e EX5, comparar:
- A_BASE: configuração exata do benchmark de rompimento M1,
  corpo >=35%, stop local 35–180 pts, spread até 45 pts,
  alvo 2R, risco max 0,25%, lote max 0,02, seis trades/dia,
  cooldown 30 minutos e capital US$5.000.
- B_CONTEXT: idêntico ao A, mas requer fechamento do H1 acima
  ou abaixo da SMA20, com SMA20 ascendente para compra ou
  descendente para venda, e fechamento do M15 acima ou abaixo
  do meio do range de 12 candles fechados, na mesma direção.

Os filtros H1 e M15 consultam só candles já FECHADOS, shift=1,
sem dados futuros. São proxies objetivas de tendência/localização
e NÃO equivalem a CHoCH, BOS ou leitura SMC institucional.

Só dois valores de preset podem divergir: RequireH1M15Context e
CSVFileName. O runner congela EX5, confere hashes e coleta
dois HTML e dois CSV, com manifesto SHA256 em ZIP privado.

## Cuidado estatístico
As duas políticas possuem limites independentes de 6/dia,
cooldown e ocupação: os trades B NÃO são necessariamente um
subconjunto dos trades A; comparar também o funil de vetos.
O período 21/10–12/11 já foi usado para desenvolver, logo o A/B
serve para conferência e diagnóstico, NÃO holdout independente.
Após congelar, rodar um período não usado anteriormente,
num periodo verificado como nao utilizado no desenvolvimento,
antes de qualquer decisão de implantação. Os dados de 2025–2026 ja apareceram em outras rodadas, portanto NÃO presumir que junho/2026 seria uma amostra nova.

## Tester, não conta Goat
As ordens existem exclusivamente no Strategy Tester isolado
MetaQuotes-Demo, nunca são enviadas à conta comprada. OnInit
recusa execução fora do tester, patrimônio inicial diferente
de US$5k e parâmetros de risco mais altos.
Respeita lote <=0,02, risco individual <=US$12,50, uma
posição simultânea, limites preventivos do benchmark.
O reset diário implementado continua pelo dia do servidor,
NÃO é o horário de reset GOAT; isso não comprova conformidade.
Há reservas de slippage, mas gaps podem ultrapassar limites.

## Executar após preparar arquivos no projeto existente

Arquivos:
- MQL5/Experts/ALIEN_GOAT5K_H1M15_AB_TESTER.mq5
- MQL5/Profiles/Tester/ALIEN_GOAT5K_H1M15_A_BASE.set
- MQL5/Profiles/Tester/ALIEN_GOAT5K_H1M15_B_CONTEXT.set
- tools/RODAR_GOAT5K_H1M15_AB.ps1
- tools/audit_goat_h1m15_ab.py (opcional)

PowerShell:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\RODAR_GOAT5K_H1M15_AB.ps1

O comando utiliza o MT5 isolado já instalado, compila no
MetaEditor do notebook e roda A e B em série. Se a compilação
falhar, não considera o teste válido.

Análise Python opcional:
    python tools/audit_goat_h1m15_ab.py PACOTES_MT5/ALIEN_H1M15_AB_*.zip

A auditoria confere 6 hashes, os modos, EX5 compartilhado,
registros de entrada/saída, net dos deals e uma estimativa de
taxa extra. Se o tester já cobrou comissão, o cenário adicional
pode contar taxa duas vezes. Drawdown do CSV de eventos não
substitui drawdown do HTML, que deve ser auditado separadamente.

## Resultado esperado
Ter duas políticas de execução com evidências e mesma base de
custos. Melhorar o PnL no período conhecido não basta:
precisamos de vantagem líquida plausível fora da amostra.

**Estado:** código publicado, testes estáticos pendentes,
compilação e resultados primários MT5 ainda não realizados.
