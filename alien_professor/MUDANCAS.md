# Mudanças do ALIEN PROFESSOR

## Versão 12.6 — O Alier te explica o gráfico, obedece, mostra seus trades e opera na demo (15/11/2026)
**Entender o gráfico**
- Mande **/explica** ou escreva "o que é essa linha?" / "me explica o gráfico". Ele manda o print e explica, em português simples, cada coisa desenhada agora (com o preço): níveis, vazios de preço, blocos, varridas, VWAP, STOP/ALVO do plano, setas, seus alertas.
- **/aula fvg** (ou liquidez, varrida, bos, choch, bloco, vwap, killzone, stop, rr, vela, disciplina): uma aula curta com exemplo do ouro.
- **/guia**: legenda das cores. O mesmo guia vem no kit: **GUIA_DO_GRAFICO.md**.
- Gráfico mais limpo: as etiquetas não ficam mais uma em cima da outra (ele afasta ou esconde a de menor importância). **/limpo on** deixa só o plano, seus alertas e as zonas mais perto do preço. **/painel ia off** (ou niveis, confluencia, conta, tudo, mini) esconde partes do painel.

**Dar ordem pra IA**
- Pode falar normal: "me avisa quando chegar 3900", "desenha uma linha em 3880", "deixa o gráfico limpo", "não quero alerta de notícia", "me lembra às 9h de olhar o gráfico", "minha regra: não operar na Ásia", "manda print". Ele faz e confirma o que fez.
- Ele só faz coisas de uma lista fechada. Pedido fora da lista ele diz que não faz e mostra o que pode (**/podes**).
- Quem muda alguma coisa (alerta, pausa, regra, ordem) é **só você**: no privado, ou no grupo com a sua conta. No grupo os outros só perguntam e veem (pausa/retoma no grupo agora também é só sua).
- Comandos novos: /alertas, /regra, /regras, /lembrete, /lembretes, /linha, /mudo, /som, /nota, /simbolo, /print.
- Quando um trade quebra uma regra sua (ex.: entrou na Ásia), ele avisa na hora.

**Seus trades**
- **/trades** ou "meus trades hoje": lista de hoje com hora de Brasília, ativo, compra/venda, lote, entrada, stop, alvo, saída e resultado, e compara com o que o painel mostrava na hora que você entrou (nota, tempos, sessão). A IA explica o porquê em poucas linhas. A IA também passa a saber dos seus trades de hoje em qualquer conversa.

**Ordens pelo Telegram (só você)**
- "compra 0.05 stop 3880 alvo 3900", "vende", "fecha tudo", "fecha metade", "move stop pro zero", "muda stop para 3885", "alvo para 3910".
- Ele mostra um resumo (ativo, compra/venda, lote, stop, alvo, risco em $ e % da conta, alvo/risco) com os botões **✅ Confirmar** e **❌ Cancelar**. Só executa se você tocar Confirmar em até 60 segundos. Depois diz se entrou, fechou ou foi recusada, com o motivo em português.
- **Sem travas**: limite de stops ou de perda do dia **não bloqueia** sua ordem, só avisa ("⚠️ já foram 2 stops hoje"). Esqueceu o stop? Ele sugere um pelo plano; se mesmo assim quiser sem stop, avisa uma vez e deixa.
- O que ele não faz: somar na posição que está perdendo (preço médio / martingale) e stop do lado errado.
- No ALIEN_config.txt: telegram_ordens=demo (padrão, só conta demo) | real (você decide) | off. Opcionais: max_stops_dia e perda_max_dia (0 = sem limite, só aviso), ordem_lote_max (teto de lote), ordem_risco_aviso_pct (avisa acima desse % de risco). Tudo fica em MQL5\Files\ALIEN_ordens_telegram.csv.

**Modo autônomo (só conta DEMO)**
- Com autonomo=demo no ALIEN_config.txt (ou **/autonomo on**) o robô opera sozinho **só na conta demo** (confere toda vez; na conta real ele se recusa), mesmo no modo assistente.
- Só entra com: nota boa, horário bom (Londres/NY ou killzone), H1 a favor, alvo de no mínimo 1,5x o risco, stop sempre, limites do dia dele. Sem martingale, sem grade, sem preço médio. A IA pode vetar a entrada, mas nunca inventa preço.
- Cada abertura e fechamento chega no Telegram com o motivo. Cada decisão fica em ALIEN_decisoes.csv.
- Aprende devagar e com segurança: depois de pelo menos 30 trades num mesmo tipo (compra/venda × sessão), se estiver perdendo ele fica mais exigente ou desliga aquele tipo. Nunca aumenta lote nem risco. Ele avisa quando muda. Veja em **/aprendizado**; desfaça com **/reset_aprendizado**. **/autonomo off** desliga.
- Lembrete honesto: no teste de 10 anos, as setas perderam dinheiro. Por isso é só na demo, pra aprender.

**A IA sabe mais do projeto**
- Ela recebe um resumo do projeto (resultados dos testes, regras, sessões, velas, Trading in the Zone) e só pode usar esses números. O arquivo é MQL5\Files\ALIEN_conhecimento.txt — você pode editar.

**Botões**
- Novos no teclado do privado: 🎓 Explica, 📒 Trades, 🔔 Alertas. O /ajuda mostra tudo que é novo.

**Pra atualizar**: rode o **INSTALAR.bat** do kit novo (ele acrescenta as linhas novas no seu ALIEN_config.txt sem apagar nada).

## Versão 12.5 — Alier sabe o dia, a hora e a agenda (15/11/2026)
**O que estava errado**
- No domingo ele falou "reabre domingo à noite, lá pelas 18h" e "revisa antes de domingo", sendo que já era domingo. E disse que não via notícias.

**O que mudou**
- Toda resposta da IA (privado, grupo, foto, resumo) agora recebe: dia da semana, data e hora de Brasília, se o mercado tá aberto ou fechado e **quando reabre** (ex.: "REABRE domingo 15/11 20:00 Brasília, em 4h50min"). A conta é feita pelo horário de Nova York: com o horário de verão dos EUA o ouro abre 19:00 de Brasília; no resto do ano, 20:00. Também sabe da pausa diária (1h por dia, seg a qui).
- Ele recebe a agenda econômica dos próximos 7 dias (notícias fortes e médias do dólar, com previsão e anterior, e feriados) e os resultados fortes da última semana. Foi proibido de dizer "não vejo notícias".
- Perguntou "o que esperar da abertura?" Ele recebe o fechamento de sexta, máxima/mínima/faixa da semana, semana anterior, VWAP da semana e o viés D1/H4/H1, e responde com cenários curtos ("se abrir acima de X... abaixo de Y..."), como observação, não certeza. Lembra do gap e do spread largo: melhor esperar os primeiros 15-30 min.
- Ele também sabe a versão dele, se a conta é demo, se está no modo assistente, os trades e stops de hoje, as posições abertas, a killzone de agora e a próxima.
- Não pode inventar horário, preço ou notícia que não esteja nos dados.
- O botão/comando de notícias agora mostra também as notícias importantes dos próximos 7 dias.

**No grupo**
- Não faz pergunta pessoal (barbearia, família) e não puxa assunto fora do tema. Fica no que a pessoa perguntou.

## Versão 12.4 — Alier no grupo (15/11/2026)
**Grupo do Telegram**
- O Alier agora fala no seu grupo. Pra liberar: no grupo, você (Vitor) manda **/grupo** uma vez. Ele guarda o número do grupo sozinho no ALIEN_config.txt (linha telegram_grupo_id).
- No grupo, qualquer pessoa pode usar: comandos (/status, /analise, /pausa...), marcar @Alierprofessorbot ou responder uma mensagem dele. O resto da conversa do grupo ele ignora.
- Ele responde no mesmo lugar onde perguntaram: grupo no grupo, privado no privado. No grupo não aparecem os botões fixos.
- Os avisos automáticos (notícia, varrida, bom dia, resumo) continuam só no seu privado. Se quiser também no grupo, coloque grupo_alertas=1 no ALIEN_config.txt.
- A conversa do grupo tem memória separada. O que ele sabe de você fica só no privado.

**Correções**
- A mensagem de "ligado/voltei" não sai mais duas vezes quando o MT5 liga.
- Nunca mais fala "horário do servidor": todo horário é de Brasília.
- Com o mercado fechado (fim de semana), ele avisa "mercado fechado desde tal hora" e não finge que tá vendo ao vivo. E não manda print do gráfico depois de toda resposta; só se você pedir print ou gráfico (ou usar /analise e /foto).

## Versão 12.3 — agente Alier (15/11/2026)
**Telegram mais fácil**
- Botões fixos no chat: Notícias, Análise, Plano, Agenda, Foto, Status, Pausa, Retoma. Pausa e Retoma pedem confirmação.
- "Voltei ✅" só depois de uma queda de verdade, no máximo 1 a cada 15 minutos, sem saldo, com o motivo em português.
- /status mostra a versão e a hora em que ligou. Todos os horários em Brasília.
- Notícias respondidas pelo próprio robô, curtinho. /agenda com as notícias de hoje, bom dia às 8h (dias úteis), aviso 15 min antes de notícia forte e o resultado depois (atual x previsão + quanto o ouro andou em 5 min).
- /diario e /aprendizado em frases normais. Resumo da semana domingo 20:00 (Brasília) com acerto da IA, dos avisos e a sua disciplina.

**Agente**
- Balão da IA no gráfico: a última observação (análise, aviso, resposta sobre o gráfico, foto) aparece num balão preto e amarelo perto do preço, à direita, com 1 ou 2 frases e a etiqueta "obs. da IA, não certeza". Não gasta pergunta extra da IA. Desliga em InpBalaoIA.
- Avisa sozinho: varrida de liquidez (Ásia, ontem, Londres), mudança de estrutura (CHoCH/BOS), bloco de ordens, VWAP, setup 7/7. Máximo 6 por hora, sem repetir depois de reiniciar.
- Conversa sobre qualquer assunto, lembra das últimas mensagens e do que você conta de você (/memoria, /esquece).
- Entende áudio 🎤 e foto 📷 (até print de gráfico de outra plataforma), usando a sua chave Gemini.
- Pergunta "seguiu o plano?" quando um trade fecha e mostra no domingo onde você mais escapa.
- Com as duas Gemini: na conversa fica a resposta mais curta; na análise, "as duas leituras bateram" ou "discordaram, então eu esperaria". Se o Google estiver no limite grátis, tenta de novo e avisa com calma.

**Instalação e dados**
- ATUALIZAR.bat: baixa a versão mais nova do GitHub, instala e compila sozinho. Dois cliques, com o MT5 fechado.
- INSTALAR.bat instala só no MT5 da RoboForex, em Experts\ALIEN, apaga cópias velhas e libera o WebRequest sozinho.
- Suas chaves, token e chat ficam em MQL5\Files\ALIEN_config.txt (fora do robô). Atualizar não apaga. /start conecta o chat sozinho.
- Kit pessoal: SUBIR_GITHUB.bat manda código e diários para a branch alien-dados.
- Diários para estudo: ALIEN_alertas_log.csv e ALIEN_disciplina.csv (colunas no README). Backup semanal dos CSV.
- Killzones com horário de verão de Nova York.

**Continua igual (segurança)**
- Conta real só se você ligar InpAllowRealAccount. Alvo mínimo 1,5R. Sem martingale, sem grade. Kit pessoal vem em modo assistente (modo=assistente no ALIEN_config.txt; apague a linha se quiser que ele opere na demo).
