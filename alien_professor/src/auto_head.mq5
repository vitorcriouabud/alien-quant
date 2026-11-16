//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR_AUTO.mq5                                         |
//| EA que OPERA os sinais do ALIEN PROFESSOR (nota >= limite).      |
//| AVISO: no teste 2016-2025 esses sinais PERDERAM dinheiro.        |
//| Sem martingale, sem grade, sem preço médio. 1 posição por vez.   |
//| Stop e alvo vão junto com a ordem. Conta real bloqueada padrão.  |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "12.60"
#property description "Robô dos sinais do ALIEN PROFESSOR. Risco fixo, 1 posição, travas diárias, DD 15%, bloqueio de conta real. ATENÇÃO: o teste histórico dos sinais foi NEGATIVO."
#define APROF_EA
#define APROF_VER "12.6"
#include <Trade\Trade.mqh>

input group "=== ROBÔ (AUTO) ==="
input bool   InpTradeEnabled      = true;        // Operar? (false = MODO ASSISTENTE: só analisa e avisa, não manda ordem)
input bool   InpAllowRealAccount  = false;       // Permitir conta REAL (padrão: NÃO)
input double InpRiskUSD           = 45.0;        // Risco fixo por operação (US$)
input int    InpScoreTrade        = 7;           // Nota mínima pra operar
input long   InpMagic             = 77261115;    // Número mágico (único deste robô)
input double InpSpreadMaxPctStop  = 10.0;        // Spread máximo (% da distância do stop) (0 = desligado)
input double InpDDPausaPct        = 15.0;        // Pausa se cair X% do pico (0 = desligado)
input int    InpLimiteMin         = 60;          // Ordem limitada vale N minutos (0 = não cancela)
input int    InpMaxHoras          = 8;           // Fecha a posição depois de N horas (0 = desligado)
input int    InpFecharHHMM        = 2345;        // Fecha tudo neste horário do servidor HHMM (0 = desligado)
input bool   InpBloquearHorarioRuim = true;      // Não opera em horário ruim (Ásia / fim de NY)

input group "=== Aprendizado (histórico) ==="
input bool   InpAprenderDesativar = false;       // Pular faixa nota/lado/sessão que está perdendo no SEU histórico
input int    InpAprenderMinN      = 30;          // Mínimo de trades na faixa pra poder desativar

input group "=== Telegram (opcional) ==="
input bool   InpUseTelegram       = true;        // Usar Telegram (precisa de token e chat id)
input string InpTelegramToken     = "";          // Token do bot (crie um NOVO no @BotFather)
input string InpTelegramChatId    = "";          // Seu chat id
input bool   InpTgFoto            = true;        // Mandar print do gráfico junto
input bool   InpTgChat            = true;        // Conversar pelo Telegram (/analise /status /noticias /ajuda e perguntas)
input int    InpTgPollSeg         = 4;           // Ler mensagens a cada N segundos
input int    InpPreAlertaMin      = 15;          // Avisar N min antes de notícia FORTE (0 = desligado)
input string InpPreAlertaMoedas   = "USD";       // Moedas do pré-aviso
input bool   InpResumos           = true;        // Resumo automático na abertura de Londres e NY
input string InpResumoLondres     = "10:00";     // Abertura de Londres (hora do SERVIDOR) (vazio = sem resumo)
input string InpResumoNY          = "16:30";     // Abertura de NY (hora do SERVIDOR) (vazio = sem resumo)

input group "=== Agente Alier (Telegram) ==="
input bool   InpAlertasProativos  = true;        // Avisar sozinho: varrida, mudança de estrutura, bloco de ordens, VWAP
input int    InpAlertasMaxHora    = 6;           // Máximo de avisos automáticos por hora
input int    InpAlertaCooldownMin = 20;          // Mesmo tipo de aviso: esperar N minutos
input bool   InpDisciplina        = true;        // Perguntar "seguiu o plano?" quando um trade fecha
input bool   InpVoz               = true;        // Entender áudio do Telegram (usa a chave Gemini)
input int    InpPausaAposStopMin  = 0;           // Depois de um stop, segurar os avisos automáticos N min (0 = desligado; não trava ordens)
input bool   InpBalaoIA           = true;        // Mostrar no gráfico a última observação da IA (balão perto do preço)
input bool   InpBackupSemanal     = true;        // Copiar os ALIEN_*.csv toda semana para MQL5/Files/ALIEN_backup/data
#define InpRiscoUSD InpRiskUSD

