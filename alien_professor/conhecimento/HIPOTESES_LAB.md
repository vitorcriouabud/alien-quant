# Hipóteses pré-registradas do laboratório

Nenhuma das hipóteses abaixo está provada. Foram tiradas só das regras mensuráveis do material (Lógica do Preço, sessões ICT e padrões clássicos de vela). O laboratório deve registrá-las **antes** de olhar o resultado de 2026 e não pode reotimizar no mesmo período.

## Regras comuns a todas

- **Mercado e tempo:** XAUUSD, gráficos M1 e M5 (a entrada no M1 só vale se o viés de pelo menos M15, ou o viés do dia, estiver a favor; isso faz parte da regra, não é filtro solto depois do resultado).
- **Custos:** spread + comissão reais da conta (e slippage médio observado, se houver). Sem custo zerado. Se a corretora mudar, anotar a tabela usada.
- **Período fora da amostra:** ano calendário de 2026, do primeiro pregão até a data do teste, sem retocar parâmetros nesse intervalo. O que restar de 2026 depois do teste continua fora da amostra. Se precisar calibrar tolerância de pavio ou tamanho de stop, usar só dados anteriores a 2026 e travar os números antes de medir 2026.
- **Critério de sucesso (igual para todas, para poder comparar):** esperança matemática por operação **maior que zero depois dos custos**; amostra mínima de **200 operações** no período (se não chegar a 200, o resultado é inconclusivo, não "quase bom"); drawdown máximo da curva de 2026 **não pior que 20%** do capital simulado; e a média do alvo realizado precisa respeitar pelo menos 1:1 médio previsto, senão a hipótese falhou por custo ou por assimetria ruim, mesmo que a taxa de acerto seja alta.
- **Stop e alvo padrão,** salvo quando a hipótese disser outra coisa: stop atrás do outro lado da estrutura que definiu a marca; alvo na próxima marca ou na máxima/mínima anterior, o que vier primeiro, desde que o alvo projetado seja pelo menos igual ao risco. Sem isso, não entra.
- **Horário:** kill zones convertidas para Brasília, com a troca do horário de verão dos EUA (em 2026: verão de 8 de março a 1º de novembro; fora isso, inverno = NY + 2 horas).
- **O que não conta como sucesso:** curva bonita só na amostra de calibração, frase do curso, ou "no olho deu certo".

## H1 — Reação no 50% do comando, em Londres ou NY

**Regra exata.** Detectar comando N1 ou N2 no M5 ou no M1 (pavio no lado da abertura de no máximo 10% do corpo; no N1, os dois lados). Na kill zone de abertura de Londres ou de Nova York, se o preço buscar os 50% do corpo desse comando e rejeitar (fechar de volta para o lado da abertura do comando), entrar nessa direção. Stop além da extremidade oposta do comando. Fora da kill zone, ignorar.

**Ideia do material.** O curso marca os 50% porque o comando "repele" (bate-estaca).

## H2 — Reteste depois do rompimento de corpo de um micro-lote

**Regra exata.** Um micro-lote (duas ou mais velas seguidas da mesma cor no M5) é rompido por uma vela cujo **corpo** atravessa a vela que abriu o lote. Não entrar no rompimento. Entrar só no primeiro retorno (throwback) à borda rompida, se a rejeição confirmar a nova direção, ainda dentro de Londres, da sobreposição ou de NY abertura. Stop atrás do extremo da vela de rompimento (ou do lote, o que for mais distante e ainda respeitar 1:1).

**Ideia do material.** Rompimento só conta com o corpo; a entrada forte é o retorno, não a perseguição.

## H3 — Pullback no alinhamento nova alta/baixa + nova posição

**Regra exata.** Depois de um rompimento de zona de pavio ou de lote, marcar o primeiro pavio novo (nova alta ou nova baixa) e a nova posição (segunda vela do movimento). Se o preço permanecer acima do alinhamento de alta, só vale compra no toque rejeitado dessa zona. Se permanecer abaixo do alinhamento de baixa, só vale venda. Sem toque na zona, não entra. Kill zones iguais às de H2. Stop atrás do pavio da nova alta/baixa (ou da nova posição, o que for mais extremo).

**Ideia do material.** Essa é a confluência que o texto chama de forte; a nova alta/baixa sozinha não é gatilho.

## H4 — Caçada da faixa da Ásia e reversão na abertura de Londres

**Regra exata.** Medir a máxima e a mínima da kill zone da Ásia (20:00–00:00 NY, já convertida). Na kill zone de abertura de Londres, se o preço romper uma das pontas dessa faixa e depois fechar de volta para dentro (varredura), entrar na direção da volta. Stop além do extremo da varredura. Alvo: a outra ponta da faixa da Ásia, ou 1:1, o que for mais conservador no momento da entrada (registrar qual dos dois foi usado; na calibração escolher um e travar).

**Ideia do material.** A Ásia em geral consolida e "segura pistas" da faixa do dia; Londres costuma fazer o movimento grande e pode marcar a máxima ou a mínima do dia.

## H5 — OTE de 62% a 70% do swing de Londres, na abertura de NY, a favor do viés do dia

**Regra exata.** Viés do dia = direção do corpo do candle diário em formação em relação à abertura verdadeira do dia (00:00 NY). Swing de Londres = máxima e mínima da sessão de Londres até o início da kill zone de NY. Na kill zone de abertura de NY, se o preço retrair 62% a 70% desse swing **a favor do viés do dia** (desconto em dia de alta, prêmio em dia de baixa) e rejeitar, entrar na direção do viés. Se Londres tiver fechado contra o viés do dia, a hipótese não opera (teste da afirmação "se Londres concordou, NY continua"). Stop além do extremo do swing. Alvo 1: o equilíbrio (50%) ou a origem do swing, o que vier primeiro com pelo menos 1:1; o resto pode ser registrado como gestão, mas o sucesso da hipótese é no primeiro alvo.

**Ideia do material.** OTE 62–79% (com 70% destacado) + regra de continuação de NY quando Londres concorda com o dia.

## H6 — Desistalação / máximas ou mínimas iguais, depois rompimento de corpo

**Regra exata.** No M5, duas ou mais velas com máximas alinhadas (tolerância de 0,3 USD) sem fazer nova alta, ou mínimas alinhadas sem fazer nova baixa, dentro de uma kill zone de Londres ou NY. Entrar só quando uma vela seguinte romper com o **corpo** o lado oposto dessa linha e o preço retestar a linha na nova direção. Stop além da linha de iguais. Não entrar só porque os pavios "estão bonitos".

**Ideia do material.** Pavios alinhados = não houve nova alta ou nova baixa, então o preço tende a sair para o outro lado; desistalação muda a cor depois de travar na simetria. Também se aproxima da liquidez de iguais do ICT (EQH/EQL).

## H7 — Comando de reversão no extremo versus comando no meio da pernada

**Regra exata.** Usar o mesmo gatilho de H1 (reação nos 50% do comando N1 ou N2, nas mesmas kill zones e com o mesmo stop/alvo). Dividir as operações em dois baldes, definidos antes: (A) o comando nasce no extremo de um swing de pelo menos 20 velas de M5 (topo ou fundo); (B) o comando nasce no meio da pernada. A hipótese afirma que o balde A tem esperança melhor que o balde B, e que só o A passa no critério de sucesso. O balde B é o controle.

**Ideia do material.** "Comandos formados em topos e fundos são muito fortes." Isso é afirmação testável, não fato.

## H8 — Não operar consolidação apertada; só rompimento + reteste

**Regra exata.** Definir consolidação apertada no M15: as últimas 12 velas cabem numa faixa menor que 1,5 vezes a mediana das faixas (high-low) das 50 velas anteriores. Nesse estado, não operar retração interna. Só entrar no primeiro reteste após um fechamento de corpo fora da faixa, na direção do rompimento, se ainda estiver em kill zone de Londres ou NY. Comparar, como controle, o que teria acontecido se as retrações internas tivessem sido operadas (mesmo stop/alvo): a hipótese afirma que o modo "só rompimento + reteste" passa no critério de sucesso e que o modo "operar dentro" não passa.

**Ideia do material.** O autor das anotações não recomenda operar gráfico consolidado; o cenário preferido são topos e fundos claros, ou fluxo depois que a região abre.

## Como reportar

Para cada hipótese: número de trades, taxa de acerto, esperança depois do custo, drawdown, pior sequência, e se passou ou falhou no critério acima. Sem "quase". Sem misturar as hipóteses no mesmo relatório como se fossem um sistema só, a não ser num teste extra, pré-registrado, de combinação explícita.
