//+------------------------------------------------------------------+
//|                                              ALIEN_Observer.mq5  |
//|                                        Projeto ALIEN LAB v1.0    |
//|                                                                   |
//|  FASE 1 — Professor Observador                                    |
//|  Detecta e registra: Varreduras de Liquidez, CHoCH/BOS,          |
//|  Retestes e Defesas no XAUUSD — SEM OPERAR.                      |
//|                                                                   |
//|  Filosofia: "Primeiro verificar se as marcações fazem sentido.   |
//|  Depois decidir se existe vantagem real."                         |
//+------------------------------------------------------------------+

#property copyright   "ALIEN LAB"
#property version     "1.00"
#property description "ALIEN Observer — Fase 1: Observar, Marcar, Registrar."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Enumeração do estado do setup
enum ENUM_ALIEN_STATE
{
   STATE_IDLE,          // Aguardando varredura
   STATE_SWEPT,         // Varredura detectada, aguardando recuperação
   STATE_STRUCTURE,     // Mudança de estrutura confirmada (CHoCH/BOS)
   STATE_RETEST,        // Em reteste da zona
   STATE_DEFENDED,      // Defesa confirmada — sinal completo
   STATE_INVALIDATED    // Hipótese invalidada
};

//--- Enumeração do tipo de sinal
enum ENUM_ALIEN_SIGNAL
{
   SIGNAL_NONE,
   SIGNAL_LONG_TRAP,    // Varredura de fundo → setup de compra
   SIGNAL_SHORT_TRAP    // Varredura de topo → setup de venda
};

//+------------------------------------------------------------------+
//| Parâmetros de entrada                                            |
//+------------------------------------------------------------------+
input group "=== DETECÇÃO DE LIQUIDEZ (M5) ==="
input int      Inp_SwingLookback      = 20;     // Candles para identificar swing H/L
input double   Inp_SweepBuffer_Pts    = 5.0;    // Tolerância da varredura (pontos)
input int      Inp_SwingMinStrength   = 3;      // Candles de cada lado p/ validar swing

input group "=== DETECÇÃO DE ESTRUTURA (M1) ==="
input int      Inp_BOS_Lookback       = 10;     // Candles p/ detectar CHoCH/BOS no M1
input double   Inp_BOS_MinMove_Pts    = 8.0;    // Deslocamento mínimo p/ confirmar BOS

input group "=== DETECÇÃO DE RETESTE E DEFESA ==="
input int      Inp_RetestWindow       = 15;     // Janela máxima de candles p/ reteste (M1)
input double   Inp_DefenseBody_Pct    = 0.6;    // % mínima do corpo na vela de defesa
input double   Inp_DefenseWick_Ratio  = 0.4;    // Proporção máxima do pavio de rejeição

input group "=== FILTROS DE QUALIDADE ==="
input double   Inp_MaxSpread_Pts      = 25.0;   // Spread máximo aceito (pontos)
input int      Inp_SessionStart_H     = 8;      // Início da sessão monitorada (hora UTC)
input int      Inp_SessionEnd_H       = 21;     // Fim da sessão monitorada (hora UTC)

input group "=== VISUAL ==="
input color    Inp_ColorSweepLong     = clrDodgerBlue;    // Cor: varredura de fundo (compra)
input color    Inp_ColorSweepShort    = clrOrangeRed;     // Cor: varredura de topo (venda)
input color    Inp_ColorBOS           = clrGold;          // Cor: BOS / CHoCH
input color    Inp_ColorDefended      = clrLime;          // Cor: sinal completo (defesa)
input color    Inp_ColorInvalidated   = clrGray;          // Cor: hipótese invalidada
input bool     Inp_ShowZoneBox        = true;             // Mostrar caixa da zona varrida
input bool     Inp_ShowLabels         = true;             // Mostrar rótulos de texto

input group "=== REGISTRO (CSV) ==="
input bool     Inp_LogEnabled         = true;             // Habilitar log em CSV
input string   Inp_LogFileName        = "ALIEN_Log";     // Nome base do arquivo CSV

//+------------------------------------------------------------------+
//| Estrutura que representa um setup em andamento                   |
//+------------------------------------------------------------------+
struct AlienSetup
{
   ENUM_ALIEN_STATE  state;
   ENUM_ALIEN_SIGNAL signal_type;
   
   // Dados da varredura
   datetime         sweep_time;
   double           sweep_price;      // Nível varrido (fundo/topo do swing)
   double           sweep_extreme;    // Extremo da varredura
   
   // Dados do BOS/CHoCH
   datetime         bos_time;
   double           bos_level;
   
   // Dados do reteste
   datetime         retest_time;
   double           retest_price;
   
   // Dados da defesa
   datetime         defense_time;
   double           defense_price;
   double           spread_at_signal;
   
   // Gestão de risco hipotética
   double           stop_level;
   double           target_level;
   double           risk_pts;
   double           reward_pts;
   double           rr_ratio;
   
   // IDs dos objetos gráficos
   string           obj_prefix;
};

//+------------------------------------------------------------------+
//| Variáveis globais                                                |
//+------------------------------------------------------------------+
AlienSetup  g_setup;                       // Setup ativo atual
bool        g_log_header    = false;       // Controle do cabeçalho do CSV
string      g_log_filename  = "";          // Nome completo do arquivo CSV
int         g_log_handle    = INVALID_HANDLE; // Handle do arquivo de log
int         g_obj_counter   = 0;          // Contador para nomes únicos de objetos
datetime    g_last_bar_time = 0;           // Controle de nova barra
int         g_sinais_total  = 0;          // Contador de sinais completos
int         g_sinais_long   = 0;          // Contador LONG
int         g_sinais_short  = 0;          // Contador SHORT

//+------------------------------------------------------------------+
//| Inicialização do indicador                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   // Verificar símbolo
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      PrintFormat("[ALIEN] AVISO: Indicador otimizado para XAUUSD. Símbolo atual: %s", _Symbol);
   
   // Reiniciar estado
   ResetSetup(g_setup);
   g_obj_counter  = 0;
   g_sinais_total = 0;
   g_sinais_long  = 0;
   g_sinais_short = 0;
   g_last_bar_time = 0;
   
   // Inicializar log
   if(Inp_LogEnabled)
      InitLog();
   
   Print("[ALIEN Observer v1.0] Iniciado. Aguardando varreduras de liquidez...");
   Print("[ALIEN] Corretora: RoboForex | Símbolo: ", _Symbol, " | TF: ", EnumToString(Period()));
   Print("[ALIEN] Sessão monitorada: ", Inp_SessionStart_H, "h - ", Inp_SessionEnd_H, "h UTC");
   Print("[ALIEN] Spread máximo aceito: ", Inp_MaxSpread_Pts, " pts | Swing lookback: ", Inp_SwingLookback);
   Print("[ALIEN] Log CSV: ", (Inp_LogEnabled ? "ATIVADO" : "DESATIVADO"));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Finalização                                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_log_handle != INVALID_HANDLE)
      FileClose(g_log_handle);
   
   // Remover todos os objetos do ALIEN
   ObjectsDeleteAll(0, "ALIEN_");
   Print("[ALIEN Observer] Finalizado.");
}

//+------------------------------------------------------------------+
//| Função principal chamada a cada candle/tick                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < Inp_SwingLookback + 10)
      return 0;
   
   // Verificar sessão
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < Inp_SessionStart_H || dt.hour >= Inp_SessionEnd_H)
      return rates_total;
   
   // Executar apenas em nova barra (evita processar o mesmo candle inúmeras vezes)
   datetime current_bar = time[rates_total - 1];
   bool is_new_bar = (current_bar != g_last_bar_time);
   if(!is_new_bar && prev_calculated > 0)
      return rates_total;
   g_last_bar_time = current_bar;

   // Verificar spread
   double current_spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   // Número de candles novos para processar
   int start = (prev_calculated == 0) ? Inp_SwingLookback : prev_calculated - 2;
   if(start < Inp_SwingLookback) start = Inp_SwingLookback;
   
   // === MÁQUINA DE ESTADOS DO SETUP ===
   for(int i = start; i < rates_total - 1; i++)
   {
      switch(g_setup.state)
      {
         case STATE_IDLE:
            DetectSweep(i, time, high, low, close, rates_total);
            break;
            
         case STATE_SWEPT:
            DetectStructureChange(i, time, high, low, close, rates_total);
            // Verificar invalidação: nova varredura oposta ou preço muito distante
            CheckSweepInvalidation(i, high, low);
            break;
            
         case STATE_STRUCTURE:
            DetectRetest(i, time, high, low, close);
            break;
            
         case STATE_RETEST:
            DetectDefense(i, time, high, low, close, open, current_spread_pts);
            CheckRetestInvalidation(i, high, low);
            break;
            
         case STATE_DEFENDED:
            // Sinal completo já registrado — aguardar próximo ciclo
            // O setup só é resetado quando o operador decidir (ou após N candles)
            CheckPostSignalInvalidation(i, high, low, close);
            break;
            
         case STATE_INVALIDATED:
            // Aguardar alguns candles e resetar
            ResetSetup(g_setup);
            break;
      }
   }
   
   return rates_total;
}

//+------------------------------------------------------------------+
//| Detectar varredura de liquidez (M5 — mas rodamos no M1)          |
//| Uma varredura ocorre quando o preço viola um swing H/L           |
//| relevante e depois retorna para dentro do range.                 |
//+------------------------------------------------------------------+
void DetectSweep(const int idx,
                 const datetime &time[],
                 const double &high[],
                 const double &low[],
                 const double &close[],
                 const int total)
{
   if(idx < Inp_SwingLookback) return;
   
   // Encontrar swing high e swing low relevantes
   double swing_high = 0, swing_low = DBL_MAX;
   int    swing_high_idx = -1, swing_low_idx = -1;
   
   for(int k = idx - Inp_SwingLookback; k < idx - Inp_SwingMinStrength; k++)
   {
      // Swing High: ponto mais alto com N candles menores de cada lado
      bool is_swing_high = true;
      for(int j = 1; j <= Inp_SwingMinStrength; j++)
      {
         if(k-j < 0 || k+j >= total) { is_swing_high = false; break; }
         if(high[k-j] >= high[k] || high[k+j] >= high[k]) { is_swing_high = false; break; }
      }
      if(is_swing_high && high[k] > swing_high)
      {
         swing_high = high[k];
         swing_high_idx = k;
      }
      
      // Swing Low: ponto mais baixo com N candles maiores de cada lado
      bool is_swing_low = true;
      for(int j = 1; j <= Inp_SwingMinStrength; j++)
      {
         if(k-j < 0 || k+j >= total) { is_swing_low = false; break; }
         if(low[k-j] <= low[k] || low[k+j] <= low[k]) { is_swing_low = false; break; }
      }
      if(is_swing_low && low[k] < swing_low)
      {
         swing_low = low[k];
         swing_low_idx = k;
      }
   }
   
   double buf_pts = Inp_SweepBuffer_Pts * _Point;
   
   // === VARREDURA DE FUNDO (setup de COMPRA) ===
   // Preço viola swing_low mas fecha acima dele
   if(swing_low_idx > 0 &&
      low[idx] < swing_low - buf_pts &&
      close[idx] > swing_low)
   {
      g_setup.state        = STATE_SWEPT;
      g_setup.signal_type  = SIGNAL_LONG_TRAP;
      g_setup.sweep_time   = time[idx];
      g_setup.sweep_price  = swing_low;
      g_setup.sweep_extreme = low[idx];
      g_setup.obj_prefix   = "ALIEN_" + IntegerToString(g_obj_counter++);
      
      // Nível de stop hipotético: abaixo da mínima da varredura
      g_setup.stop_level = low[idx] - 3 * _Point;
      
      DrawSweepArrow(time[idx], low[idx], SIGNAL_LONG_TRAP);
      DrawZoneBox(time[swing_low_idx], time[idx], swing_low, low[idx], Inp_ColorSweepLong, g_setup.obj_prefix + "_zone");
      
      PrintFormat("[ALIEN] 🔵 VARREDURA DE FUNDO | %s | Swing: %.5f | Mínima: %.5f",
                  TimeToString(time[idx], TIME_DATE|TIME_MINUTES),
                  swing_low, low[idx]);
   }
   
   // === VARREDURA DE TOPO (setup de VENDA) ===
   // Preço viola swing_high mas fecha abaixo dele
   else if(swing_high_idx > 0 &&
           high[idx] > swing_high + buf_pts &&
           close[idx] < swing_high)
   {
      g_setup.state        = STATE_SWEPT;
      g_setup.signal_type  = SIGNAL_SHORT_TRAP;
      g_setup.sweep_time   = time[idx];
      g_setup.sweep_price  = swing_high;
      g_setup.sweep_extreme = high[idx];
      g_setup.obj_prefix   = "ALIEN_" + IntegerToString(g_obj_counter++);
      
      // Nível de stop hipotético: acima da máxima da varredura
      g_setup.stop_level = high[idx] + 3 * _Point;
      
      DrawSweepArrow(time[idx], high[idx], SIGNAL_SHORT_TRAP);
      DrawZoneBox(time[swing_high_idx], time[idx], high[idx], swing_high, Inp_ColorSweepShort, g_setup.obj_prefix + "_zone");
      
      PrintFormat("[ALIEN] 🔴 VARREDURA DE TOPO | %s | Swing: %.5f | Máxima: %.5f",
                  TimeToString(time[idx], TIME_DATE|TIME_MINUTES),
                  swing_high, high[idx]);
   }
}

//+------------------------------------------------------------------+
//| Detectar mudança de estrutura (CHoCH / BOS) no M1               |
//+------------------------------------------------------------------+
void DetectStructureChange(const int idx,
                           const datetime &time[],
                           const double &high[],
                           const double &low[],
                           const double &close[],
                           const int total)
{
   if(idx < Inp_BOS_Lookback) return;
   
   double min_move = Inp_BOS_MinMove_Pts * _Point;
   
   if(g_setup.signal_type == SIGNAL_LONG_TRAP)
   {
      // Para compra: precisamos de um CHoCH de baixa para alta
      // O preço deve romper um swing high interno formado APÓS a varredura
      double last_internal_high = 0;
      int    last_internal_high_idx = -1;
      
      for(int k = idx - Inp_BOS_Lookback; k < idx - 1; k++)
      {
         if(k < 0) continue;
         bool is_local_high = (k > 0 && k < total-1 && high[k] > high[k-1] && high[k] > high[k+1]);
         if(is_local_high && high[k] > last_internal_high)
         {
            last_internal_high = high[k];
            last_internal_high_idx = k;
         }
      }
      
      // BOS: close atual supera o último high interno com movimento significativo
      if(last_internal_high_idx > 0 &&
         close[idx] > last_internal_high + min_move)
      {
         g_setup.state     = STATE_STRUCTURE;
         g_setup.bos_time  = time[idx];
         g_setup.bos_level = last_internal_high;
         g_setup.target_level = g_setup.sweep_price + 
                                (g_setup.sweep_price - g_setup.stop_level) * 2.0; // Alvo 2R inicial
         
         DrawBOSLine(time[last_internal_high_idx], time[idx], last_internal_high, Inp_ColorBOS);
         
         PrintFormat("[ALIEN] 🟡 CHoCH/BOS COMPRA | %s | Nível: %.5f | Deslocamento: %.1f pts",
                     TimeToString(time[idx], TIME_DATE|TIME_MINUTES),
                     last_internal_high,
                     (close[idx] - last_internal_high) / _Point);
      }
   }
   else if(g_setup.signal_type == SIGNAL_SHORT_TRAP)
   {
      // Para venda: CHoCH de alta para baixa
      double last_internal_low = DBL_MAX;
      int    last_internal_low_idx = -1;
      
      for(int k = idx - Inp_BOS_Lookback; k < idx - 1; k++)
      {
         if(k < 0) continue;
         bool is_local_low = (k > 0 && k < total-1 && low[k] < low[k-1] && low[k] < low[k+1]);
         if(is_local_low && low[k] < last_internal_low)
         {
            last_internal_low = low[k];
            last_internal_low_idx = k;
         }
      }
      
      if(last_internal_low_idx > 0 &&
         close[idx] < last_internal_low - min_move)
      {
         g_setup.state     = STATE_STRUCTURE;
         g_setup.bos_time  = time[idx];
         g_setup.bos_level = last_internal_low;
         g_setup.target_level = g_setup.sweep_price - 
                                (g_setup.stop_level - g_setup.sweep_price) * 2.0;
         
         DrawBOSLine(time[last_internal_low_idx], time[idx], last_internal_low, Inp_ColorBOS);
         
         PrintFormat("[ALIEN] 🟡 CHoCH/BOS VENDA | %s | Nível: %.5f | Deslocamento: %.1f pts",
                     TimeToString(time[idx], TIME_DATE|TIME_MINUTES),
                     last_internal_low,
                     (last_internal_low - close[idx]) / _Point);
      }
   }
}

//+------------------------------------------------------------------+
//| Detectar reteste da zona de interesse                            |
//+------------------------------------------------------------------+
void DetectRetest(const int idx,
                  const datetime &time[],
                  const double &high[],
                  const double &low[],
                  const double &close[])
{
   double zone_level = g_setup.sweep_price;
   double tolerance  = 8 * _Point;
   
   // Verificar janela de reteste (não pode demorar demais)
   int candles_since_bos = (int)((TimeCurrent() - g_setup.bos_time) / PeriodSeconds(PERIOD_M1));
   if(candles_since_bos > Inp_RetestWindow)
   {
      // Tempo expirado sem reteste
      PrintFormat("[ALIEN] ⏰ Reteste não ocorreu em %d candles. Resetando.", Inp_RetestWindow);
      LogEvent(g_setup, "RETEST_TIMEOUT", 0);
      g_setup.state = STATE_INVALIDATED;
      return;
   }
   
   bool in_zone = false;
   
   if(g_setup.signal_type == SIGNAL_LONG_TRAP)
      in_zone = (low[idx] <= zone_level + tolerance && low[idx] >= zone_level - tolerance);
   else
      in_zone = (high[idx] >= zone_level - tolerance && high[idx] <= zone_level + tolerance);
   
   if(in_zone)
   {
      g_setup.state        = STATE_RETEST;
      g_setup.retest_time  = time[idx];
      g_setup.retest_price = close[idx];
      
      PrintFormat("[ALIEN] 🔄 RETESTE DETECTADO | %s | Preço: %.5f | Zona: %.5f",
                  TimeToString(time[idx], TIME_DATE|TIME_MINUTES),
                  close[idx], zone_level);
   }
}

//+------------------------------------------------------------------+
//| Detectar defesa da zona (confirmação do sinal completo)          |
//+------------------------------------------------------------------+
void DetectDefense(const int idx,
                   const datetime &time[],
                   const double &high[],
                   const double &low[],
                   const double &close[],
                   const double &open[],
                   const double spread_pts)
{
   // Checar se spread está aceitável
   if(spread_pts > Inp_MaxSpread_Pts)
   {
      PrintFormat("[ALIEN] ⚠️ Spread alto (%.1f pts) — sinal ignorado.", spread_pts);
      return;
   }
   
   double candle_range = high[idx] - low[idx];
   if(candle_range < _Point) return;
   
   double body      = MathAbs(close[idx] - open[idx]);
   double body_pct  = body / candle_range;
   
   bool defended = false;
   
   if(g_setup.signal_type == SIGNAL_LONG_TRAP)
   {
      // Vela compradora com corpo sólido e pavio inferior pequeno
      double lower_wick = MathMin(open[idx], close[idx]) - low[idx];
      double wick_ratio = (candle_range > 0) ? lower_wick / candle_range : 1.0;
      
      defended = (close[idx] > open[idx] &&          // Vela compradora
                  body_pct >= Inp_DefenseBody_Pct &&  // Corpo mínimo
                  wick_ratio <= Inp_DefenseWick_Ratio); // Pavio pequeno
   }
   else if(g_setup.signal_type == SIGNAL_SHORT_TRAP)
   {
      // Vela vendedora com corpo sólido e pavio superior pequeno
      double upper_wick = high[idx] - MathMax(open[idx], close[idx]);
      double wick_ratio = (candle_range > 0) ? upper_wick / candle_range : 1.0;
      
      defended = (close[idx] < open[idx] &&
                  body_pct >= Inp_DefenseBody_Pct &&
                  wick_ratio <= Inp_DefenseWick_Ratio);
   }
   
   if(defended)
   {
      g_setup.state             = STATE_DEFENDED;
      g_setup.defense_time      = time[idx];
      g_setup.defense_price     = close[idx];
      g_setup.spread_at_signal  = spread_pts;
      
      // Calcular R:R
      g_setup.risk_pts    = MathAbs(g_setup.defense_price - g_setup.stop_level) / _Point;
      g_setup.reward_pts  = MathAbs(g_setup.target_level - g_setup.defense_price) / _Point;
      g_setup.rr_ratio    = (g_setup.risk_pts > 0) ? g_setup.reward_pts / g_setup.risk_pts : 0;
      
      // Registrar no log
      LogEvent(g_setup, "SIGNAL_COMPLETE", spread_pts);
      
      // Contadores
      g_sinais_total++;
      if(g_setup.signal_type == SIGNAL_LONG_TRAP)  g_sinais_long++;
      else                                          g_sinais_short++;
      
      // Desenhar seta de sinal completo
      DrawDefenseArrow(time[idx], close[idx], g_setup.signal_type);
      DrawRRLabel(time[idx], close[idx], g_setup);
      
      PrintFormat("[ALIEN] ✅ SINAL COMPLETO [%s] | %s | Sinal #%d (L:%d S:%d)",
                  g_setup.signal_type == SIGNAL_LONG_TRAP ? "COMPRA 🟢" : "VENDA 🔴",
                  TimeToString(time[idx], TIME_DATE|TIME_MINUTES),
                  g_sinais_total, g_sinais_long, g_sinais_short);
      PrintFormat("        Entrada: %.5f | Stop: %.5f | Alvo: %.5f",
                  g_setup.defense_price, g_setup.stop_level, g_setup.target_level);
      PrintFormat("        Risco: %.1f pts | Prêmio: %.1f pts | R:R: %.2f",
                  g_setup.risk_pts, g_setup.reward_pts, g_setup.rr_ratio);
      PrintFormat("        Spread: %.1f pts", spread_pts);
   }
}

//+------------------------------------------------------------------+
//| Verificar invalidação após varredura (antes do BOS)              |
//+------------------------------------------------------------------+
void CheckSweepInvalidation(const int idx,
                            const double &high[],
                            const double &low[])
{
   bool invalidated = false;
   
   if(g_setup.signal_type == SIGNAL_LONG_TRAP)
   {
      // Invalidado se preço fechar abaixo do stop
      if(low[idx] < g_setup.stop_level)
         invalidated = true;
   }
   else
   {
      if(high[idx] > g_setup.stop_level)
         invalidated = true;
   }
   
   if(invalidated)
   {
      PrintFormat("[ALIEN] ❌ Hipótese invalidada após varredura. Stop: %.5f", g_setup.stop_level);
      LogEvent(g_setup, "INVALIDATED_POST_SWEEP", 0);
      DrawInvalidationMark(g_setup);
      g_setup.state = STATE_INVALIDATED;
   }
}

//+------------------------------------------------------------------+
//| Verificar invalidação durante reteste                            |
//+------------------------------------------------------------------+
void CheckRetestInvalidation(const int idx,
                             const double &high[],
                             const double &low[])
{
   bool invalidated = false;
   
   if(g_setup.signal_type == SIGNAL_LONG_TRAP)
   {
      if(low[idx] < g_setup.stop_level)
         invalidated = true;
   }
   else
   {
      if(high[idx] > g_setup.stop_level)
         invalidated = true;
   }
   
   if(invalidated)
   {
      PrintFormat("[ALIEN] ❌ Hipótese invalidada durante reteste. Stop: %.5f", g_setup.stop_level);
      LogEvent(g_setup, "INVALIDATED_RETEST", 0);
      DrawInvalidationMark(g_setup);
      g_setup.state = STATE_INVALIDATED;
   }
}

//+------------------------------------------------------------------+
//| Monitorar o que acontece APÓS o sinal completo                   |
//+------------------------------------------------------------------+
void CheckPostSignalInvalidation(const int idx,
                                 const double &high[],
                                 const double &low[],
                                 const double &close[])
{
   bool hit_stop   = false;
   bool hit_target = false;
   
   if(g_setup.signal_type == SIGNAL_LONG_TRAP)
   {
      hit_stop   = (low[idx]  < g_setup.stop_level);
      hit_target = (high[idx] > g_setup.target_level);
   }
   else
   {
      hit_stop   = (high[idx] > g_setup.stop_level);
      hit_target = (low[idx]  < g_setup.target_level);
   }
   
   if(hit_target)
   {
      PrintFormat("[ALIEN] 🎯 ALVO ATINGIDO (hipotético) | %.5f", g_setup.target_level);
      LogEvent(g_setup, "TARGET_HIT", 0);
      ResetSetup(g_setup);
   }
   else if(hit_stop)
   {
      PrintFormat("[ALIEN] 🛑 STOP ATINGIDO (hipotético) | %.5f", g_setup.stop_level);
      LogEvent(g_setup, "STOP_HIT", 0);
      ResetSetup(g_setup);
   }
}

//+------------------------------------------------------------------+
//| Funções de desenho                                               |
//+------------------------------------------------------------------+
void DrawSweepArrow(const datetime t, const double price, const ENUM_ALIEN_SIGNAL sig)
{
   if(!Inp_ShowLabels) return;
   string name = g_setup.obj_prefix + "_sweep";
   color  clr  = (sig == SIGNAL_LONG_TRAP) ? Inp_ColorSweepLong : Inp_ColorSweepShort;
   int    code = (sig == SIGNAL_LONG_TRAP) ? 233 : 234; // setas Wingdings
   
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   (sig == SIGNAL_LONG_TRAP ? "🔵 VARREDURA FUNDO" : "🔴 VARREDURA TOPO"));
}

void DrawZoneBox(const datetime t1, const datetime t2,
                 const double price1, const double price2,
                 const color clr, const string name)
{
   if(!Inp_ShowZoneBox) return;
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, price1, t2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, MathMax(price1, price2));
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, MathMin(price1, price2));
}

void DrawBOSLine(const datetime t1, const datetime t2,
                 const double price, const color clr)
{
   if(!Inp_ShowLabels) return;
   string name = g_setup.obj_prefix + "_bos";
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "BOS / CHoCH");
}

void DrawDefenseArrow(const datetime t, const double price,
                      const ENUM_ALIEN_SIGNAL sig)
{
   string name = g_setup.obj_prefix + "_def";
   color  clr  = Inp_ColorDefended;
   int    code = (sig == SIGNAL_LONG_TRAP) ? 233 : 234;
   
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   (sig == SIGNAL_LONG_TRAP ? "✅ SINAL COMPRA" : "✅ SINAL VENDA"));
}

void DrawRRLabel(const datetime t, const double price,
                 const AlienSetup &setup)
{
   if(!Inp_ShowLabels) return;
   string name = setup.obj_prefix + "_rr";
   string label = StringFormat("R:R %.1f | %s", setup.rr_ratio,
                               setup.signal_type == SIGNAL_LONG_TRAP ? "BUY" : "SELL");
   
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, label);
   ObjectSetInteger(0, name, OBJPROP_COLOR, Inp_ColorDefended);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
}

void DrawInvalidationMark(const AlienSetup &setup)
{
   string name = setup.obj_prefix + "_inv";
   double price = (setup.signal_type == SIGNAL_LONG_TRAP) ? 
                   setup.stop_level : setup.stop_level;
   
   ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 251); // X
   ObjectSetInteger(0, name, OBJPROP_COLOR, Inp_ColorInvalidated);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "❌ HIPÓTESE INVALIDADA");
}

//+------------------------------------------------------------------+
//| Log em CSV                                                       |
//+------------------------------------------------------------------+
void InitLog()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_log_filename = StringFormat("%s_%04d%02d%02d.csv",
                                  Inp_LogFileName, dt.year, dt.mon, dt.day);
   
   g_log_handle = FileOpen(g_log_filename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
   
   if(g_log_handle == INVALID_HANDLE)
   {
      Print("[ALIEN] ERRO: Não foi possível criar arquivo de log: ", g_log_filename);
      return;
   }
   
   // Escrever cabeçalho
   FileWrite(g_log_handle,
             "data_hora_sweep",
             "tipo_sinal",
             "preco_swing",
             "extremo_varredura",
             "data_hora_bos",
             "nivel_bos",
             "data_hora_reteste",
             "preco_reteste",
             "data_hora_defesa",
             "preco_defesa",
             "stop",
             "alvo",
             "risco_pts",
             "premio_pts",
             "rr_ratio",
             "spread_pts",
             "resultado",
             "hora_utc");
   
   Print("[ALIEN] Log iniciado: ", g_log_filename);
}

void LogEvent(const AlienSetup &setup, const string resultado, const double spread)
{
   if(!Inp_LogEnabled || g_log_handle == INVALID_HANDLE) return;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   FileWrite(g_log_handle,
             TimeToString(setup.sweep_time, TIME_DATE|TIME_SECONDS),
             (setup.signal_type == SIGNAL_LONG_TRAP ? "LONG" : "SHORT"),
             DoubleToString(setup.sweep_price, _Digits),
             DoubleToString(setup.sweep_extreme, _Digits),
             TimeToString(setup.bos_time, TIME_DATE|TIME_SECONDS),
             DoubleToString(setup.bos_level, _Digits),
             TimeToString(setup.retest_time, TIME_DATE|TIME_SECONDS),
             DoubleToString(setup.retest_price, _Digits),
             TimeToString(setup.defense_time, TIME_DATE|TIME_SECONDS),
             DoubleToString(setup.defense_price, _Digits),
             DoubleToString(setup.stop_level, _Digits),
             DoubleToString(setup.target_level, _Digits),
             DoubleToString(setup.risk_pts, 1),
             DoubleToString(setup.reward_pts, 1),
             DoubleToString(setup.rr_ratio, 2),
             DoubleToString(setup.spread_at_signal, 1),
             resultado,
             IntegerToString(dt.hour));
   
   FileFlush(g_log_handle);
}

//+------------------------------------------------------------------+
//| Resetar estado do setup                                          |
//+------------------------------------------------------------------+
void ResetSetup(AlienSetup &setup)
{
   setup.state          = STATE_IDLE;
   setup.signal_type    = SIGNAL_NONE;
   setup.sweep_time     = 0;
   setup.sweep_price    = 0;
   setup.sweep_extreme  = 0;
   setup.bos_time       = 0;
   setup.bos_level      = 0;
   setup.retest_time    = 0;
   setup.retest_price   = 0;
   setup.defense_time   = 0;
   setup.defense_price  = 0;
   setup.spread_at_signal = 0;
   setup.stop_level     = 0;
   setup.target_level   = 0;
   setup.risk_pts       = 0;
   setup.reward_pts     = 0;
   setup.rr_ratio       = 0;
   setup.obj_prefix     = "";
}
//+------------------------------------------------------------------+
