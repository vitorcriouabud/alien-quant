# A/B 23/11/2026 23:44 — repetição incorreta do intervalo antigo

Fonte primária: usuário enviou `ENVIAR_ALIEN_AB_20261123_234432.zip` (A e B, HTML, CSV, TXT, arquivos de validação).

## Conclusão

**Não corresponde ao teste novo solicitado (13–22/11).** O próprio `VALIDACAO_E_VERSAO.txt` afirma `Periodo de VALIDACAO CANDIDATA: 2026.11.02 a 2026.11.12`, e ambos os HTML confirmam `M1 (2026.11.02 - 2026.11.12)` e `Qualidade do histórico: 0% de ticks reais`. Resultado idêntico ao teste anteriormente recebido; **não é uma validação independente**.

| Métrica | A | B |
|---|---:|---:|
| Período MT5 | 02–12/11 | 02–12/11 |
| Qualidade MT5 | 0% ticks reais | 0% ticks reais |
| Líquido | +48,32 USD | +11,14 USD |
| Negociações | 78 | 43 |
| Profit factor | 5,21 | 1,67 |
| DD máximo equity | 0,05% | 0,18% |
| Mesmo EX5 SHA256 | `317F2B54C29365782E04376AE84544EAD5D3167E3C82D5EE298AFAE20646A940` | mesmo |

A e B continuam distinguíveis pelo parâmetro `RequireSweepCandleAlignment=false/true`. Fonte, risco e data permanecem inalterados. Não inferir lucro real nem robustez.

## Correção no automatizador, fora do EA

O pacote anterior para 13–22/11 **já continha** `FromDate=2026.11.13` e `ToDate=2026.11.22` no PowerShell. Assim, a evidência é compatível com o usuário ter aberto o iniciador antigo ainda extraído no computador, cuja versão deixava as datas 02–12/11. Não é possível demonstrar a ação do usuário com certeza; diagnosticar como **versão errada do iniciador efetivamente executada**.

Foi criado um pacote local novo `ALIEN_AB_13_A_22_NOV_V2_CORRIGIDO.zip` com iniciador **diferente** `EXECUTAR_TESTE_13_A_22_NOV_V2.cmd`, tela com título de data, código de coleta com nome de relatório/ZIP único `ENVIAR_ALIEN_AB_NOV13_22_V2_`, checagens automáticas do `FromDate`/`ToDate` no INI e **verificação da data efetiva no HTML** além da qualidade 100% de ticks reais. Não há mudanças no código MQL5, presets ou estratégia.

**Status**: novo pacote montado e inspecionado estaticamente; **ainda não foi executado no Windows do usuário**. Se der 0% de ticks reais, não considerar aprovado. O período 13–22/11 é diagnóstico dentro da amostra já conhecida, não validação fora da amostra. Não operar em conta real ou fazer merge.
