# Mudanças do ALIEN PROFESSOR

## Versão 12.3 — agente Alier (15/11/2026)
**Telegram mais fácil**
- Botões fixos no chat: Notícias, Análise, Plano, Agenda, Foto, Status, Pausa, Retoma. Pausa e Retoma pedem confirmação.
- "Voltei ✅" só depois de uma queda de verdade, no máximo 1 a cada 15 minutos, sem saldo, com o motivo em português.
- /status mostra a versão e a hora em que ligou. Todos os horários em Brasília.
- Notícias respondidas pelo próprio robô, curtinho. /agenda com as notícias de hoje, bom dia às 8h (dias úteis), aviso 15 min antes de notícia forte e o resultado depois (atual x previsão + quanto o ouro andou em 5 min).
- /diario e /aprendizado em frases normais. Resumo da semana domingo 20:00 (Brasília) com acerto da IA, dos avisos e a sua disciplina.

**Agente**
- Avisa sozinho: varrida de liquidez (Ásia, ontem, Londres), mudança de estrutura (CHoCH/BOS), bloco de ordens, VWAP, setup 7/7. Máximo 6 por hora, sem repetir depois de reiniciar.
- Conversa sobre qualquer assunto, lembra das últimas mensagens e do que você conta de você (/memoria, /esquece).
- Entende áudio 🎤 e foto 📷 (até print de gráfico de outra plataforma), usando a sua chave Gemini.
- Pergunta "seguiu o plano?" quando um trade fecha e mostra no domingo onde você mais escapa.
- Com as duas Gemini: na conversa fica a resposta mais curta; na análise, "as duas leituras bateram" ou "discordaram, então eu esperaria". Se o Google estiver no limite grátis, tenta de novo e avisa com calma.

**Instalação e dados**
- INSTALAR.bat instala só no MT5 da RoboForex, em Experts\ALIEN, apaga cópias velhas e libera o WebRequest sozinho.
- Suas chaves, token e chat ficam em MQL5\Files\ALIEN_config.txt (fora do robô). Atualizar não apaga. /start conecta o chat sozinho.
- Kit pessoal: SUBIR_GITHUB.bat manda código e diários para a branch alien-dados.
- Diários para estudo: ALIEN_alertas_log.csv e ALIEN_disciplina.csv (colunas no README). Backup semanal dos CSV.
- Killzones com horário de verão de Nova York.

**Continua igual (segurança)**
- Conta real só se você ligar InpAllowRealAccount. Alvo mínimo 1,5R. Sem martingale, sem grade. Kit pessoal vem em modo assistente (modo=assistente no ALIEN_config.txt; apague a linha se quiser que ele opere na demo).
