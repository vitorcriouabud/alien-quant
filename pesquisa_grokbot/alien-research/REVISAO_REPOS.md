# Revisão dos repositórios GitHub do Vitor

**Data:** 15/11/2026 (horário de Brasília)  
**Conta:** [vitorcriouabud](https://github.com/vitorcriouabud)  
**O que eu fiz:** listei todos os repositórios visíveis na conta (5 no total), li o que cada um contém e comparei as ideias de estratégia com a pesquisa que está em `/workspace/alien-research`. Não alterei nenhum outro repositório. Não mexi na `main` nem nos arquivos da V11 que já estão lá.

**Conclusão curta:** nos projetos que você já tentou, não achei uma estratégia nova e pronta que a pesquisa ainda não tenha testado e que pareça forte. A única vantagem que passou nos testes honestos continua sendo a **cesta de índices** (RSI2 + IBS em US500, Nasdaq e DAX), com cerca de **3,8% ao ano** depois do swap real da RoboForex. Quase tudo de ouro, SMC/ICT e scalping M1 já foi medido e reprovado.

---

## Os 5 repositórios

### 1. alien-quant (público) — o projeto principal do ALIEN

**O que é:** o repositório do robô ALIEN no MetaTrader 5. Na `main` estão a V11 SCALPER, a V11.1 SNIPER, a V11.2 (Freedom e Goat 10K), a V12 / V12.1 Institutional, o indicador Observer (só observa, não opera), a V10.89 e o EA educativo P0 (preservados), mais dezenas de scripts de teste, painel e Telegram.

**O que o próprio repositório já concluiu (e o que a pesquisa nova corrigiu):**
- O EA educativo P0 no M5 foi rejeitado no próprio `DECISOES.md` (perdeu US$ 444 em 3 meses, fator de lucro 0,83).
- A Confluência v0.2 foi rejeitada no branch `research/alien-evidence-gate-20261112` (expectativa −0,36 R por trade, fator de lucro 0,54).
- Rompimento + reteste histórico também foi rejeitado (as duas políticas perderam depois do custo).
- O arquivo `ESTADO_ATUAL.md` (08/11/2026) ainda diz que a V11 ganhou +US$ 37,48 em 5 semanas de outubro/novembro, com fator de lucro 1,42. **Essa conta não se sustenta.** Nos testes desta pesquisa, com ticks reais e um período maior (agosto a novembro de 2026), a V11 fica no prejuízo ou no zero. O “lucro” antigo veio, em boa parte, do modo de ticks gerados pelo testador, que inventa um caminho dentro do minuto e favorece a entrada da V11. O diagnóstico está em `DIAGNOSTICO_V11.md` e `REAL_TICKS_V11.md`. As 5 correções tentadas (filtro, stop, break-even, etc.) foram reprovadas. O disjuntor de US$ 12 funciona; a entrada é que não tem vantagem.

**Branches e PRs (coisas que você já tentou, fora da main):** há 19 branches e vários PRs em rascunho. As ideias principais:

| Ideia (branch / PR) | O que é | Já testamos? | Promissor? |
|---|---|---|---|
| SMC + liquidez (PR 3) | Auditoria de um EA SMC (sweep, CHoCH/BOS, FVG/OB, zona premium/discount). O arquivo original nem entrou no GitHub. Só análise estática, sem backtest. | Sim, na essência: 720 combinações de SMC/ICT (viés, liquidez, FVG/OB, alvo 2R/3R) em ouro, câmbio e índices. Nenhuma sobreviveu. | Não como está. É o mesmo modelo, com problemas graves de risco no código auditado. |
| Hipóteses de scalp V12.2 (PR 1) | Seis padrões novos no M1, com definição fechada, ainda **sem backtest com custo**. | Em parte. FVG, OB e falso rompimento já foram testados e reprovados. Impulso/correção e compressão/rompimento são as definições mais “novas”. | Só como teste honesto, com expectativa baixa. Não é evidência de lucro. Ver seção “o que ainda vale testar”. |
| Gate de evidências (PR 2) | Boa disciplina: congelar regras, auditar custos, não promover o que não passou. Cita também um “gap semanal” frágil (41 trades, PF 1,68, poucos outliers). | Reabertura / gaps já entraram em MERCADO.md e LITERATURA.md e ficaram fracos. | O método sim; o gap semanal, não — amostra pequena e dependente de poucos trades. |
| GENESIS R4, R4.1–R4.4 | Motor multi-tempo, reteste depois de stop, CHoCH cedo no M1, stop no pivô M1 vs M5, só observando. | A cascata H4→M1 (confluência) foi testada em MERCADO.md e **piorou** o resultado. CHoCH/BOS já estavam nas 720 combinações. | Como laboratório de medição, ok. Como estratégia pronta, não. |
| Goat 5K (vários PRs) | Perfil de risco 1% floating, tester, A/B H1/M15, “turbo” sem travas, 9 backtests. | A simulação Goat da cesta de índices está em GOAT.md (ainda com o swap antigo, depois corrigido). Scalping no ouro para passar a mesa rápido não tem base. | Útil como infraestrutura de teste. Não muda o fato de que o ouro M1 não tem vantagem. |
| Filtros institucionais (`dev-filtros-institucionais`) | Tentativa de filtrar “fluxo institucional”. | Volume, sessão, BB e confluência já foram medidos e não criaram vantagem no ouro. | Pouco provável, a menos que o filtro seja outra coisa bem definida e ainda não testada. |

**Atenção de segurança (não alterei a main):** na `main` já existem arquivos com token de Telegram em texto puro, citados no pedido (`tools/telegram_alien_bot.py`, `tools/send_demo_chart.py`, `tools/alien_sync_engine.py`, `tools/alien_neural_bridge.py`). O repositório é **público**. Vale trocar o token no BotFather e tirar esses arquivos da `main` numa PR sua, depois. Eu não mexi nesses arquivos.

---

### 2. bud-central-sync (privado) — ponte de leitura

**O que é:** um script que, de 5 em 5 minutos, publica no GitHub um resumo só de leitura (estado do observador, até 10 candles M1, spread, contagem de posições). Não instala EA, não abre nem fecha operação, não muda stop nem lote.

**Estratégia?** Nenhuma. É infraestrutura. Não há o que testar como regra de lucro.

---

### 3. bud_smc_forex (público) — plataforma SMC para Forex

**O que é:** um sistema web (React + Node + scripts Python) para detectar Order Block, FVG, BOS e CHoCH, juntar vários tempos gráficos, mandar alerta no Telegram e mostrar um painel. Data de janeiro de 2026. Desenvolvido com Manus AI.

**O que falta no próprio projeto:** o `todo.md` mostra que backtest, conexão de dados ao vivo, bot, dashboard e gestão de risco **não foram implementados**. A engine SMC existe no código (`server/smc-engine.ts`), mas não há resultado histórico publicado.

**Já testamos?** Sim, a ideia central. Na pesquisa V2, 720 regras objetivas de SMC/ICT (incluindo FVG, OB, BOS/CHoCH, liquidez da Ásia e do dia anterior, entrada e alvo) foram rodadas em ouro, câmbio e índices, com e sem custo. Nenhuma passou. Em MERCADO.md, juntar mais filtros (confluência máxima) **piorou** o desempenho.

**Promissor?** Não como fonte de uma vantagem nova. Pode servir no futuro como painel do “robô professor” (marcar FVG/BOS no gráfico e avisar), mas isso é ferramenta, não estratégia lucrativa.

---

### 4. bud_ai_module (público) — conversa no Telegram

**O que é:** módulo de conversa com personalidade “alienígena”, rodando modelo local (Ollama / Phi-3), para o bot do Telegram. Junho de 2025.

**Estratégia?** Nenhuma. Não opera, não lê gráfico, não tem regra de entrada.

---

### 5. bud_supreme (público, branch padrão `master`) — “IA preditiva”

**O que é:** um esqueleto de sistema autônomo que editaria o próprio código (comandante, editor, guardião, intérprete + Telegram). A descrição fala em “trading com IA preditiva”, mas o arquivo de estratégia é só isto:

```
def adjust_strategy_for_bullish_trend():
    # Implementar lógica aqui
    pass
```

O gerenciador de risco também está vazio. Não há modelo preditivo treinado, nem backtest, nem regra operacional.

**Promissor como estratégia?** Não. É arquitetura de software, não uma ideia de mercado testável.

---

## O que a pesquisa desta semana já mediu (para comparar)

- Cerca de **2.350 tentativas** (ouro, câmbio, índices, petróleo, prata, notícias, literatura, “tiro” de alvo alto).
- **V11 com ticks reais:** sem vantagem. O lucro antigo era efeito do testador com ticks gerados. Correções F1–F5 reprovadas.
- **Bug do swap:** na pesquisa V2 o swap estava cerca de 1.000 vezes menor do que o real (o pandas guarda data em microssegundos e o código dividia como se fosse nanossegundo). Na prática a pesquisa rodou quase sem swap. Com o swap certo da RoboForex, a cesta de índices cai de ~6,2% para **~3,8% ao ano** no testador do MT5 (swap comeu ~38% do lucro bruto). Em 2025 e 2026 o resultado ficou praticamente no zero. Queda máxima ~7–8%. Não quebra a conta, mas é lento.
- **Ouro, SMC/ICT, varredura de liquidez, fixing de Londres, COT, Larry Williams, notícias, tendência H4/D1, confluência multi-tempo:** reprovados depois do custo.
- Uma pista fraca, só para observação (não para dinheiro): candle de corpo forte + volume 2× + rompimento + FVG no M15 (VO3 da literatura). Deu lucro de 2016 a 2024 (poucos trades), perdeu em 2025, e um único dia carregou 14,5% do lucro.

---

## O que ainda vale testar (com honestidade, expectativa baixa)

Estas são as únicas ideias dos seus projetos que **ainda não foram medidas do mesmo jeito** (custo real, período longo, validação fora da amostra):

1. **Hipóteses 6 e 7 da V12.2 (impulso/correção e compressão/rompimento no M1 do ouro)**  
   Estão definidas no branch `feat/scalp-hypotheses-lab`, com presets, mas **nunca rodaram um backtest com custo**. São primas de padrões que já falharam, então a chance é pequena. Se for testar: ticks reais (ou pelo menos bid/ask), comissão e spread da ECN, período 2016–2024 para escolher e 2025 + 2026 só no fim, sem mexer regra depois de ver o número.

2. **Conta ou corretora com swap menor (ou swap-free) na cesta de índices**  
   Não é uma estratégia nova: é a mesma cesta, com outro custo. O swap da RoboForex come quase 40% do lucro. Se existir uma conta legal, com execução parecida e swap bem menor, o retorno pode chegar mais perto dos 6% da pesquisa “sem swap”. Isso precisa ser medido na conta real/demo daquela mesa, não chutado.

3. **VO3 (volume + corpo forte + FVG no M15 do ouro)**  
   Só observação. Não operar. Se no futuro o volume real (futuros COMEX) ficar disponível, aí sim vale repetir o teste. No MT5 o volume do ouro é só tick volume.

**Não recomendo gastar tempo agora em:** repetir SMC/ICT, V11/V12 como estão, P0 M5, gap semanal, filtros “institucionais” genéricos, nem aumentar o risco para passar a Goat mais rápido.

---

## Testes recomendados (ordem)

1. Deixar a cesta de índices rodando só em **demo**, com o EA `ALIEN_INDICES_V1`, e conferir se o lucro/swap do extrato bate com o `TESTE.md`.
2. Se quiser uma última cartada no ouro M1: testar só as hipóteses 6 e 7 da V12.2, com o protocolo acima. Se falharem, encerrar essa família.
3. Pesquisar (sem operar) uma conta swap-free / swap menor para a cesta, e só então simular de novo.
4. O “robô professor” (marcar liquidez, FVG, BOS e volume no gráfico, você decide) continua sendo útil no dia a dia, mesmo sem vantagem automática — isso é ferramenta, não fonte de 1.000 dólares por dia.

