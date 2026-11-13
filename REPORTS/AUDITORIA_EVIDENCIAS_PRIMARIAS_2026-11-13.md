# ALIEN LAB — Auditoria de evidências recebidas em 13/11/2026

**Estado:** auditoria de evidências primárias de testes históricos e CSVs, NÃO aprovação da estratégia.

## Proveniência e integridade

Recebido um ZIP de coleta `ALIEN_EVIDENCIAS_20261113_032408.zip`, com
`manifest.json`. O repositório é público; **nenhum arquivo bruto foi enviado
ao GitHub**. Pacote coletado em 2026-11-13 03:24 UTC. Os arquivos foram
lidos diretamente do ZIP, sem modificar os originais.

- 48 arquivos de origem: 23 relatórios HTM do Testador, 24 CSVs e 1 HTML.
- 48/48 SHA256 do manifesto verificados, 0 falhas de CRC, manifesto externo
  idêntico ao manifesto incorporado.
- Integridade de bytes **não significa** veracidade da hipótese, identidade
  do binário EX5, fidelidade de custos reais ou reprodutibilidade.

## Evidência primária selecionada

| Relatório MT5 | Janela | Qualidade indicada no MT5 | PnL USD | PF | Trades | DD máximo equity USD |
|---|---|---:|---:|---:|---:|---:|
| V10_89_OUTUBRO_2026 | 19–24/10 | 60% ticks reais | +51,77 | 1,14 | 949 | 133,25 |
| V11_OUTUBRO_SEM1 | 05–10/10 | 0% ticks reais | +33,60 | 3,18 | 75 | 4,30 |
| V11_OUTUBRO_SEM2 | 12–17/10 | 0% ticks reais | +13,73 | 1,92 | 75 | 4,95 |
| V11_OUTUBRO_2026 | 19–24/10 | 60% ticks reais | +10,54 | 1,49 | 68 | 11,51 |
| V11_OUTUBRO_SEM4 | 26–31/10 | 100% ticks reais | -12,42 | 0,38 | 37 | 13,92 |
| V11_NOVEMBRO_2026 | 02–07/11 | 100% ticks reais | -7,97 | 0,69 | 65 | 10,12 |
| EXP_014_GOAT_10K | 05–17/10 | **0% ticks reais** | +748,30 | 2,47 | 140 | 90,12 |
| EXP_015_V12_1_BENCHMARK | 21–24/10 | 100% ticks reais | -105,66 | 0,71 | 30 | **223,28** |
| EXP_018_V12_1_VERIFIED | 21–24/10 | 100% ticks reais | -3,24 | 0,98 | 30 | 110,59 |
| ALIEN_EXP018 | 21–24/10 | 100% ticks reais | +69,32 | 1,40 | 32 | 58,37 |
| EXP_019_V11_2_GOAT_AB | 21/10–06/11 | 100% ticks reais | -730,17 | 0,46 | 155 | 835,87 |
| EXP_020_V12_1_AB | 21/10–06/11 | 100% ticks reais | -155,14 | 0,81 | 118 | 251,28 |
| EXP_020_REPRO | 21/10–06/11 | 100% ticks reais | -189,90 | 0,62 | 65 | 268,92 |
| EXP_021_V12_1_VALIDATED | 21/10–06/11 | 100% ticks reais | -73,08 | 0,76 | 37 | 153,90 |
| EXP_022_V12_1_HARMONIC | 21/10–06/11 | 100% ticks reais | -109,44 | 0,79 | 75 | 190,44 |
| EXP_023_V12_1_IN_SAMPLE | 05–17/10 | 100% ticks reais | -200,88 | 0,14 | 18 | 200,88 |
| EXP_024_V12_1_IN_SAMPLE_CORRECTED | 05–17/10 | 100% ticks reais | -555,30 | 0,33 | 62 | 563,40 |

A tabela acima é um subconjunto de 23 relatórios. Outros arquivos incluem
o P0 Turbo (-444,64, PF 0,83, 192 trades em M5) e EXP-016/017 (negativos).

**Resumo de cobertura:** 15 relatórios indicam literalmente
`100% de ticks reais`; **14 deram prejuízo e 1 lucro**. As janelas e
variantes se sobrepõem; isso NÃO corresponde a 15 observações independentes
nem a uma estimativa estatística da probabilidade de lucro.

## Achados críticos

### P0 — Métrica confundida com guarda de risco

EXP-015: saldo final -105,66; `Rebaixamento Absoluto do Capital Líquido`
105,66; **Rebaixamento Máximo do Capital Líquido 223,28 (2,21%)**.
Um registro histórico alegava DD máximo 105,66, usando a medida errada.
**Ressalva:** DD de pico a vale > 200 *não prova, sozinho*, que o
`TotalMaxLossMoney=200` foi violado: o limite do EA pode usar outra
referência (por exemplo, saldo/equity inicial da conta). Auditar a semântica
da trava e a série de equity com referência explícita.

### P0 — Cobertura de ticks diferente do rótulo do experimento

EXP-014, as duas semanas positivas V11 e o V11.2 DESAFIO registram
**0% de ticks reais** embora `EXPERIMENTOS.csv` os rotule
`Real Ticks (4)`. V10.89 outubro e V11 outubro registram **60%**, não
100%. A seleção do modelo de ticks é diferente da cobertura real de dados.
Não chamar resultados de 100% tick real quando o HTML diz o contrário.

### P0 — Resultado não reprodutível no EXP-018

`ALIEN_EXP018.htm`: +69,32, PF 1,40, 32 trades;
`EXP_018_V12_1_VERIFIED.htm`: -3,24, PF 0,98, 30 trades.
Ambos reportam **mesmos 4.125 candles e 1.440.985 ticks reais**, mesma
janela, ativo, depósito e alavancagem. Diferença entre entradas
parametrizadas observáveis: `TeacherPanelCompactRows` e
`TeacherPanelWidth` (painel visual). Entretanto a primeira entrada
efetiva diverge (11:10 versus 11:01).
**Não está comprovado** que o EX5/EA binário era idêntico; sem hash do
binário, Git SHA, .set e logs de inicialização é impossível atribuir a
diferença ao painel ou declarar reprodutível.

### P0 — A/B e extensão temporal falharam

EXP-014 +748,30 / 0% ticks reais no período 05–17/10 versus
EXP-019 -730,17 / 100% ticks reais no período 21/10–06/11:
não são testes diretamente comparáveis nem prova de ganho robusto.

EXP-020 A/B -155,14, 118 trades versus EXP-020 REPRO -189,90,
65 trades, mesma janela e ticks. Os `input` declarados exibem uma
diferença adicional na presença de `AllowLiveRealTrading` (presente
no REPRO), sugerindo build/configuração divergentes. Não afirmar
reprodução até congelar binário e ambiente.

### P1 — Preset diverge da meta de risco

Vários testes V12.1 usam `MaxRiskPercentEquity=0.5` e
`FixedLot=0.18` numa conta de 10K, enquanto o objetivo de pesquisa
definido posteriormente é 0,25% por trade. Resultados em 0,5%
não validam a configuração de 0,25% nem os limites de mesa 5K.

### P1 — CSV de observador não é tabularmente confiável

`ALIEN_CONFLUENCIA_OBSERVER.csv` do agente do testador: 3.983 linhas
de dados; **41 têm mais que as 14 colunas do cabeçalho**, por
ponto e vírgula sem escape no campo `reason` ou `poi`.
Contando a decisão pelo campo correto apesar do desalinhamento:
**3.983 ABSTER, 0 ordens enviadas**. Há 8 candidatos de sinal
(sweep/reclaim/MSS), todos abstidos (6 por contexto HTF e 2 por
configuração de filtro de spread). Isso é evidência de bloqueio de
execução, não de retorno financeiro.

CSV observado no terminal (53 linhas) é de AUDCAD, 53 ABSTER,
sem sinais nem ordens; não serve de resultado XAUUSD.

### P1 — Telemetria de sweeps é repetitiva e não equivale a trades

Um CSV de terminal tem aproximadamente 3.105 eventos brutos:
3.101 `SWEEP_OBSERVED_*`, mas só 1 `ENTRY` e 1 `CLOSED_POSITION`
no registro. Muitos sweeps são notificações de observação repetidas
por tick, não setups independentes. Exigir `event_id` estável, motivo
de veto e resultado por evento.

### P1 — CSV `EXPERIMENTOS.csv` precisa de auditoria automática

O arquivo contém 23 registros de experimentos. Vários têm notas
adjetivas de 'campeão', 'sucesso', 'protegido' sem vincular hash do
relatório original, versão exata e qualidade real de ticks.
EXPERIMENTOS.csv deve ser **derivado de artefato**, não fonte primária
para alegar retorno. `Model=4` não substitui `Qualidade do histórico`.

## Decisão metodológica

1. Preservar os EAs e **não publicar** o ZIP bruto num repositório público.
2. Não liberar real nem proclamar "versão final".
3. Bloquear merges que alterem lógica de ordens até reunir:
   fonte/EX5 hash, commit SHA, .set, símbolo+contrato, ticks reais,
   inicialização, spread/commission/slippage e relatório completo.
4. Repetir EXP-018 três vezes, em instalação MT5 isolada, EX5 e .set
   idênticos, comparação de lista de deals e timestamps.
5. Corrigir o CSV do observador (quotes/escape ou remover `;` dos
   campos de texto) e teste de schema de 14 colunas.
6. Construir matriz de experimentos isolados para testar SMC Liquidity
   **após** correção de risco e cronologia; este ZIP não inclui relatório
   de backtest do SMC Liquidity e não permite comparar performance.
7. Separar calibragem, validação temporal e holdout nunca utilizados
   para seleção; exigir resultado líquido após custos e DD aceitável,
   não apenas PF positivo numa janela curta.

**Conclusão:** integridade da coleta está confirmada; vantagem
estatística confiável do ALIEN V12.1 **não está demonstrada**.
