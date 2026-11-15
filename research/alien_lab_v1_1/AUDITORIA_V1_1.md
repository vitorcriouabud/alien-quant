# Auditoria independente — ALIEN LAB V1.1

## Base e reprodutibilidade

- Motor de origem: `ALIEN_LAB_V1_MOTOR.zip`, SHA-256 `af9c00fcce3fe68491db0e9e6b32518177ff0bbf1271778e9953e891a89321bf`.
- CSV M1 da RoboForex: 100.000 barras; SHA-256 `2e49d012df1183a2ad29cb538ccc3df1c38f19c4d67bb7b81e786d84027e7558`. **Não publicar CSV com possível metadado de conta; permanece local.**
- Texto das definições A–G: SHA-256 `cf3314529d3562b679fc45706fc22782cc3134ad3d94a08f8bed4064265ece4e`, preservado.
- Ferramentas: Python 3, Pandas/Numpy/Pytest. Rodadas e testes reexecutados localmente sem acesso a operações MT5.
- Testes de regressão adicionais: leitura do CSV, invalidade rejeitada, reserva interna, overlap, retomada com CSV/config/código alterados ou ausentes, ZIP reconstruído, eventos adulterados, causalidade por truncamento.

## Resultados da grade reduzida 100K

Parâmetros: entrada M1 seguinte; saída após 15 barras; slippage hipotético 10 pontos MT5; spread zero excluído e penalizado (20 pts); `position_policy=one_per_hypothesis`; fuso do servidor fixo UTC+2 não verificado. Relatório gerado automaticamente; veja CSV para números completos.

- 168.466 sinais detectados, 336.932 eventos registrados (ambos os cenários de spread).
- H14/H16 originais continuam com resultados exploratórios predominantemente negativos; não modificar regras para otimizá-las sobre a base conhecida.
- Resultados da família E não são classificáveis: horário de verão e offset da corretora não verificados.
- Nenhuma hipótese foi promovida a lucrativa, nenhuma ordem foi enviada.

## Corrigido

1. Alias nativo `time_server` e recusa de linhas inválidas.
2. Identidade de corrida com hashes de dados, parâmetros, código e definições; retomada exige eventos completos e produz ZIP validado.
3. Exclusão do período reservado se **qualquer barra** do sinal até a saída estiver dentro dele.
4. Política anti-overlap por hipótese configurável; evento descartado recebe `overlap_skipped` (auditável).
5. Classificação `TIMEZONE_UNVERIFIED` e aviso sobre sessões quando offset é apenas assumido.
6. Relatório de pares inclui contagem de eventos coincidentes e deixa claro que comparação de médias distintas não é prova de melhora causal.
7. O comando `.cmd` não faz reinstalações repetidas das dependências.

## Pendente — não esconder

- Falta gerenciador de carteira global e política de risco por saldo, correção por múltiplos testes, walk-forward com embargo e dados tick-a-tick.
- Falta conversão DST fidedigna do servidor RoboForex e custos reais de comissão, swap, execução/slippage.
- Grande grade completa ainda retém eventos em memória; no notebook 8 GB use a grade reduzida para não esgotar RAM. Não é executor noturno escalável por chunks.
- Não há recuperação de meio de execução se o processo cair antes de escrever events.csv: apenas retomada a partir do CSV completo.
- Confiança nas 7 famílias depende de validações adicionais independentes; uso autorizado **somente pesquisa**.
