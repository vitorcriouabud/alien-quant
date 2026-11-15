# ALIEN PROFESSOR — manual simples

É um **indicador** pro MT5. Ele **não abre, não fecha e não mexe em ordem nenhuma**. Ele lê o gráfico pra você e mostra tudo num painel preto e amarelo. **Quem decide é você.**

Feito pra ouro (XAUUSD) e índices (.US500Cash, .USTECHCash, .DE40Cash) na RoboForex ECN. Usa os dados reais do símbolo (valor do tick, lote mínimo, passo do lote), então o lote é calculado certo pra cada um.

## O que funciona de verdade (leia antes de tudo)
- **Índices = robô ALIEN_INDICES_V1** (pasta `indices/`). Opera S&P 500, Nasdaq 100 e DAX 40 no diário (reversão à média, stop fixo, sem martingale). No teste longo a cesta dos 3 índices deu **~3,8% ao ano**, com **queda máxima ~7,6%** e **PF 1,28**. É pouco, mas é **real e positivo**.
  - Precisa de **~US$ 3.200** na conta (Pro/ECN em dólar) pra operar os 3 a 1% de risco. Com menos ele pula sinais.
  - **Rode 1 mês em DEMO primeiro.** Manual completo: `indices/README_PT.md`, testes em `indices/TESTE.md`.
- **Ouro = professor (manual).** O indicador ALIEN_PROFESSOR e o chat do Telegram te ajudam a ler o gráfico, mas **quem decide é você**. O robô AUTO no ouro perdeu no teste de 10 anos: use só em demo, ou no **MODO ASSISTENTE** (*InpTradeEnabled = false*).

## 1. Instalar (2 minutos)
**Jeito fácil:** descompacte o zip e dê dois cliques em **INSTALAR.bat**. Ele acha seus MT5 e copia tudo. Depois feche e abra o MT5.

**Jeito manual:**
1. No MT5: **Arquivo > Abrir pasta de dados**.
2. Entre em `MQL5\Indicators` e cole o `ALIEN_PROFESSOR.ex5` (ou o `.mq5`).
3. Volte no MT5, no **Navegador** clique com o botão direito em *Indicadores* > **Atualizar**.
4. Abra o gráfico do XAUUSD no **M1** (ou qualquer tempo) e arraste o **ALIEN PROFESSOR** pra dentro dele.
5. Pronto. Ele deixa o fundo preto e as velas amarelas (dá pra desligar em *Tema ALIEN*).

> Ele lê sozinho os outros tempos (D1, H4, H1, M15, M5, M1). Se no começo aparecer "carregando dados", espere alguns segundos ou abra uma vez o gráfico H1 e M5 desse símbolo.

## 2. O que aparece no gráfico
| Desenho | O que é |
|---|---|
| Linha **amarela** | Liquidez **acima** (máx. de ontem, semana passada, Ásia, Londres, NY, topos iguais) |
| Linha **laranja** | Liquidez **abaixo** (mínimas) |
| Linha **rosa (magenta)** + "VARRIDA" | O preço furou o nível com pavio e **fechou de volta** = pegou os stops e voltou |
| Linha **cinza pontilhada** "rompido" | O preço fechou além do nível (não vale mais como alvo) |
| Caixa **verde escura** | FVG de compra do M5 ainda aberto |
| Caixa **vermelha escura** | FVG de venda do M5 ainda aberto |
| Caixa **cinza** | FVG que já foi preenchido (apagado) |
| Contorno **azul / roxo** "FVG H1" | FVG do H1 (compra / venda) |
| Contorno **ciano / marrom** "FVG M15" | FVG do M15 (compra / venda) |
| Tracejado verde/vermelho "BOS" / "CHoCH" | Quebra de estrutura no M5 (CHoCH = virou de lado) |
| **V** amarelo | Volume mais de 2x a média das 20 velas |
| **c** / **VC** | Vela de corpo forte (corpo > 60% da vela) / com volume forte |
| Linhas **ENTRADA / STOP / ALVO** | Plano sugerido (só aparece com nota ≥ 4 e sem bloqueio) |
| **Seta verde / vermelha** | Momento em que a nota passou de 7 (com entrada, stop, alvo e lote escritos) |

## 3. O painel, de cima pra baixo
1. **D1 H4 H1 M15 M5 M1** com ▲ verde (alta), ▼ vermelho (baixa) ou ■ cinza (sem direção).
   **ALINHADO** = H4, H1, M15 e M5 do mesmo lado. **CONFLITO** = estão brigando → cuidado.
2. **Leitura do professor**: uma frase em português explicando o que está acontecendo e o que esperar.
   Ex.: *"H1 de alta (M15 junto), varreu Ásia mín., BOS no M5 a favor, FVG de compra em 2650. => Esperar o preço VOLTAR ao FVG e confirmar no M1."*
3. **Contexto**: tendência do H1 (EMA200 + topos/fundos), viés do dia, sessão e se o horário é bom ou ruim.
4. **Liquidez**: a mais perto acima e abaixo (distância em ATR) e as varridas recentes.
5. **Estrutura M5**: último BOS, FVGs abertos, último volume forte.
6. **SEMÁFORO + nota 0–10** com o checklist:
   - [x] tendência H1 a favor (2)
   - [x] varreu liquidez do outro lado (2) — pra comprar, ter varrido um fundo
   - [x] BOS a favor (2)
   - [x] FVG aberto a favor (1)
   - [x] volume forte a favor (1)
   - [x] horário bom (1) — abertura de Londres e de NY
   - [x] alvo a pelo menos 2R (1)
   - **VERDE** = 7 ou mais · **AMARELO** = 4 a 6 · **VERMELHO** = menos de 4 ou **BLOQUEADO**
7. **Plano sugerido**: entrada (meio do FVG), stop (além da varrida/swing + folga), alvo (próxima liquidez), R:R, **lote pro seu risco** (padrão US$ 45, já com comissão e spread), quanto perde no stop e quanto ganha no alvo.
   Mostra também se cabe no limite da **Goat (perda flutuante máx. US$ 50)**.
8. **Disciplina**: lê o histórico da conta de hoje. Com **2 stops**, ou meta do dia batida, ou perda máxima do dia → **PARE POR HOJE** em vermelho e o semáforo trava.
9. **Honestidade**: lembra o que os testes mostraram (abaixo).

## 4. Como usar como checklist (o jeito certo)
1. Olhe a linha **ALINHADO / CONFLITO**. Conflito = só olhar.
2. Leia a **Leitura do professor**.
3. Só pense em entrar com **VERDE**, em **horário bom**, sem **notícia** e sem **PARE POR HOJE**.
4. Confirme no M1 você mesmo (rejeição no FVG, vela forte a favor).
5. Use o **lote do painel**. Nunca aumente o lote pra recuperar.
6. Bateu 2 stops → fecha a plataforma. Amanhã tem mais.

## 5. Ajustes principais (aba Parâmetros)
- *Risco por operação* (US$ 45), *Limite flutuante da mesa* (US$ 50), *Comissão por milhão por lado* (automático: ouro US$ 20 ≈ US$ 16 por lote ida+volta; índices US$ 5) — entra no cálculo do lote.
- *Máximo de stops por dia* (2), *Meta do dia*, *Perda máxima do dia*.
- *Horários de notícia hoje*: escreva assim `15:30,21:00` (hora do servidor). 30 min antes e depois o painel bloqueia.
- *Sessões*: em hora do **servidor** da RoboForex (= hora de Nova York + 7). Ásia 01–09, Londres 09–15, NY 16–23, horário bom 10–13 e 16–19.
- *Alerta na tela* / *Notificação no celular*: alerta quando a nota chega em 7 (ajustável).
- *Painel compacto*: esconde as partes detalhadas se o painel estiver tampando o gráfico.

## 6. Telegram (opcional) — EA "carteiro" ALIEN_PROFESSOR_TELEGRAM
Indicador não pode acessar a internet no MT5, então tem um EA pequeno que **só lê os sinais do indicador e manda no Telegram** (texto + print do gráfico). Ele **não tem nenhuma função de ordem**.
1. No Telegram, fale com **@BotFather** e crie um **bot NOVO** (`/newbot`). **Não use o token antigo** — ele está exposto nos seus repositórios públicos do GitHub; revogue o antigo no BotFather (`/revoke`).
2. Mande uma mensagem pro seu bot novo e pegue seu *chat id* (ex.: com o @userinfobot).
3. No MT5: **Ferramentas > Opções > Expert Advisors** → marque **"Permitir WebRequest para as URLs listadas"** e adicione:
   - `https://api.telegram.org` (Telegram)
   - `https://api.x.ai` (IA xAI / Grok)
   - `https://generativelanguage.googleapis.com` (IA reserva Google Gemini)
   - `https://api.openai.com` (só se usar OpenAI)
4. Copie `ALIEN_PROFESSOR_TELEGRAM.ex5` para `MQL5\Experts`, arraste no **mesmo gráfico** do indicador e preencha *Token* e *Chat id*. Ele manda uma mensagem de teste ao ligar.
5. O token fica só no seu MT5. Nunca coloque ele em arquivo do GitHub.

## 7. O que os testes mostraram (leia!)
Testei as setas do próprio indicador em 10 anos de dados (2016–2025), com custos de conta ECN, sem otimizar nada (detalhes em `TESTE_SINAIS.md`):
- **Ouro:** seguir toda seta com nota ≥ 7 deu **−0,32R por operação**, 0 de 10 anos positivos.
- **US500:** **−0,17R por operação**, 0 de 10 anos positivos.
- A nota alta **não** separa operação boa de ruim.

Então: o ALIEN PROFESSOR é uma **ferramenta de leitura, de lote e de disciplina** — não é um robô de sinal e não promete lucro. A parte que mais protege sua conta é o **PARE POR HOJE** e o **lote certo**.


## 8. ROBÔ AUTOMÁTICO — ALIEN_PROFESSOR_AUTO (leia o aviso inteiro)

> ⚠️ **AVISO:** este robô opera exatamente as setas do professor (nota ≥ 7). No teste de 10 anos (2016–2025) essas setas **perderam dinheiro em todos os anos**. No testador do MT5 em 2025 ele **perdeu** (veja abaixo). Use **só em conta DEMO**. Se colocar em conta real ou de mesa, é decisão e risco seus.

**Instalação:** rode o `INSTALAR.bat` (copia tudo pros seus MT5) ou copie `ALIEN_PROFESSOR_AUTO.ex5` para `MQL5\Experts`. Arraste no gráfico **M1 do XAUUSD**, ligue o **Algo Trading** e, na aba Parâmetros, clique **Carregar** → `ALIEN_PROFESSOR_AUTO_seguro.set` (ou `_goat.set`, risco US$ 20).

**O que ele faz:**
- Mesmo painel do professor + linha **ROBÔ:** com o que está fazendo ou por que está bloqueado.
- Quando a nota de um lado cruza o limite (padrão 7): ordem **limitada no meio do FVG** (vale 60 min) ou **a mercado** se não tiver FVG. **Stop e alvo vão junto com a ordem.**
- **Lote pelo risco fixo** (padrão US$ 45, arredonda pra baixo). Se nem o lote mínimo cabe no risco, **pula**.
- **1 posição por vez. Sem martingale, sem grade, sem preço médio.** Número mágico próprio: 77261115.
- Fecha a posição depois de 8 horas ou às 23:45 do servidor.

**Travas (todas são parâmetros; 0 = desligado; o padrão é seguro):**
| Parâmetro | Padrão | O que faz |
|---|---|---|
| InpRiskUSD | 45 | risco por operação em US$ |
| InpMaxStopsDia | 2 | para o dia depois de 2 stops |
| InpPerdaMaxDiaUSD | 90 | para o dia se perder US$ 90 |
| InpMetaDiaUSD | 100 | para o dia se ganhar US$ 100 |
| InpDDPausaPct | 15 | pausa se cair 15% do pico (só volta reiniciando) |
| InpSpreadMaxPctStop | 10 | não entra se o spread for > 10% do stop |
| InpBloquearHorarioRuim | true | não opera na Ásia / fim de NY |
| InpCalendario / InpCalBloquearForte | true / true | lê o **calendário econômico do MT5** (USD, EUR; impacto alto e médio) e **não entra** ±InpNoticiaMin (30) min de notícia **FORTE** |
| InpNoticias | vazio | horários extras manuais (ex.: 15:30,21:00) também bloqueiam ±30 min |
| **InpTradeEnabled** | true | **false = MODO ASSISTENTE**: não manda ordem nenhuma; só analisa, avisa os sinais e conversa no Telegram |
| InpMaxHoras / InpFecharHHMM | 8 / 2345 | saída por tempo / horário |
| **InpAllowRealAccount** | **false** | em conta real mostra **BLOQUEADO: CONTA REAL** e não opera |

**Telegram e IA já vêm ligados** (InpUseTelegram / InpUseAI = true). Sem chave eles não fazem nada e o painel avisa: *"IA: coloque sua chave…"* / *"Telegram: coloque token e chat id"*.
- **IA:** a cada sinal o robô manda o estado do professor (tendências, níveis, varridas, BOS, nota, plano) pra IA e mostra a resposta em **ANÁLISE IA** e no Telegram. Primeiro tenta **xAI** (`grok-4.20-0309-non-reasoning`, chave em *InpAIKey*); se der erro, tempo ou cota, usa a **reserva Google Gemini** (`gemini-3.5-flash-lite`, chave em *InpAI2Key*). A IA **só comenta**: ela não abre trade. Se você ligar *InpAIVeto*, ela pode **apenas vetar** (respondendo VETO).
- Testado em 15/11/2026: xAI (`grok-4.20-0309-non-reasoning`) respondeu em ~2 s e Gemini (`gemini-3.5-flash-lite`) em ~1 s, os dois em português, com o mesmo formato de pedido que o robô usa. A lista de URLs do WebRequest **tem que ser feita por você** em Ferramentas > Opções > Expert Advisors (o MT5 não aceita por arquivo).
- As chaves ficam só no seu MT5. **Nunca** coloque chave/token em arquivo, print ou GitHub.

### Conversar com o robô pelo Telegram (duas vias)
1. Crie o bot no **@BotFather**, cole o token em *InpTelegramToken*.
2. Deixe *InpTelegramChatId* vazio, ligue o robô e mande **/start** para o seu bot. O robô mostra **seu chat id** no painel e na aba Experts e responde com o número. Cole em *InpTelegramChatId* e reinicie.
3. Pronto: o robô **só aceita mensagens desse chat**. Mensagens de qualquer outra pessoa são ignoradas.

| Comando | O que faz |
|---|---|
| `/analise` | análise completa de agora pela IA + print do gráfico |
| `/status` | posições abertas, resultado de hoje, disciplina (PARE POR HOJE, pausa), nota agora, resumo do seu aprendizado |
| `/noticias` | próximas notícias fortes e médias (USD/EUR), em hora do servidor |
| `/foto` | só o print do gráfico |
| `/ajuda` | lista de comandos |
| qualquer texto | pergunta livre, ex.: *"vale vender agora?"*, *"onde está a liquidez?"*. A IA responde com os dados do gráfico e manda o print |

- Na pergunta livre e no /analise a IA recebe: tendência D1/H4/H1/M15/M5/M1, níveis e varridas, BOS, FVGs (M5/M15/H1), nota dos dois lados, plano, spread, notícias, posições abertas, o resultado de hoje e o seu histórico.
- **Pré-aviso:** 15 min antes de notícia **FORTE** em USD chega um "ATENÇÃO: notícia FORTE…" (*InpPreAlertaMin*, *InpPreAlertaMoedas*).
- **Resumos automáticos:** na abertura de **Londres (10:00)** e **NY (16:30)**, em hora do servidor RoboForex, chega um resumo da IA com print (*InpResumos*, *InpResumoLondres*, *InpResumoNY*). Sem IA, chega a leitura do professor. Não manda no fim de semana.
- **Limite da IA:** no mínimo 15 s entre perguntas e no máximo 30 por hora (*InpAIMinSeg*, *InpAIMaxHora*). Os sinais de trade não entram nesse limite.
- Com o robô em **vários gráficos**, só **um** lê as mensagens (o painel mostra *"chat ATIVO neste gráfico"*) e responde sobre o símbolo dele. Os resumos de abertura saem de cada gráfico.
- Telegram, IA e calendário **não funcionam no testador** (o MT5 não deixa). Lá o robô só opera.
- Se aparecer erro 409, outro programa está lendo as mensagens do mesmo bot (webhook ou outro robô). O EA carteiro só envia, então pode usar o mesmo bot.


**Aprendizado (seu histórico):** o robô grava em `MQL5\Files`:
- `ALIEN_diario.csv`: todo sinal, operado ou pulado, com o motivo (horário ruim, já tinha posição, IA vetou…).
- `ALIEN_aprendizado.csv`: cada trade fechado, com nota, faixa, lado, sessão, hora, risco, resultado em US$ e em R.
A IA recebe um resumo disso: os setups parecidos (mesma faixa de nota, lado e sessão), com acerto, R médio e quantidade, além da melhor e da pior hora. Assim a resposta fala do **seu** histórico.
Se ligar *InpAprenderDesativar*, o robô pula a faixa/lado/sessão que já tem ≥ 30 trades (*InpAprenderMinN*) e R médio negativo. Vem **desligado**: com poucos trades isso é sorte, não aprendizado.

**Resultado no testador do MT5 (XAUUSD M1, US$ 5.000, travas padrão):**
| Teste | Ticks | Trades | Lucro líquido | PF | Rebaixamento máx. |
|---|---|---|---|---|---|
| 30/10 a 14/11/2026 | **reais** (100%) | 13 | **+US$ 158** | 1,72 | US$ 165 (3,3%) |
| 2025 inteiro | gerados (não confiáveis) | 22 | **−US$ 626** | 0,25 | 15,6% → **pausou em janeiro** pela trava de 15% |
| 2025 inteiro, trava de DD desligada | gerados (não confiáveis) | 340 | **−US$ 408** | 0,96 | **US$ 1.616 (31%)** |

Como ler: as 2 semanas positivas são só **13 trades** (sorte ou azar cabem aí). O ano de 2025 perdeu e chegou a cair 31%. A comissão do testador é US$ 8 por lote; na sua conta ECN é ~US$ 16, então na vida real seria **pior**. Ticks gerados não são confiáveis (foi o que enganou no V11).

## 9. VIGIA — deixar o MT5 sempre ligado (VIGIA_INSTALAR.bat)
O vigia confere **a cada 60 segundos** se o MT5 está aberto e respondendo. Se fechou, ou travou por 3 checagens seguidas, ele **abre de novo**. O MT5 reabre os gráficos e robôs do último perfil.
1. Dois cliques em **VIGIA_INSTALAR.bat**. Ele acha o MT5 sozinho (se tiver mais de um, pergunta qual) e liga o vigia toda vez que você entra no Windows (Tarefa Agendada; se o Windows não deixar, usa a pasta *Inicializar*). Não precisa ser administrador.
2. **Não deixar o PC dormir**: abra o *Prompt de Comando* e cole:
   `powercfg /change standby-timeout-ac 0` e `powercfg /change hibernate-timeout-ac 0`
3. **Login automático do MT5**: ao entrar na conta, marque **Salvar senha**.
4. Deixe o gráfico com o robô aberto e o **Algo Trading** verde e feche o MT5 pelo X uma vez (ele salva o perfil).
5. Opcional: Windows entrar sozinho (Win+R → `netplwiz` → desmarque "Os usuários devem inserir um nome…").
- O robô AUTO manda **"ALIEN reiniciado"** no Telegram toda vez que liga. Se chegar essa mensagem sem você ter mexido, o MT5 caiu e o vigia trouxe de volta.
- Log do vigia: `%LOCALAPPDATA%\ALIEN_VIGIA\vigia_log.txt`.
- **Backup diário (opcional):** na instalação ele pergunta uma pasta (ex.: `D:\ALIEN_BACKUP`). Uma vez por dia copia os diários (`ALIEN_*.csv`), os sinais e os relatórios do testador pra `pasta\data\`. Se a unidade (pendrive/HD) não estiver ligada, ele pula sem erro.
- **Sincronizar com o GitHub (opcional):** uma vez por dia envia `ALIEN_diario.csv`, `ALIEN_aprendizado.csv` e os textos dos sinais pra pasta `alien_dados/` do seu repositório **privado** (padrão `vitorcriouabud/bud-central-sync`).
  1. Instale o Git: https://git-scm.com (deixe marcado o *Git Credential Manager*).
  2. Rode uma vez: PowerShell na pasta → `.\VIGIA_MT5.ps1 -TestarGit`. Vai abrir a janela de login do GitHub; entre com sua conta. Depois disso funciona sozinho.
  3. Sem Git, ele só pula (anota no log).
  - Os arquivos **não têm** token, chave nem senha (só hora, símbolo, nota, preços e resultado). Mesmo assim o vigia confere cada arquivo e **não envia** se achar algo parecido com token/chave/senha.
  - Confira no GitHub que o repositório está como **Private**.
- Para desligar: abra o PowerShell na pasta e rode `VIGIA_MT5.ps1 -Remover`.
- Se a internet ou a energia caírem, o vigia não resolve. Para 24 horas de verdade, o certo é uma VPS.

## Arquivos
- `indices/` — robô dos índices ALIEN_INDICES_V1 (.ex5/.mq5/.set), README_PT.md e TESTE.md (o INSTALAR copia para Experts\ALIEN e Presets)
- `ALIEN_PROFESSOR.mq5` / `.ex5` — o indicador (tudo num arquivo só)
- `ALIEN_PROFESSOR_TELEGRAM.mq5` / `.ex5` — EA carteiro do Telegram + IA (opcional, não opera)
- `ALIEN_PROFESSOR_AUTO.mq5` / `.ex5` — robô automático (painel + Telegram + IA num EA só) — **só demo**
- `INSTALAR.bat` + `INSTALAR.ps1` — instalação em 1 clique
- `VIGIA_INSTALAR.bat` + `VIGIA_MT5.ps1` — vigia que reabre o MT5 se fechar/travar
- `presets/` — `ALIEN_PROFESSOR_AUTO_seguro.set` e `ALIEN_PROFESSOR_AUTO_goat.set`
- `TESTE_SINAIS.md` — pré-registro e resultado do teste das setas
- `prints/` — prints do indicador rodando no M1
