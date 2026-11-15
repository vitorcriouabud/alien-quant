# Mudanças do ALIEN PROFESSOR

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
