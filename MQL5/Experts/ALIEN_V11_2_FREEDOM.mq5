//+------------------------------------------------------------------+
//| XAU TICK ALIEN V11.2 FREEDOM - SESSION + AMD + YELLOW LAB                                 |
//| Tick scalper M1, soft trend scoring, costs, adaptive exits        |
//| LAB MULTISETUP: Sweep+BOS default. PA/OB had weak prior results.|
//| Keep original V10.70 for controlled comparison.                  |
//| V10.89: free-session defaults; sweep and risk checks maintained  |
//| EXPERIMENTAL: DEMO / STRATEGY TESTER ONLY                         |
//| Trading losses are possible. There is no guaranteed profit.      |
//+------------------------------------------------------------------+
#property strict
#property version   "10.88"
#property description "ALIEN V11.2 FREEDOM LAB - Sweep + BOS Retest, mapa AMD, painel professor, demo"

#include <Trade/Trade.mqh>
CTrade trade;

#define ALIEN_TICK_CAP 1024



input group "=== ALIEN V11.2: MESA PROPRIETARIA ($10K) & META R$ 10.000/MES ==="
input double DailyProfitTargetMoney  = 90.00;  // Meta diaria de lucro em USD (R$ 510/dia = R$ 10.000/mes)
input bool   StopOnDailyProfitTarget = true;   // Ao bater a meta diaria, cessa as operacoes do dia
input bool   EnableFastBreakEven     = true;   // Puxa stop para BE assim que atingir 1.2R (nao devolve lucro)
input double FastBERatio             = 1.20;   // Relacao R para acionar o breakeven rapido

input group "=== ALIEN V11: DISJUNTOR DE CAPITAL ($12 SEMANAL) ==="
input double WeeklyMaxLossMoney = 350.00; // Disjuntor semanal da mesa ($350) // Limite semanal absoluto em USD ($12 maximo)
input double DailyMaxLossMoney = 150.00; // Disjuntor diario da mesa ($150)  // Limite diario absoluto em USD ($4 maximo)
input int    MaxDailyTrades         = 15;    // Teto maximo de trades por dia (evita atrito)
input bool   TradeLondonAndNYOnly   = true;  // Operar apenas 08:00 as 18:00 UTC (Londres + NY)
input double MinTrailStepPoints     = 6.0;   // Passo minimo para mover stop (evita spam de modificacao)

input group "=== LABORATORIO M1 ==="
input bool   OneEntryPerM1Candle    = true;  // ON: Maximo 1 entrada por candle M1 (elimina overtrading) // OFF: repeated cycles in SAME M1 candle
input int    MaxEntriesPerM1Candle  = 1;     // Maximo 1 trade por setup no candle     // 0 = unlimited; other values optional
input int    MinMsBetweenEntries    = 250;   // Execution throttle, not a per-candle cap
input int    MinMsAfterExit         = 1500;   // Brief re-entry protection after closing
input int    MinTicksInCandle       = 4;
input int    MinMillisecondsInBar   = 750;
input int    MinimumScore          = 55;  // 0..100. Quality score, NOT win probability
input int    MinDirectionalTicks   = 2;
input int    ShortWindowMs         = 350;
input int    LongWindowMs          = 1600;
input double MinImpulsePoints      = 2.0;
input double MinDirectionalPercent = 54.0;
input double MinMoveOverSpread = 1.10; // Evita sinais menores do que o custo do spread
input bool   RequireTickAlignment  = true;

input group "=== FILTROS DE MERCADO ==="
input int    EMAFastPeriod         = 9;
input int    EMASlowPeriod         = 21;
input int    ATRPeriod             = 14;
input bool   EnableTrendScoring    = true; // Soft scoring: M5 mismatch is not a hard veto
input int    AbsoluteMaxSpreadPts  = 25;    // Limite rigoroso de spread no Ouro (2.5 pips)
input double MaxSpreadAsATR        = 0.18;
input double MinimumATRPoints     = 12.0;
input double MinimumATRToSpread   = 3.0;  // Estimated M1 motion must exceed spread

input group "=== PRICE ACTION / SMC / ICT - 3 SETUPS ==="
input bool   EnableLiquiditySweep    = true;
input bool   EnableBreakRetest       = true;  // DEMO: BOS com reteste confirmado, segunda estrategia
input bool   EnablePAMomentum        = false; // Continuar OFF: perdas historicas em momentum puro
input bool   AllowZoneDirectEntries = false; // FVG/OB visuais; nao operam sozinhos
input int    StructureLookbackBars   = 10;     // Highest/lowest of CLOSED M1 bars
input double MinSweepPoints         = 3.0;    // Wick crosses liquidity by this many points
input double SweepReclaimPoints     = 1.0;    // Price must reclaim former high/low
input double BOSBreakPoints         = 3.0;    // Closed M1 candle closes beyond structure
input double RetestTolerancePoints  = 10.0;   // Retest of broken level
input double MOMBreakPoints         = 2.0;    // PA breakout of previous candle
input double MinPrevBodyATR         = 0.10;   // Previous candle body as fraction of M1 ATR
input bool   RequireSetupValidation = true;  // Never enter from raw tick score alone

input group "=== CONTEXTO M15/H1, FVG, ORDER BLOCK, LIQUIDEZ ==="
input bool   UseHigherTimeframes  = true;
input bool   EnableFVGSetup       = true;
input bool   EnableOrderBlockSetup= true;
input int    HigherTFScanBars     = 16;  // Somente candles fechados
input double MinFVGPoints        = 10.0; // Pontos do simbolo: calibrar no XAU
input double OBDisplacementATR   = 0.22; // Impulso minimo da vela seguinte / ATR TF
input double ZoneToleranceATR    = 0.12; // Distancia maxima ate a zona (ATR M1)
input double MinimumRoomSpreadMult=2.0; // Espaco livre antes de liquidez oposta
input int    HTFTrendBonus       = 10;   // bonus, NAO veto cego
input double RepeatSignalResetPts= 12.0;// Mesmo setup+area precisa deslocamento novo

input group "=== V10.89 DEMO: SWEEP + BOS / RETESTE ==="
input bool   SweepOnlyTradeMode           = false; // DEMO: Sweep + BOS; sem momentum puro
input int    SweepMinimumEntryScore       = 64;   // Score tecnico; NAO percentual de acerto
input double SweepMinimumWickATR          = 0.04; // Varredura minima relativa ao ATR M1
input double SweepMaxEntryDistanceATR     = 0.15; // Limite BASE: mercado fraco
input bool   SweepUseAdaptiveDistance      = true; // 0.15 a 0.25 ATR por qualidade do contexto
input double SweepDistanceMidATR           = 0.20; // Recuperacao moderadamente confirmada
input double SweepDistanceStrongATR        = 0.25; // So se ticks e tendencias estiverem alinhados
input double SweepFreshExtremePoints      = 12.0; // Mesmo candle so repete se varrer extremo NOVO
input double SweepMaxCandleExtensionATR  = 0.70; // Nao perseguir candle ja muito esticado
input bool   UseSweepStructureStop       = true; // SL alem da maxima/minima varrida
input double SweepStopBufferATR           = 0.045; // Folga estrutural extra em ATR M1
input double SweepMinimumStopATR          = 0.15;  // Distancia minima para evitar stop microscopico
input bool   RequireObservedSweepEvent     = true;  // So operar varredura observada apos iniciar EA
input int    SweepEventMaxAgeSeconds      = 55;    // Evento atravessa M1 se ainda valido, expira por tempo
input int    SweepReclaimConfirmTicks     = 2;     // Ticks consecutivos do lado recuperado
input double SweepNewExtremeToRefreshPts  = 12.0;  // Extremo novo inicia novo evento
input bool   SweepRequireRoomForStop      = true;  // Checa espaco disponivel vs risco do SL
input double SweepMinRoomRiskRatio        = 1.0;   // Espaco esperado / risco em pontos
input bool   BlockIfOtherPendingOnSymbol = true; // Evita conflito com versoes antigas/ordens manuais

input group "=== TAMANHO E EXECUCAO ==="
input double FixedLot = 0.20; // Lote proporcional para conta de $10.000
input ulong  ExpertMagic           = 802092; // Magic ALIEN V11 // Magic novo: nao interfere nos EAs antigos
input int    SlippagePoints        = 25;
input double MinFreeMarginMoney    = 3.0;
input bool   AllowBuy              = true;
input bool   AllowSell             = true;

input group "=== AUMENTO COM EVIDENCIA (DEMO) ==="
input bool   EnableEvidenceScaling = false;  // Nao aumenta lote sem historico consistente
input int    MinClosedTradesForBoost = 50;  // Amostras nesta sessao
input int    MinimumScoreForBoost    = 88;  // Score NAO e probabilidade de lucro
input double MinimumProfitFactorBoost = 1.50;
input double MinimumWinRateBoost      = 65.0;  // % de operacoes completas
input double MinAverageNetBoost       = 0.03;  // moeda da conta por posicao
input double MaxAdaptiveLot = 0.40;
input double MaxAdaptiveStopRiskMoney = 50.00;  // escalada OFF; acompanha teto da entrada base
input double MaxRiskPercentEquity      = 0.50;  // teto percentual por posicao
input double MaxMarginPercentEquity    = 50.0;
input double MaxBaseMarginPercentEquity = 50.0; // evita usar quase toda margem mesmo em 0.01
input int    LossStreakPauseAfter = 3;   // Pausa apos 3 stops consecutivos  // pausa temporaria; nao trava o dia
input int    LossStreakPauseSeconds = 1800; // 30 minutos de pausa para mercado acalmar  // margem total, apenas para boost
input bool   EnablePyramid           = false; // Opcional: 2a posicao SOMENTE apos protecao
input int    MinimumScoreForPyramid   = 92;
input double PyramidMinProfitMoney = 5.00;
input int    MaxOwnPositions         = 2;


input group "=== GERENCIAMENTO (NAO E META DE LUCRO) ==="
input double RoundTurnCommissionPerLot = 0.0; // Account currency / lot: configure broker
input double RiskStopMoney = 40.00; // Risco maximo em USD (20 pips)  // LAB DEMO: risco monetario max; nao usar na banca real de $12
input bool   UseRiskRewardTakeProfit = true;  // Alvo servidor 3R, trailing pode proteger antes
input double RiskRewardMultiple      = 3.00;  // Relacao alvo / risco nominal, nao garantia
input bool   UseBOSStructureStop     = true;  // Invalida BOS atras de ultimo fundo/topo fechado
input double MaxFloatingLossMoney = 25.00;  // Legacy mode only: early market-close guard
input bool   StopOnlyRunnerMode    = true; // Saida NORMAL apenas por SL inicial/movel no servidor
input bool   UseProfitHarvest      = false; // Usado somente se StopOnlyRunnerMode=false;
input double MinNetProfitToHarvest = 1.00;  // Only exit on reversal AFTER net profit
input double ReversalImpulsePoints = 2.0;
input double BreakEvenAfterPoints  = 12.0;
input double TrailStartPoints      = 22.0;
input double TrailATRMultiplier    = 0.15;
input double RunnerMinTrailPoints  = 10.0; // Minimo para trailing, sujeito ao stop/freeze corretora
input double RunnerLockBufferPts   = 3.0; // Pontos extras acima das taxas estimadas ao mover para BE
input bool   ExitOnTimeout        = false; // Legacy: desligado no modo stop-only
input int    MaxHoldSeconds        = 180;   // Helps free next opportunities; may close at loss
input int    ModifyCooldownMs      = 550;
input int    RunnerMinimumHoldSeconds = 10; // Mantem o SL inicial antes de BE/trailing
input group "=== V10.61 RUNNER ADAPTATIVO ==="
input bool   UseAdaptiveRunner       = true; // Stop por regime: nao aperta no 1o micro-recuo
input double AdaptiveBEStartATR      = 0.33; // So trava BE apos avancar ao menos 0.33 ATR
input double AdaptiveTrailStartATR   = 0.55; // So inicia trailing apos avancar 0.55 ATR
input double AdaptiveTrendTrailATR   = 0.40; // Mais espaco quando M1 e M5 estao alinhados
input double AdaptiveNormalTrailATR  = 0.27; // Espaco neutro
input double AdaptiveReversalTrailATR= 0.20; // Aperta so diante de contra-impulso real
input double AdaptiveReversalMinATR  = 0.08; // Reversao curta minima em ATR


input group "=== V10 SUPERVISOR INDEPENDENTE ==="
input bool   DrawContextZone          = false;   // Mostrar zona HTF no grafico
input bool   RestrictToXAU            = true;   // Evita anexar por engano a outro ativo
input bool   EnableDailyEquityGuard  = true;   // Bloqueia novas entradas no drawdown diario
input double DailyEquityLossPct      = 2.0;    // Medido contra equity inicial persistida do dia
input double MinimumMarginLevelPct  = 150.0;  // Nivel de margem projetado apos OrderCheck
input bool   RequireOrderPrecheck    = true;   // Verifica requisicao antes de executar
input int    DashboardEveryMs        = 350;    // Evita trabalho grafico em cada tick
input bool   BlockOnMissingSL        = true;   // Emergencia se stop desaparecer
input bool   DisablePyramidInV10     = true;   // V10 inicial: uma posicao por simbolo

input group "=== V10.50 MAPA INSTITUCIONAL / PROFESSOR ==="
input bool   EnableInstitutionalMap = true;     // Desenha SMC / ICT como HIPOTESES de preco
input int    MapScanBars = 32;                  // Velas fechadas por TF
input int    MapRefreshSeconds = 20;            // Varredura leve por timer
input int    MapMaxDrawZones = 2;              // Limita poluicao visual
input bool   DrawFVG = true;
input bool   DrawOrderBlocks = true;
input bool   DrawLiquidity = true;
input bool   DrawStructure = true;
input bool   DrawPremiumDiscount = false;
input double EqualHighLowTolerancePoints = 15.0;
input int    MapProjectionMinutes = 15;
input bool   CleanVisualMode = true;          // Somente visual: nao altera sinais, risco ou ordens
input int    CleanVisualMaxZones = 2;         // 1 a 5 zonas visiveis
input int    CleanVisualMinutesBack = 5;      // Janela pequena, sem cobrir todo o passado
input int    CleanVisualMinutesAhead = 12;    // Extensao da borda para a direita

input group "=== V10.89 SESSOES E FUSO HORARIO ==="
enum ALIEN_BROKER_DST_RULE { ALIEN_DST_FIXED=0, ALIEN_DST_EUROPE=1, ALIEN_DST_USA=2 };
input bool   UseSessionEngine = true;
input int    BrokerWinterUTCOffsetMinutes = 120;  // RoboForex costuma usar UTC+2 no inverno; CONFIRME
input ALIEN_BROKER_DST_RULE BrokerDSTSchedule = ALIEN_DST_EUROPE;
input bool   RestrictNewTradesToWindows = false; // V10.89: horario LIVRE por padrao; sessao continua informativa
input bool   ScoreSessionContext = true;
input int    ActiveSessionBonus = 3;             // Pontos de score, NAO taxa de acerto
input bool   MarkAsiaHighLow = false; // Mapa mais limpo: BSL/SSL de M15
input bool   MarkSessionRange = true;
input bool   DrawAMDStructure = true;
input bool   UseNY0830Blackout = false;          // Opcional: 08:29-08:33 NY, nao substitui calendario
input bool   UseNY1000Blackout = false;          // Opcional: 09:59-10:03 NY

input group "=== V10.89 AMD (HIPOTESES DE PRECO) ==="
input bool   UseAMDContext = true;
input int    AMDRangeBarsM5 = 6;                 // 6 x 5 min de M5 FECHADOS
input double AMDMaxRangeATR = 1.80;              // Largura da faixa / ATR M5
input double AMDSweepMinPoints = 5.0;
input double AMDReclaimPoints = 2.0;
input double AMDExpansionMinATR = 0.38;         // Corpo M1 / ATR M1
input double AMDBreakBufferPoints = 4.0;
input int    AMDKeepSweepMinutes = 7;
input int    AMDAlignedBonus = 5;
input int    AMDOpposingPenalty = 5;
input bool   BlockOppositeConfirmedAMD = true; // Inicie com false: evitar filtro nao validado

input group "=== V10.89 PROFESSOR / PAINEL AO VIVO ==="
input bool   AlienYellowBlackWhite = true;
input bool   RestoreChartThemeOnRemove = true;
input bool   UseGraphicTeacherPanel = true;
input bool   LiveTradeTeacherMode = true; // Durante posicao, mostrar avaliacao continua e progressao em R
input int    TeacherPanelWidth = 540;
input int    TeacherPanelFontSize = 9;
input int    TeacherPanelCorner = 2;        // 0=sup esq | 1=sup dir | 2=inf esq | 3=inf dir
input int    TeacherPanelXOffset = 10;
input int    TeacherPanelYOffset = 22;
input bool   TeacherPanelCompactRows = false;
input int    SessionMapForwardMinutes = 14;

input group "=== V10.50 ORDENS ANTECIPADAS NAS ZONAS ==="
input bool   EnableZonePendingOrders = false;   // ON na DEMO; desligue para apenas estudar o mapa
input bool   EnableMarketEntriesAlongsidePending = true;
input int    PendingOnlyFromTF = 15;            // 5, 15 ou 60 minutos
input int    PendingMaxAgeMinutes = 45;
input int    PendingScanEverySeconds = 5;
input double PendingMaxDistanceATR = 2.0;      // Evita pendentes muito distantes
input double PendingMinDistancePoints = 10.0;  // Distancia minima antes de tocar zona
input double PendingSLBufferATR = 0.10;        // Invalida alem da zona
input double PendingRiskCapMoney = 0.75;       // Moeda da conta: teto estimado
input double PendingMinRoomToRisk = 1.20;      // Espaco de lucro / risco (estimado)
input bool   RequireHigherTFTrendForPending = true;
input bool   RequireServerOrderExpiration = true; // Reservado: prazo server-side sempre exigido
input bool   CancelPendingWhenChartRemoved = true;

input group "=== MONITORAMENTO ==="
input bool   ShowDashboard         = true;
input bool   CompactDashboard      = true; // Texto curto, facil de ler no print
input bool   WriteCsvJournal       = true;   // MT5 common files directory
input bool   PrintDetailedReasons  = false;
input bool   EnableTelemetry        = true;  // CSV de sinais/operacoes e resumo TXT
input int    ReportEverySeconds    = 20;    // Relatorio atualizado continuamente
input int    TelemetryMaxRecords   = 500;   // Amostras por sessao (sem sobrescrever a historia CSV)

struct TickMetrics
{
   double movePoints;
   double directionPercent;
   int    changes;
   int    up;
   int    down;
   double durationMs;
};

long      tickTimes[ALIEN_TICK_CAP];
double    tickPrices[ALIEN_TICK_CAP];
int       tickHead = -1;
int       tickCount = 0;
int       ticksInBar = 0;
long      ticksTotal = 0;
long      barFirstTickMs = 0;
datetime barStart = 0;
double    barOpen = 0.0;
bool      enteredThisBar = false;
int       entriesThisBar = 0;
long      lastEntryTimeMsc = 0;
long      lastExitTimeMsc = 0;
int       lastScore = 0;
// Controle do ultimo SWEEP executado. Reentrada exige varrer extremo novo.
datetime  lastSweepTradeBar = 0;
int       lastSweepTradeDirection = 0;
double    lastSweepTradeLevel = 0.0;
double    lastSweepTradeExtreme = 0.0;
// V10.89: freshness based on observed ticks, never stale candle wick alone.
datetime  sweepObservedBar=0;
double    sweepCachedHigh=0.0, sweepCachedLow=0.0;
double    sweepLastBid=0.0;
long      sweepEventTimeBuy=0, sweepEventTimeSell=0;
double    sweepExtremeBuy=0.0, sweepExtremeSell=0.0;
// Nivel e extremos congelados para que um evento nao desapareca na virada do M1.
double    sweepEventLevelBuy=0.0, sweepEventLevelSell=0.0;
double    sweepRefreshAnchorBuy=0.0, sweepRefreshAnchorSell=0.0;
string    sweepDiagnostic="SWEEP: aguardando evento observado.";
string    sweepPanelSummary="SWEEP: sem evento";
// V10.89: funil de eventos reais, sem contar o mesmo sweep em todo tick.
int       sweepObservedCount=0;
int       sweepConfirmedCount=0;
int       sweepExpiredCount=0;
int       sweepBudgetRejectCount=0;
int       sweepRoomRejectCount=0;
int       sweepExecutedCount=0;
ulong     countedConfirmBuy=0, countedConfirmSell=0;
ulong     countedExpireBuy=0, countedExpireSell=0;
double    lastPreviewMinimumRisk=-1.0;
double    lastCalculatedStopRisk=-1.0;
double    lastCalculatedStopPoints=0.0;
string    lastRiskDecision="Sem stop calculado para a proxima entrada";
long      sweepLastDiagnosticLogSec=0;
int       sweepReclaimBuy=0, sweepReclaimSell=0;
ulong     sweepSeqCounter=0, sweepSeqBuy=0, sweepSeqSell=0;
ulong     lastTradedSweepSeq=0;
// Cache: EMA e ATR dos candles FECHADOS; atualizado uma vez por novo M1.
// O gerenciamento de posicoes permanece em todos os ticks recebidos.
datetime cachedMarketBar = 0;
double   cachedATRPoints = 0.0;
int      cachedTrendM1 = 0;
int      cachedTrendM5 = 0;
bool     cachedMarketReady = false;
long     lastPanelMs = 0;
// Limite de drawdown diario por equity, persistido para sobreviver a reinicio.
string   dailyEquityKey = "";
double   dayOpeningEquity = 0.0;
bool     dailyGuardTripped = false;
string   supervisorMessage = "Avaliando limites.";
int      riskRejected = 0;
int      precheckRejected = 0;
int      recoveredPositions = 0;

int       candlesObserved = 0;
int       opportunitiesFound = 0;
int       attempts = 0;
int       entriesSession = 0;
int       exitsSession = 0;
int       rejectedEntries = 0;
string    lastReason = "Inicializando...";
int       lastSetup = 0;                // 1 sweep, 2 BOS, 3 PA, 4 FVG, 5 OB
string    lastSetupInfo = "Sem padrao confirmado";
double    lastSetupLevel = 0.0;
int       setupCount[6];
int       setupWins[6];
double    setupNet[6];
int       setupSignals[6];
datetime statsDayStart = 0;
double    dailyRealizedNet = 0.0;
int       dailyEntryDeals = 0;
int       dailyProfitableExitDeals = 0;
int       dailyLosingExitDeals = 0;
// Cada posicao tem seu proprio relogio de modificacao e pico observado.
#define ALIEN_RUNNER_TRACKS 16
ulong runnerTickets[ALIEN_RUNNER_TRACKS];
long  runnerModifyMs[ALIEN_RUNNER_TRACKS];
double runnerPeakPoints[ALIEN_RUNNER_TRACKS];

int       hFastM1 = INVALID_HANDLE;
int       hSlowM1 = INVALID_HANDLE;
int       hFastM5 = INVALID_HANDLE;
int       hSlowM5 = INVALID_HANDLE;
int       hAtrM1 = INVALID_HANDLE;
int       hFastM15 = INVALID_HANDLE;
int       hSlowM15 = INVALID_HANDLE;
int       hFastH1 = INVALID_HANDLE;
int       hSlowH1 = INVALID_HANDLE;
int       hAtrM5 = INVALID_HANDLE;
int       hAtrM15 = INVALID_HANDLE;
int       hAtrH1 = INVALID_HANDLE;
int       higherTrendM15=0, higherTrendH1=0;
long      lastZoneScanMsc=0;
int       lastZoneScanDir=0;
int       cachedZoneId=0;
string    lastZoneName="SEM_ZONA";
double    lastZoneLower=0.0,lastZoneUpper=0.0,lastZoneDistance=0.0;
double    lastOpposingRoomPts=1e9;
int       lastEntrySetupId=0, lastEntryDir=0;
double    lastEntryZoneLevel=0.0,lastEntryPrice=0.0;
string    htfDescription="Carregando contexto M15/H1";
int       logFile = INVALID_HANDLE;

// Relatorios ficam em Arquivo > Abrir Pasta de Dados > MQL5 > Files.
// A telemetria apenas observa. Nao altera a estrategia nem envia dados na rede.
#define ALIEN_RECORD_CAP 500
#define ALIEN_BUCKETS 3
struct AlienFactorPoints
{
   int pressure;
   int impulse;
   int fast;
   int candle;
   int trend;
   int costs;
};
struct AlienTradeSample
{
   ulong positionId;
   datetime opened;
   int direction;
   int score;
   int setup;                      // 1 Sweep; 2 BOS; 3 PA; 4 FVG; 5 OB
   double setupLevel;
   AlienFactorPoints points;
   double spread;
   double atr;
   double shortMove;
   double longMove;
   double pressure;
   int ema1;
   int ema5;
   int ema15;
   int emaH1;
   string zone;
   double zoneDist;
   double roomToLiquidity;
   int entrySessionCode;
   int entryAMDPhaseCode;
   string entrySessionName;
   string entryAMDName;
   double net;
   double volume;
   bool finished;
   string exitReason;
};
AlienFactorPoints lastFactor;
AlienFactorPoints lastEntryFactor;
bool telemetryCapacityWarned = false;
AlienTradeSample records[ALIEN_RECORD_CAP];
int recordCount = 0;
int completedSession = 0;
int profitableSession = 0;
int losingSession = 0;
double netSession = 0.0;
double grossGains = 0.0;
double grossLosses = 0.0;
double sessionPeakNet = 0.0;
double maxRealizedDrawdown = 0.0;
int currentLossStreak = 0;
datetime lastCompletedAt = 0;
int maxLossStreak = 0;
long totalTradeSeconds = 0;
int exitTypeCount[5];
double exitTypeNet[5];
int spreadGroupCount[ALIEN_BUCKETS];
int spreadGroupWins[ALIEN_BUCKETS];
double spreadGroupNet[ALIEN_BUCKETS];
int    scoreGroupCount[ALIEN_BUCKETS];
int    scoreGroupWins[ALIEN_BUCKETS];
double scoreGroupNet[ALIEN_BUCKETS];
int    trendGroupCount[ALIEN_BUCKETS];
int    trendGroupWins[ALIEN_BUCKETS];
double trendGroupNet[ALIEN_BUCKETS];
int    pressureGroupCount[ALIEN_BUCKETS];
int    pressureGroupWins[ALIEN_BUCKETS];
double pressureGroupNet[ALIEN_BUCKETS];
int    blockedCounts[8];
int    reasonGroupLast = -1;
long   reasonLastSecond = -1;
string eventFileName = "";
string tradesFileName = "";
string reportFileName = "";
int    tradesFile = INVALID_HANDLE;
long   lastReportTime = 0;
int    lastSignalDirection = 0;
double lastSignalSpread = 0.0;
double lastSignalATR = 0.0;
double lastSignalShort = 0.0;
double lastSignalLong = 0.0;
double lastSignalPressure = 0.0;
int    lastSignalM1 = 0;
int    lastSignalM5 = 0;
string lastExitReason = "Aguardando primeiro fechamento";
int    boostedEntries = 0;
int    additionalEntries = 0;
int    boostRefusals = 0;
string sizingExplanation = "Lote-base: aguardando historico.";
double lastEntryLot = 0.0;
string lastConversation = "Lendo ticks e montando estatisticas.";
int recentW = 0;
double recentGains=0.0;
double recentLosses=0.0;
double recentNet=0.0;
int recentCount=0;


// ---------------- V10.50 INSTITUTIONAL MAP ----------------
#define ALIEN_MAP_MAX 64
struct AlienMapZone
{
   string id;
   string label;
   int kind;                  // 4 = FVG, 5 = OB
   int direction;
   ENUM_TIMEFRAMES tf;
   datetime confirmed;
   double low;
   double high;
   int touches;
   bool valid;
};
AlienMapZone mapZones[ALIEN_MAP_MAX];
int mapZoneCount=0;
datetime mapLastScanTime=0;
datetime mapLastM15Bar=0;
string mapSummary="Mapa em preparacao";
string mapPendingMessage="Pendentes desativadas";
string mapBestZone="SEM_ZONA";
ulong mapPendingTicket=0;
string mapPendingZoneId="";
datetime mapPendingCreated=0;
int mapPendingSetup=0;
int mapPendingDirection=0;
int mapDrawn=0;
int mapCancelled=0;
int mapPlaced=0;
int mapBlocked=0;
string mapPrefix="";
string sessionPrefix="";
string teacherPrefix="";
string sessionName="FORA DA JANELA";
string amdPhaseName="AGUARDANDO";
string sessionExplanation="Aguardando dados das sessoes";
string amdExplanation="Sem contexto AMD confirmado";
int sessionCode=3;                  // 0 Asia, 1 Londres, 2 Nova York, 3 Fora
int amdPhaseCode=0;                 // 0 neutro, 1 faixa, 2 sweep, 3 expansao
int amdBias=0;
datetime lastSessionProcessedBar=0;
datetime lastAMDLastSweepTime=0;
int lastAMDSweepDirection=0;
double asiaHigh=0.0,asiaLow=0.0;
datetime asiaStartServer=0,asiaEndServer=0;
double amdRangeHigh=0.0,amdRangeLow=0.0;
int sessionTrades[4],sessionWins[4];
double sessionNet[4];
int phaseTrades[4],phaseWins[4];
double phaseNet[4];
string lastClockInfo="";
long oldChartColors[8];
bool chartThemeCaptured=false;
// ---------------------------------------------------------

// Classificacao EXCLUSIVA por dimensao. Sao correlacoes, nao causa do lucro.
int ScoreBucket(int score)
{
   if(score < 60) return 0;
   if(score < 75) return 1;
   return 2;
}
int TrendBucket(int direction, int m1, int m5)
{
   if(m1 == direction && m5 == direction) return 0; // ambos favoraveis
   if(m1 == direction || m5 == direction) return 1; // apenas um favoravel
   return 2;                                     // nenhum favoravel
}
int SpreadBucket(double spread, double atr)
{
   if(atr<=0.0) return 2;
   if(spread<=0.07*atr) return 0;
   if(spread<=0.12*atr) return 1;
   return 2;
}
int ExitReasonBucket(string reason)
{
   if(reason=="REVERSAO_LUCRO") return 0;
   if(reason=="STOP_LOSS" || reason=="STOP_OUT") return 1;
   if(reason=="TEMPO_LIMITE") return 2;
   if(reason=="GUARDA_PREJUIZO") return 3;
   return 4;
}
int PressureBucket(double pressure)
{
   if(pressure < 70.0) return 0;
   if(pressure < 80.0) return 1;
   return 2;
}
int BlockReasonGroup(string reason)
{
   if(StringFind(reason,"Spread") >= 0 || StringFind(reason,"ATR") >= 0) return 0;
   if(StringFind(reason,"Score") >= 0) return 1;
   if(StringFind(reason,"pressao") >= 0 || StringFind(reason,"ticks") >= 0 ||
      StringFind(reason,"impulso") >= 0) return 2;
   if(StringFind(reason,"Margem") >= 0 || StringFind(reason,"Lote") >= 0 ||
      StringFind(reason,"Stop minimo") >= 0) return 3;
   if(StringFind(reason,"Posicao ja") >= 0) return 4;
   if(StringFind(reason,"intervalo") >= 0 || StringFind(reason,"Aguardando novo tick") >= 0) return 5;
   if(StringFind(reason,"Candle") >= 0 || StringFind(reason,"primeiros ticks") >= 0) return 6;
   return 7;
}
void ObserveReason()
{
   int group = BlockReasonGroup(lastReason);
   // Somente uma amostra por segundo, nao uma por tick.
   long secondKey = (long)TimeCurrent();
   if(group != reasonGroupLast || secondKey != reasonLastSecond)
   {
      blockedCounts[group]++;
      reasonGroupLast = group;
      reasonLastSecond = secondKey;
   }
}

int FindSample(ulong posId)
{
   for(int i=0; i<recordCount; i++)
      if(records[i].positionId == posId) return i;
   return -1;
}

bool PositionIdentifierStillOpen(ulong posId)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == posId)
         return true;
   }
   return false;
}

void StoreEntryContext(ulong dealTicket, int dir, int score,
                       double spread, double atr, double shortMove,
                       double longMove, double pressure, int m1, int m5)
{
   if(!EnableTelemetry || dealTicket == 0) return;
   if(!HistoryDealSelect(dealTicket)) return;
   ulong posId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   if(posId == 0 || FindSample(posId) >= 0) return;
   if(recordCount >= TelemetryMaxRecords)
   {
      if(!telemetryCapacityWarned)
      {
         Print("ALIEN TELEMETRIA: limite de amostras em memoria atingido. Reinicie a sessao para nova coleta.");
         telemetryCapacityWarned = true;
      }
      return;
   }
   int at = recordCount++;
   records[at].positionId = posId;
   records[at].opened = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   records[at].direction = dir;
   records[at].score = score;
   records[at].setup = lastSetup;
   records[at].setupLevel = lastSetupLevel;
   records[at].points = lastFactor;
   records[at].spread = spread;
   records[at].atr = atr;
   records[at].shortMove = shortMove;
   records[at].longMove = longMove;
   records[at].pressure = pressure;
   records[at].ema1 = m1;
   records[at].ema5 = m5;
   records[at].ema15 = higherTrendM15;
   records[at].emaH1 = higherTrendH1;
   records[at].zone = lastZoneName;
   records[at].zoneDist = lastZoneDistance;
   records[at].roomToLiquidity = lastOpposingRoomPts;
   records[at].entrySessionCode = sessionCode;
   records[at].entryAMDPhaseCode = amdPhaseCode;
   records[at].entrySessionName = sessionName;
   records[at].entryAMDName = amdPhaseName;
   records[at].net = 0.0;
   records[at].volume = HistoryDealGetDouble(dealTicket,DEAL_VOLUME);
   records[at].finished = false;
   records[at].exitReason = "Indefinido";
   LogEvent("SETUP",StringFormat("pos=%I64u dir=%s score=%d pressure=%d impulse=%d fast=%d candle=%d trend=%d cost=%d spread=%.1f atr=%.1f short=%.1f long=%.1f pressao=%.0f ema1=%d ema5=%d",
            posId,dir>0?"BUY":"SELL",score,lastFactor.pressure,lastFactor.impulse,
            lastFactor.fast,lastFactor.candle,lastFactor.trend,lastFactor.costs,
            spread,atr,shortMove,longMove,pressure,m1,m5), 0.0);
}

void RememberExitReason(ulong ticket, string reason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   int i=FindSample(pid);
   if(i>=0 && !records[i].finished)
      records[i].exitReason=reason;
   lastExitReason=reason;
}

// Soma TODAS as taxas do ID da posicao, inclusive a comissao de entrada.
// Nao classifica um fechamento parcial como operacao completa.
void ReconcileTrades()
{
   if(!EnableTelemetry) return;
   for(int i=0; i<recordCount; i++)
   {
      if(records[i].finished) continue;
      ulong posId = records[i].positionId;
      if(PositionIdentifierStillOpen(posId)) continue;
      if(!HistorySelectByPosition(posId)) continue;
      int n = HistoryDealsTotal();
      int exits = 0;
      double totalNet = 0.0;
      datetime closedAt = 0;
      for(int k=0; k<n; k++)
      {
         ulong d = HistoryDealGetTicket(k);
         if(d == 0) continue;
         totalNet += HistoryDealGetDouble(d, DEAL_PROFIT) +
                     HistoryDealGetDouble(d, DEAL_COMMISSION) +
                     HistoryDealGetDouble(d, DEAL_SWAP) +
                     HistoryDealGetDouble(d, DEAL_FEE);
         ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
         if(e == DEAL_ENTRY_OUT || e == DEAL_ENTRY_OUT_BY || e == DEAL_ENTRY_INOUT)
         {
            exits++;
            datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
            if(t > closedAt) closedAt = t;
         }
      }
      if(exits == 0) continue;
      records[i].net = totalNet;
      records[i].finished = true;
      if(records[i].exitReason=="Indefinido")
         records[i].exitReason="FECHAMENTO_NAO_CLASSIFICADO";
      // A corretora pode executar SL sem uma requisicao do EA.
      // O ultimo deal de saida informa se foi por stop ou stop-out.
      for(int k=n-1;k>=0;k--)
      {
         ulong lastD = HistoryDealGetTicket(k);
         if(lastD==0) continue;
         ENUM_DEAL_ENTRY ed=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(lastD,DEAL_ENTRY);
         if(ed!=DEAL_ENTRY_OUT && ed!=DEAL_ENTRY_OUT_BY && ed!=DEAL_ENTRY_INOUT) continue;
         ENUM_DEAL_REASON dr=(ENUM_DEAL_REASON)HistoryDealGetInteger(lastD,DEAL_REASON);
         if(dr==DEAL_REASON_SL) records[i].exitReason="STOP_LOSS";
         else if(dr==DEAL_REASON_SO) records[i].exitReason="STOP_OUT";
         else if(dr==DEAL_REASON_TP) records[i].exitReason="TAKE_PROFIT";
         else if(dr!=DEAL_REASON_EXPERT) records[i].exitReason="FECHAMENTO_EXTERNO";
         break;
      }
      completedSession++;
      lastCompletedAt = closedAt;
      netSession += totalNet;
      if(netSession > sessionPeakNet) sessionPeakNet = netSession;
      double dd = sessionPeakNet - netSession;
      if(dd > maxRealizedDrawdown) maxRealizedDrawdown = dd;
      if(closedAt>records[i].opened) totalTradeSeconds += (long)(closedAt-records[i].opened);
      if(records[i].setup>=1 && records[i].setup<=5)
      {
         int g=records[i].setup;
         setupCount[g]++;
         setupNet[g]+=totalNet;
         if(totalNet>0.0) setupWins[g]++;
      }
      if(totalNet > 0.0)
      {
         profitableSession++;
         grossGains += totalNet;
         currentLossStreak = 0;
      }
      else if(totalNet < 0.0)
      {
         losingSession++;
         grossLosses += -totalNet;
         currentLossStreak++;
         if(currentLossStreak > maxLossStreak) maxLossStreak = currentLossStreak;
      }
      int ex=ExitReasonBucket(records[i].exitReason);
      exitTypeCount[ex]++;
      exitTypeNet[ex]+=totalNet;
      int sp=SpreadBucket(records[i].spread,records[i].atr);
      spreadGroupCount[sp]++;
      spreadGroupNet[sp]+=totalNet;
      if(totalNet>0.0) spreadGroupWins[sp]++;
      int sc = ScoreBucket(records[i].score);
      int tr = TrendBucket(records[i].direction,records[i].ema1,records[i].ema5);
      int pr = PressureBucket(records[i].pressure);
      scoreGroupCount[sc]++;
      scoreGroupNet[sc] += totalNet;
      if(totalNet > 0.0) scoreGroupWins[sc]++;
      trendGroupCount[tr]++;
      trendGroupNet[tr] += totalNet;
      if(totalNet > 0.0) trendGroupWins[tr]++;
      pressureGroupCount[pr]++;
      pressureGroupNet[pr] += totalNet;
      if(totalNet > 0.0) pressureGroupWins[pr]++;

      int sessIdx=records[i].entrySessionCode;
      int phaseIdx=records[i].entryAMDPhaseCode;
      if(sessIdx>=0 && sessIdx<4)
      {
         sessionTrades[sessIdx]++;
         sessionNet[sessIdx]+=totalNet;
         if(totalNet>0.0) sessionWins[sessIdx]++;
      }
      if(phaseIdx>=0 && phaseIdx<4)
      {
         phaseTrades[phaseIdx]++;
         phaseNet[phaseIdx]+=totalNet;
         if(totalNet>0.0) phaseWins[phaseIdx]++;
      }

      if(tradesFile != INVALID_HANDLE)
      {
         FileWrite(tradesFile,
            IntegerToString((long)posId),
            TimeToString(records[i].opened,TIME_DATE|TIME_SECONDS),
            TimeToString(closedAt,TIME_DATE|TIME_SECONDS),
            IntegerToString((int)(closedAt-records[i].opened)),
            records[i].direction>0?"BUY":"SELL",
            IntegerToString(records[i].score),
            IntegerToString(records[i].points.pressure),
            IntegerToString(records[i].points.impulse),
            IntegerToString(records[i].points.fast),
            IntegerToString(records[i].points.candle),
            IntegerToString(records[i].points.trend),
            IntegerToString(records[i].points.costs),
            DoubleToString(records[i].spread,2),
            DoubleToString(records[i].atr,2),
            DoubleToString(records[i].shortMove,2),
            DoubleToString(records[i].longMove,2),
            DoubleToString(records[i].pressure,1),
            IntegerToString(records[i].ema1),
            IntegerToString(records[i].ema5),
            records[i].exitReason,
            DoubleToString(totalNet,4),
            DoubleToString(records[i].volume,2),
            SetupName(records[i].setup),
            DoubleToString(records[i].setupLevel,_Digits),
            IntegerToString(records[i].ema15),
            IntegerToString(records[i].emaH1),
            records[i].zone,
            DoubleToString(records[i].zoneDist,1),
            DoubleToString(records[i].roomToLiquidity,1),
            records[i].entrySessionName,records[i].entryAMDName);
         FileFlush(tradesFile);
      }
      LogEvent("CLOSED_POSITION",StringFormat("pos=%I64u score=%d result=%.4f",posId,records[i].score,totalNet),totalNet);
   }
}

void ReportLine(int f,string line)
{
   FileWriteString(f,line+"\r\n");
}
string GroupText(string label, int n, int wins, double net)
{
   if(n==0) return StringFormat("  %s: sem amostra",label);
   return StringFormat("  %s: %d operacoes | acerto %.1f%% | liquido %+.2f | media %+.3f",
           label,n,100.0*wins/n,net,net/n);
}

void WriteReport()
{
   if(!EnableTelemetry || reportFileName=="") return;
   ReconcileTrades();
   int f = FileOpen(reportFileName,FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_SHARE_READ);
   if(f==INVALID_HANDLE) return;
   ReportLine(f,"XAU TICK ALIEN V11.2 FREEDOM - SESSION / AMD / SMC / ICT (DEMO)");
   ReportLine(f,"Atualizado: "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+" (horario da corretora)");
   ReportLine(f,"Ativo: "+_Symbol+" | M1 | conta DEMO/testador | magic="+IntegerToString((long)ExpertMagic));
   ReportLine(f,"Observacao: SEM garantia de rentabilidade. Score NAO e probabilidade de acerto.");
   ReportLine(f,StringFormat("HORARIOS: %s | motor de sessoes: %s | sessao detectada: %s",
               RestrictNewTradesToWindows ? "RESTRITOS" : "LIVRES",
               UseSessionEngine ? "ATIVO" : "OFF",sessionName));
   ReportLine(f,SweepOnlyTradeMode ?
      "V10.89: Sweep-only ativo por parametro; BOS/FVG/OB apenas mapa." :
      "V10.89: SWEEP+BOS; PA OFF; FVG/OB so no mapa por padrao.");
   ReportLine(f,StringFormat("SWEEP CONTROLES: minScore %d | wick/ATR %.2f | maxDist/ATR %.2f | novo extremo %.1f pts",
          SweepMinimumEntryScore,SweepMinimumWickATR,SweepMaxEntryDistanceATR,SweepFreshExtremePoints));
   ReportLine(f,"----------------------------------------------------------------------");
   ReportLine(f,StringFormat("Saldo %.2f | Equity %.2f | Livre %.2f | Hoje realizado %+.2f %s",
             AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY),
             AccountInfoDouble(ACCOUNT_MARGIN_FREE),dailyRealizedNet,AccountInfoString(ACCOUNT_CURRENCY)));
   ReportLine(f,StringFormat("Ticks %I64d | candles %d | sinais %d | tentativas %d | entradas %d | saidas %d | rejeitadas %d",
              ticksTotal,candlesObserved,opportunitiesFound,attempts,entriesSession,exitsSession,rejectedEntries));
   ReportLine(f,StringFormat("Posicoes abertas %d | entradas neste candle %d | score atual %d/100",
              OurPositionCount(),entriesThisBar,lastScore));
   ReportLine(f,"ALIEN DIZ: "+lastConversation);
   ReportLine(f,"Decisao mais recente: "+lastReason);
   ReportLine(f,"SWEEP DIAGNOSTICO: "+sweepDiagnostic);
   ReportLine(f,StringFormat("FUNIL: observados %d | confirmados %d | expirados %d | enviados %d | risco recusado %d | espaco recusado %d",
             sweepObservedCount,sweepConfirmedCount,sweepExpiredCount,sweepExecutedCount,
             sweepBudgetRejectCount,sweepRoomRejectCount));
   ReportLine(f,StringFormat("RISCO DEMO: teto bruto %.2f | teto %% equity %.2f | minimo preliminar %s | ultimo SL %s pts / custo %s",
             RiskStopMoney,AccountInfoDouble(ACCOUNT_EQUITY)*MaxRiskPercentEquity/100.0,
             lastPreviewMinimumRisk>=0?DoubleToString(lastPreviewMinimumRisk,2):"n/d",
             lastCalculatedStopRisk>=0?DoubleToString(lastCalculatedStopPoints,1):"n/d",
             lastCalculatedStopRisk>=0?DoubleToString(lastCalculatedStopRisk,2):"n/d"));
   ReportLine(f,"ULTIMA DECISAO RISCO: "+lastRiskDecision);
   ReportLine(f,"AVISO: SL planejado pode perder mais que estimativa por slippage, gap e comissao nao informada.");
   ReportLine(f,StringFormat("DISTANCIA SWEEP: base %.2f ATR | adaptativa %s | moderado %.2f | forte %.2f | validade %ds",
             SweepMaxEntryDistanceATR,SweepUseAdaptiveDistance?"SIM":"NAO",
             SweepDistanceMidATR,SweepDistanceStrongATR,SweepEventMaxAgeSeconds));
   ReportLine(f,"COMO ESCOLHI O LOTE: "+sizingExplanation);
   ReportLine(f,StopOnlyRunnerMode ? "SAIDA: SOMENTE SL DE PROTECAO/TRAILING - sem timeout nem lucro por reversao"
                                 : "SAIDA: MODO LEGADO - permite fechamento antecipado a mercado");
   ReportLine(f,StringFormat("Lote ultimo %.2f | Boosts %d | Adicoes %d | Boosts negados %d",
                             lastEntryLot,boostedEntries,additionalEntries,boostRefusals));
   ComputeRecentEvidence();
   ReportLine(f,StringFormat("ESCALADA: historico %d/%d | PF %s | win rate %s | media %s",
      completedSession,MinClosedTradesForBoost,
      grossLosses>0.0?DoubleToString(grossGains/grossLosses,2):"n/d",
      completedSession>0?DoubleToString(100.0*profitableSession/completedSession,1)+"%":"n/d",
      completedSession>0?DoubleToString(netSession/completedSession,3):"n/d"));
   ReportLine(f,StringFormat("ULTIMAS %d POSICOES: resultado %+.2f | PF %s | acerto %s | media %s",
            recentCount,recentNet,recentLosses>0.0?DoubleToString(recentGains/recentLosses,2):"n/d",
            recentCount>0?DoubleToString(100.0*recentW/recentCount,1)+"%":"n/d",
            recentCount>0?DoubleToString(recentNet/recentCount,3):"n/d"));
   ReportLine(f,"Ultima condicao de entrada: "+(lastSignalDirection>0?"COMPRA":(lastSignalDirection<0?"VENDA":"SEM SINAL")));
   ReportLine(f,StringFormat("  Spread %.1f pts | ATR %.1f pts | Impulso curto %+.1f pts | longo %+.1f pts | pressao %.1f%% | EMA M1 %d M5 %d",
             lastSignalSpread,lastSignalATR,lastSignalShort,lastSignalLong,lastSignalPressure,lastSignalM1,lastSignalM5));
   ReportLine(f,StringFormat("  Score por componente: pressao %d/25 | impulso %d/20 | aceleracao %d/15 | candle %d/15 | EMAs %d/15 | custo %d/10",
               lastEntryFactor.pressure,lastEntryFactor.impulse,lastEntryFactor.fast,lastEntryFactor.candle,lastEntryFactor.trend,lastEntryFactor.costs));
   ReportLine(f,"----------------------------------------------------------------------");
   ReportLine(f,"RESULTADO DAS OPERACOES COMPLETADAS NESTA SESSAO (liquido com taxas registradas)");
   ReportLine(f,StringFormat("Amostras %d | positivas %d | negativas %d | liquido %+.2f | acerto %s | profit factor %s",
             completedSession, profitableSession, losingSession, netSession,
             completedSession>0?DoubleToString(100.0*profitableSession/completedSession,1)+"%":"n/d",
             grossLosses>0?DoubleToString(grossGains/grossLosses,2):"n/d"));
   ReportLine(f,"SESSOES E AMD NO MOMENTO: "+sessionExplanation);
   ReportLine(f,"FASE: "+amdPhaseName+" | "+amdExplanation);
   ReportLine(f,StringFormat("ASIA max %.2f / min %.2f | faixa AMD %.2f / %.2f",
                             asiaHigh,asiaLow,amdRangeHigh,amdRangeLow));
   ReportLine(f,"Relogio: horario do servidor convertido pelo fuso e regra DST CONFIGURADOS. Validar antes de interpretar resultados.");
   ReportLine(f,"AMD: compressao, sweep e expansao sao ROTULOS MECANICOS, NAO prova de intencao institucional.");
   ReportLine(f,"POR SESSAO NO MOMENTO DA ENTRADA (desta execucao)");
   for(int s=0;s<4;s++)
      ReportLine(f,GroupText(AlienSessionTitle(s),sessionTrades[s],sessionWins[s],sessionNet[s]));
   string phaseNames[4]={"SEM FASE","ACUMULACAO","SWEEP POSSIVEL","EXPANSAO"};
   ReportLine(f,"POR FASE AMD NA ENTRADA (desta execucao)");
   for(int q=0;q<4;q++)
      ReportLine(f,GroupText(phaseNames[q],phaseTrades[q],phaseWins[q],phaseNet[q]));
   ReportLine(f,"SETUPS PRICE ACTION / SMC / ICT - lucro liquido por posicao completa");
   ReportLine(f,"Definicoes operacionais: sweep, BOS+reteste, PA momentum, FVG e OB com retorno a zona.");
   for(int i=1;i<=5;i++)
   {
      ReportLine(f,GroupText(SetupName(i),setupCount[i],setupWins[i],setupNet[i]));
      ReportLine(f,StringFormat("  sinais detectados %d (nao equivale a entradas)",setupSignals[i]));
   }
   ReportLine(f,"SETUP ATUAL: "+SetupName(lastSetup)+" | "+lastSetupInfo);
   ReportLine(f,StringFormat("CONTEXTO: EMA M15=%d H1=%d | zona=%s [%.2f a %.2f], distancia=%.1f pontos | espaco ate liquidez contraria=%.1f pontos",
      higherTrendM15,higherTrendH1,lastZoneName,lastZoneLower,lastZoneUpper,lastZoneDistance,lastOpposingRoomPts));
   ReportLine(f,"IMPORTANTE: FVG/OB sao definicoes mecanicas e nao preveem o preco. Comparar amostras fora do periodo usado para ajustar parametros.");
   ReportLine(f,"ATENCAO: diferencas entre setups nao provam desempenho futuro; validar fora da amostra.");
   ReportLine(f,"POR SCORE (grupos exclusivos)");
   ReportLine(f,GroupText("0-59",scoreGroupCount[0],scoreGroupWins[0],scoreGroupNet[0]));
   ReportLine(f,GroupText("60-74",scoreGroupCount[1],scoreGroupWins[1],scoreGroupNet[1]));
   ReportLine(f,GroupText("75-100",scoreGroupCount[2],scoreGroupWins[2],scoreGroupNet[2]));
   ReportLine(f,StringFormat("Drawdown max realizado na sessao %.2f (sem flutuante) | maior serie de perdas %d | duracao media %s s",
      maxRealizedDrawdown,maxLossStreak,completedSession>0?DoubleToString((double)totalTradeSeconds/completedSession,1):"n/d"));
   int best=-1, worst=-1;
   double bestMean=-1.0e100, worstMean=1.0e100;
   for(int g=0;g<ALIEN_BUCKETS;g++)
   {
      if(scoreGroupCount[g]<10) continue;
      double mean=scoreGroupNet[g]/scoreGroupCount[g];
      if(mean>bestMean){bestMean=mean;best=g;}
      if(mean<worstMean){worstMean=mean;worst=g;}
   }
   string scoreNames[3]={"0-59","60-74","75-100"};
   if(best>=0 && worst>=0)
   {
      ReportLine(f,StringFormat("MELHOR FAIXA OBSERVADA: score %s media %+.3f (%d ops)",
                scoreNames[best],bestMean,scoreGroupCount[best]));
      ReportLine(f,StringFormat("PIOR FAIXA OBSERVADA: score %s media %+.3f (%d ops)",
                scoreNames[worst],worstMean,scoreGroupCount[worst]));
   }
   else ReportLine(f,"MELHOR/PIOR FAIXA: amostra insuficiente (minimo 10 por grupo).");
   ReportLine(f,"ATENCAO: rankings exploratorios. Testar em periodo diferente para confirmar.");
   ReportLine(f,"POR ALINHAMENTO EMA M1/M5 (grupos exclusivos)");
   ReportLine(f,GroupText("Ambas favoraveis",trendGroupCount[0],trendGroupWins[0],trendGroupNet[0]));
   ReportLine(f,GroupText("Uma favoravel",trendGroupCount[1],trendGroupWins[1],trendGroupNet[1]));
   ReportLine(f,GroupText("Nenhuma favoravel",trendGroupCount[2],trendGroupWins[2],trendGroupNet[2]));
   ReportLine(f,"POR PRESSAO DE TICKS (grupos exclusivos)");
   ReportLine(f,GroupText("Abaixo de 70%",pressureGroupCount[0],pressureGroupWins[0],pressureGroupNet[0]));
   ReportLine(f,GroupText("70-79%",pressureGroupCount[1],pressureGroupWins[1],pressureGroupNet[1]));
   ReportLine(f,GroupText("80% ou mais",pressureGroupCount[2],pressureGroupWins[2],pressureGroupNet[2]));
   ReportLine(f,"POR SPREAD/ATR (grupos exclusivos)");
   ReportLine(f,GroupText("Custo ate 7% do ATR",spreadGroupCount[0],spreadGroupWins[0],spreadGroupNet[0]));
   ReportLine(f,GroupText("Custo 7-12% ATR",spreadGroupCount[1],spreadGroupWins[1],spreadGroupNet[1]));
   ReportLine(f,GroupText("Custo acima 12% ATR",spreadGroupCount[2],spreadGroupWins[2],spreadGroupNet[2]));
   ReportLine(f,"POR MOTIVO DE SAIDA (operacoes completas)");
   string exitNames[5]={"Reversao com lucro","SL inicial / SL movel / stop-out","Tempo limite","Guarda de perda","Outro"};
   for(int j=0;j<5;j++) ReportLine(f,StringFormat("  %s: %d posicoes | liquido %+.2f",exitNames[j],exitTypeCount[j],exitTypeNet[j]));
   ReportLine(f,"----------------------------------------------------------------------");
   ReportLine(f,"MOTIVOS DE ESPERA (amostrados ate 1 vez/segundo, nao sao ticks)");
   string reasons[8]={"Custo/spread/ATR","Score insuficiente","Ticks/impulso/pressao",
      "Margem/contrato/stop","Ja havia posicao","Intervalo tecnico",
      "Inicio de candle","Outros"};
   for(int i=0;i<8;i++) ReportLine(f,StringFormat("  %s: %d",reasons[i],blockedCounts[i]));
   ReportLine(f,"----------------------------------------------------------------------");
   ReportLine(f,"COMO INTERPRETAR: maior acerto nao implica maior lucro; compare MEDIA LIQUIDA, numero de amostras, spread e perdas.");
   ReportLine(f,"O painel registra associacoes entre fatores e resultados, nao prova causalidade.");
   ReportLine(f,"O CSV TRADE registra cada operacao fechada com todas as condicoes da entrada.");
   ReportLine(f,"Nota: os agrupamentos sao desta EXECUCAO do robo, nao do historico anterior.");
   ReportLine(f,"LOTE MAIOR: PF e media calculados nas ultimas posicoes completas, nao no score atual.");
   ReportLine(f,"PAUSA: apos perdas consecutivas, pausa curta. Supervisor pode bloquear entradas ate o proximo dia.");
   ReportLine(f,"FILTRO DE CUSTO: impulso dos ticks deve superar o spread configurado.");
   ReportLine(f,"ZONAS: M5/M15/H1 feitas de candles FECHADOS, reavaliadas em intervalos de 2s para reduzir carga; nao garantem reacao.");
   ReportLine(f,"ANTI-REENTRADA: mesma estrutura e preco precisam deslocamento novo para permitir outro ciclo.");
   ReportLine(f,"Importante: AUMENTO DE LOTE pode ampliar perdas. So ativar sob protecao de margem/risco; nao existe certeza.");
   ReportLine(f,"Para me enviar: anexe este TXT e o CSV TRADES na conversa do ChatGPT. O EA nao envia dados sozinho.");
   ReportLine(f,"Cuidado: taxas cobradas em lancamentos separados podem nao ser atribuidas ao ID da posicao.");
   ReportLine(f,"CUIDADO: se a corretora cobrar comissao, preencha RoundTurnCommissionPerLot.");
   ReportLine(f,"AUTONOMOUS SUPERVISOR V10:");
   ReportLine(f,"Equity base = primeiro inicio do EA neste dia de servidor; nao o inicio real do dia se instalado depois.");
   ReportLine(f,"Trava diaria persiste reinicio via GlobalVariable; nao zera no mesmo dia.");
   ReportLine(f,StringFormat("Guard equity: %s | base %.2f | atual %.2f | limite diario %.2f%% | disparado %s",
      EnableDailyEquityGuard?"ON":"OFF",dayOpeningEquity,AccountInfoDouble(ACCOUNT_EQUITY),
      DailyEquityLossPct,dailyGuardTripped?"SIM":"NAO"));
   ReportLine(f,StringFormat("OrderCheck: %s | piso margin-level: %.1f%% | recusas de risco: %d | precheck: %d",
      RequireOrderPrecheck?"ON":"OFF",MinimumMarginLevelPct,riskRejected,precheckRejected));
   ReportLine(f,StringFormat("Posicoes recuperadas apos restart: %d; sem inferir historico/score desconhecido",recoveredPositions));
   ReportLine(f,"O historico estatistico de setup nesta versao e POR SESSAO; o CSV permanece como auditoria apos restart.");
   ReportLine(f,"Arquivo de operacoes (MQL5/Files): "+tradesFileName);
   ReportLine(f,"Diario de eventos fica em Common/Files (ALIEN_V10_88_...).");
   FileClose(f);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool IsAcceptedRetcode(uint rc)
{
   return rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL;
}

//+------------------------------------------------------------------+
void LogEvent(string kind, string details, double number = 0.0)
{
   if(logFile == INVALID_HANDLE)
      return;
   FileWrite(logFile, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             _Symbol, IntegerToString((long)ExpertMagic), kind,
             details, DoubleToString(number, 5));
   FileFlush(logFile);
}

//+------------------------------------------------------------------+
datetime BeginningOfDay()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   d.hour = 0;
   d.min = 0;
   d.sec = 0;
   return StructToTime(d);
}

//+------------------------------------------------------------------+
void RefreshDailyStats()
{
   dailyRealizedNet = 0.0;
   dailyEntryDeals = 0;
   dailyProfitableExitDeals = 0;
   dailyLosingExitDeals = 0;
   statsDayStart = BeginningOfDay();

   if(!HistorySelect(statsDayStart, TimeCurrent() + 60))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != ExpertMagic) continue;

      double net = HistoryDealGetDouble(deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                 + HistoryDealGetDouble(deal, DEAL_SWAP)
                 + HistoryDealGetDouble(deal, DEAL_FEE);
      dailyRealizedNet += net;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN) ++dailyEntryDeals;
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
      {
         if(net > 0.0) ++dailyProfitableExitDeals;
         else if(net < 0.0) ++dailyLosingExitDeals;
      }
   }
}

//+------------------------------------------------------------------+
// Supervisor independente do score. A referencia e a equity no primeiro
// inicio do EA naquele dia (horario do servidor), salva em GlobalVariable.
// Nao tenta estimar lucro que o usuario fez antes do primeiro inicio.

//+------------------------------------------------------------------+
//| ALIEN V11: GESTAO DE CAPITAL SEMANAL E DIARIA                    |
//+------------------------------------------------------------------+
string   weeklyEquityKey = "";
double   weekOpeningEquity = 0.0;
bool     weeklyGuardTripped = false;
double   weeklyRealizedNet = 0.0;
int      weeklyTradeCount = 0;

datetime BeginningOfWeek()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   d.hour = 0;
   d.min = 0;
   d.sec = 0;
   datetime dayStart = StructToTime(d);
   int daysFromMonday = (d.day_of_week == 0) ? 6 : (d.day_of_week - 1);
   return dayStart - (daysFromMonday * 86400);
}

void RefreshWeeklyEquityBaseline()
{
   string key = StringFormat("ALIEN_V11_WK_%I64d_%s_%I64u_%d",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic,
                  (int)BeginningOfWeek());
   if(key != weeklyEquityKey)
   {
      weeklyEquityKey = key;
      if(GlobalVariableCheck(key))
         weekOpeningEquity = GlobalVariableGet(key);
      else
      {
         weekOpeningEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(key, weekOpeningEquity);
      }
      weeklyGuardTripped = GlobalVariableCheck(key + "_LOCK");
   }
}

void RefreshWeeklyStats()
{
   weeklyRealizedNet = 0.0;
   weeklyTradeCount = 0;
   datetime weekStart = BeginningOfWeek();
   if(!HistorySelect(weekStart, TimeCurrent() + 60))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != ExpertMagic) continue;

      double net = HistoryDealGetDouble(deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(deal, DEAL_COMMISSION)
                 + HistoryDealGetDouble(deal, DEAL_SWAP)
                 + HistoryDealGetDouble(deal, DEAL_FEE);
      weeklyRealizedNet += net;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
         ++weeklyTradeCount;
   }
}

void RefreshDailyEquityBaseline()
{
   string key = StringFormat("ALIEN_V1089_EQ_%I64d_%s_%I64u_%d",
                  AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, ExpertMagic,
                  (int)BeginningOfDay());
   if(key != dailyEquityKey)
   {
      dailyEquityKey=key;
      if(GlobalVariableCheck(key))
         dayOpeningEquity=GlobalVariableGet(key);
      else
      {
         dayOpeningEquity=AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(key,dayOpeningEquity);
      }
      dailyGuardTripped=GlobalVariableCheck(key+"_LOCK");
   }
}

bool NewEntriesAllowedBySupervisor()
{
   RefreshDailyEquityBaseline();
   RefreshDailyStats();
   RefreshWeeklyEquityBaseline();
   RefreshWeeklyStats();

   // Disjuntor Semanal ($12)
   if(WeeklyMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double weeklyLoss = weekOpeningEquity - curEq;
      if(weeklyLoss >= WeeklyMaxLossMoney || weeklyRealizedNet <= -WeeklyMaxLossMoney)
      {
         weeklyGuardTripped = true;
         GlobalVariableSet(weeklyEquityKey + "_LOCK", 1.0);
      }
      if(weeklyGuardTripped)
      {
         double curLoss = (weeklyLoss > -weeklyRealizedNet ? weeklyLoss : -weeklyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR SEMANAL ATIVADO: Perda acumulada -$%.2f >= Teto -$%.2f. Travado ate segunda-feira.",
                                          curLoss, WeeklyMaxLossMoney);
         return false;
      }
   }


   // Meta Diaria de Lucro (Meta R$ 10.000/mes: $90/dia)
   if(StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0 && dailyRealizedNet >= DailyProfitTargetMoney)
   {
      supervisorMessage = StringFormat("META DIARIA ATINGIDA: +$%.2f >= +$%.2f (R$ 510 garantidos). Operacoes encerradas hoje com sucesso!",
                                       dailyRealizedNet, DailyProfitTargetMoney);
      return false;
   }

   // Disjuntor Diario ($150 da mesa)
   if(DailyMaxLossMoney > 0.0)
   {
      double curEq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyLoss = dayOpeningEquity - curEq;
      if(dailyLoss >= DailyMaxLossMoney || dailyRealizedNet <= -DailyMaxLossMoney)
      {
         dailyGuardTripped = true;
         GlobalVariableSet(dailyEquityKey + "_LOCK", 1.0);
      }
      if(dailyGuardTripped)
      {
         double curLoss = (dailyLoss > -dailyRealizedNet ? dailyLoss : -dailyRealizedNet);
         supervisorMessage = StringFormat("DISJUNTOR DIARIO ATIVADO: Perda -$%.2f >= Teto -$%.2f. Pausa ate amanha.",
                                          curLoss, DailyMaxLossMoney);
         return false;
      }
   }

   // Teto Diario de Trades
   if(MaxDailyTrades > 0 && dailyEntryDeals >= MaxDailyTrades)
   {
      supervisorMessage = StringFormat("TETO DIARIO DE TRADES ATINGIDO: %d/%d operacoes realizadas hoje.",
                                       dailyEntryDeals, MaxDailyTrades);
      return false;
   }

   // Filtro de Sessao de Alta Liquidez (Londres + NY: 08:00 as 18:00 UTC)
   if(TradeLondonAndNYOnly)
   {
      MqlDateTime dt;
      TimeToStruct(AlienServerUTC(TimeCurrent()), dt);
      if(dt.hour < 8 || dt.hour >= 18)
      {
         supervisorMessage = StringFormat("FORA DA JANELA DE ALTA LIQUIDEZ: UTC %02d:%02d (Permitido: 08:00 as 18:00 UTC).",
                                          dt.hour, dt.min);
         return false;
      }
   }

   if(RestrictToXAU && StringFind(_Symbol,"XAU")<0)
   {
      supervisorMessage="V10: simbolo fora de XAU (bloqueado).";
      return false;
   }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq<=0.0 || dayOpeningEquity<=0.0)
   {
      supervisorMessage="Equity invalida.";
      return false;
   }
   if(EnableDailyEquityGuard && DailyEquityLossPct>0.0)
   {
      double drawdown=100.0*(dayOpeningEquity-eq)/dayOpeningEquity;
      if(drawdown>=DailyEquityLossPct)
      {
         dailyGuardTripped=true;
         GlobalVariableSet(dailyEquityKey+"_LOCK",1.0);
      }
      if(dailyGuardTripped)
      {
         supervisorMessage=StringFormat("PAUSA DE RISCO: equity %.2f; limite diario %.2f%%.",
                                         eq,DailyEquityLossPct);
         return false;
      }
   }
   if(!MQLInfoInteger(MQL_TESTER) && !TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      supervisorMessage="Sem conexao com servidor.";
      return false;
   }
   if(DisablePyramidInV10 && OurPositionCount()>0)
   {
      supervisorMessage="Posicao existente: sem piramide nesta versao.";
      return false;
   }
   supervisorMessage="Supervisor OK. Entrada sujeita aos filtros.";
   return true;
}

// Preflight real de margem. O retorno do OrderCheck e informativo;
// a ordem ainda pode falhar ou executar diferente no servidor.
bool PreflightOrder(ENUM_ORDER_TYPE side,double vol,double price,double sl,string &why)
{
   if(!RequireOrderPrecheck) return true;
   MqlTradeRequest req={};
   MqlTradeCheckResult check={};
   req.action=TRADE_ACTION_DEAL;
   req.symbol=_Symbol;
   req.magic=ExpertMagic;
   req.type=side;
   req.volume=vol;
   req.price=price;
   req.sl=sl;
   req.tp=0.0;
   req.deviation=SlippagePoints;
   req.comment="ALIEN V10 CHECK";
   long execMode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE);
   long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
      req.type_filling=ORDER_FILLING_FOK;
   else if((filling & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
      req.type_filling=ORDER_FILLING_IOC;
   else if(execMode!=SYMBOL_TRADE_EXECUTION_MARKET)
      req.type_filling=ORDER_FILLING_RETURN;
   else
   {
      why="Corretora sem filling FOK/IOC permitido";
      return false;
   }
   ResetLastError();
   if(!OrderCheck(req,check))
   {
      why=StringFormat("OrderCheck falhou: terminal=%d servidor=%u %s",
                       GetLastError(),check.retcode,check.comment);
      return false;
   }
   if(check.retcode!=0 && check.retcode!=TRADE_RETCODE_DONE &&
      check.retcode!=TRADE_RETCODE_PLACED)
   {
      why=StringFormat("OrderCheck negado: %u %s",check.retcode,check.comment);
      return false;
   }
   if(check.margin_free<MinFreeMarginMoney)
   {
      why="OrderCheck: margem livre projetada insuficiente";
      return false;
   }
   if(check.margin_level>0.0 && check.margin_level<MinimumMarginLevelPct)
   {
      why="OrderCheck: nivel de margem projetado abaixo do piso";
      return false;
   }
   return true;
}

// A recuperacao protege posicoes antes de permitir novas entradas.
// As estatisticas de setup da sessao nao sao inventadas: contexto ausente
// e explicitamente marcado como RECUPERADA_APOS_REINICIO.
void RecoverOpenPositions()
{
   recoveredPositions=0;
   if(!EnableTelemetry) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=ExpertMagic) continue;
      ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(FindSample(pid)>=0 || recordCount>=ALIEN_RECORD_CAP) continue;
      int at=recordCount++;
      records[at].positionId=pid;
      records[at].opened=(datetime)PositionGetInteger(POSITION_TIME);
      records[at].direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);
      records[at].score=0;
      records[at].setup=0;
      records[at].setupLevel=0.0;
      records[at].spread=0.0;
      records[at].atr=0.0;
      records[at].shortMove=0.0;
      records[at].longMove=0.0;
      records[at].pressure=0.0;
      records[at].ema1=0;
      records[at].ema5=0;
      records[at].ema15=0;
      records[at].emaH1=0;
      records[at].zone="RECUPERADA_APOS_REINICIO";
      records[at].zoneDist=0.0;
      records[at].roomToLiquidity=0.0;
      records[at].entrySessionCode=3;
      records[at].entryAMDPhaseCode=0;
      records[at].entrySessionName="NAO_IDENTIFICADA_POS_RESTART";
      records[at].entryAMDName="NAO_IDENTIFICADA_POS_RESTART";
      records[at].net=0.0;
      records[at].volume=PositionGetDouble(POSITION_VOLUME);
      records[at].finished=false;
      records[at].exitReason="INDEFINIDO";
      records[at].points.pressure=0;
      records[at].points.impulse=0;
      records[at].points.fast=0;
      records[at].points.candle=0;
      records[at].points.trend=0;
      records[at].points.costs=0;
      recoveredPositions++;
   }
   if(recoveredPositions>0)
      Print("ALIEN V10: recuperadas ",recoveredPositions,
            " posicoes; contexto anterior nao pode ser reconstruido com certeza.");
}

//+------------------------------------------------------------------+
// Retangulo de contexto: a zona HTF e uma hipotese, nao uma previsao.
void DrawProfessorZone()
{
   if(!DrawContextZone) return;
   string name="ALIEN_V1050_LEGACY_ZONE_"+IntegerToString((long)ExpertMagic);
   if(cachedZoneId==0 || lastZoneLower<=0.0 || lastZoneUpper<=lastZoneLower)
   {
      ObjectDelete(0,name);
      return;
   }
   datetime t1=TimeCurrent()-3600;
   datetime t2=TimeCurrent()+900;
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,lastZoneLower,t2,lastZoneUpper))
         return;
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrDeepSkyBlue);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_FILL,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   }
   ObjectMove(0,name,0,t1,lastZoneLower);
   ObjectMove(0,name,1,t2,lastZoneUpper);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,
                   lastZoneName+" | regiao HTF, nao previsao");
}

//+------------------------------------------------------------------+
void AddTick(const MqlTick &tick)
{
   tickHead = (tickHead + 1) % ALIEN_TICK_CAP;
   tickTimes[tickHead] = tick.time_msc;
   tickPrices[tickHead] = tick.bid;
   if(tickCount < ALIEN_TICK_CAP) ++tickCount;
   ++ticksTotal;
}

//+------------------------------------------------------------------+
// Includes the oldest tick in the price delta (fixes previous off-by-one).
TickMetrics MeasureTicks(long nowMsc, int windowMs)
{
   TickMetrics m;
   m.movePoints = 0.0;
   m.directionPercent = 0.0;
   m.changes = 0;
   m.up = 0;
   m.down = 0;
   m.durationMs = 0.0;

   if(tickCount < 2 || tickHead < 0) return m;

   double newest = tickPrices[tickHead];
   double previous = newest;
   double oldest = newest;
   long oldestMsc = tickTimes[tickHead];
   for(int k = 1; k < tickCount; ++k)
   {
      int ix = (tickHead - k + ALIEN_TICK_CAP) % ALIEN_TICK_CAP;
      if(nowMsc - tickTimes[ix] > windowMs) break;
      double value = tickPrices[ix];
      if(previous > value) ++m.up;
      else if(previous < value) ++m.down;
      previous = value;
      oldest = value;
      oldestMsc = tickTimes[ix];
   }

   m.changes = m.up + m.down;
   m.movePoints = (newest - oldest) / _Point;
   m.durationMs = (double)(nowMsc - oldestMsc);
   if(m.changes > 0)
   {
      if(m.movePoints > 0.0) m.directionPercent = 100.0 * m.up / m.changes;
      else if(m.movePoints < 0.0) m.directionPercent = 100.0 * m.down / m.changes;
   }
   return m;
}

//+------------------------------------------------------------------+
bool GetMarketFilters(double &atrPts, int &trendM1, int &trendM5)
{
   atrPts = 0.0;
   trendM1 = 0;
   trendM5 = 0;
   double a[1], f1[1], s1[1], f5[1], s5[1];
   // Use CLOSED bars (shift 1), so trend does not flip with every current tick.
   if(CopyBuffer(hAtrM1, 0, 1, 1, a) != 1 ||
      CopyBuffer(hFastM1, 0, 1, 1, f1) != 1 ||
      CopyBuffer(hSlowM1, 0, 1, 1, s1) != 1 ||
      CopyBuffer(hFastM5, 0, 1, 1, f5) != 1 ||
      CopyBuffer(hSlowM5, 0, 1, 1, s5) != 1)
      return false;

   if(a[0] <= 0.0) return false;
   atrPts = a[0] / _Point;
   if(f1[0] > s1[0]) trendM1 = 1;
   else if(f1[0] < s1[0]) trendM1 = -1;
   if(f5[0] > s5[0]) trendM5 = 1;
   else if(f5[0] < s5[0]) trendM5 = -1;
   return true;
}

//+------------------------------------------------------------------+
// Uses broker's OrderCalcProfit instead of assuming gold contract size.
double MoneyPerPoint(ENUM_ORDER_TYPE type, double volume, double referencePrice)
{
   double hypotheticalClose = referencePrice +
      (type == ORDER_TYPE_BUY ? _Point : -_Point);
   double pnl = 0.0;
   if(OrderCalcProfit(type, _Symbol, volume, referencePrice, hypotheticalClose, pnl) &&
      MathAbs(pnl) > 1e-9)
      return MathAbs(pnl);

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0) return 0.0;
   return tickValue * _Point / tickSize * volume;
}

//+------------------------------------------------------------------+
double ValidVolume(double requested)
{
   double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0 || requested < minV || requested > maxV) return 0.0;
   double volume = minV + MathFloor((requested - minV + 1e-10) / step) * step;
   return NormalizeDouble(volume, 8);
}

//+------------------------------------------------------------------+
// Never interfere with positions belonging to another EA / magic.
int OurPositionCount()
{
   int n = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != ExpertMagic) continue;
      ++n;
   }
   return n;
}

//+------------------------------------------------------------------+
// Other EAs / manual orders on the same symbol must not silently overlap
// with a sweep-only experiment. Cancel them manually after verification.
bool SymbolHasForeignPendingOrders()
{
   for(int i=OrdersTotal()-1; i>=0; --i)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type!=ORDER_TYPE_BUY_LIMIT && type!=ORDER_TYPE_SELL_LIMIT &&
         type!=ORDER_TYPE_BUY_STOP && type!=ORDER_TYPE_SELL_STOP &&
         type!=ORDER_TYPE_BUY_STOP_LIMIT && type!=ORDER_TYPE_SELL_STOP_LIMIT)
         continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC)!=ExpertMagic) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// Avoid mixing EAs on netting accounts, or two ALIEN copies on a symbol.
bool SymbolHasAnyPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool WasAlreadyTradedThisBar(datetime startBar)
{
   if(startBar == 0) return false;
   if(!HistorySelect(startBar, TimeCurrent() + 5)) return false;
   for(int i = HistoryDealsTotal()-1; i >= 0; --i)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_MAGIC) != ExpertMagic) continue;
      ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
      if(e == DEAL_ENTRY_IN || e == DEAL_ENTRY_INOUT) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// PRICE ACTION / SMC-I.C.T. are operational definitions, not predictive truth.
// Only past CLOSED M1 candles and current live price are used, no lookahead.
string SetupName(int kind)
{
   if(kind==1) return "LIQUIDITY_SWEEP";
   if(kind==2) return "BOS_RETEST";
   if(kind==3) return "PA_MOMENTUM";
   if(kind==4) return "FVG_REACAO";
   if(kind==5) return "ORDER_BLOCK_REACAO";
   return "SEM_SETUP";
}

bool StructureExtremes(int firstShift, int n, double &highest, double &lowest)
{
   if(n<=0 || Bars(_Symbol,PERIOD_M1)<firstShift+n+1) return false;
   highest=-1.0e100;
   lowest=1.0e100;
   for(int k=firstShift;k<firstShift+n;k++)
   {
      double h=iHigh(_Symbol,PERIOD_M1,k);
      double l=iLow(_Symbol,PERIOD_M1,k);
      if(h<=0.0 || l<=0.0) return false;
      if(h>highest) highest=h;
      if(l<lowest) lowest=l;
   }
   return highest>lowest;
}

// We use CLOSED TF candles only, and nearest zone to the current quote.
// These rules are operational approximations, not predictive labels.
int TrendFromHandles(int fastHandle, int slowHandle)
{
   double f[1],sl[1];
   if(CopyBuffer(fastHandle,0,1,1,f)!=1 || CopyBuffer(slowHandle,0,1,1,sl)!=1)
      return 0;
   if(f[0]>sl[0]) return 1;
   if(f[0]<sl[0]) return -1;
   return 0;
}

double ATRFromHandle(int handle)
{
   double a[1];
   if(CopyBuffer(handle,0,1,1,a)!=1 || a[0]<=0.0) return 0.0;
   return a[0];
}

string TFName(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_M5) return "M5";
   if(tf==PERIOD_M15) return "M15";
   if(tf==PERIOD_H1) return "H1";
   return "TF";
}

// Fully mitigated historical zones are excluded by closed-candle evidence.
// A wick through the far edge of a zone invalidates it for our test model.
bool ZoneFullyMitigated(ENUM_TIMEFRAMES tf,int newestFormationShift,
                        int direction,double lower,double upper)
{
   for(int k=newestFormationShift-1;k>=1;--k)
   {
      if(direction>0 && iLow(_Symbol,tf,k)<=lower) return true;
      if(direction<0 && iHigh(_Symbol,tf,k)>=upper) return true;
   }
   return false;
}

// Returns nearest valid historical zone, based only on CLOSED bars.
// Each zone is mechanical and needs out-of-sample validation.

// A future validation should track each zone's creation and mitigation.
// Always use shifts >=1: never a future candle.
int NearestHTFZone(int direction, double bid, double atrM1Pts,
                   double &lower, double &upper, double &distPts, string &label)
{
   lower=0.0;upper=0.0;distPts=1e9;label="SEM_ZONA";
   if(!UseHigherTimeframes || (!EnableFVGSetup && !EnableOrderBlockSetup)) return 0;
   ENUM_TIMEFRAMES frames[3]={PERIOD_M5,PERIOD_M15,PERIOD_H1};
   int atrHandles[3]={hAtrM5,hAtrM15,hAtrH1};
   int found=0;
   for(int f=0;f<3;f++)
   {
      ENUM_TIMEFRAMES tf=frames[f];
      if(Bars(_Symbol,tf)<HigherTFScanBars+6) continue;
      double tfATR=ATRFromHandle(atrHandles[f]);
      if(tfATR<=0.0) continue;
      for(int shift=2;shift<=HigherTFScanBars;shift++)
      {
         // FVG: newer closed bar at shift-1; older closed bar at shift+1.
         // Bull: low(newer)>high(older); Bear: high(newer)<low(older).
         if(EnableFVGSetup)
         {
            double lo=0.0,hi=0.0;
            if(direction>0)
            {
               lo=iHigh(_Symbol,tf,shift+1);
               hi=iLow(_Symbol,tf,shift-1);
            }
            else
            {
               lo=iHigh(_Symbol,tf,shift-1);
               hi=iLow(_Symbol,tf,shift+1);
            }
            if(lo>0.0 && hi-lo>=MinFVGPoints*_Point &&
               !ZoneFullyMitigated(tf,shift-1,direction,lo,hi))
            {
               double d= MathMax(0.0,MathMax(lo-bid,bid-hi))/_Point;
               if(d<distPts)
               {
                  distPts=d;lower=lo;upper=hi;
                  label="FVG_"+TFName(tf);
                  found=4;
               }
            }
         }
         if(EnableOrderBlockSetup)
         {
            // Last opposite-colored CLOSED candle before a displacement candle.
            // Bullish zone: down candle (shift) + bullish close above its high (shift-1).
            // Bearish zone: up candle (shift) + bearish close below its low (shift-1).
            double o=iOpen(_Symbol,tf,shift),c=iClose(_Symbol,tf,shift);
            double h=iHigh(_Symbol,tf,shift),l=iLow(_Symbol,tf,shift);
            double nextO=iOpen(_Symbol,tf,shift-1),nextC=iClose(_Symbol,tf,shift-1);
            bool valid=false;
            double lo=0.0,hi=0.0;
            if(direction>0 && c<o && nextC>nextO &&
               nextC>h+tfATR*OBDisplacementATR)
            {
               lo=l;hi=o;valid=true;
            }
            if(direction<0 && c>o && nextC<nextO &&
               nextC<l-tfATR*OBDisplacementATR)
            {
               lo=o;hi=h;valid=true;
            }
            if(valid && hi>lo &&
               !ZoneFullyMitigated(tf,shift-1,direction,lo,hi))
            {
               double d=MathMax(0.0,MathMax(lo-bid,bid-hi))/_Point;
               if(d<distPts)
               {
                  distPts=d;lower=lo;upper=hi;
                  label="OB_"+TFName(tf);
                  found=5;
               }
            }
         }
      }
   }
   return found;
}

// Nearest opposing HIGH for buys / LOW for sells on recent closed M5/M15 bars.
// This is a conservative room estimate, not a guaranteed target.
double RoomToOpposingLiquidity(int direction,double quote)
{
   double nearest=1e9;
   ENUM_TIMEFRAMES frames[2]={PERIOD_M5,PERIOD_M15};
   for(int f=0;f<2;f++)
   {
      if(Bars(_Symbol,frames[f])<HigherTFScanBars+3) continue;
      for(int k=1;k<=HigherTFScanBars;k++)
      {
         double level=direction>0?iHigh(_Symbol,frames[f],k):iLow(_Symbol,frames[f],k);
         if(level<=0.0) continue;
         double dist=(level-quote)*direction/_Point;
         if(dist>0.0 && dist<nearest) nearest=dist;
      }
   }
   return nearest;
}

// Evento de varredura observado nesta execucao, nao inferido apenas de pavio
// acumulado. Uma nova minima/maxima so reativa o sinal se houver deslocamento real.
void ObserveSweepEvent(const MqlTick &tick,datetime currentBar)
{
   if(currentBar<=0 || tick.bid<=0.0 || tick.time_msc<=0) return;
   if(sweepObservedBar!=currentBar)
   {
      // Atualiza apenas a referencia para NOVAS varreduras; preserva eventos
      // existentes e seus niveis congelados ate serem usados ou expirarem.
      sweepObservedBar=currentBar;
      sweepCachedHigh=0.0;
      sweepCachedLow=0.0;
      StructureExtremes(1,StructureLookbackBars,sweepCachedHigh,sweepCachedLow);
   }

   if(sweepCachedLow>0.0 && sweepCachedHigh>sweepCachedLow)
   {
      double buyBreak=sweepCachedLow-MinSweepPoints*_Point;
      double sellBreak=sweepCachedHigh+MinSweepPoints*_Point;
      bool crossedLow=(sweepLastBid>0.0 && sweepLastBid>buyBreak && tick.bid<=buyBreak);
      bool crossedHigh=(sweepLastBid>0.0 && sweepLastBid<sellBreak && tick.bid>=sellBreak);
      bool activeBuy=(sweepEventTimeBuy>0 && tick.time_msc>=sweepEventTimeBuy &&
                      tick.time_msc-sweepEventTimeBuy<=1000*(long)SweepEventMaxAgeSeconds);
      bool activeSell=(sweepEventTimeSell>0 && tick.time_msc>=sweepEventTimeSell &&
                       tick.time_msc-sweepEventTimeSell<=1000*(long)SweepEventMaxAgeSeconds);
      bool deeperBuy=activeBuy && tick.bid<=sweepRefreshAnchorBuy-
                     SweepNewExtremeToRefreshPts*_Point;
      bool deeperSell=activeSell && tick.bid>=sweepRefreshAnchorSell+
                      SweepNewExtremeToRefreshPts*_Point;

      if(crossedLow || deeperBuy)
      {
         if(crossedLow || sweepEventLevelBuy<=0.0)
            sweepEventLevelBuy=sweepCachedLow;
         sweepExtremeBuy=tick.bid;
         sweepRefreshAnchorBuy=tick.bid;
         sweepEventTimeBuy=tick.time_msc;
         sweepReclaimBuy=0;
         sweepSeqBuy=++sweepSeqCounter;
         sweepObservedCount++;
         LogEvent("SWEEP_OBSERVED_BUY",StringFormat("nivel=%.2f extremo=%.2f",sweepEventLevelBuy,sweepExtremeBuy),tick.bid);
      }
      else if(activeBuy && tick.bid<sweepExtremeBuy)
      {
         // Atualiza o extremo real do evento sem inventar sequencia nova.
         sweepExtremeBuy=tick.bid;
         sweepReclaimBuy=0;
      }
      if(crossedHigh || deeperSell)
      {
         if(crossedHigh || sweepEventLevelSell<=0.0)
            sweepEventLevelSell=sweepCachedHigh;
         sweepExtremeSell=tick.bid;
         sweepRefreshAnchorSell=tick.bid;
         sweepEventTimeSell=tick.time_msc;
         sweepReclaimSell=0;
         sweepSeqSell=++sweepSeqCounter;
         sweepObservedCount++;
         LogEvent("SWEEP_OBSERVED_SELL",StringFormat("nivel=%.2f extremo=%.2f",sweepEventLevelSell,sweepExtremeSell),tick.bid);
      }
      else if(activeSell && tick.bid>sweepExtremeSell)
      {
         sweepExtremeSell=tick.bid;
         sweepReclaimSell=0;
      }
   }
   // A recuperacao usa o nivel CONGELADO na hora do rompimento, inclusive
   // quando a varredura aconteceu no candle anterior.
   if(sweepEventTimeBuy>0 && sweepEventLevelBuy>0.0)
   {
      if(tick.bid>=sweepEventLevelBuy+SweepReclaimPoints*_Point)
         sweepReclaimBuy++;
      else sweepReclaimBuy=0;
   }
   if(sweepEventTimeSell>0 && sweepEventLevelSell>0.0)
   {
      if(tick.bid<=sweepEventLevelSell-SweepReclaimPoints*_Point)
         sweepReclaimSell++;
      else sweepReclaimSell=0;
   }
   // Um evento pode atravessar candles; conte confirmacao/expiracao UMA vez.
   if(sweepSeqBuy>0 && sweepEventTimeBuy>0)
   {
      bool expired=tick.time_msc-sweepEventTimeBuy>1000*(long)SweepEventMaxAgeSeconds;
      if(expired && countedExpireBuy!=sweepSeqBuy && sweepSeqBuy!=lastTradedSweepSeq)
      { countedExpireBuy=sweepSeqBuy; sweepExpiredCount++; }
      else if(!expired && sweepReclaimBuy>=SweepReclaimConfirmTicks && countedConfirmBuy!=sweepSeqBuy)
      { countedConfirmBuy=sweepSeqBuy; sweepConfirmedCount++; }
   }
   if(sweepSeqSell>0 && sweepEventTimeSell>0)
   {
      bool expired=tick.time_msc-sweepEventTimeSell>1000*(long)SweepEventMaxAgeSeconds;
      if(expired && countedExpireSell!=sweepSeqSell && sweepSeqSell!=lastTradedSweepSeq)
      { countedExpireSell=sweepSeqSell; sweepExpiredCount++; }
      else if(!expired && sweepReclaimSell>=SweepReclaimConfirmTicks && countedConfirmSell!=sweepSeqSell)
      { countedConfirmSell=sweepSeqSell; sweepConfirmedCount++; }
   }
   sweepLastBid=tick.bid;
}

bool SweepEventFresh(int direction,long nowMsc)
{
   if(!RequireObservedSweepEvent) return true;
   long eventMs=(direction>0)?sweepEventTimeBuy:sweepEventTimeSell;
   int confirms=(direction>0)?sweepReclaimBuy:sweepReclaimSell;
   ulong seq=(direction>0)?sweepSeqBuy:sweepSeqSell;
   return (seq>0 && seq!=lastTradedSweepSeq && eventMs>0 &&
           nowMsc>=eventMs && nowMsc-eventMs<=1000*(long)SweepEventMaxAgeSeconds &&
           confirms>=SweepReclaimConfirmTicks);
}

// Limite aumentado apenas quando a confirmacao curta e o contexto favorecem
// a reversao. O limite de RISCO monetario continua independente.
double SweepAllowedDistanceATR(int direction,const TickMetrics &shortM,
                               double spreadPts,double atrPts,int trendM1,int trendM5)
{
   double cap=SweepMaxEntryDistanceATR;
   if(!SweepUseAdaptiveDistance || direction==0 || atrPts<=0.0) return cap;
   bool impulseConfirmed=(shortM.movePoints*direction >= spreadPts*1.5);
   bool alignedTicks=(shortM.directionPercent>=75.0 && impulseConfirmed);
   if(alignedTicks && trendM1==direction)
      cap=MathMax(cap,SweepDistanceMidATR);
   if(alignedTicks && shortM.directionPercent>=85.0 &&
      trendM1==direction && trendM5==direction && spreadPts<=0.08*atrPts)
      cap=MathMax(cap,SweepDistanceStrongATR);
   return cap;
}

void UpdateSweepDiagnostics(const MqlTick &tick,const TickMetrics &shortM,
                             double atrPts,int trendM1,int trendM5)
{
   bool buyPresent=(sweepSeqBuy>0 && sweepEventTimeBuy>0);
   bool sellPresent=(sweepSeqSell>0 && sweepEventTimeSell>0);
   if(!buyPresent && !sellPresent)
   {
      sweepDiagnostic="SWEEP: sem varredura observada; aguardando novo evento.";
      sweepPanelSummary="SWEEP: aguardando varredura";
      return;
   }
   int direction=1;
   if(!buyPresent) direction=-1;
   else if(sellPresent && sweepEventTimeSell>sweepEventTimeBuy) direction=-1;
   long ev=(direction>0)?sweepEventTimeBuy:sweepEventTimeSell;
   double level=(direction>0)?sweepEventLevelBuy:sweepEventLevelSell;
   int confirms=(direction>0)?sweepReclaimBuy:sweepReclaimSell;
   ulong seq=(direction>0)?sweepSeqBuy:sweepSeqSell;
   double price=direction>0?tick.ask:tick.bid;
   double distance=(direction>0?price-level:level-price)/_Point;
   double spread=(tick.ask-tick.bid)/_Point;
   double cap=SweepAllowedDistanceATR(direction,shortM,spread,atrPts,trendM1,trendM5);
   double maxDist=cap*atrPts;
   long ageMs=(tick.time_msc>=ev)?(tick.time_msc-ev):0;
   string state="AGUARDANDO RETOMADA";
   if(seq==lastTradedSweepSeq) state="JA OPERADO";
   else if(ageMs>1000*(long)SweepEventMaxAgeSeconds) state="EXPIRADO";
   else if(confirms>=SweepReclaimConfirmTicks) state="CONFIRMADO";
   if(distance>maxDist && maxDist>0.0 && state=="CONFIRMADO") state="LONGE DO NIVEL";
   sweepDiagnostic=StringFormat("SWEEP %s %s | idade %ds | ticks %d/%d | dist %.0f/%.0f pts | limite %.2f ATR",
                 direction>0?"BUY":"SELL",state,(int)(ageMs/1000),
                 confirms,SweepReclaimConfirmTicks,distance,maxDist,cap);
   sweepPanelSummary=StringFormat("SW %s %s %ds | %.0f/%.0f pts | t%d/%d",
                 direction>0?"B":"S",state,(int)(ageMs/1000),distance,maxDist,
                 confirms,SweepReclaimConfirmTicks);
}



// Return one of five testable entry-pattern IDs. Priority: sweep, BOS, zones, PA.
// direction is already determined from the tick impulse and confirmed separately.
int SelectSetup(int direction, const MqlTick &tick, double atrPts,
                int trendM1, int trendM5, TickMetrics &shortM,
                int zoneId, double zoneLower, double zoneUpper,
                double zoneDistance, double zoneTolerance,
                double &structureLevel, string &description)
{
   structureLevel=0.0;
   description="Nenhum padrao PA/SMC confirmado";
   if(direction==0 || atrPts<=0.0) return 0;

   double prevHigh=0.0,prevLow=0.0;
   if(!StructureExtremes(1,StructureLookbackBars,prevHigh,prevLow))
   {
      description="Aguardando historico de estrutura M1";
      return 0;
   }
   double currentLow=iLow(_Symbol,PERIOD_M1,0);
   double currentHigh=iHigh(_Symbol,PERIOD_M1,0);
   double bid=tick.bid;
   double candleOpen=iOpen(_Symbol,PERIOD_M1,0);
   if(currentLow<=0.0 || currentHigh<=0.0 || candleOpen<=0.0) return 0;

   // Liquidity sweep observado: o evento nao desaparece ao mudar o candle.
   // Em modo comparativo antigo, ainda aceitamos o pavio do candle atual.
   if(EnableLiquiditySweep)
   {
      bool observedMode=(RequireObservedSweepEvent);
      double level=direction>0?sweepEventLevelBuy:sweepEventLevelSell;
      double extreme=direction>0?sweepExtremeBuy:sweepExtremeSell;
      bool fresh=observedMode && SweepEventFresh(direction,tick.time_msc);
      bool bullishSweep=false, bearishSweep=false;
      if(observedMode)
      {
         bullishSweep=(direction>0 && fresh && level>0.0 &&
                        extreme<=level-MinSweepPoints*_Point &&
                        bid>=level+SweepReclaimPoints*_Point &&
                        shortM.movePoints>0.0);
         bearishSweep=(direction<0 && fresh && level>0.0 &&
                        extreme>=level+MinSweepPoints*_Point &&
                        bid<=level-SweepReclaimPoints*_Point &&
                        shortM.movePoints<0.0);
         if(!fresh)
            description="Sweep: evento nao confirmado, expirado ou ja negociado";
      }
      else
      {
         level=direction>0?prevLow:prevHigh;
         extreme=direction>0?currentLow:currentHigh;
         bullishSweep=(direction>0 && currentLow<=prevLow-MinSweepPoints*_Point &&
                       bid>=prevLow+SweepReclaimPoints*_Point && shortM.movePoints>0.0);
         bearishSweep=(direction<0 && currentHigh>=prevHigh+MinSweepPoints*_Point &&
                       bid<=prevHigh-SweepReclaimPoints*_Point && shortM.movePoints<0.0);
      }
      if(bullishSweep || bearishSweep)
      {
         double sweepDepthPts=direction>0?(level-extreme)/_Point:(extreme-level)/_Point;
         double executable=direction>0?tick.ask:tick.bid;
         double distanceFromLevelPts=direction>0?(executable-level)/_Point:
                                               (level-executable)/_Point;
         double currentSpread=(tick.ask-tick.bid)/_Point;
         double maxDistATR=SweepAllowedDistanceATR(direction,shortM,currentSpread,
                                                   atrPts,trendM1,trendM5);
         double maxDistPts=atrPts*maxDistATR;
         if(sweepDepthPts < atrPts*SweepMinimumWickATR)
         {
            description=StringFormat("Sweep raso %.0f < %.0f pts | %s",
                         sweepDepthPts,atrPts*SweepMinimumWickATR,sweepDiagnostic);
            bullishSweep=false; bearishSweep=false;
         }
         else if(distanceFromLevelPts > maxDistPts)
         {
            description=StringFormat("Sweep longe: dist %.0f / limite %.0f pts (%.2f ATR)",
                                    distanceFromLevelPts,maxDistPts,maxDistATR);
            bullishSweep=false; bearishSweep=false;
         }
      }
      if(bullishSweep || bearishSweep)
      {
         structureLevel=level;
         description=StringFormat("Sweep %s: recuperou %.2f | %s",
                           direction>0?"FUNDO":"TOPO",structureLevel,sweepDiagnostic);
         return 1;
      }
   }

   // BOS: prior CLOSED bar broke structure of earlier closed bars, now retesting.
   if(EnableBreakRetest)
   {
      double olderHigh=0.0,olderLow=0.0;
      if(StructureExtremes(2,StructureLookbackBars,olderHigh,olderLow))
      {
         double prevClose=iClose(_Symbol,PERIOD_M1,1);
         double prevOpen=iOpen(_Symbol,PERIOD_M1,1);
         bool buyBOS = direction>0 && trendM1>0 &&
            prevClose>olderHigh + BOSBreakPoints*_Point &&
            prevClose>prevOpen &&
            currentLow<=olderHigh+RetestTolerancePoints*_Point &&
            bid>olderHigh + SweepReclaimPoints*_Point &&
            shortM.movePoints>0.0;
         bool sellBOS = direction<0 && trendM1<0 &&
            prevClose<olderLow - BOSBreakPoints*_Point &&
            prevClose<prevOpen &&
            currentHigh>=olderLow-RetestTolerancePoints*_Point &&
            bid<olderLow - SweepReclaimPoints*_Point &&
            shortM.movePoints<0.0;
         if(buyBOS || sellBOS)
         {
            structureLevel=direction>0?olderHigh:olderLow;
            description=StringFormat("BOS %s com reteste de %.2f",
                          direction>0?"ALTA":"BAIXA",structureLevel);
            return 2;
         }
      }
   }

   // New explicit setups: return to a pre-existing FVG or order-block zone
   // with tick impulse IN THE SAME direction. No signal in empty space.
   if(zoneId>=4 && zoneId<=5 && zoneDistance<=zoneTolerance &&
      shortM.movePoints*direction>0.0 &&
      AllowZoneDirectEntries && (zoneId==4 ? EnableFVGSetup : EnableOrderBlockSetup))
   {
      structureLevel = direction>0 ? zoneUpper : zoneLower;
      description = StringFormat("%s: preco reagindo na zona %.2f..%.2f",
                                SetupName(zoneId),zoneLower,zoneUpper);
      return zoneId;
   }

   // Price action momentum: previous candle body + M1 trend + new breakout.
   if(EnablePAMomentum)
   {
      double prevO=iOpen(_Symbol,PERIOD_M1,1);
      double prevC=iClose(_Symbol,PERIOD_M1,1);
      double priorHigh=iHigh(_Symbol,PERIOD_M1,1);
      double priorLow=iLow(_Symbol,PERIOD_M1,1);
      double bodyPts=MathAbs(prevC-prevO)/_Point;
      bool strongBody=bodyPts>=atrPts*MinPrevBodyATR;
      bool buyPA=direction>0 && trendM1>0 && strongBody && prevC>prevO &&
         bid>priorHigh+MOMBreakPoints*_Point && shortM.movePoints>0.0;
      bool sellPA=direction<0 && trendM1<0 && strongBody && prevC<prevO &&
         bid<priorLow-MOMBreakPoints*_Point && shortM.movePoints<0.0;
      if(buyPA || sellPA)
      {
         structureLevel=direction>0?priorHigh:priorLow;
         description=StringFormat("PA rompimento %s apos candle forte %.2f",
                         direction>0?"ALTA":"BAIXA",structureLevel);
         return 3;
      }
   }

   return 0;
}

//+------------------------------------------------------------------+
// Objective 0-100 score, not a prediction of success probability.
int ScoreSignal(int direction, TickMetrics &shortM, TickMetrics &longM,
                double spreadPts, double atrPts, int m1Trend, int m5Trend,
                double candleMove)
{
   lastFactor.pressure=0;
   lastFactor.impulse=0;
   lastFactor.fast=0;
   lastFactor.candle=0;
   lastFactor.trend=0;
   lastFactor.costs=0;
   double alignedShort = shortM.movePoints * direction;
   double alignedLong = longM.movePoints * direction;
   double alignedBar = candleMove * direction;

   if(longM.directionPercent >= 80.0) lastFactor.pressure=25;
   else if(longM.directionPercent >= 70.0) lastFactor.pressure=20;
   else if(longM.directionPercent >= MinDirectionalPercent) lastFactor.pressure=14;
   else if(longM.directionPercent >= 51.0) lastFactor.pressure=7;

   if(alignedLong >= MathMax(MinImpulsePoints,spreadPts*1.5)) lastFactor.impulse=20;
   else if(alignedLong >= MathMax(MinImpulsePoints,spreadPts*0.8)) lastFactor.impulse=14;
   else if(alignedLong>0.0) lastFactor.impulse=7;

   if(alignedShort >= MathMax(1.0,MinImpulsePoints*1.5)) lastFactor.fast=15;
   else if(alignedShort >= MinImpulsePoints*0.5) lastFactor.fast=10;
   else if(alignedShort>0.0) lastFactor.fast=5;

   if(alignedBar >= MathMax(1.0,MinImpulsePoints)) lastFactor.candle=15;
   else if(alignedBar>=0.0) lastFactor.candle=7;

   if(EnableTrendScoring)
   {
      if(m1Trend==direction) lastFactor.trend+=9;
      if(m5Trend==direction) lastFactor.trend+=6;
   }
   else lastFactor.trend=8;

   if(spreadPts<=atrPts*0.07) lastFactor.costs=10;
   else if(spreadPts<=atrPts*0.12) lastFactor.costs=7;
   else if(spreadPts<=atrPts*MaxSpreadAsATR) lastFactor.costs=3;

   return MathMin(100,MathMax(0,lastFactor.pressure+lastFactor.impulse+
      lastFactor.fast+lastFactor.candle+lastFactor.trend+lastFactor.costs));
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool EntryMarketSafe(const MqlTick &tick, double atrPts, double volume)
{
   double spread = (tick.ask-tick.bid)/_Point;
   if(tick.ask <= 0.0 || tick.bid <= 0.0 || spread < 0.0)
   {
      lastReason = "Cotacao invalida";
      return false;
   }
   if(spread > AbsoluteMaxSpreadPts || spread > atrPts * MaxSpreadAsATR)
   {
      lastReason = "Spread acima do limite de custo";
      return false;
   }
   if(atrPts < MinimumATRPoints || atrPts < spread * MinimumATRToSpread)
   {
      lastReason = "ATR insuficiente em relacao ao spread";
      return false;
   }
   if(volume <= 0.0)
   {
      lastReason = "Lote 0.01 nao permitido para simbolo";
      return false;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      lastReason = "Negociacao automatica desabilitada";
      return false;
   }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
   {
      lastReason = "Negociacao desabilitada no simbolo";
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
// Janela recente de posicoes completas, sem usar trades abertos ou futuros.
void ComputeRecentEvidence()
{
   recentW=0; recentGains=0.0; recentLosses=0.0; recentNet=0.0; recentCount=0;
   for(int i=recordCount-1;i>=0 && recentCount<MinClosedTradesForBoost;i--)
   {
      if(!records[i].finished) continue;
      recentCount++;
      double net=records[i].net;
      recentNet+=net;
      if(net>0.0){recentW++;recentGains+=net;}
      else if(net<0.0) recentLosses+=-net;
   }
}

// O score NAO representa chance de lucro. Amplia lote so apos evidencia
// estatistica na sessao, acordo de tendencia e margem verificada.
// Isto e um EXPERIMENTO: mesmo um historico positivo pode falhar depois.
bool CanBoostEvidence(int direction, int score, double pressure,
                      double spreadPts, double atrPts, int m1, int m5)
{
   if(!EnableEvidenceScaling)
   { sizingExplanation="Lote adaptativo desligado nos parametros.";return false; }
   ComputeRecentEvidence();
   if(recentCount < MinClosedTradesForBoost)
   {
      sizingExplanation=StringFormat("Lote 0.01: %d/%d trades para validar aumento.",
                                     recentCount,MinClosedTradesForBoost);
      return false;
   }
   double pf=(recentLosses>0.0?recentGains/recentLosses:0.0);
   double wr=(recentCount>0?100.0*recentW/recentCount:0.0);
   double avg=(recentCount>0?recentNet/recentCount:0.0);
   if(recentLosses<=0.0 || pf<MinimumProfitFactorBoost ||
      wr<MinimumWinRateBoost || avg<MinAverageNetBoost ||
      currentLossStreak>0)
   {
      sizingExplanation=StringFormat("Sem boost: %d trades PF %.2f acerto %.1f%% media %+.3f",
                                    recentCount,pf,wr,avg);
      return false;
   }
   // Nao confundir score com probabilidade: validacao por faixa de score.
   int recentHighN=0;
   double recentHighNet=0.0;
   int seen=0;
   for(int i=recordCount-1;i>=0 && seen<MinClosedTradesForBoost;i--)
   {
      if(!records[i].finished) continue;
      seen++;
      if(records[i].score>=75)
      {
         recentHighN++;
         recentHighNet+=records[i].net;
      }
   }
   if(recentHighN<15 || recentHighNet<=0.0)
   {
      sizingExplanation="Sem boost: sinais score 75+ ainda nao deram lucro recente.";
      return false;
   }
   if(score<MinimumScoreForBoost || pressure<80.0 ||
      m1!=direction || m5!=direction || atrPts<=0.0 ||
      spreadPts>atrPts*0.07)
   {
      sizingExplanation="Sem boost: este sinal nao passou os filtros extras.";
      return false;
   }
   return true;
}

// Avalia margem TOTAL e risco estimado por tamanho antes de enviar ordem.
// O OrderCalcProfit e preferido a conversao fixa do contrato de ouro.
bool CheckExposure(ENUM_ORDER_TYPE side, double volume, double price,
                   double riskBudget, bool boosted, string &why)
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq<=0.0) { why="Equity invalida"; return false; }
   double margin=0.0;
   if(!OrderCalcMargin(side,_Symbol,volume,price,margin))
   { why="Falha no calculo de margem"; return false; }
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)-margin<MinFreeMarginMoney)
   { why="Margem livre insuficiente"; return false; }
   double marginShare=(AccountInfoDouble(ACCOUNT_MARGIN)+margin)/eq*100.0;
   if(marginShare>MaxBaseMarginPercentEquity)
   { why="Margem total elevada para esta banca";return false; }
   if(boosted && marginShare>MaxMarginPercentEquity)
   { why="Boost negado: margem ultrapassaria teto";return false; }
   if(riskBudget > eq*MaxRiskPercentEquity/100.0)
   { why="Risco por operacao ultrapassa % da equity"; return false; }
   return true;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool SendEntry(int direction, const MqlTick &tick, int score, double spreadPts,
               double atrPts, TickMetrics &shortM, TickMetrics &longM,
               int trendM1, int trendM5, bool addon=false)
{
   if(!NewEntriesAllowedBySupervisor())
   {
      lastReason=supervisorMessage;
      ++riskRejected;
      return false;
   }
   double volume = ValidVolume(FixedLot);
   bool boosted=false;
   double price = direction > 0 ? tick.ask : tick.bid;
   ENUM_ORDER_TYPE side = direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double chosenRisk=RiskStopMoney;
   if(!addon && CanBoostEvidence(direction,score,longM.directionPercent,
                               spreadPts,atrPts,trendM1,trendM5))
   {
      double candidate = ValidVolume(MathMin(MaxAdaptiveLot, FixedLot*2.0));
      if(candidate > volume)
      {
         string reason="";
         double riskForCandidate= MathMin(MaxAdaptiveStopRiskMoney,
                                        RiskStopMoney*candidate/FixedLot);
         if(CheckExposure(side,candidate,price,riskForCandidate,true,reason))
         {
            volume=candidate;
            chosenRisk=riskForCandidate;
            boosted=true;
            sizingExplanation="Boost liberado: evidencias + margem + score.";
         }
         else
         {
            sizingExplanation=reason;
            boostRefusals++;
         }
      }
   }
   if(addon)
   {
      chosenRisk=RiskStopMoney;
      sizingExplanation="Adicao experimental: base protegida e sinal forte.";
   }
   if(volume <= 0.0) { lastReason = "Lote invalido"; return false; }

   string exposureReason="";
   if(!CheckExposure(side,volume,price,chosenRisk,boosted||addon,exposureReason))
   {
      lastReason=exposureReason;
      lastRiskDecision="EXPOSICAO: "+exposureReason;
      return false;
   }

   double moneyPt = MoneyPerPoint(side, volume, price);
   if(moneyPt <= 0.0) { lastReason = "Contrato sem valor de ponto valido"; return false; }

   // Broker SL is validated against Bid for buy and Ask for sell.
   // On a sweep, prefer the invalidation level instead of an arbitrary cash stop.
   // If structural risk exceeds the budget, SKIP the trade instead of silently
   // tightening the stop into normal price noise.
   double brokerStopPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double currentSpreadPts = (tick.ask - tick.bid) / _Point;
   double minBrokerPts = brokerStopPts + currentSpreadPts + 3.0;
   double stopPts = MathMax(minBrokerPts, 0.92*chosenRisk / moneyPt);
   if(UseSweepStructureStop && lastSetup==1 && atrPts>0.0)
   {
      double extreme=direction>0?sweepExtremeBuy:sweepExtremeSell;
      if(!RequireObservedSweepEvent || extreme<=0.0)
         extreme=direction>0?iLow(_Symbol,PERIOD_M1,0):iHigh(_Symbol,PERIOD_M1,0);
      if(extreme<=0.0)
      {
         lastReason="Sweep: extremo de candle indisponivel para SL";
         return false;
      }
      double structuralSL=extreme-direction*MathMax(2.0,SweepStopBufferATR*atrPts)*_Point;
      double structuralPts=direction*(price-structuralSL)/_Point;
      if(structuralPts<=0.0)
      {
         lastReason="Sweep: nivel de invalidacao do stop incorreto";
         return false;
      }
      stopPts=MathMax(minBrokerPts,MathMax(structuralPts,SweepMinimumStopATR*atrPts));
   }
   if(UseBOSStructureStop && lastSetup==2 && atrPts>0.0 && lastSetupLevel>0.0)
   {
      double previousLow=iLow(_Symbol,PERIOD_M1,1);
      double previousHigh=iHigh(_Symbol,PERIOD_M1,1);
      double invalidation=direction>0 ? MathMin(lastSetupLevel,previousLow) :
                                         MathMax(lastSetupLevel,previousHigh);
      double structuralSL=invalidation-direction*MathMax(2.0,0.06*atrPts)*_Point;
      double structuralPts=direction*(price-structuralSL)/_Point;
      if(structuralPts<=0.0)
      {
         lastReason="BOS: estrutura invalida para posicionar stop";
         return false;
      }
      stopPts=MathMax(minBrokerPts,structuralPts);
   }
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0.0) tickSz = _Point;
   double stop = direction > 0 ? price - stopPts * _Point : price + stopPts * _Point;
   if(direction > 0) stop = MathFloor(stop / tickSz) * tickSz;
   else stop = MathCeil(stop / tickSz) * tickSz;
   stop = NormalizeDouble(stop, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   // Account-currency risk from the actual symbol's profit calculation.
   double simulatedPnl=0.0;
   if(!OrderCalcProfit(side,_Symbol,volume,price,stop,simulatedPnl))
   {
      lastReason="Nao foi possivel calcular o risco do stop";
      return false;
   }
   double expectedLoss=MathMax(0.0,-simulatedPnl)+RoundTurnCommissionPerLot*volume;
   lastCalculatedStopRisk=expectedLoss;
   lastCalculatedStopPoints=MathAbs(price-stop)/_Point;
   lastRiskDecision=StringFormat("SL %.0fpts custo %.2f | teto %.2f",
                                  lastCalculatedStopPoints,expectedLoss,chosenRisk);
   if(lastSetup==1 && SweepRequireRoomForStop &&
      UseHigherTimeframes && lastOpposingRoomPts>0.0 && lastOpposingRoomPts<1.0e8)
   {
      double neededRoom=stopPts*SweepMinRoomRiskRatio;
      if(lastOpposingRoomPts<neededRoom)
      {
         lastReason=StringFormat("Sweep: espaco %.0f pts menor que risco %.0f pts.",
                          lastOpposingRoomPts,neededRoom);
         sweepRoomRejectCount++;
         lastRiskDecision=lastReason;
         LogEvent("SWEEP_REJECT_ROOM",lastReason,lastOpposingRoomPts);
         return false;
      }
   }
   double equityRiskCap=AccountInfoDouble(ACCOUNT_EQUITY)*MaxRiskPercentEquity/100.0;
   // O orcamento monetario e um TETO para a estimativa, nao uma sugestao.
   // Nunca encurte SL estrutural so para fazer 0.01 lote caber no orcamento.
   if(expectedLoss > chosenRisk+0.000001 || expectedLoss > equityRiskCap+0.000001)
   {
      lastReason=StringFormat("SL exige %.2f; teto %.2f (equity %.2f). RECUSADO.",
                              expectedLoss,chosenRisk,equityRiskCap);
      lastRiskDecision=lastReason;
      sweepBudgetRejectCount++;
      LogEvent("SWEEP_REJECT_RISK",lastReason,expectedLoss);
      return false;
   }

   string precheckReason="";
   if(!PreflightOrder(side,volume,price,stop,precheckReason))
   {
      ++precheckRejected;
      ++riskRejected;
      lastReason="Supervisor: "+precheckReason;
      LogEvent("ORDER_CHECK_REJECT",lastReason,0.0);
      return false;
   }

   double takeProfit=0.0;
   if(UseRiskRewardTakeProfit && RiskRewardMultiple>=1.0)
   {
      double goal=price+direction*RiskRewardMultiple*MathAbs(price-stop);
      if(direction>0) goal=MathCeil(goal/tickSz)*tickSz;
      else goal=MathFloor(goal/tickSz)*tickSz;
      takeProfit=NormalizeDouble(goal,_Digits);
   }
   ++attempts;
   bool sent = direction > 0
      ? trade.Buy(volume, _Symbol, 0.0, stop, takeProfit, "ALIEN V11.2 FREEDOM BUY")
      : trade.Sell(volume, _Symbol, 0.0, stop, takeProfit, "ALIEN V11.2 FREEDOM SELL");
   uint rc = trade.ResultRetcode();

   if(sent && IsAcceptedRetcode(rc) && trade.ResultDeal() != 0)
   {
      enteredThisBar = true;
      ++entriesThisBar;
      lastEntryTimeMsc = tick.time_msc;
      lastEntrySetupId=lastSetup;
      lastEntryDir=direction;
      lastEntryZoneLevel=lastSetupLevel;
      lastEntryPrice=price;
      ++entriesSession;
      lastEntryLot=volume;
      if(boosted) ++boostedEntries;
      if(addon) ++additionalEntries;
      if(lastSetup==1) sweepExecutedCount++;
      lastRiskDecision=StringFormat("Autorizado: SL %.0f pts, risco estimado %.2f / teto %.2f",
                                     lastCalculatedStopPoints,lastCalculatedStopRisk,chosenRisk);
      lastSignalDirection = direction;
      lastEntryFactor = lastFactor;
      lastSignalSpread = spreadPts;
      lastSignalATR = atrPts;
      lastSignalShort = shortM.movePoints;
      lastSignalLong = longM.movePoints;
      lastSignalPressure = longM.directionPercent;
      lastSignalM1 = trendM1;
      lastSignalM5 = trendM5;
      StoreEntryContext(trade.ResultDeal(),direction,score,spreadPts,atrPts,
                        shortM.movePoints,longM.movePoints,longM.directionPercent,
                        trendM1,trendM5);
      lastReason = (direction > 0 ? "BUY " : "SELL ") + SetupName(lastSetup) + " executada";
      LogEvent("ENTRY", StringFormat("%s score=%d spread=%.1f order=%I64u vol=%.2f boosted=%s addon=%s setup=" + SetupName(lastSetup),
                direction > 0 ? "BUY" : "SELL", score, spreadPts,
                trade.ResultOrder(),volume,boosted?"SIM":"NAO",addon?"SIM":"NAO"), price);
      Print("ALIEN V11.2 FREEDOM: ", lastReason, " score=", score,
            " spread=", DoubleToString(spreadPts,1),
            " ATR=", DoubleToString(atrPts,1),
            " stopPts=", DoubleToString(MathAbs(price-stop)/_Point,1),
            " riscoEstimado=", DoubleToString(expectedLoss,2),
            " SL=", DoubleToString(stop,_Digits));
      return true;
   }
   ++rejectedEntries;
   lastReason = "Ordem recusada: " + trade.ResultRetcodeDescription();
   Print("ALIEN V11.2 FREEDOM: ", lastReason, " rc=", rc);
   LogEvent("REJECT", lastReason, (double)rc);
   return false;
}

//+------------------------------------------------------------------+
// Track SL modification frequency and best favorable tick independently
// for every position. No two tickets share a single cooldown.
int RunnerSlot(const ulong ticket)
{
   int empty=-1;
   for(int i=0; i<ALIEN_RUNNER_TRACKS; i++)
   {
      if(runnerTickets[i]==ticket) return i;
      if(empty<0 && runnerTickets[i]==0) empty=i;
   }
   // When all slots were used, reuse a ticket no longer in the account.
   if(empty<0)
   {
      for(int i=0; i<ALIEN_RUNNER_TRACKS; i++)
      {
         if(!PositionSelectByTicket(runnerTickets[i]))
         { empty=i; break; }
      }
   }
   if(empty<0) return -1; // conservative: do not force slot collisions
   runnerTickets[empty]=ticket;
   runnerModifyMs[empty]=0;
   runnerPeakPoints[empty]=0.0;
   return empty;
}

//+------------------------------------------------------------------+
// Exit strategy: actual floating P/L already includes bid-ask spread.
// Subtract only expected round-turn commissions (not spread twice).
void ManageOpenPosition(const MqlTick &tick, TickMetrics &shortM,
                        double atrPts)
{
   long nowMsc = tick.time_msc;
   double brokerMinDist = MathMax(
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) + 2.0;

   for(int i = PositionsTotal()-1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != ExpertMagic) continue;

      bool buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      int direction = buy ? 1 : -1;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double quote = buy ? tick.bid : tick.ask;
      double gainPts = direction * (quote - entry) / _Point;
      int runnerSlot=RunnerSlot(ticket);
      if(runnerSlot>=0)
         runnerPeakPoints[runnerSlot]=MathMax(runnerPeakPoints[runnerSlot],gainPts);
      double net = PositionGetDouble(POSITION_PROFIT) +
                   PositionGetDouble(POSITION_SWAP) -
                   RoundTurnCommissionPerLot * vol;

      // Safety exception: a broker-side SL must exist at all times. If a
      // pre-existing position lost its SL, attempt to restore a protective one.
      // If the broker refuses, close it rather than leave unlimited exposure.
      if(BlockOnMissingSL && sl <= 0.0)
      {
         ENUM_ORDER_TYPE side = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         double moneyPtStop = MoneyPerPoint(side,vol,entry);
         double tickSzStop = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         if(tickSzStop<=0.0) tickSzStop=_Point;
         double pointsRisk = (moneyPtStop>0.0 ? RiskStopMoney*vol/FixedLot/moneyPtStop : 0.0);
         double stopPoints = MathMax(brokerMinDist+5.0,pointsRisk);
         double emergencySL = quote - direction*stopPoints*_Point;
         emergencySL = buy ? MathFloor(emergencySL/tickSzStop)*tickSzStop
                           : MathCeil(emergencySL/tickSzStop)*tickSzStop;
         emergencySL = NormalizeDouble(emergencySL,_Digits);
         double restoredPnl=0.0;
         bool restoredEstimateOK = (moneyPtStop>0.0 &&
            OrderCalcProfit(side,_Symbol,vol,entry,emergencySL,restoredPnl));
         double maximumRestoreRisk=MathMin(RiskStopMoney*vol/FixedLot*1.15,
            AccountInfoDouble(ACCOUNT_EQUITY)*MaxRiskPercentEquity/100.0);
         double restoreRisk= -restoredPnl+RoundTurnCommissionPerLot*vol;
         bool riskValid=restoredEstimateOK && restoreRisk<=maximumRestoreRisk;
         if(!riskValid ||
            !trade.PositionModify(ticket,emergencySL,tp) ||
            !IsAcceptedRetcode(trade.ResultRetcode()))
         {
            Print("ALIEN V11.2 FREEDOM: SEM SL confirmado. Fechando em emergencia: ",ticket);
            RememberExitReason(ticket,"SEM_SL_EMERGENCIA");
            if(!trade.PositionClose(ticket) || !IsAcceptedRetcode(trade.ResultRetcode()))
               Print("ALIEN V11.2 FREEDOM CRITICO: falha ao proteger/fechar posicao ",ticket,
                     " retcode=",trade.ResultRetcodeDescription());
         }
         continue;
      }

      if(!StopOnlyRunnerMode && MaxFloatingLossMoney > 0.0 && net <= -MaxFloatingLossMoney)
      {
         RememberExitReason(ticket,"GUARDA_PREJUIZO");
         if(trade.PositionClose(ticket) && IsAcceptedRetcode(trade.ResultRetcode()))
            LogEvent("EXIT_LOSS_GUARD", "Market loss protection", net);
         else Print("ALIEN V11.2 FREEDOM: close loss guard failed: ", trade.ResultRetcodeDescription());
         continue;
      }

      double opposingImpulse = -direction * shortM.movePoints;
      bool sharpReversal = shortM.changes >= 2 &&
         opposingImpulse >= ReversalImpulsePoints;
      if(!StopOnlyRunnerMode && UseProfitHarvest && net >= MinNetProfitToHarvest && sharpReversal)
      {
         RememberExitReason(ticket,"REVERSAO_LUCRO");
         if(trade.PositionClose(ticket) && IsAcceptedRetcode(trade.ResultRetcode()))
            LogEvent("EXIT_REVERSAL_PROFIT", "Reversal with positive estimated net", net);
         else Print("ALIEN V11.2 FREEDOM: close reversal failed: ", trade.ResultRetcodeDescription());
         continue;
      }

      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(!StopOnlyRunnerMode && ExitOnTimeout && MaxHoldSeconds > 0 && TimeCurrent()-opened >= MaxHoldSeconds)
      {
         RememberExitReason(ticket,"TEMPO_LIMITE");
         if(trade.PositionClose(ticket) && IsAcceptedRetcode(trade.ResultRetcode()))
            LogEvent("EXIT_TIMEOUT", "Timed exit (can be negative)", net);
         else Print("ALIEN V11.2 FREEDOM: close timeout failed: ", trade.ResultRetcodeDescription());
         continue;
      }

      // Do not move the stop on the first micro-pullback after a fast entry.
      // The server-side initial SL remains active throughout this period.
      if(RunnerMinimumHoldSeconds>0 &&
         TimeCurrent()-opened < RunnerMinimumHoldSeconds) continue;
      if(runnerSlot>=0 && nowMsc-runnerModifyMs[runnerSlot]<ModifyCooldownMs) continue;
      ENUM_ORDER_TYPE orderType = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double moneyPt = MoneyPerPoint(orderType, vol, entry);
      if(moneyPt <= 0.0) continue;
      double commissionPts = RoundTurnCommissionPerLot * vol / moneyPt;
      double candidate = sl;
      double trigger = MathMax(BreakEvenAfterPoints,
                               commissionPts + brokerMinDist + RunnerLockBufferPts);
      double trailingStart = TrailStartPoints;
      double trailingDistanceATR = TrailATRMultiplier;

      
      // V11.2 Freedom: Fast BreakEven em 1.2R
      if(EnableFastBreakEven && sl > 0.0 && tp > 0.0)
      {
         double riskPts = MathAbs(entry - sl) / _Point;
         double gainPts = direction * (quote - entry) / _Point;
         if(riskPts > 1.0 && gainPts >= riskPts * FastBERatio)
         {
            double bePrice = entry + direction * (commissionPts + RunnerLockBufferPts) * _Point;
            if(direction > 0 && (candidate == 0.0 || candidate < bePrice)) candidate = bePrice;
            else if(direction < 0 && (candidate == 0.0 || candidate > bePrice)) candidate = bePrice;
         }
      }

      if(UseAdaptiveRunner && atrPts>0.0)
      {
         // The EMA context comes from CLOSED M1/M5 candles.
         // A brief tick correction does not by itself end a trend.
         bool strongTrend = cachedMarketReady &&
                            cachedTrendM1==direction && cachedTrendM5==direction;
         bool confirmedReversal = shortM.changes>=3 &&
                            (-direction*shortM.movePoints) >=
                            MathMax(ReversalImpulsePoints, atrPts*AdaptiveReversalMinATR);
         trigger=MathMax(trigger,atrPts*AdaptiveBEStartATR);
         trailingStart=MathMax(trailingStart,atrPts*AdaptiveTrailStartATR);
         trailingDistanceATR=strongTrend ? AdaptiveTrendTrailATR : AdaptiveNormalTrailATR;
         if(confirmedReversal && gainPts>0.0)
            trailingDistanceATR=AdaptiveReversalTrailATR;
      }
      // Cost-aware break-even; never push broker SL away from profit.
      if(gainPts >= trigger)
      {
         double be = entry + direction * (commissionPts + RunnerLockBufferPts) * _Point;
         if(candidate == 0.0 || direction * (be-candidate) > 0.0) candidate = be;
      }
      if(gainPts >= trailingStart)
      {
         double distPts = MathMax(brokerMinDist + 1.0,
                                  MathMax(RunnerMinTrailPoints, atrPts * trailingDistanceATR));
         double trail = quote - direction * distPts * _Point;
         if(candidate == 0.0 || direction*(trail-candidate) > 0.0) candidate = trail;
      }
      if(candidate <= 0.0 ||
         (sl > 0.0 && direction*(candidate-sl) < MinTrailStepPoints * _Point)) continue;

      double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(ts <= 0.0) ts = _Point;
      if(buy) candidate = MathFloor(candidate / ts) * ts;
      else candidate = MathCeil(candidate / ts) * ts;
      candidate = NormalizeDouble(candidate, _Digits);
      if(sl > 0.0 && direction * (candidate-sl) < MinTrailStepPoints * _Point) continue;
      if(direction * (quote-candidate) <= brokerMinDist * _Point) continue;

      if(trade.PositionModify(ticket, candidate, tp) &&
         IsAcceptedRetcode(trade.ResultRetcode()))
      {
         if(runnerSlot>=0) runnerModifyMs[runnerSlot]=nowMsc;
      }
      else if(PrintDetailedReasons)
         Print("ALIEN V11.2 FREEDOM: stop modify failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// V10.70: Relogio deterministico para sessoes. NAO usar TimeGMT() no tester:
// ele representa o horario simulado do servidor, nao o UTC historico.
// Estimar o fuso exige especificar a regra DST do broker nos parametros.
//+------------------------------------------------------------------+
int AlienSundayOfMonth(int year,int mon,int nth)
{
   MqlDateTime d={};
   d.year=year; d.mon=mon; d.day=1;
   datetime t=StructToTime(d);
   MqlDateTime first={};
   TimeToStruct(t,first);
   int firstSun=1+(7-first.day_of_week)%7;
   if(nth>0) return firstSun+(nth-1)*7;
   int nextMonth=mon+1,nextYear=year;
   if(nextMonth==13) {nextMonth=1;nextYear++;}
   MqlDateTime nxt={};
   nxt.year=nextYear;nxt.mon=nextMonth;nxt.day=1;
   datetime end=StructToTime(nxt)-86400;
   MqlDateTime last={};
   TimeToStruct(end,last);
   return last.day-(last.day_of_week%7);
}

datetime AlienUTCDate(int year,int mon,int day,int hour=0,int minute=0)
{
   MqlDateTime d={};
   d.year=year;d.mon=mon;d.day=day;d.hour=hour;d.min=minute;
   return StructToTime(d);
}

bool AlienUsSummer(datetime utc)
{
   MqlDateTime d={};TimeToStruct(utc,d);
   datetime a=AlienUTCDate(d.year,3,AlienSundayOfMonth(d.year,3,2),7,0);
   datetime b=AlienUTCDate(d.year,11,AlienSundayOfMonth(d.year,11,1),6,0);
   return utc>=a && utc<b;
}

bool AlienEuSummer(datetime utc)
{
   MqlDateTime d={};TimeToStruct(utc,d);
   datetime a=AlienUTCDate(d.year,3,AlienSundayOfMonth(d.year,3,-1),1,0);
   datetime b=AlienUTCDate(d.year,10,AlienSundayOfMonth(d.year,10,-1),1,0);
   return utc>=a && utc<b;
}

int AlienBrokerOffsetSeconds(datetime server)
{
   int winter=BrokerWinterUTCOffsetMinutes*60;
   if(BrokerDSTSchedule==ALIEN_DST_FIXED) return winter;
   // Itera duas vezes para manter coerencia proximo da troca de horario.
   int guess=winter;
   for(int i=0;i<2;i++)
   {
      datetime utc=server-guess;
      bool summer=BrokerDSTSchedule==ALIEN_DST_USA ? AlienUsSummer(utc) : AlienEuSummer(utc);
      guess=winter+(summer?3600:0);
   }
   return guess;
}

datetime AlienServerUTC(datetime server)
{
   return server-AlienBrokerOffsetSeconds(server);
}

datetime AlienNYLocal(datetime utc)
{
   return utc+(AlienUsSummer(utc)?-4:-5)*3600;
}

datetime AlienLondonLocal(datetime utc)
{
   return utc+(AlienEuSummer(utc)?1:0)*3600;
}

int AlienMinuteOfDay(datetime civil)
{
   MqlDateTime d={};TimeToStruct(civil,d);
   return d.hour*60+d.min;
}

int AlienIdentifySession(datetime utc)
{
   int utcMin=AlienMinuteOfDay(utc);
   int nyMin=AlienMinuteOfDay(AlienNYLocal(utc));
   int lnMin=AlienMinuteOfDay(AlienLondonLocal(utc));
   if(nyMin>=8*60 && nyMin<11*60+30) return 2;
   if(lnMin>=8*60 && lnMin<11*60) return 1;
   if(utcMin>=0 && utcMin<6*60) return 0;
   return 3;
}

string AlienSessionTitle(int id)
{
   if(id==0) return "ASIA";
   if(id==1) return "LONDRES";
   if(id==2) return "NOVA YORK";
   return "FORA DA JANELA";
}

bool AlienInNYBlackout(datetime server)
{
   if(!UseNY0830Blackout && !UseNY1000Blackout) return false;
   datetime utc=AlienServerUTC(server);
   int m=AlienMinuteOfDay(AlienNYLocal(utc));
   return (UseNY0830Blackout && m>=8*60+29 && m<=8*60+33) ||
          (UseNY1000Blackout && m>=9*60+59 && m<=10*60+3);
}

bool AlienSessionEntryAllowed(datetime server)
{
   if(!UseSessionEngine) return true;
   datetime utc=AlienServerUTC(server);
   if(AlienInNYBlackout(server)) return false;
   if(RestrictNewTradesToWindows && AlienIdentifySession(utc)==3) return false;
   return true;
}

void AlienRefreshSessionAMD(bool force=false)
{
   if(!UseSessionEngine && !UseAMDContext) return;
   datetime m1=iTime(_Symbol,PERIOD_M1,0);
   datetime now=TimeCurrent();
   if(m1<=0) return;
   if(!force && m1==lastSessionProcessedBar) return;
   lastSessionProcessedBar=m1;
   datetime utc=AlienServerUTC(now);
   sessionCode=UseSessionEngine?AlienIdentifySession(utc):3;
   sessionName=UseSessionEngine?AlienSessionTitle(sessionCode):"SESSOES OFF";
   datetime ny=AlienNYLocal(utc), ln=AlienLondonLocal(utc);
   MqlDateTime nys={};TimeToStruct(ny,nys);
   MqlDateTime lns={};TimeToStruct(ln,lns);
   MqlDateTime uts={};TimeToStruct(utc,uts);
   lastClockInfo=StringFormat("NY %02d:%02d | LON %02d:%02d | UTC %02d:%02d | broker UTC%+.1f",
             nys.hour,nys.min,lns.hour,lns.min,uts.hour,uts.min,
             (double)AlienBrokerOffsetSeconds(now)/3600.0);
   sessionExplanation=sessionName+" | "+lastClockInfo;

   // Asia de HOJE em UTC, candles M5 fechados; faixa parc. enquanto sessao aberta.
   asiaHigh=0.0;asiaLow=0.0;
   datetime utcMidnight=(datetime)(((long)utc/86400)*86400);
   asiaStartServer=utcMidnight+AlienBrokerOffsetSeconds(now);
   asiaEndServer=asiaStartServer+6*3600;
   if(UseSessionEngine)
   {
      MqlRates asiaRates[];
      int got=CopyRates(_Symbol,PERIOD_M5,1,330,asiaRates);
      double hi=-1e100,lo=1e100;
      for(int i=0;i<got;i++)
      {
         datetime barUTC=AlienServerUTC(asiaRates[i].time);
         if(barUTC>=utcMidnight && barUTC<utcMidnight+6*3600)
         {
            if(asiaRates[i].high>hi) hi=asiaRates[i].high;
            if(asiaRates[i].low<lo) lo=asiaRates[i].low;
         }
      }
      if(hi>lo && lo>0.0) {asiaHigh=hi;asiaLow=lo;}
   }

   amdRangeHigh=0.0;amdRangeLow=0.0;
   amdPhaseCode=0;amdBias=0;
   amdPhaseName="SEM FASE DEFINIDA";
   amdExplanation="Aguardando faixa e estrutura confirmadas";
   if(!UseAMDContext || Bars(_Symbol,PERIOD_M5)<AMDRangeBarsM5+4 ||
      Bars(_Symbol,PERIOD_M1)<5) return;
   double hi=-1e100,lo=1e100;
   // Exclui M5 atual e M5 anterior, evitando misturar a vela usada para o sweep.
   for(int k=2;k<AMDRangeBarsM5+2;k++)
   {
      hi=MathMax(hi,iHigh(_Symbol,PERIOD_M5,k));
      lo=MathMin(lo,iLow(_Symbol,PERIOD_M5,k));
   }
   if(hi<=lo || lo<=0.0) return;
   amdRangeHigh=hi;amdRangeLow=lo;
   double atr5=ATRFromHandle(hAtrM5)/_Point;
   double atr1=cachedATRPoints;
   if(atr1<=0.0) atr1=ATRFromHandle(hAtrM1)/_Point;
   if(atr5<=0.0 || atr1<=0.0) return;
   double widthPts=(hi-lo)/_Point;
   bool compressed=widthPts<=atr5*AMDMaxRangeATR;
   double o=iOpen(_Symbol,PERIOD_M1,1);
   double c=iClose(_Symbol,PERIOD_M1,1);
   double h=iHigh(_Symbol,PERIOD_M1,1);
   double l=iLow(_Symbol,PERIOD_M1,1);
   datetime closedBar=iTime(_Symbol,PERIOD_M1,1);
   if(compressed)
   {
      amdPhaseCode=1;
      amdPhaseName="ACUMULACAO / FAIXA";
      amdExplanation=StringFormat("M5 comprimido: largura %.0f pts (%.2f ATR5)",widthPts,widthPts/atr5);
   }
   // Uma varredura so e uma hipotese de preco: nao prova manipulacao.
   int sweep=0;
   if(compressed && l<=lo-AMDSweepMinPoints*_Point && c>=lo+AMDReclaimPoints*_Point)
      sweep=1;
   else if(compressed && h>=hi+AMDSweepMinPoints*_Point && c<=hi-AMDReclaimPoints*_Point)
      sweep=-1;
   if(sweep!=0)
   {
      lastAMDSweepDirection=sweep;
      lastAMDLastSweepTime=closedBar;
   }
   bool recentSweep=lastAMDLastSweepTime>0 &&
                    now-lastAMDLastSweepTime<=AMDKeepSweepMinutes*60;
   bool bullExpansion=c>hi+AMDBreakBufferPoints*_Point &&
                      c>o && (c-o)/_Point>=atr1*AMDExpansionMinATR;
   bool bearExpansion=c<lo-AMDBreakBufferPoints*_Point &&
                      c<o && (o-c)/_Point>=atr1*AMDExpansionMinATR;
   if(bullExpansion || bearExpansion)
   {
      amdBias=bullExpansion?1:-1;
      amdPhaseCode=3;
      amdPhaseName=amdBias>0?"DISTRIBUICAO / EXPANSAO ALTA":"DISTRIBUICAO / EXPANSAO BAIXA";
      amdExplanation=StringFormat("Fechamento M1 alem da faixa, corpo %.0f pts | sweep recente %s",
                       MathAbs(c-o)/_Point,recentSweep?"SIM":"NAO");
   }
   else if(recentSweep)
   {
      amdBias=lastAMDSweepDirection;
      amdPhaseCode=2;
      amdPhaseName=amdBias>0?"SWEEP ABAIXO (POSSIVEL COMPRA)":
                               "SWEEP ACIMA (POSSIVEL VENDA)";
      amdExplanation="Rompimento e recuperacao da faixa; aguardando deslocamento";
   }
}

// Objetos do grafico sao separados do motor de sinais. Zonas continuam hipotese.
void AlienSessionLine(string suffix,double price,color c,string name)
{
   if(price<=0.0) return;
   datetime to=TimeCurrent()+SessionMapForwardMinutes*60;
   datetime from=TimeCurrent()-10*60;
   string k=sessionPrefix+suffix;
   if(!ObjectCreate(0,k,OBJ_TREND,0,from,price,to,price)) return;
   ObjectSetInteger(0,k,OBJPROP_COLOR,c);
   ObjectSetInteger(0,k,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,k,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,k,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,k,OBJPROP_BACK,true);
   ObjectSetInteger(0,k,OBJPROP_SELECTABLE,false);
   string label=k+"_TITLE";
   if(ObjectCreate(0,label,OBJ_TEXT,0,TimeCurrent()+30,price))
   {
      ObjectSetString(0,label,OBJPROP_TEXT,name);
      ObjectSetInteger(0,label,OBJPROP_COLOR,c);
      ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
   }
}

// Marcacoes DIDATICAS: faixa e possivel manipulacao sao hipoteses visuais.
void AlienDrawAMDStudy(datetime until)
{
   if(!UseAMDContext || !DrawAMDStructure || amdRangeLow<=0.0 || amdRangeHigh<=amdRangeLow)
      return;
   datetime from=TimeCurrent()-AMDRangeBarsM5*5*60;
   string key=sessionPrefix+"CONSOLIDACAO_M5";
   if(ObjectCreate(0,key,OBJ_RECTANGLE,0,from,amdRangeHigh,until,amdRangeLow))
   {
      ObjectSetInteger(0,key,OBJPROP_COLOR,clrDimGray);
      ObjectSetInteger(0,key,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,key,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,key,OBJPROP_FILL,false);
      ObjectSetInteger(0,key,OBJPROP_BACK,true);
      ObjectSetInteger(0,key,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,key,OBJPROP_TOOLTIP,
         "Faixa M5: POSSIVEL consolidacao; rompimento nao garante distribuicao");
   }
   if(amdPhaseCode==2 && lastAMDLastSweepTime>0 &&
      TimeCurrent()-lastAMDLastSweepTime<AMDKeepSweepMinutes*60)
   {
      int idx=iBarShift(_Symbol,PERIOD_M1,lastAMDLastSweepTime,false);
      if(idx>=0)
      {
         double level=lastAMDSweepDirection>0?iLow(_Symbol,PERIOD_M1,idx):
                                                iHigh(_Symbol,PERIOD_M1,idx);
         AlienSessionLine("HIPOTESE_SWEEP",level,clrYellow,
                          lastAMDSweepDirection>0?"SWEEP ABAIXO? POSSIVEL MANIPULACAO":
                                                    "SWEEP ACIMA? POSSIVEL MANIPULACAO");
      }
   }
   if(amdPhaseCode==3)
      AlienSessionLine("EXPANSAO",amdBias>0?amdRangeHigh:amdRangeLow,
                       clrGold,amdBias>0?"EXPANSAO ALTA CONFIRMADA M1":
                                         "EXPANSAO BAIXA CONFIRMADA M1");
}

void AlienDrawSessionMap()
{
   if(sessionPrefix=="" || (!UseSessionEngine && !UseAMDContext)) return;
   ObjectsDeleteAll(0,sessionPrefix);
   if(MarkAsiaHighLow && UseSessionEngine && asiaHigh>asiaLow && asiaLow>0.0)
   {
      AlienSessionLine("ASIA_HI",asiaHigh,clrGold,"ASIA MAX | LIQUIDEZ");
      AlienSessionLine("ASIA_LO",asiaLow,clrKhaki,"ASIA MIN | LIQUIDEZ");
   }
   if(MarkSessionRange && DrawAMDStructure && UseAMDContext &&
      amdRangeHigh>amdRangeLow && amdRangeLow>0.0)
   {
      AlienSessionLine("AMD_UP",amdRangeHigh,clrWhite,"AMD FAIXA SUPERIOR");
      AlienSessionLine("AMD_DN",amdRangeLow,clrSilver,"AMD FAIXA INFERIOR");
      AlienDrawAMDStudy(TimeCurrent()+SessionMapForwardMinutes*60);
   }
}

void AlienApplyTheme()
{
   if(!AlienYellowBlackWhite) return;
   int props[8]={CHART_COLOR_BACKGROUND,CHART_COLOR_FOREGROUND,CHART_COLOR_GRID,
                CHART_COLOR_CHART_UP,CHART_COLOR_CHART_DOWN,
                CHART_COLOR_CANDLE_BULL,CHART_COLOR_CANDLE_BEAR,
                CHART_COLOR_VOLUME};
   for(int i=0;i<8;i++) oldChartColors[i]=ChartGetInteger(0,(ENUM_CHART_PROPERTY_INTEGER)props[i]);
   chartThemeCaptured=true;
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);
   ChartSetInteger(0,CHART_COLOR_GRID,clrDimGray);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,clrGold);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,clrWhite);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrYellow);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,clrBlack); // preto com contorno branco
   ChartSetInteger(0,CHART_COLOR_VOLUME,clrSilver);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartRedraw(0);
}

void AlienRestoreTheme()
{
   if(!RestoreChartThemeOnRemove || !chartThemeCaptured) return;
   int props[8]={CHART_COLOR_BACKGROUND,CHART_COLOR_FOREGROUND,CHART_COLOR_GRID,
                CHART_COLOR_CHART_UP,CHART_COLOR_CHART_DOWN,
                CHART_COLOR_CANDLE_BULL,CHART_COLOR_CANDLE_BEAR,
                CHART_COLOR_VOLUME};
   for(int i=0;i<8;i++)
      ChartSetInteger(0,(ENUM_CHART_PROPERTY_INTEGER)props[i],oldChartColors[i]);
   ChartRedraw(0);
}

string AlienClip(string t,int maxLen)
{
   if(StringLen(t)<=maxLen) return t;
   return StringSubstr(t,0,maxLen-3)+"...";
}

// CORRECAO VISUAL V10.89: usar SEMPRE coordenadas absoltas a partir
// do canto SUPERIOR ESQUERDO tanto no retangulo quanto nas linhas.
// Coordenadas de cantos inferiores com OBJ_LABEL sem ANCHOR coerente
// faziam o texto aparecer longe do fundo do painel.
void AlienPanelRow(int row,string content,color ink,int left,int top,int width)
{
   int maxChars=(int)MathMax(26,(width-24)/(TeacherPanelFontSize*0.82));
   string first=content,second="";
   if(StringLen(content)>maxChars)
   {
      int cut=maxChars;
      for(int n=maxChars;n>maxChars/2;n--)
         if(StringGetCharacter(content,n)==32) {cut=n;break;}
      first=StringSubstr(content,0,cut);
      second=StringSubstr(content,cut);
      StringTrimLeft(second);
      if(StringLen(second)>maxChars)
         second=StringSubstr(second,0,maxChars-3)+"...";
   }
   for(int line=0;line<2;line++)
   {
      string key=teacherPrefix+"R"+IntegerToString(row)+(line==0?"":"_B");
      if(ObjectFind(0,key)<0) ObjectCreate(0,key,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,key,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,key,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,key,OBJPROP_XDISTANCE,left+10);
      ObjectSetInteger(0,key,OBJPROP_YDISTANCE,top+7+row*29+line*13);
      ObjectSetInteger(0,key,OBJPROP_COLOR,ink);
      ObjectSetInteger(0,key,OBJPROP_FONTSIZE,TeacherPanelFontSize);
      ObjectSetString(0,key,OBJPROP_FONT,"Consolas");
      ObjectSetString(0,key,OBJPROP_TEXT,line==0?(first==""?" ":first):(second==""?" ":second));
      ObjectSetInteger(0,key,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,key,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,key,OBJPROP_ZORDER,2);
   }
}

// Pre-visualizacao MINIMA do stop do sweep em 0.01, nao o stop estrutural final.
// Utiliza OrderCalcProfit na moeda da conta; nao inclui slippage futuro.
double PreviewMinimumSweepStopRisk(const MqlTick &tk,double atrPts)
{
   if(tk.ask<=tk.bid || tk.bid<=0.0 || atrPts<=0.0) return -1.0;
   double volume=ValidVolume(FixedLot);
   if(volume<=0.0) return -1.0;
   double spread=(tk.ask-tk.bid)/_Point;
   double stopPts=MathMax(SweepMinimumStopATR*atrPts,
                          (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+spread+3.0);
   double pnlBuy=0.0, pnlSell=0.0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,volume,tk.ask,tk.ask-stopPts*_Point,pnlBuy)) return -1.0;
   if(!OrderCalcProfit(ORDER_TYPE_SELL,_Symbol,volume,tk.bid,tk.bid+stopPts*_Point,pnlSell)) return -1.0;
   return MathMax(MathMax(0.0,-pnlBuy),MathMax(0.0,-pnlSell))
          +RoundTurnCommissionPerLot*volume;
}

void AlienTeacherPanel(const MqlTick &tk,double atrPts,int trend1,int trend5)
{
   if(!ShowDashboard || !UseGraphicTeacherPanel) return;
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(cw<=80 || ch<=90) return;
   int width=(int)MathMin(TeacherPanelWidth,MathMax(220,cw-20));
   int rows=TeacherPanelCompactRows ? 9 : 12;
   int height=rows*29+12;
   if(ch<height+16) { rows=(int)MathMax(5,(ch-30)/29); height=rows*29+12; }
   int offsetX=(int)MathMax(4,TeacherPanelXOffset);
   int offsetY=(int)MathMax(4,TeacherPanelYOffset);
   bool onRight=(TeacherPanelCorner==1 || TeacherPanelCorner==3);
   bool onBottom=(TeacherPanelCorner==2 || TeacherPanelCorner==3);
   int left=onRight ? cw-width-offsetX : offsetX;
   int top=onBottom ? ch-height-offsetY : offsetY;
   left=(int)MathMax(2,MathMin(left,cw-width-2));
   top=(int)MathMax(2,MathMin(top,ch-height-2));
   string bg=teacherPrefix+"BG";
   if(ObjectFind(0,bg)<0) ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,left);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,top);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'15,20,30');
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,clrGold);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,bg,OBJPROP_ZORDER,0);

   bool dailyTargetHit = (StopOnDailyProfitTarget && DailyProfitTargetMoney > 0.0 && dailyRealizedNet >= DailyProfitTargetMoney);
   bool dailyLossHit   = (DailyMaxLossMoney > 0.0 && dailyRealizedNet <= -DailyMaxLossMoney);
   bool weeklyLossHit  = (weeklyGuardTripped || (WeeklyMaxLossMoney > 0.0 && weeklyRealizedNet <= -WeeklyMaxLossMoney));
   double curWeeklyLoss = (weeklyRealizedNet < 0.0 ? -weeklyRealizedNet : 0.0);

   string estadoRobo = "OPERANDO AO VIVO";
   if(dailyTargetHit)
      estadoRobo = "META DO DIA BATIDA! [MOTOR DESLIGADO]";
   else if(dailyLossHit)
      estadoRobo = "LIMITE DIARIO ATINGIDO [DESLIGADO ATE AMANHA]";
   else if(weeklyLossHit)
      estadoRobo = "DISJUNTOR SEMANAL ATIVO [PROTECAO TOTAL]";

   string panels[12];
   panels[0] = "=== ALIEN FREEDOM | MESA US$ 10.000 | OPERADOR VITOR ===";
   panels[1] = StringFormat("STATUS: %s | XAUUSD M1", estadoRobo);
   panels[2] = StringFormat("LUCRO HOJE: %+.2f USD | META DO DIA: $%.2f", dailyRealizedNet, DailyProfitTargetMoney);
   panels[3] = StringFormat("PERDA HOJE: $%.2f | LIMITE DIARIO: $%.2f", (dailyRealizedNet<0 ? -dailyRealizedNet : 0.0), DailyMaxLossMoney);
   panels[4] = StringFormat("DISJUNTOR SEMANAL: $%.2f / TETO: $%.2f", curWeeklyLoss, WeeklyMaxLossMoney);
   panels[5] = StringFormat("TRADES HOJE: %d / %d (Blindagem contra excesso de cliques)", dailyEntryDeals, MaxDailyTrades);

   string direcaoBancos = (trend1>0 && trend5>0) ? "ALTA (Compradores no comando)" :
                          ((trend1<0 && trend5<0) ? "BAIXA (Vendedores no comando)" : "CONSOLIDADO (Mercado indeciso)");
   panels[6] = "FLUXO DOS BANCOS: " + direcaoBancos;

   string setupClaro = "Aguardando Pegadinha dos Tubaroes";
   if(lastSetup == 1) setupClaro = "Pegadinha de Fundo/Topo (Falso Rompimento)";
   else if(lastSetup == 2) setupClaro = "Rompeu Estrutura e Veio Testar";
   else if(lastSetup == 3) setupClaro = "Porrada Institucional com Volume";
   else if(lastSetup == 4) setupClaro = "Preenchimento de Vacuo de Preco";
   else if(lastSetup == 5) setupClaro = "Defesa de Regiao dos Bancos";

   panels[7] = "PADRAO DETECTADO: " + setupClaro;
   panels[8] = StringFormat("CUSTOS: Spread %.1f pts | Volatilidade ATR: %.0f pts", (tk.ask-tk.bid)/_Point, atrPts);
   panels[9] = "MATEMATICA: Arrisca pouco para buscar mais que o dobro (R:R > 2:1)";
   panels[10] = "ULTIMA LEITURA: " + (StringLen(lastReason)>50 ? StringSubstr(lastReason,0,48)+"..." : lastReason);
   panels[11] = "SEGURANCA: Stop Loss e Take Profit automaticos no servidor";

   if(LiveTradeTeacherMode && OurPositionCount()>0)
   {
      for(int pi=PositionsTotal()-1; pi>=0; pi--)
      {
         ulong ticket=PositionGetTicket(pi);
         if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
            (ulong)PositionGetInteger(POSITION_MAGIC)!=ExpertMagic) continue;
         bool buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
         int dir=buy?1:-1;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double sl=PositionGetDouble(POSITION_SL);
         double tp=PositionGetDouble(POSITION_TP);
         double vol=PositionGetDouble(POSITION_VOLUME);
         double price=buy?tk.bid:tk.ask;
         double pl=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);

         double distanceTP=tp>0.0?MathAbs(tp-price)/_Point:0.0;
         double distanceSL=sl>0.0?MathAbs(price-sl)/_Point:0.0;

         string protecao = "Stop Loss Protegendo a Conta";
         if((buy && sl>=entry) || (!buy && sl<=entry))
            protecao = "RISCO ZERO! Stop ja colocado no Lucro (Break-Even)";

         panels[0] = "=== ALIEN FREEDOM | OPERACAO AO VIVO NA TELA ===";
         panels[1] = StringFormat("ORDEM: %s %.2f LOTES | RESULTADO: %+.2f USD", buy?"COMPRA JUNTO AOS BANCOS":"VENDA JUNTO AOS BANCOS", vol, pl);
         panels[2] = StringFormat("ENTRADA: %.2f | ATUAL: %.2f | PADRAO: %s", entry, price, setupClaro);
         panels[3] = StringFormat("ALVO (TP): %.2f (Faltam %.0f pts) | STOP: %.2f (Faltam %.0f pts)", tp, distanceTP, sl, distanceSL);
         panels[4] = "STATUS DA PROTECAO: " + protecao;
         panels[5] = pl>0 ? "ANDAMENTO: Ouro correndo a nosso favor! Buscando alvo..." : "ANDAMENTO: Flutuacao normal; ordem blindada pelo stop.";
         panels[6] = StringFormat("LUCRO HOJE COM FECHADAS: %+.2f USD | META: $%.2f", dailyRealizedNet, DailyProfitTargetMoney);
         panels[7] = "REGRA: Deixe o robo trabalhar. Nunca feche por panico!";
         panels[8] = StringFormat("TRAVA DIARIA: Perda maxima controlada em $%.2f", DailyMaxLossMoney);
         panels[9] = "PROXIMO PASSO: Stop move sozinho pro zero a zero quando avancar.";
         panels[10] = "DISCIPLINA: A matematica do lucro esta programada em codigo.";
         panels[11] = "OPERADOR VITOR: Relaxe e observe a maquina executar.";
         break;
      }
   }

   for(int r=0;r<rows;r++)
   {
      color rowColor = clrWhite;
      if(r==0 || r==2) rowColor = clrGold;
      else if(r==1 && dailyTargetHit) rowColor = clrLime;
      else if(r==4 || r==7) rowColor = clrAqua;
      AlienPanelRow(r,panels[r],rowColor,left,top,width);
   }
   for(int r=rows;r<12;r++)
   {
      ObjectSetString(0,teacherPrefix+"R"+IntegerToString(r),OBJPROP_TEXT," ");
      ObjectSetString(0,teacherPrefix+"R"+IntegerToString(r)+"_B",OBJPROP_TEXT," ");
   }
}

void Dashboard(const MqlTick &tick, TickMetrics &longM,
               TickMetrics &shortM, double atrPts, int trend1, int trend5)
{
   ObserveReason();
   long nowMs=tick.time_msc;
   if(ShowDashboard && DashboardEveryMs>0 && lastPanelMs>0 &&
      nowMs-lastPanelMs<DashboardEveryMs) return;
   lastPanelMs=nowMs;
   if(OurPositionCount()>0)
      lastConversation="Estou gerenciando risco e saida. Avalio cada tick.";
   else if(lastScore>=MinimumScore && StringFind(lastReason,"executada")>=0)
      lastConversation="Entrei: sinal passou qualidade, custo e margem.";
   else if(StringFind(lastReason,"Spread")>=0 || StringFind(lastReason,"ATR")>=0)
      lastConversation="Fiquei de fora: custo ou volatilidade nao compensou.";
   else if(StringFind(lastReason,"Score")>=0)
      lastConversation="Fiquei de fora: fatores do sinal ainda fracos.";
   else if(StringFind(lastReason,"Margem")>=0)
      lastConversation="Fiquei de fora: priorizei a margem da conta.";
   else if(completedSession>0)
      lastConversation=StringFormat("Ja fechei %d posicoes. Liquido %+.2f nesta sessao.",
                                     completedSession,netSession);
   else
      lastConversation="Analisando ticks; aguardando sinal com custos aceitaveis.";
   if(!ShowDashboard) return;
   if(UseGraphicTeacherPanel)
   {
      AlienTeacherPanel(tick,atrPts,trend1,trend5);
      Comment("");
      return;
   }
   double spread = (tick.ask-tick.bid)/_Point;
   if(CleanVisualMode)
   {
      string state="OBSERVANDO";
      if(OurPositionCount()>0) state="POSICAO EM GERENCIAMENTO";
      else if(StringFind(lastReason,"Spread")>=0) state="AGUARDANDO SPREAD";
      else if(StringFind(lastReason,"bloquead")>=0 || StringFind(supervisorMessage,"BLOQ")>=0)
         state="PROTECAO ATIVA";
      string direction="NEUTRO";
      if(trend1>0 && trend5>0) direction="ALTA M1/M5";
      else if(trend1<0 && trend5<0) direction="BAIXA M1/M5";
      else if(trend1!=0 || trend5!=0) direction="TENDENCIAS MISTAS";
      string reason=lastReason;
      if(StringLen(reason)>83) reason=StringSubstr(reason,0,80)+"...";
      string shortPanel="ALIEN V11.2 FREEDOM | "+_Symbol+" | "+state+"\n";
      shortPanel+="DIRECAO: "+direction+" | SCORE: "+IntegerToString(lastScore)+"/100\n";
      shortPanel+=StringFormat("SPREAD: %.1f pts | POSICOES: %d | ENTRADAS M1: %d\n",
                               spread,OurPositionCount(),entriesThisBar);
      shortPanel+="ZONA MAIS PROXIMA: "+mapBestZone+"\n";
      shortPanel+="SETUP: "+SetupName(lastSetup)+"\n";
      if(OurPositionCount()>0 && UseAdaptiveRunner)
      {
         double peak=0.0, current=0.0;
         for(int p=0;p<ALIEN_RUNNER_TRACKS;p++)
         {
            if(runnerTickets[p]==0 || !PositionSelectByTicket(runnerTickets[p])) continue;
            int d=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1:-1;
            double q=d>0 ? tick.bid:tick.ask;
            double nowPts=d*(q-PositionGetDouble(POSITION_PRICE_OPEN))/_Point;
            if(runnerPeakPoints[p]>peak)
            {
               peak=runnerPeakPoints[p];
               current=nowPts;
            }
         }
         shortPanel+=StringFormat("RUNNER: atual %+.0f | pico %+.0f | recuo %.0f pts\n",
                         current,peak,MathMax(0.0,peak-current));
         shortPanel+=StringFormat("STOP: BE apos %.0f | trailing apos %.0f pts\n",
                         MathMax(BreakEvenAfterPoints,cachedATRPoints*AdaptiveBEStartATR),
                         MathMax(TrailStartPoints,cachedATRPoints*AdaptiveTrailStartATR));
      }
      shortPanel+="POR QUE: "+reason+"\n";
      shortPanel+=StringFormat("RESULTADO HOJE: %+.2f | PROTECAO: %s",
                               dailyRealizedNet,supervisorMessage);
      Comment(shortPanel);
      return;
   }
   string panel = "=== XAU TICK ALIEN V11.2 FREEDOM | AUTONOMO + PROFESSOR (DEMO) ===\n";
   if(CompactDashboard)
   {
      ComputeRecentEvidence();
      panel+=StringFormat("%s M1 | entradas candle %d | posicoes %d | score %d/100\n",
                _Symbol,entriesThisBar,OurPositionCount(),lastScore);
      panel+=StringFormat("HOJE realizado %+.2f | SESSAO %+.2f | W %d L %d\n",
                dailyRealizedNet,netSession,profitableSession,losingSession);
      panel+=StringFormat("RECENTE %d trades: %+.2f | PF %s\n",recentCount,recentNet,
                recentLosses>0.0?DoubleToString(recentGains/recentLosses,2):"n/d");
      panel+=StringFormat("SINAIS: pressao %.0f%% | M1 %d M5 %d | spread %.1f | ATR %.1f\n",
                longM.directionPercent,trend1,trend5,spread,atrPts);
      panel+="SETUP: "+SetupName(lastSetup)+" | "+lastSetupInfo+"\n";
      panel+="CONTEXT: "+htfDescription+"\n";
      panel+="MAPA: "+mapSummary+"\n";
      panel+="PENDENTE: "+mapPendingMessage+"\n";
      panel+="ALIEN DIZ: "+lastConversation+"\n";
      panel+="SUPERVISOR: "+supervisorMessage+"\n";
      panel+=StringFormat("GUARDA EQUITY: %.2f -> %.2f | limite %.2f%% | rejeicoes risco %d\n",
             dayOpeningEquity,AccountInfoDouble(ACCOUNT_EQUITY),DailyEquityLossPct,riskRejected);
      panel+="LOTE: "+sizingExplanation+"\n";
      panel+=StopOnlyRunnerMode ? "SAIDA: STOP RUNNER - stop inicial + BE + trailing\n"
                               : "SAIDA: LEGADA (fechamento antecipado possivel)\n";
      panel+="AGORA: "+lastReason+"\n";
      panel+="TXT + TRADES CSV em MQL5/Files; envie ambos para ChatGPT";
      Comment(panel);
      return;
   }

   panel += StringFormat("SIMBOLO: %s | M1 candle: %s\n", _Symbol,
                         TimeToString(barStart, TIME_MINUTES));
   panel += StringFormat("Saldo: %.2f | Equity: %.2f | Margem livre: %.2f\n",
                         AccountInfoDouble(ACCOUNT_BALANCE),
                         AccountInfoDouble(ACCOUNT_EQUITY),
                         AccountInfoDouble(ACCOUNT_MARGIN_FREE));
   panel += StringFormat("Resultado realizado hoje: %+.2f %s\n",
                         dailyRealizedNet, AccountInfoString(ACCOUNT_CURRENCY));
   panel += StringFormat("Ticks: %I64d | Candle: %d | Movimento: %+.1f / %+.1f pts\n",
                         ticksTotal, ticksInBar, longM.movePoints, shortM.movePoints);
   panel += StringFormat("Pressao: %.0f%% | Mudancas: %d | Spread: %.1f pts | ATR: %.1f pts\n",
                         longM.directionPercent, longM.changes, spread, atrPts);
   panel += StringFormat("EMA M1: %d | EMA M5: %d | Score: %d/100 (min %d)\n",
                         trend1, trend5, lastScore, MinimumScore);
   panel += StringFormat("Candles observados: %d | Sinais: %d | Tentativas: %d\n",
                         candlesObserved, opportunitiesFound, attempts);
   panel += StringFormat("Entradas sessao: %d | Saidas sessao: %d | Rejeitadas: %d\n",
                         entriesSession, exitsSession, rejectedEntries);
   panel += StringFormat("Posicoes: %d | Entradas neste M1: %d | Modo: %s\n",
                         OurPositionCount(), entriesThisBar,
                         OneEntryPerM1Candle ? "UMA POR CANDLE" : "MULTIPLAS POR CANDLE");
   panel += StringFormat("Limite por candle: %s | Intervalo minimo: %d ms\n",
                         MaxEntriesPerM1Candle <= 0 ? "LIVRE" : IntegerToString(MaxEntriesPerM1Candle),
                         MinMsBetweenEntries);
   panel += StringFormat("Hoje: %d entradas | %d saidas + | %d saidas -\n",
                         dailyEntryDeals, dailyProfitableExitDeals, dailyLosingExitDeals);
   panel += StringFormat("TELEMETRIA: trades fechados %d | W %d | L %d | liquido %+.2f (sessao)\n",
                          completedSession,profitableSession,losingSession,netSession);
   panel += StringFormat("POR EMA: 2 favoraveis %d operacoes %+.2f | 1 favoravel %d %+.2f\n",
                         trendGroupCount[0],trendGroupNet[0],trendGroupCount[1],trendGroupNet[1]);
   panel += StringFormat("PONTOS: pressao %d | impulso %d | curto %d | candle %d | EMA %d | custo %d\n",
              lastFactor.pressure,lastFactor.impulse,lastFactor.fast,lastFactor.candle,lastFactor.trend,lastFactor.costs);
   panel += "ULTIMO SETUP: "+SetupName(lastSetup)+" | "+lastSetupInfo+"\n";
   panel += "CONTEXTO: "+htfDescription+"\n";
   panel += "MAPA: "+mapSummary+"\n";
   panel += "PENDENTE: "+mapPendingMessage+"\n";
   panel += StringFormat("SETUPS: SW %d/%+.2f | BOS %d/%+.2f | PA %d/%+.2f | FVG %d/%+.2f | OB %d/%+.2f\n",
      setupCount[1],setupNet[1],setupCount[2],setupNet[2],setupCount[3],setupNet[3],
      setupCount[4],setupNet[4],setupCount[5],setupNet[5]);
   panel += "ALIEN DIZ: "+lastConversation+"\n";
   panel += "SUPERVISOR: "+supervisorMessage+"\n";
   panel += StringFormat("GUARDA: equity inicial %.2f | atual %.2f | max perda %.2f%% | bloqueios risco %d | precheck %d\n",
       dayOpeningEquity,AccountInfoDouble(ACCOUNT_EQUITY),DailyEquityLossPct,riskRejected,precheckRejected);
   panel += "LOTE: "+sizingExplanation+"\n";
   panel += StringFormat("Ultimo %.2f | Boost %d | Add %d | Negados %d\n",
                           lastEntryLot,boostedEntries,additionalEntries,boostRefusals);
   panel += StopOnlyRunnerMode ? "SAIDA: stop inicial + breakeven + trailing (sem prazo)\n"
                               : "SAIDA: legada, fechamento antecipado habilitado\n";
   panel += "Status: " + lastReason + "\n";
   panel += "Relatorio TXT + CSV: MQL5/Files (envie para analisar)";
   Comment(panel);
}

//+------------------------------------------------------------------+
// V10.50 - Mapa institucional: zonas determinadas por regras explicitas.
// NAO confirma que bancos/fundos operaram nas regioes.
string MapTF(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_M5) return "M5";
   if(tf==PERIOD_M15) return "M15";
   if(tf==PERIOD_H1) return "H1";
   return "TF";
}

bool MapZoneStillValid(AlienMapZone &z)
{
   if(z.low<=0.0 || z.high<=z.low || z.confirmed<=0) return false;
   int newerShift=iBarShift(_Symbol,z.tf,z.confirmed,true);
   if(newerShift<1) return false;
   int touches=0;
   // Apenas velas FECHADAS apos a confirmacao; nunca usa informacao futura.
   for(int k=newerShift-1;k>=1;k--)
   {
      double hi=iHigh(_Symbol,z.tf,k);
      double lo=iLow(_Symbol,z.tf,k);
      if(hi<=0.0 || lo<=0.0) return false;
      if(z.direction>0 && lo<=z.low) return false;
      if(z.direction<0 && hi>=z.high) return false;
      if(hi>=z.low && lo<=z.high) touches++;
   }
   z.touches=touches;
   return true;
}

void MapInsertZone(int kind,int direction,ENUM_TIMEFRAMES tf,datetime confirmed,
                   double lo,double hi)
{
   if(mapZoneCount>=ALIEN_MAP_MAX || lo<=0.0 || hi<=lo || confirmed<=0) return;
   AlienMapZone z;
   z.kind=kind; z.direction=direction; z.tf=tf; z.confirmed=confirmed;
   z.low=lo; z.high=hi; z.touches=0; z.valid=true;
   z.id=StringFormat("%s_%s_%s_%I64d",kind==4?"FVG":"OB",
                  MapTF(tf),direction>0?"BUY":"SELL",(long)confirmed);
   z.label=StringFormat("%s %s %s",kind==4?"FVG":"OB",MapTF(tf),
                        direction>0?"BUY":"SELL");
   if(!MapZoneStillValid(z)) return;
   mapZones[mapZoneCount++]=z;
}

void MapScanTF(ENUM_TIMEFRAMES tf,int atrHandle)
{
   int inserted=0;
   int bars=Bars(_Symbol,tf);
   if(bars<MapScanBars+5) return;
   double atr=ATRFromHandle(atrHandle);
   if(atr<=0.0) return;
   // shift>=2: o padrao e confirmado apenas por candle fechado (shift-1).
   for(int shift=2;shift<=MapScanBars && mapZoneCount<ALIEN_MAP_MAX && inserted<21;shift++)
   {
      int before=mapZoneCount;
      datetime confirmed=iTime(_Symbol,tf,shift-1);
      double olderHigh=iHigh(_Symbol,tf,shift+1);
      double olderLow =iLow(_Symbol,tf,shift+1);
      double newerLow =iLow(_Symbol,tf,shift-1);
      double newerHigh=iHigh(_Symbol,tf,shift-1);
      if(confirmed==0 || olderHigh<=0.0 || olderLow<=0.0) continue;
      if(DrawFVG && EnableFVGSetup)
      {
         if(newerLow-olderHigh>=MinFVGPoints*_Point)
            MapInsertZone(4,1,tf,confirmed,olderHigh,newerLow);
         if(olderLow-newerHigh>=MinFVGPoints*_Point)
            MapInsertZone(4,-1,tf,confirmed,newerHigh,olderLow);
      }
      if(!DrawOrderBlocks || !EnableOrderBlockSetup)
      {
         inserted+=(mapZoneCount-before);
         continue;
      }
      double o=iOpen(_Symbol,tf,shift),c=iClose(_Symbol,tf,shift);
      double h=iHigh(_Symbol,tf,shift),l=iLow(_Symbol,tf,shift);
      double nc=iClose(_Symbol,tf,shift-1),no=iOpen(_Symbol,tf,shift-1);
      if(c<o && nc>no && nc>h+atr*OBDisplacementATR)
         MapInsertZone(5,1,tf,confirmed,l,o);
      if(c>o && nc<no && nc<l-atr*OBDisplacementATR)
         MapInsertZone(5,-1,tf,confirmed,o,h);
      inserted+=(mapZoneCount-before);
   }
}

void MapDrawLine(string suffix,double level,color c,string label,
                 datetime since,datetime until)
{
   if(level<=0.0 || since<=0 || until<=since) return;
   string key=mapPrefix+suffix;
   if(!ObjectCreate(0,key,OBJ_TREND,0,since,level,until,level)) return;
   ObjectSetInteger(0,key,OBJPROP_COLOR,c);
   ObjectSetInteger(0,key,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,key,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,key,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,key,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,key,OBJPROP_BACK,true);
   string textKey=key+"_LABEL";
   if(ObjectCreate(0,textKey,OBJ_TEXT,0,until,level))
   {
      ObjectSetString(0,textKey,OBJPROP_TEXT,label);
      ObjectSetInteger(0,textKey,OBJPROP_COLOR,c);
      ObjectSetInteger(0,textKey,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,textKey,OBJPROP_ANCHOR,ANCHOR_RIGHT);
      ObjectSetInteger(0,textKey,OBJPROP_SELECTABLE,false);
   }
}

void MapDrawStructure(ENUM_TIMEFRAMES tf,int count,datetime until)
{
   if(!DrawStructure || Bars(_Symbol,tf)<count+4) return;
   // Break of Structure: ultimo fechamento FECHADO acima/abaixo do range anterior.
   double upper=-1e100,lower=1e100;
   for(int j=2;j<=count+1;j++)
   {
      upper=MathMax(upper,iHigh(_Symbol,tf,j));
      lower=MathMin(lower,iLow(_Symbol,tf,j));
   }
   double prevClose=iClose(_Symbol,tf,1);
   double olderClose=iClose(_Symbol,tf,2);
   datetime start=iTime(_Symbol,tf,1);
   int bias=(tf==PERIOD_M5?TrendFromHandles(hFastM5,hSlowM5):
             TrendFromHandles(hFastM15,hSlowM15));
   if(prevClose>upper && olderClose<=upper)
      MapDrawLine("MS_"+MapTF(tf),upper,clrGold,
                  (bias<0?"CHoCH? ALTA ":"BOS ALTA ")+MapTF(tf),start,until);
   else if(prevClose<lower && olderClose>=lower)
      MapDrawLine("MS_"+MapTF(tf),lower,clrWhite,
                  (bias>0?"CHoCH? BAIXA ":"BOS BAIXA ")+MapTF(tf),start,until);
}

void MapDrawLiquidity(datetime until)
{
   if(!DrawLiquidity || Bars(_Symbol,PERIOD_M5)<15) return;
   double high=-1e100,low=1e100;
   int hiShift=1,loShift=1;
   for(int i=1;i<=12;i++)
   {
      double h=iHigh(_Symbol,PERIOD_M5,i),l=iLow(_Symbol,PERIOD_M5,i);
      if(h>high) {high=h;hiShift=i;}
      if(l<low) {low=l;loShift=i;}
   }
   MapDrawLine("BSL",high,clrGold,"BSL M5 | LIQUIDEZ ACIMA",iTime(_Symbol,PERIOD_M5,hiShift),until);
   MapDrawLine("SSL",low,clrSilver,"SSL M5 | LIQUIDEZ ABAIXO",iTime(_Symbol,PERIOD_M5,loShift),until);
   // Equal highs/lows: aproximacao mecanica (tol. configurada).
   int highs=0,lows=0;
   for(int j=1;j<=12;j++)
   {
      if(MathAbs(iHigh(_Symbol,PERIOD_M5,j)-high)<=EqualHighLowTolerancePoints*_Point) highs++;
      if(MathAbs(iLow(_Symbol,PERIOD_M5,j)-low)<=EqualHighLowTolerancePoints*_Point) lows++;
   }
   if(highs>=2)
      MapDrawLine("EQH",high,clrGold,"EQH >=2 toques",iTime(_Symbol,PERIOD_M5,12),until);
   if(lows>=2)
      MapDrawLine("EQL",low,clrSilver,"EQL >=2 toques",iTime(_Symbol,PERIOD_M5,12),until);
}

void MapDrawPremiumDiscount(datetime until)
{
   if(!DrawPremiumDiscount || Bars(_Symbol,PERIOD_H1)<27) return;
   double h=-1e100,l=1e100;
   for(int i=1;i<=24;i++)
   {
      h=MathMax(h,iHigh(_Symbol,PERIOD_H1,i));
      l=MathMin(l,iLow(_Symbol,PERIOD_H1,i));
   }
   if(h<=l) return;
   double mid=(h+l)*0.5;
   MapDrawLine("EQ50",mid,clrSilver,"EQUILIBRIO H1 (50%)",
               iTime(_Symbol,PERIOD_H1,24),until);
   MapDrawLine("PREMIUM",h,clrWhite,"PREMIUM H1",
               iTime(_Symbol,PERIOD_H1,24),until);
   MapDrawLine("DISCOUNT",l,clrGold,"DISCOUNT H1",
               iTime(_Symbol,PERIOD_H1,24),until);
}

void RefreshInstitutionalMap(bool force=false)
{
   if(!EnableInstitutionalMap) return;
   if(!force && mapLastScanTime>0 && TimeCurrent()-mapLastScanTime<MapRefreshSeconds)
      return;
   if(Bars(_Symbol,PERIOD_H1)<MapScanBars+6 || Bars(_Symbol,PERIOD_M15)<MapScanBars+6)
   {
      mapSummary="Aguardando historico M15/H1";
      return;
   }
   mapLastScanTime=TimeCurrent();
   mapZoneCount=0;
   MapScanTF(PERIOD_H1,hAtrH1);
   MapScanTF(PERIOD_M15,hAtrM15);
   MapScanTF(PERIOD_M5,hAtrM5);
   // Objetos prefixados: NAO apaga desenhos do usuario nem de outros EAs.
   ObjectsDeleteAll(0,mapPrefix);
   datetime until=TimeCurrent()+(CleanVisualMode?CleanVisualMinutesAhead:MapProjectionMinutes)*60;
   int drawLimit=CleanVisualMode?
                 (MapMaxDrawZones<CleanVisualMaxZones?MapMaxDrawZones:CleanVisualMaxZones):
                 MapMaxDrawZones;
   MqlTick tk;
   bool gotQuote=SymbolInfoTick(_Symbol,tk);
   int drawn=0;
   bool selected[ALIEN_MAP_MAX];
   for(int si=0;si<ALIEN_MAP_MAX;si++) selected[si]=false;
   for(int pass=0;pass<mapZoneCount && drawn<drawLimit;pass++)
   {
      int bestIdx=-1;
      double bestDist=1e100;
      for(int j=0;j<mapZoneCount;j++)
      {
         if(selected[j] || !mapZones[j].valid) continue;
         double d=gotQuote?MathMax(0.0,MathMax(mapZones[j].low-tk.bid,
                                                  tk.bid-mapZones[j].high)):0.0;
         if(d<bestDist) {bestDist=d;bestIdx=j;}
      }
      if(bestIdx<0) break;
      selected[bestIdx]=true;
      AlienMapZone z=mapZones[bestIdx];
      if(!z.valid || z.high<=z.low) continue;
      // Desenha as zonas mais proximas primeiro (ordem de varredura temporal).
      string key=mapPrefix+z.id;
      datetime from=CleanVisualMode?TimeCurrent()-CleanVisualMinutesBack*60:z.confirmed;
      if(!ObjectCreate(0,key,OBJ_RECTANGLE,0,from,z.low,until,z.high)) continue;
      color col=(z.direction>0?clrGold:clrWhite);
      if(z.kind==4) col=z.direction>0?clrKhaki:clrSilver;
      ObjectSetInteger(0,key,OBJPROP_COLOR,col);
      ObjectSetInteger(0,key,OBJPROP_FILL,!CleanVisualMode);
      ObjectSetInteger(0,key,OBJPROP_BACK,true);
      if(CleanVisualMode)
      {
         ObjectSetInteger(0,key,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,key,OBJPROP_WIDTH,1);
      }
      ObjectSetInteger(0,key,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,key,OBJPROP_TOOLTIP,z.label+
                      StringFormat(" | toques fechados=%d | hipotese, nao garantia",z.touches));
      string label=key+"_NAME";
      if(ObjectCreate(0,label,OBJ_TEXT,0,CleanVisualMode?TimeCurrent()+60:until,z.high))
      {
         ObjectSetString(0,label,OBJPROP_TEXT,z.label+(z.touches>0?" | TOCADA":" | NOVA"));
         ObjectSetInteger(0,label,OBJPROP_COLOR,col);
         ObjectSetInteger(0,label,OBJPROP_ANCHOR,CleanVisualMode?ANCHOR_LEFT:ANCHOR_RIGHT);
         ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
         ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
      }
      drawn++;
   }
   mapDrawn=drawn;
   MapDrawStructure(PERIOD_M5,10,until);
   MapDrawStructure(PERIOD_M15,10,until);
   MapDrawLiquidity(until);
   MapDrawPremiumDiscount(until);
   if(gotQuote)
   {
      double nearest=1e100;
      mapBestZone="SEM_ZONA";
      for(int i=0;i<mapZoneCount;i++)
      {
         double d=MathMax(0.0,MathMax(mapZones[i].low-tk.bid,
                                         tk.bid-mapZones[i].high));
         if(d<nearest) { nearest=d;mapBestZone=mapZones[i].label; }
      }
   }
   mapSummary=StringFormat("Mapa: %d zonas validas | %d desenhadas | mais perto %s",
                           mapZoneCount,drawn,mapBestZone);
   ChartRedraw(0);
}

int MapPendingOrdersCount()
{
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol &&
         (ulong)OrderGetInteger(ORDER_MAGIC)==ExpertMagic) n++;
   }
   return n;
}

bool MapCancelPending(ulong ticket,string reason)
{
   if(ticket==0 || !OrderSelect(ticket)) return false;
   if(OrderGetString(ORDER_SYMBOL)!=_Symbol ||
      (ulong)OrderGetInteger(ORDER_MAGIC)!=ExpertMagic) return false;
   bool sent=trade.OrderDelete(ticket);
   uint ret=trade.ResultRetcode();
   if(sent && ret==TRADE_RETCODE_DONE)
   {
      mapCancelled++;
      mapPendingMessage="Cancelei pendente: "+reason;
      LogEvent("PENDING_CANCEL",reason,(double)ticket);
      if(ticket==mapPendingTicket) {mapPendingTicket=0;mapPendingZoneId="";}
      return true;
   }
   mapPendingMessage=StringFormat("Falha cancelar pendente #%I64u: %u",ticket,ret);
   Print("ALIEN V11.2 FREEDOM: ",mapPendingMessage);
   return false;
}

string MapZoneGlobalKey(AlienMapZone &z)
{
   return StringFormat("A1050_%I64d_%I64u_%s_%d_%d_%I64d",
          (long)AccountInfoInteger(ACCOUNT_LOGIN),ExpertMagic,MapTF(z.tf),
          z.kind,z.direction,(long)z.confirmed);
}

bool MapMatchPendingToZone(double entry,int direction)
{
   double tolerance=2.0*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tolerance<=0.0) tolerance=2.0*_Point;
   for(int z=0;z<mapZoneCount;z++)
   {
      if(mapZones[z].direction!=direction || mapZones[z].touches>0) continue;
      if(entry>=mapZones[z].low-tolerance && entry<=mapZones[z].high+tolerance)
         return true;
   }
   return false;
}

void MapMaintainPendingOrders()
{
   if(!EnableZonePendingOrders) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   bool riskOK=NewEntriesAllowedBySupervisor() &&
               AlienSessionEntryAllowed(TimeCurrent());
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC)!=ExpertMagic) continue;
      ENUM_ORDER_TYPE typ=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(typ!=ORDER_TYPE_BUY_LIMIT && typ!=ORDER_TYPE_SELL_LIMIT) continue;
      int dir=(typ==ORDER_TYPE_BUY_LIMIT)?1:-1;
      double entry=OrderGetDouble(ORDER_PRICE_OPEN);
      datetime placed=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
      bool expired=TimeCurrent()-placed>=PendingMaxAgeMinutes*60;
      bool crossed=(dir>0 && tick.bid<entry-PendingMinDistancePoints*_Point) ||
                   (dir<0 && tick.ask>entry+PendingMinDistancePoints*_Point);
      bool invalid=!MapMatchPendingToZone(entry,dir);
      // Protege a conta: remove ordens orfas e cancelamentos antigos.
      if(!riskOK || OurPositionCount()>0 || SymbolHasAnyPosition() ||
         expired || invalid || crossed)
      {
         string why=!riskOK?"Supervisor de risco":
                     (OurPositionCount()>0 || SymbolHasAnyPosition())?"Posicao existente":
                     expired?"Prazo expirado":invalid?"Zona invalida ou ja testada":
                     "Preco atravessou o nivel";
         MapCancelPending(ticket,why);
      }
      else
      {
         mapPendingTicket=ticket;
         mapPendingMessage=StringFormat("PENDENTE #%I64u %s em %.2f",ticket,
                          dir>0?"BUY LIMIT":"SELL LIMIT",entry);
      }
   }
}

int MapFindPendingCandidate(const MqlTick &tick,double atrPts,
                            double &entry,int &direction,double &stop,string &why)
{
   entry=0.0;stop=0.0;direction=0;
   double best=1e100;
   int found=-1;
   int m15=TrendFromHandles(hFastM15,hSlowM15);
   int h1=TrendFromHandles(hFastH1,hSlowH1);
   double sz=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(sz<=0.0) sz=_Point;
   double stopLevel=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double spreadPts=(tick.ask-tick.bid)/_Point;
   for(int i=0;i<mapZoneCount;i++)
   {
      AlienMapZone z=mapZones[i];
      if(z.touches>0 || !z.valid) continue;
      // Se a vela atual do timeframe JA tocou a zona, nao arma depois do fato.
      if(z.direction>0 && iLow(_Symbol,z.tf,0)<=z.high) continue;
      if(z.direction<0 && iHigh(_Symbol,z.tf,0)>=z.low) continue;
      if(PendingOnlyFromTF>=15 && z.tf==PERIOD_M5) continue;
      if(GlobalVariableCheck(MapZoneGlobalKey(z))) continue;
      if(PendingOnlyFromTF==60 && z.tf!=PERIOD_H1) continue;
      if(PendingOnlyFromTF==15 && z.tf==PERIOD_M5) continue;
      if((z.direction > 0 && !AllowBuy) || (z.direction < 0 && !AllowSell)) continue;
      if(RequireHigherTFTrendForPending &&
         ((m15!=z.direction) || (h1!=z.direction))) continue;
      // Limit tem que estar abaixo do ASK (compra) ou acima do BID (venda).
      double mid=(z.low+z.high)*0.5;
      double distance=(z.direction>0 ? tick.ask-mid : mid-tick.bid)/_Point;
      if(distance<=MathMax(stopLevel+2.0,PendingMinDistancePoints+spreadPts)) continue;
      if(distance>atrPts*PendingMaxDistanceATR) continue;
      double sl=(z.direction>0?z.low-PendingSLBufferATR*atrPts*_Point:
                                z.high+PendingSLBufferATR*atrPts*_Point);
      if(z.direction>0) {mid=MathFloor(mid/sz)*sz;sl=MathFloor(sl/sz)*sz;}
      else {mid=MathCeil(mid/sz)*sz;sl=MathCeil(sl/sz)*sz;}
      mid=NormalizeDouble(mid,_Digits);
      sl=NormalizeDouble(sl,_Digits);
      double stopPts=MathAbs(mid-sl)/_Point;
      if(stopPts<stopLevel+3.0 || stopPts<=0.0) continue;
      double room=RoomToOpposingLiquidity(z.direction,mid);
      if(room<stopPts*PendingMinRoomToRisk) continue;
      if(distance<best)
      {
         best=distance;found=i;entry=mid;direction=z.direction;stop=sl;
      }
   }
   if(found<0) why="Sem zona NOVA, tendencia alinhada e espaco para risco";
   return found;
}

bool MapPrecheckPending(ENUM_ORDER_TYPE typ,double lot,double entry,double stop,
                        datetime expires,string &why)
{
   MqlTradeRequest req={};
   MqlTradeCheckResult chk={};
   req.action=TRADE_ACTION_PENDING;
   req.symbol=_Symbol;
   req.magic=ExpertMagic;
   req.type=typ;
   req.volume=lot;
   req.price=entry;
   req.sl=stop;
   req.tp=0.0;
   req.type_time=ORDER_TIME_SPECIFIED;
   req.expiration=expires;
   req.type_filling=ORDER_FILLING_RETURN;
   req.comment="ALIEN1050 ZONE CHECK";
   ResetLastError();
   if(!OrderCheck(req,chk))
   {
      why=StringFormat("OrderCheck pendente falhou: %d %u %s",GetLastError(),chk.retcode,chk.comment);
      return false;
   }
   if(chk.retcode!=0 && chk.retcode!=TRADE_RETCODE_DONE &&
      chk.retcode!=TRADE_RETCODE_PLACED)
   {
      why=StringFormat("Pendente recusada no precheck: %u %s",chk.retcode,chk.comment);
      return false;
   }
   if(chk.margin_free<MinFreeMarginMoney ||
      (chk.margin_level>0.0 && chk.margin_level<MinimumMarginLevelPct))
   {
      why="Margem projetada insuficiente para pendente";
      return false;
   }
   return true;
}

void MapMaybePlacePending()
{
   if(SweepOnlyTradeMode)
   {
      mapPendingMessage="Pendentes de zonas desligadas enquanto modo sweep-only estiver ativo.";
      return;
   }
   if(!EnableZonePendingOrders || !EnableInstitutionalMap) return;
   if(!AlienSessionEntryAllowed(TimeCurrent()))
   {mapPendingMessage="Sessao/cautela: nenhuma nova pendente";return;}
   if(MapPendingOrdersCount()>0 || SymbolHasAnyPosition()) return;
   if(!NewEntriesAllowedBySupervisor())
   {mapPendingMessage="Risco: "+supervisorMessage;return;}
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=tick.bid || tick.bid<=0.0) return;
   double atrPts=cachedATRPoints;
   if(atrPts<=0.0) {mapPendingMessage="Aguardando ATR M1";return;}
   double spr=(tick.ask-tick.bid)/_Point;
   if(spr>AbsoluteMaxSpreadPts || spr>atrPts*MaxSpreadAsATR)
   {mapPendingMessage="Spread alto para ordem antecipada";return;}
   long allowed=(long)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   if((allowed&SYMBOL_EXPIRATION_SPECIFIED)==0)
   {
      mapPendingMessage="Corretora sem prazo de expiracao especificado; nao arma pendente";
      return;
   }
   double entry=0.0,stop=0.0;
   int dir=0;
   string why="";
   int idx=MapFindPendingCandidate(tick,atrPts,entry,dir,stop,why);
   if(idx<0) {mapPendingMessage=why;return;}
   double lot=ValidVolume(FixedLot);
   if(lot<=0.0) {mapPendingMessage="Volume invalido";return;}
   ENUM_ORDER_TYPE marketSide=dir>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   ENUM_ORDER_TYPE limitSide=dir>0?ORDER_TYPE_BUY_LIMIT:ORDER_TYPE_SELL_LIMIT;
   double expected=0.0;
   if(!OrderCalcProfit(marketSide,_Symbol,lot,entry,stop,expected))
   {mapPendingMessage="OrderCalcProfit falhou";return;}
   double loss=MathAbs(expected)+RoundTurnCommissionPerLot*lot;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double budget=MathMin(PendingRiskCapMoney,eq*MaxRiskPercentEquity/100.0);
   if(loss<=0.0 || loss>budget)
   {
      mapBlocked++;
      mapPendingMessage=StringFormat("Risco pendente %.2f maior que teto %.2f",loss,budget);
      return;
   }
   string exposure="";
   if(!CheckExposure(marketSide,lot,entry,loss,false,exposure))
   {mapBlocked++;mapPendingMessage="Exposicao pendente: "+exposure;return;}
   datetime expiry=TimeCurrent()+PendingMaxAgeMinutes*60;
   string checked="";
   if(!MapPrecheckPending(limitSide,lot,entry,stop,expiry,checked))
   {mapBlocked++;mapPendingMessage=checked;return;}
   string comment=StringFormat("ALIEN1050 %s %s",mapZones[idx].kind==4?"FVG":"OB",
                               MapTF(mapZones[idx].tf));
   bool sent=dir>0?
      trade.BuyLimit(lot,entry,_Symbol,stop,0.0,ORDER_TIME_SPECIFIED,expiry,comment):
      trade.SellLimit(lot,entry,_Symbol,stop,0.0,ORDER_TIME_SPECIFIED,expiry,comment);
   uint rc=trade.ResultRetcode();
   if(sent && rc==TRADE_RETCODE_PLACED && trade.ResultOrder()!=0)
   {
      mapPendingTicket=trade.ResultOrder();
      mapPendingZoneId=mapZones[idx].id;
      GlobalVariableSet(MapZoneGlobalKey(mapZones[idx]),(double)TimeCurrent());
      mapPendingDirection=dir;
      mapPendingSetup=mapZones[idx].kind;
      mapPendingCreated=TimeCurrent();
      mapPlaced++;
      mapPendingMessage=StringFormat("ARMADA %s em %.2f SL %.2f | %s",
                         dir>0?"BUY LIMIT":"SELL LIMIT",entry,stop,mapZones[idx].label);
      LogEvent("PENDING_ARMED",mapPendingMessage,loss);
      Print("ALIEN V11.2 FREEDOM: ",mapPendingMessage);
   }
   else
   {
      mapBlocked++;
      mapPendingMessage=StringFormat("Pendente rejeitada: %u %s",rc,
                                      trade.ResultRetcodeDescription());
      LogEvent("PENDING_REJECT",mapPendingMessage,(double)rc);
   }
}

void MapOnFilledDeal(ulong deal)
{
   if(!EnableTelemetry || deal==0) return;
   ulong orderTicket=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
   if(orderTicket==0 || !HistoryOrderSelect(orderTicket)) return;
   ENUM_ORDER_TYPE originalType=(ENUM_ORDER_TYPE)HistoryOrderGetInteger(orderTicket,ORDER_TYPE);
   if(originalType!=ORDER_TYPE_BUY_LIMIT && originalType!=ORDER_TYPE_SELL_LIMIT)
      return;
   string comment=HistoryOrderGetString(orderTicket,ORDER_COMMENT);
   int dir=originalType==ORDER_TYPE_BUY_LIMIT?1:-1;
   int setup=StringFind(comment,"FVG")>=0?4:5;
   lastSetup=setup;
   lastSetupLevel=HistoryDealGetDouble(deal,DEAL_PRICE);
   lastZoneName=comment;
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk)) return;
   double spread=(tk.ask-tk.bid)/_Point;
   StoreEntryContext(deal,dir,0,spread,cachedATRPoints,0.0,0.0,0.0,
                     cachedTrendM1,cachedTrendM5);
   lastReason="Pendente de zona executada: "+comment;
   mapPendingMessage=lastReason;
   mapPendingTicket=0;
   mapPendingZoneId="";
   LogEvent("PENDING_FILLED",comment,HistoryDealGetDouble(deal,DEAL_PRICE));
}

//+------------------------------------------------------------------+
int OnInit()
{
   // This laboratory build refuses to run on live accounts.
   if(UseRiskRewardTakeProfit && RiskRewardMultiple<1.0)
   {
      Print("ALIEN V11.2 FREEDOM: RiskRewardMultiple deve ser >= 1.0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO &&
      !MQLInfoInteger(MQL_TESTER))
   {
      Print("ALIEN V11.2 FREEDOM LAB: somente conta DEMO ou Testador de Estrategias.");
      return INIT_FAILED;
   }
   // Primeiro falha? Mostra TODAS as condicoes invalidas, com valores atuais.
   // Assim configuracoes .set salvas de versoes antigas nao causam falha silenciosa.
   if((RestrictToXAU && StringFind(_Symbol,"XAU")<0))
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #1: (RestrictToXAU && StringFind(_Symbol,\"XAU\")<0) | "," RestrictToXAU=",RestrictToXAU);
   if(DailyEquityLossPct<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #2: DailyEquityLossPct<0.0 | "," DailyEquityLossPct=",DailyEquityLossPct);
   if(DailyEquityLossPct>100.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #3: DailyEquityLossPct>100.0 | "," DailyEquityLossPct=",DailyEquityLossPct);
   if(MinimumMarginLevelPct<100.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #4: MinimumMarginLevelPct<100.0 | "," MinimumMarginLevelPct=",MinimumMarginLevelPct);
   if(DashboardEveryMs<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #5: DashboardEveryMs<0 | "," DashboardEveryMs=",DashboardEveryMs);
   if(StructureLookbackBars<4)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #6: StructureLookbackBars<4 | "," StructureLookbackBars=",StructureLookbackBars);
   if(StructureLookbackBars>80)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #7: StructureLookbackBars>80 | "," StructureLookbackBars=",StructureLookbackBars);
   if(MinSweepPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #8: MinSweepPoints<0.0 | "," MinSweepPoints=",MinSweepPoints);
   if(SweepReclaimPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #9: SweepReclaimPoints<0.0 | "," SweepReclaimPoints=",SweepReclaimPoints);
   if(BOSBreakPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #10: BOSBreakPoints<0.0 | "," BOSBreakPoints=",BOSBreakPoints);
   if(RetestTolerancePoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #11: RetestTolerancePoints<0.0 | "," RetestTolerancePoints=",RetestTolerancePoints);
   if(MOMBreakPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #12: MOMBreakPoints<0.0 | "," MOMBreakPoints=",MOMBreakPoints);
   if(MinPrevBodyATR<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #13: MinPrevBodyATR<0.0 | "," MinPrevBodyATR=",MinPrevBodyATR);
   if(MinPrevBodyATR>1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #14: MinPrevBodyATR>1.0 | "," MinPrevBodyATR=",MinPrevBodyATR);
   if((!EnableLiquiditySweep && !EnableBreakRetest && !EnablePAMomentum &&
       !EnableFVGSetup && !EnableOrderBlockSetup && RequireSetupValidation))
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #15: (!EnableLiquiditySweep && !EnableBreakRetest && !EnablePAMomentum && !EnableFVGSetup && !EnableOrderBlockSetup && RequireSetupValidation) | "," EnableLiquiditySweep=",EnableLiquiditySweep," EnableBreakRetest=",EnableBreakRetest," EnablePAMomentum=",EnablePAMomentum," EnableFVGSetup=",EnableFVGSetup," EnableOrderBlockSetup=",EnableOrderBlockSetup," RequireSetupValidation=",RequireSetupValidation);
   if(HigherTFScanBars<4)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #16: HigherTFScanBars<4 | "," HigherTFScanBars=",HigherTFScanBars);
   if(HigherTFScanBars>100)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #17: HigherTFScanBars>100 | "," HigherTFScanBars=",HigherTFScanBars);
   if(MinFVGPoints<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #18: MinFVGPoints<=0.0 | "," MinFVGPoints=",MinFVGPoints);
   if(OBDisplacementATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #19: OBDisplacementATR<=0.0 | "," OBDisplacementATR=",OBDisplacementATR);
   if(ZoneToleranceATR<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #20: ZoneToleranceATR<0.0 | "," ZoneToleranceATR=",ZoneToleranceATR);
   if(ZoneToleranceATR>1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #21: ZoneToleranceATR>1.0 | "," ZoneToleranceATR=",ZoneToleranceATR);
   if(MinimumRoomSpreadMult<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #22: MinimumRoomSpreadMult<0.0 | "," MinimumRoomSpreadMult=",MinimumRoomSpreadMult);
   if(HTFTrendBonus<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #23: HTFTrendBonus<0 | "," HTFTrendBonus=",HTFTrendBonus);
   if(HTFTrendBonus>20)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #24: HTFTrendBonus>20 | "," HTFTrendBonus=",HTFTrendBonus);
   if(RepeatSignalResetPts<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #25: RepeatSignalResetPts<0.0 | "," RepeatSignalResetPts=",RepeatSignalResetPts);
   if(MaxEntriesPerM1Candle < 0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #26: MaxEntriesPerM1Candle < 0 | "," MaxEntriesPerM1Candle=",MaxEntriesPerM1Candle);
   if(MinMsBetweenEntries < 0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #27: MinMsBetweenEntries < 0 | "," MinMsBetweenEntries=",MinMsBetweenEntries);
   if(MinMsAfterExit < 0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #28: MinMsAfterExit < 0 | "," MinMsAfterExit=",MinMsAfterExit);
   if(MinTicksInCandle < 2)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #29: MinTicksInCandle < 2 | "," MinTicksInCandle=",MinTicksInCandle);
   if(LongWindowMs <= ShortWindowMs)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #30: LongWindowMs <= ShortWindowMs | "," LongWindowMs=",LongWindowMs," ShortWindowMs=",ShortWindowMs);
   if(ShortWindowMs < 50)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #31: ShortWindowMs < 50 | "," ShortWindowMs=",ShortWindowMs);
   if(MinMillisecondsInBar < 0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #32: MinMillisecondsInBar < 0 | "," MinMillisecondsInBar=",MinMillisecondsInBar);
   if(MinimumScore < 1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #33: MinimumScore < 1 | "," MinimumScore=",MinimumScore);
   if(MinimumScore > 100)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #34: MinimumScore > 100 | "," MinimumScore=",MinimumScore);
   if(SweepMinimumEntryScore<MinimumScore)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #35: SweepMinimumEntryScore<MinimumScore | "," SweepMinimumEntryScore=",SweepMinimumEntryScore," MinimumScore=",MinimumScore);
   if(SweepMinimumEntryScore>100)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #36: SweepMinimumEntryScore>100 | "," SweepMinimumEntryScore=",SweepMinimumEntryScore);
   if(SweepMinimumWickATR<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #37: SweepMinimumWickATR<0.0 | "," SweepMinimumWickATR=",SweepMinimumWickATR);
   if(SweepMinimumWickATR>1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #38: SweepMinimumWickATR>1.0 | "," SweepMinimumWickATR=",SweepMinimumWickATR);
   if(SweepMaxEntryDistanceATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #39: SweepMaxEntryDistanceATR<=0.0 | "," SweepMaxEntryDistanceATR=",SweepMaxEntryDistanceATR);
   if(SweepMaxEntryDistanceATR>0.50)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #40: SweepMaxEntryDistanceATR>0.50 | "," SweepMaxEntryDistanceATR=",SweepMaxEntryDistanceATR);
   if(SweepDistanceMidATR<SweepMaxEntryDistanceATR)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #41: SweepDistanceMidATR<SweepMaxEntryDistanceATR | "," SweepDistanceMidATR=",SweepDistanceMidATR," SweepMaxEntryDistanceATR=",SweepMaxEntryDistanceATR);
   if(SweepDistanceMidATR>0.50)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #42: SweepDistanceMidATR>0.50 | "," SweepDistanceMidATR=",SweepDistanceMidATR);
   if(SweepDistanceStrongATR<SweepDistanceMidATR)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #43: SweepDistanceStrongATR<SweepDistanceMidATR | "," SweepDistanceStrongATR=",SweepDistanceStrongATR," SweepDistanceMidATR=",SweepDistanceMidATR);
   if(SweepDistanceStrongATR>0.50)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #44: SweepDistanceStrongATR>0.50 | "," SweepDistanceStrongATR=",SweepDistanceStrongATR);
   if(SweepFreshExtremePoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #45: SweepFreshExtremePoints<0.0 | "," SweepFreshExtremePoints=",SweepFreshExtremePoints);
   if(SweepEventMaxAgeSeconds<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #46: SweepEventMaxAgeSeconds<1 | "," SweepEventMaxAgeSeconds=",SweepEventMaxAgeSeconds);
   if(SweepEventMaxAgeSeconds>180)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #47: SweepEventMaxAgeSeconds>180 | "," SweepEventMaxAgeSeconds=",SweepEventMaxAgeSeconds);
   if(SweepReclaimConfirmTicks<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #48: SweepReclaimConfirmTicks<1 | "," SweepReclaimConfirmTicks=",SweepReclaimConfirmTicks);
   if(SweepReclaimConfirmTicks>20)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #49: SweepReclaimConfirmTicks>20 | "," SweepReclaimConfirmTicks=",SweepReclaimConfirmTicks);
   if(SweepNewExtremeToRefreshPts<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #50: SweepNewExtremeToRefreshPts<=0.0 | "," SweepNewExtremeToRefreshPts=",SweepNewExtremeToRefreshPts);
   if(SweepMinRoomRiskRatio<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #51: SweepMinRoomRiskRatio<0.0 | "," SweepMinRoomRiskRatio=",SweepMinRoomRiskRatio);
   if(SweepMinRoomRiskRatio>5.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #52: SweepMinRoomRiskRatio>5.0 | "," SweepMinRoomRiskRatio=",SweepMinRoomRiskRatio);
   if(MinMoveOverSpread<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #53: MinMoveOverSpread<=0.0 | "," MinMoveOverSpread=",MinMoveOverSpread);
   if(FixedLot <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #54: FixedLot <= 0.0 | "," FixedLot=",FixedLot);
   if(ATRPeriod < 2)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #55: ATRPeriod < 2 | "," ATRPeriod=",ATRPeriod);
   if(EMAFastPeriod < 2)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #56: EMAFastPeriod < 2 | "," EMAFastPeriod=",EMAFastPeriod);
   if(EMASlowPeriod <= EMAFastPeriod)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #57: EMASlowPeriod <= EMAFastPeriod | "," EMASlowPeriod=",EMASlowPeriod," EMAFastPeriod=",EMAFastPeriod);
   if(MinDirectionalTicks < 1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #58: MinDirectionalTicks < 1 | "," MinDirectionalTicks=",MinDirectionalTicks);
   if(MaxSpreadAsATR <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #59: MaxSpreadAsATR <= 0.0 | "," MaxSpreadAsATR=",MaxSpreadAsATR);
   if(MinimumATRToSpread < 1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #60: MinimumATRToSpread < 1.0 | "," MinimumATRToSpread=",MinimumATRToSpread);
   if(RiskStopMoney <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #61: RiskStopMoney <= 0.0 | "," RiskStopMoney=",RiskStopMoney);
   if(RoundTurnCommissionPerLot < 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #62: RoundTurnCommissionPerLot < 0.0 | "," RoundTurnCommissionPerLot=",RoundTurnCommissionPerLot);
   if(MinNetProfitToHarvest < 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #63: MinNetProfitToHarvest < 0.0 | "," MinNetProfitToHarvest=",MinNetProfitToHarvest);
   if(MaxFloatingLossMoney < 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #64: MaxFloatingLossMoney < 0.0 | "," MaxFloatingLossMoney=",MaxFloatingLossMoney);
   if(TrailATRMultiplier <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #65: TrailATRMultiplier <= 0.0 | "," TrailATRMultiplier=",TrailATRMultiplier);
   if(RunnerMinTrailPoints <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #66: RunnerMinTrailPoints <= 0.0 | "," RunnerMinTrailPoints=",RunnerMinTrailPoints);
   if(RunnerLockBufferPts < 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #67: RunnerLockBufferPts < 0.0 | "," RunnerLockBufferPts=",RunnerLockBufferPts);
   if(AdaptiveBEStartATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #68: AdaptiveBEStartATR<=0.0 | "," AdaptiveBEStartATR=",AdaptiveBEStartATR);
   if(AdaptiveBEStartATR>4.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #69: AdaptiveBEStartATR>4.0 | "," AdaptiveBEStartATR=",AdaptiveBEStartATR);
   if(AdaptiveTrailStartATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #70: AdaptiveTrailStartATR<=0.0 | "," AdaptiveTrailStartATR=",AdaptiveTrailStartATR);
   if(AdaptiveTrailStartATR>4.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #71: AdaptiveTrailStartATR>4.0 | "," AdaptiveTrailStartATR=",AdaptiveTrailStartATR);
   if(AdaptiveTrendTrailATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #72: AdaptiveTrendTrailATR<=0.0 | "," AdaptiveTrendTrailATR=",AdaptiveTrendTrailATR);
   if(AdaptiveTrendTrailATR>4.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #73: AdaptiveTrendTrailATR>4.0 | "," AdaptiveTrendTrailATR=",AdaptiveTrendTrailATR);
   if(AdaptiveNormalTrailATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #74: AdaptiveNormalTrailATR<=0.0 | "," AdaptiveNormalTrailATR=",AdaptiveNormalTrailATR);
   if(AdaptiveNormalTrailATR>4.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #75: AdaptiveNormalTrailATR>4.0 | "," AdaptiveNormalTrailATR=",AdaptiveNormalTrailATR);
   if(AdaptiveReversalTrailATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #76: AdaptiveReversalTrailATR<=0.0 | "," AdaptiveReversalTrailATR=",AdaptiveReversalTrailATR);
   if(AdaptiveReversalTrailATR>4.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #77: AdaptiveReversalTrailATR>4.0 | "," AdaptiveReversalTrailATR=",AdaptiveReversalTrailATR);
   if(AdaptiveReversalMinATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #78: AdaptiveReversalMinATR<=0.0 | "," AdaptiveReversalMinATR=",AdaptiveReversalMinATR);
   if(AdaptiveReversalMinATR>2.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #79: AdaptiveReversalMinATR>2.0 | "," AdaptiveReversalMinATR=",AdaptiveReversalMinATR);
   if(SweepMaxCandleExtensionATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #80: SweepMaxCandleExtensionATR<=0.0 | "," SweepMaxCandleExtensionATR=",SweepMaxCandleExtensionATR);
   if(SweepMaxCandleExtensionATR>3.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #81: SweepMaxCandleExtensionATR>3.0 | "," SweepMaxCandleExtensionATR=",SweepMaxCandleExtensionATR);
   if(SweepStopBufferATR<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #82: SweepStopBufferATR<0.0 | "," SweepStopBufferATR=",SweepStopBufferATR);
   if(SweepStopBufferATR>1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #83: SweepStopBufferATR>1.0 | "," SweepStopBufferATR=",SweepStopBufferATR);
   if(SweepMinimumStopATR<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #84: SweepMinimumStopATR<0.0 | "," SweepMinimumStopATR=",SweepMinimumStopATR);
   if(SweepMinimumStopATR>2.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #85: SweepMinimumStopATR>2.0 | "," SweepMinimumStopATR=",SweepMinimumStopATR);
   if(RunnerMinimumHoldSeconds<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #86: RunnerMinimumHoldSeconds<0 | "," RunnerMinimumHoldSeconds=",RunnerMinimumHoldSeconds);
   if(RunnerMinimumHoldSeconds>600)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #87: RunnerMinimumHoldSeconds>600 | "," RunnerMinimumHoldSeconds=",RunnerMinimumHoldSeconds);
   if(BreakEvenAfterPoints <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #88: BreakEvenAfterPoints <= 0.0 | "," BreakEvenAfterPoints=",BreakEvenAfterPoints);
   if(TrailStartPoints <= 0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #89: TrailStartPoints <= 0.0 | "," TrailStartPoints=",TrailStartPoints);
   if(ReportEverySeconds < 5)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #90: ReportEverySeconds < 5 | "," ReportEverySeconds=",ReportEverySeconds);
   if(TelemetryMaxRecords < 10)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #91: TelemetryMaxRecords < 10 | "," TelemetryMaxRecords=",TelemetryMaxRecords);
   if(TelemetryMaxRecords > ALIEN_RECORD_CAP)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #92: TelemetryMaxRecords > ALIEN_RECORD_CAP | "," TelemetryMaxRecords=",TelemetryMaxRecords);
   if(MinClosedTradesForBoost<10)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #93: MinClosedTradesForBoost<10 | "," MinClosedTradesForBoost=",MinClosedTradesForBoost);
   if(MinimumScoreForBoost<MinimumScore)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #94: MinimumScoreForBoost<MinimumScore | "," MinimumScoreForBoost=",MinimumScoreForBoost," MinimumScore=",MinimumScore);
   if(MinimumScoreForBoost>100)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #95: MinimumScoreForBoost>100 | "," MinimumScoreForBoost=",MinimumScoreForBoost);
   if(MinimumWinRateBoost<50.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #96: MinimumWinRateBoost<50.0 | "," MinimumWinRateBoost=",MinimumWinRateBoost);
   if(MinimumWinRateBoost>100.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #97: MinimumWinRateBoost>100.0 | "," MinimumWinRateBoost=",MinimumWinRateBoost);
   if(MinimumProfitFactorBoost<=1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #98: MinimumProfitFactorBoost<=1.0 | "," MinimumProfitFactorBoost=",MinimumProfitFactorBoost);
   if(MaxAdaptiveLot<FixedLot)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #99: MaxAdaptiveLot<FixedLot | "," MaxAdaptiveLot=",MaxAdaptiveLot," FixedLot=",FixedLot);
   if(MaxAdaptiveStopRiskMoney<RiskStopMoney)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #100: MaxAdaptiveStopRiskMoney<RiskStopMoney | "," MaxAdaptiveStopRiskMoney=",MaxAdaptiveStopRiskMoney," RiskStopMoney=",RiskStopMoney);
   if(MaxRiskPercentEquity<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #101: MaxRiskPercentEquity<=0.0 | "," MaxRiskPercentEquity=",MaxRiskPercentEquity);
   if(MaxMarginPercentEquity<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #102: MaxMarginPercentEquity<=0.0 | "," MaxMarginPercentEquity=",MaxMarginPercentEquity);
   if(MaxMarginPercentEquity>100.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #103: MaxMarginPercentEquity>100.0 | "," MaxMarginPercentEquity=",MaxMarginPercentEquity);
   if(MaxBaseMarginPercentEquity<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #104: MaxBaseMarginPercentEquity<=0.0 | "," MaxBaseMarginPercentEquity=",MaxBaseMarginPercentEquity);
   if(MaxBaseMarginPercentEquity>100.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #105: MaxBaseMarginPercentEquity>100.0 | "," MaxBaseMarginPercentEquity=",MaxBaseMarginPercentEquity);
   if(LossStreakPauseAfter<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #106: LossStreakPauseAfter<0 | "," LossStreakPauseAfter=",LossStreakPauseAfter);
   if(LossStreakPauseSeconds<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #107: LossStreakPauseSeconds<0 | "," LossStreakPauseSeconds=",LossStreakPauseSeconds);
   if(MaxOwnPositions<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #108: MaxOwnPositions<1 | "," MaxOwnPositions=",MaxOwnPositions);
   if(MaxOwnPositions>2)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #109: MaxOwnPositions>2 | "," MaxOwnPositions=",MaxOwnPositions);
   if(MinimumScoreForPyramid<MinimumScore)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #110: MinimumScoreForPyramid<MinimumScore | "," MinimumScoreForPyramid=",MinimumScoreForPyramid," MinimumScore=",MinimumScore);
   if(MinimumScoreForPyramid>100)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #111: MinimumScoreForPyramid>100 | "," MinimumScoreForPyramid=",MinimumScoreForPyramid);
   if(PyramidMinProfitMoney<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #112: PyramidMinProfitMoney<=0.0 | "," PyramidMinProfitMoney=",PyramidMinProfitMoney);
   if(MapScanBars<8)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #113: MapScanBars<8 | "," MapScanBars=",MapScanBars);
   if(MapScanBars>80)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #114: MapScanBars>80 | "," MapScanBars=",MapScanBars);
   if(MapMaxDrawZones<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #115: MapMaxDrawZones<1 | "," MapMaxDrawZones=",MapMaxDrawZones);
   if(MapMaxDrawZones>36)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #116: MapMaxDrawZones>36 | "," MapMaxDrawZones=",MapMaxDrawZones);
   if(MapRefreshSeconds<5)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #117: MapRefreshSeconds<5 | "," MapRefreshSeconds=",MapRefreshSeconds);
   if(MapProjectionMinutes<10)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #118: MapProjectionMinutes<10 | "," MapProjectionMinutes=",MapProjectionMinutes);
   if(MapProjectionMinutes>360)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #119: MapProjectionMinutes>360 | "," MapProjectionMinutes=",MapProjectionMinutes);
   if(CleanVisualMaxZones<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #120: CleanVisualMaxZones<1 | "," CleanVisualMaxZones=",CleanVisualMaxZones);
   if(CleanVisualMaxZones>5)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #121: CleanVisualMaxZones>5 | "," CleanVisualMaxZones=",CleanVisualMaxZones);
   if(CleanVisualMinutesBack<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #122: CleanVisualMinutesBack<1 | "," CleanVisualMinutesBack=",CleanVisualMinutesBack);
   if(CleanVisualMinutesBack>60)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #123: CleanVisualMinutesBack>60 | "," CleanVisualMinutesBack=",CleanVisualMinutesBack);
   if(CleanVisualMinutesAhead<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #124: CleanVisualMinutesAhead<1 | "," CleanVisualMinutesAhead=",CleanVisualMinutesAhead);
   if(CleanVisualMinutesAhead>120)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #125: CleanVisualMinutesAhead>120 | "," CleanVisualMinutesAhead=",CleanVisualMinutesAhead);
   if(EqualHighLowTolerancePoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #126: EqualHighLowTolerancePoints<0.0 | "," EqualHighLowTolerancePoints=",EqualHighLowTolerancePoints);
   if((PendingOnlyFromTF!=5 && PendingOnlyFromTF!=15 && PendingOnlyFromTF!=60))
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #127: (PendingOnlyFromTF!=5 && PendingOnlyFromTF!=15 && PendingOnlyFromTF!=60) | "," PendingOnlyFromTF=",PendingOnlyFromTF);
   if(PendingMaxAgeMinutes<5)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #128: PendingMaxAgeMinutes<5 | "," PendingMaxAgeMinutes=",PendingMaxAgeMinutes);
   if(PendingMaxAgeMinutes>1440)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #129: PendingMaxAgeMinutes>1440 | "," PendingMaxAgeMinutes=",PendingMaxAgeMinutes);
   if(PendingScanEverySeconds<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #130: PendingScanEverySeconds<1 | "," PendingScanEverySeconds=",PendingScanEverySeconds);
   if(PendingMaxDistanceATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #131: PendingMaxDistanceATR<=0.0 | "," PendingMaxDistanceATR=",PendingMaxDistanceATR);
   if(PendingMinDistancePoints<1.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #132: PendingMinDistancePoints<1.0 | "," PendingMinDistancePoints=",PendingMinDistancePoints);
   if(PendingSLBufferATR<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #133: PendingSLBufferATR<0.0 | "," PendingSLBufferATR=",PendingSLBufferATR);
   if(PendingRiskCapMoney<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #134: PendingRiskCapMoney<=0.0 | "," PendingRiskCapMoney=",PendingRiskCapMoney);
   if(PendingMinRoomToRisk<0.5)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #135: PendingMinRoomToRisk<0.5 | "," PendingMinRoomToRisk=",PendingMinRoomToRisk);
   if(BrokerWinterUTCOffsetMinutes<(-12*60))
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #136: BrokerWinterUTCOffsetMinutes<(-12*60) | "," BrokerWinterUTCOffsetMinutes=",BrokerWinterUTCOffsetMinutes);
   if(BrokerWinterUTCOffsetMinutes>(14*60))
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #137: BrokerWinterUTCOffsetMinutes>(14*60) | "," BrokerWinterUTCOffsetMinutes=",BrokerWinterUTCOffsetMinutes);
   if(ActiveSessionBonus<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #138: ActiveSessionBonus<0 | "," ActiveSessionBonus=",ActiveSessionBonus);
   if(ActiveSessionBonus>20)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #139: ActiveSessionBonus>20 | "," ActiveSessionBonus=",ActiveSessionBonus);
   if(AMDRangeBarsM5<3)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #140: AMDRangeBarsM5<3 | "," AMDRangeBarsM5=",AMDRangeBarsM5);
   if(AMDRangeBarsM5>24)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #141: AMDRangeBarsM5>24 | "," AMDRangeBarsM5=",AMDRangeBarsM5);
   if(AMDMaxRangeATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #142: AMDMaxRangeATR<=0.0 | "," AMDMaxRangeATR=",AMDMaxRangeATR);
   if(AMDSweepMinPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #143: AMDSweepMinPoints<0.0 | "," AMDSweepMinPoints=",AMDSweepMinPoints);
   if(AMDReclaimPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #144: AMDReclaimPoints<0.0 | "," AMDReclaimPoints=",AMDReclaimPoints);
   if(AMDExpansionMinATR<=0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #145: AMDExpansionMinATR<=0.0 | "," AMDExpansionMinATR=",AMDExpansionMinATR);
   if(AMDExpansionMinATR>4.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #146: AMDExpansionMinATR>4.0 | "," AMDExpansionMinATR=",AMDExpansionMinATR);
   if(AMDBreakBufferPoints<0.0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #147: AMDBreakBufferPoints<0.0 | "," AMDBreakBufferPoints=",AMDBreakBufferPoints);
   if(AMDKeepSweepMinutes<1)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #148: AMDKeepSweepMinutes<1 | "," AMDKeepSweepMinutes=",AMDKeepSweepMinutes);
   if(AMDKeepSweepMinutes>120)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #149: AMDKeepSweepMinutes>120 | "," AMDKeepSweepMinutes=",AMDKeepSweepMinutes);
   if(AMDAlignedBonus<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #150: AMDAlignedBonus<0 | "," AMDAlignedBonus=",AMDAlignedBonus);
   if(AMDAlignedBonus>20)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #151: AMDAlignedBonus>20 | "," AMDAlignedBonus=",AMDAlignedBonus);
   if(AMDOpposingPenalty<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #152: AMDOpposingPenalty<0 | "," AMDOpposingPenalty=",AMDOpposingPenalty);
   if(AMDOpposingPenalty>20)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #153: AMDOpposingPenalty>20 | "," AMDOpposingPenalty=",AMDOpposingPenalty);
   if(TeacherPanelWidth<280)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #154: TeacherPanelWidth<280 | "," TeacherPanelWidth=",TeacherPanelWidth);
   if(TeacherPanelWidth>650)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #155: TeacherPanelWidth>650 | "," TeacherPanelWidth=",TeacherPanelWidth);
   if(TeacherPanelFontSize<7)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #156: TeacherPanelFontSize<7 | "," TeacherPanelFontSize=",TeacherPanelFontSize);
   if(TeacherPanelFontSize>14)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #157: TeacherPanelFontSize>14 | "," TeacherPanelFontSize=",TeacherPanelFontSize);
   if(TeacherPanelCorner<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #158: TeacherPanelCorner<0 | "," TeacherPanelCorner=",TeacherPanelCorner);
   if(TeacherPanelCorner>3)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #159: TeacherPanelCorner>3 | "," TeacherPanelCorner=",TeacherPanelCorner);
   if(TeacherPanelXOffset<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #160: TeacherPanelXOffset<0 | "," TeacherPanelXOffset=",TeacherPanelXOffset);
   if(TeacherPanelXOffset>400)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #161: TeacherPanelXOffset>400 | "," TeacherPanelXOffset=",TeacherPanelXOffset);
   if(TeacherPanelYOffset<0)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #162: TeacherPanelYOffset<0 | "," TeacherPanelYOffset=",TeacherPanelYOffset);
   if(TeacherPanelYOffset>300)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #163: TeacherPanelYOffset>300 | "," TeacherPanelYOffset=",TeacherPanelYOffset);
   if(SessionMapForwardMinutes<2)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #164: SessionMapForwardMinutes<2 | "," SessionMapForwardMinutes=",SessionMapForwardMinutes);
   if(SessionMapForwardMinutes>60)
      Print("ALIEN V11.2 FREEDOM PARAM INVALIDO #165: SessionMapForwardMinutes>60 | "," SessionMapForwardMinutes=",SessionMapForwardMinutes);

   if((RestrictToXAU && StringFind(_Symbol,"XAU")<0) ||
      DailyEquityLossPct<0.0 || DailyEquityLossPct>100.0 ||
      MinimumMarginLevelPct<100.0 || DashboardEveryMs<0 ||
      StructureLookbackBars<4 || StructureLookbackBars>80 ||
      MinSweepPoints<0.0 || SweepReclaimPoints<0.0 || BOSBreakPoints<0.0 ||
      RetestTolerancePoints<0.0 || MOMBreakPoints<0.0 ||
      MinPrevBodyATR<0.0 || MinPrevBodyATR>1.0 ||
      (!EnableLiquiditySweep && !EnableBreakRetest && !EnablePAMomentum &&
       !EnableFVGSetup && !EnableOrderBlockSetup && RequireSetupValidation) ||
      HigherTFScanBars<4 || HigherTFScanBars>100 || MinFVGPoints<=0.0 ||
      OBDisplacementATR<=0.0 || ZoneToleranceATR<0.0 || ZoneToleranceATR>1.0 ||
      MinimumRoomSpreadMult<0.0 || HTFTrendBonus<0 || HTFTrendBonus>20 ||
      RepeatSignalResetPts<0.0 ||
      MaxEntriesPerM1Candle < 0 || MinMsBetweenEntries < 0 || MinMsAfterExit < 0 ||
      MinTicksInCandle < 2 || LongWindowMs <= ShortWindowMs || ShortWindowMs < 50 ||
      MinMillisecondsInBar < 0 || MinimumScore < 1 || MinimumScore > 100 ||
      SweepMinimumEntryScore<MinimumScore || SweepMinimumEntryScore>100 ||
      SweepMinimumWickATR<0.0 || SweepMinimumWickATR>1.0 ||
      SweepMaxEntryDistanceATR<=0.0 || SweepMaxEntryDistanceATR>0.50 ||
      SweepDistanceMidATR<SweepMaxEntryDistanceATR || SweepDistanceMidATR>0.50 ||
      SweepDistanceStrongATR<SweepDistanceMidATR || SweepDistanceStrongATR>0.50 ||
      SweepFreshExtremePoints<0.0 || SweepEventMaxAgeSeconds<1 ||
      SweepEventMaxAgeSeconds>180 || SweepReclaimConfirmTicks<1 ||
      SweepReclaimConfirmTicks>20 || SweepNewExtremeToRefreshPts<=0.0 ||
      SweepMinRoomRiskRatio<0.0 || SweepMinRoomRiskRatio>5.0 ||
      MinMoveOverSpread<=0.0 ||
      FixedLot <= 0.0 || ATRPeriod < 2 || EMAFastPeriod < 2 ||
      EMASlowPeriod <= EMAFastPeriod || MinDirectionalTicks < 1 ||
      MaxSpreadAsATR <= 0.0 || MinimumATRToSpread < 1.0 ||
      RiskStopMoney <= 0.0 || RoundTurnCommissionPerLot < 0.0 ||
      MinNetProfitToHarvest < 0.0 || MaxFloatingLossMoney < 0.0 ||
      TrailATRMultiplier <= 0.0 || RunnerMinTrailPoints <= 0.0 || RunnerLockBufferPts < 0.0 ||
      AdaptiveBEStartATR<=0.0 || AdaptiveBEStartATR>4.0 ||
      AdaptiveTrailStartATR<=0.0 || AdaptiveTrailStartATR>4.0 ||
      AdaptiveTrendTrailATR<=0.0 || AdaptiveTrendTrailATR>4.0 ||
      AdaptiveNormalTrailATR<=0.0 || AdaptiveNormalTrailATR>4.0 ||
      AdaptiveReversalTrailATR<=0.0 || AdaptiveReversalTrailATR>4.0 ||
      AdaptiveReversalMinATR<=0.0 || AdaptiveReversalMinATR>2.0 ||
      SweepMaxCandleExtensionATR<=0.0 || SweepMaxCandleExtensionATR>3.0 ||
      SweepStopBufferATR<0.0 || SweepStopBufferATR>1.0 ||
      SweepMinimumStopATR<0.0 || SweepMinimumStopATR>2.0 ||
      RunnerMinimumHoldSeconds<0 || RunnerMinimumHoldSeconds>600 ||
      BreakEvenAfterPoints <= 0.0 || TrailStartPoints <= 0.0 || ReportEverySeconds < 5 ||
      TelemetryMaxRecords < 10 || TelemetryMaxRecords > ALIEN_RECORD_CAP ||
      MinClosedTradesForBoost<10 || MinimumScoreForBoost<MinimumScore ||
      MinimumScoreForBoost>100 || MinimumWinRateBoost<50.0 ||
      MinimumWinRateBoost>100.0 || MinimumProfitFactorBoost<=1.0 ||
      MaxAdaptiveLot<FixedLot || MaxAdaptiveStopRiskMoney<RiskStopMoney ||
      MaxRiskPercentEquity<=0.0 || MaxMarginPercentEquity<=0.0 ||
      MaxMarginPercentEquity>100.0 || MaxBaseMarginPercentEquity<=0.0 ||
      MaxBaseMarginPercentEquity>100.0 || LossStreakPauseAfter<0 ||
      LossStreakPauseSeconds<0 || MaxOwnPositions<1 || MaxOwnPositions>2 ||
      MinimumScoreForPyramid<MinimumScore || MinimumScoreForPyramid>100 ||
      PyramidMinProfitMoney<=0.0 || MapScanBars<8 || MapScanBars>80 ||
      MapMaxDrawZones<1 || MapMaxDrawZones>36 || MapRefreshSeconds<5 ||
      MapProjectionMinutes<10 || MapProjectionMinutes>360 ||
      CleanVisualMaxZones<1 || CleanVisualMaxZones>5 ||
      CleanVisualMinutesBack<1 || CleanVisualMinutesBack>60 ||
      CleanVisualMinutesAhead<1 || CleanVisualMinutesAhead>120 ||
      EqualHighLowTolerancePoints<0.0 ||
      (PendingOnlyFromTF!=5 && PendingOnlyFromTF!=15 && PendingOnlyFromTF!=60) ||
      PendingMaxAgeMinutes<5 || PendingMaxAgeMinutes>1440 ||
      PendingScanEverySeconds<1 || PendingMaxDistanceATR<=0.0 ||
      PendingMinDistancePoints<1.0 || PendingSLBufferATR<0.0 ||
      PendingRiskCapMoney<=0.0 || PendingMinRoomToRisk<0.5 ||
      BrokerWinterUTCOffsetMinutes<(-12*60) || BrokerWinterUTCOffsetMinutes>(14*60) ||
      ActiveSessionBonus<0 || ActiveSessionBonus>20 ||
      AMDRangeBarsM5<3 || AMDRangeBarsM5>24 ||
      AMDMaxRangeATR<=0.0 || AMDSweepMinPoints<0.0 ||
      AMDReclaimPoints<0.0 || AMDExpansionMinATR<=0.0 ||
      AMDExpansionMinATR>4.0 || AMDBreakBufferPoints<0.0 ||
      AMDKeepSweepMinutes<1 || AMDKeepSweepMinutes>120 ||
      AMDAlignedBonus<0 || AMDAlignedBonus>20 ||
      AMDOpposingPenalty<0 || AMDOpposingPenalty>20 ||
      TeacherPanelWidth<280 || TeacherPanelWidth>650 ||
      TeacherPanelFontSize<7 || TeacherPanelFontSize>14 ||
      TeacherPanelCorner<0 || TeacherPanelCorner>3 ||
      TeacherPanelXOffset<0 || TeacherPanelXOffset>400 ||
      TeacherPanelYOffset<0 || TeacherPanelYOffset>300 ||
      SessionMapForwardMinutes<2 || SessionMapForwardMinutes>60)
   {
      Print("ALIEN V11.2 FREEDOM: inicializacao recusada. Veja acima o nome e o valor do parametro incorreto.");
      Print("SOLUCAO: Inputs > Resetar para os padroes da V10.89; depois recoloque alteracoes individualmente.");
      return INIT_PARAMETERS_INCORRECT;
   }

   mapPrefix="ALIEN_V1089_MAP_"+IntegerToString((long)ExpertMagic)+"_";
   sessionPrefix="ALIEN_V1089_SESSION_"+IntegerToString((long)ExpertMagic)+"_";
   teacherPrefix="ALIEN_V1089_TEACHER_"+IntegerToString((long)ExpertMagic)+"_";
   trade.SetExpertMagicNumber(ExpertMagic);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   hFastM1 = iMA(_Symbol, PERIOD_M1, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hSlowM1 = iMA(_Symbol, PERIOD_M1, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hFastM5 = iMA(_Symbol, PERIOD_M5, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hSlowM5 = iMA(_Symbol, PERIOD_M5, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hAtrM1  = iATR(_Symbol, PERIOD_M1, ATRPeriod);
   hFastM15 = iMA(_Symbol,PERIOD_M15,EMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   hSlowM15 = iMA(_Symbol,PERIOD_M15,EMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   hFastH1 = iMA(_Symbol,PERIOD_H1,EMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   hSlowH1 = iMA(_Symbol,PERIOD_H1,EMASlowPeriod,0,MODE_EMA,PRICE_CLOSE);
   hAtrM5 = iATR(_Symbol,PERIOD_M5,ATRPeriod);
   hAtrM15 = iATR(_Symbol,PERIOD_M15,ATRPeriod);
   hAtrH1 = iATR(_Symbol,PERIOD_H1,ATRPeriod);
   if(hFastM15==INVALID_HANDLE || hSlowM15==INVALID_HANDLE ||
      hFastH1==INVALID_HANDLE || hSlowH1==INVALID_HANDLE ||
      hAtrM5==INVALID_HANDLE || hAtrM15==INVALID_HANDLE || hAtrH1==INVALID_HANDLE ||
      hFastM1 == INVALID_HANDLE || hSlowM1 == INVALID_HANDLE ||
      hFastM5 == INVALID_HANDLE || hSlowM5 == INVALID_HANDLE ||
      hAtrM1 == INVALID_HANDLE)
   {
      Print("ALIEN V11.2 FREEDOM: erro ao criar EMA/ATR.");
      return INIT_FAILED;
   }

   ArrayInitialize(tickTimes, 0);
   ArrayInitialize(tickPrices, 0.0);
   RefreshDailyStats();
   RefreshDailyEquityBaseline();
   if(EnableTelemetry)
      Print("ALIEN V11.2 FREEDOM: Inicio diario de equity = ",DoubleToString(dayOpeningEquity,2));

   if(WriteCsvJournal)
   {
      string fileName = "ALIEN_V10_88_" + _Symbol + "_" +
                        IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
      logFile = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_CSV |
                        FILE_COMMON | FILE_SHARE_READ, ';');
      if(logFile != INVALID_HANDLE)
      {
         if(FileSize(logFile) == 0)
            FileWrite(logFile, "time", "symbol", "magic", "event", "details", "value");
         FileSeek(logFile, 0, SEEK_END);
      }
      else Print("ALIEN V11.2 FREEDOM: nao conseguiu abrir diario CSV. Erro=", GetLastError());
   }

   if(EnableTelemetry)
   {
      string key = _Symbol + "_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) +
                   "_" + IntegerToString((long)ExpertMagic);
      string session=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
      StringReplace(session,".","");
      StringReplace(session,":","");
      StringReplace(session," ","_");
      eventFileName = "ALIEN_V1089_EVENTS_" + key + "_" + session + ".csv";
      tradesFileName = "ALIEN_V1089_TRADES_" + key + "_" + session + ".csv";
      reportFileName = "ALIEN_V1089_REPORT_" + key + "_" + session + ".txt";
      tradesFile = FileOpen(tradesFileName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,';');
      if(tradesFile != INVALID_HANDLE)
      {
         if(FileSize(tradesFile)==0)
            FileWrite(tradesFile,"position_id","entrada_hora","saida_hora","duracao_s","lado",
                      "score","p_pressao","p_impulso","p_curto","p_candle","p_ema","p_custo",
                      "spread_pts","atr_pts","mov_curto_pts","mov_longo_pts","pressao_pct",
                      "ema_m1","ema_m5","motivo_saida","liquido_conta","lote",
                      "setup","nivel_estrutura","ema_m15","ema_h1","zona_htf","dist_zona_pts","espaco_liquidez_pts",
                      "sessao_entrada","fase_amd_entrada");
         FileSeek(tradesFile,0,SEEK_END);
      }
      else Print("ALIEN V11.2 FREEDOM: falha abrindo CSV de operacoes: ",GetLastError());

      RecoverOpenPositions();
      WriteReport();
      Print("ALIEN TELEMETRIA: relatorio MQL5/Files/",reportFileName);
      Print("ALIEN TELEMETRIA: planilha MQL5/Files/",tradesFileName);
   }

   EventSetTimer(5);
   AlienApplyTheme();
   AlienRefreshSessionAMD(true);
   AlienDrawSessionMap();
   if(EnableInstitutionalMap) RefreshInstitutionalMap(true);
   if(EnableZonePendingOrders)
      Print("ALIEN V11.2 FREEDOM: limit pendente ATIVA, valida somente em DEMO; sem garantia de execucao/ganho.");
   Print("ALIEN V11.2 FREEDOM MULTI CICLOS iniciado em ", _Symbol,
         " | 0.01 lote (configuravel), MULTIPLAS entradas por M1, GUARDA de equity ativa se configurada.");
   Print("ALIEN V11.2 FREEDOM HORARIOS: ",RestrictNewTradesToWindows?"JANELAS RESTRITAS":"LIVRE (24H EM DIAS COM MERCADO ABERTO)",
         " | Sessoes informativas: ",UseSessionEngine?"ATIVAS":"OFF",
         " | Sweep-only: ",SweepOnlyTradeMode?"ATIVO":"OFF");
   Print("Escalonamento condicionado: ",EnableEvidenceScaling?"ATIVO":"DESATIVADO",
         " | Piramide: ",EnablePyramid?"ATIVA":"DESATIVADA");
   Print("Entradas por candle: ", MaxEntriesPerM1Candle == 0 ? "SEM LIMITE" : IntegerToString(MaxEntriesPerM1Candle),
         " | Posicoes simultaneas: 1 | Intervalo minimo(ms): ", MinMsBetweenEntries);
   Print("Modo saida: ",StopOnlyRunnerMode ? "STOP RUNNER (SL inicial e movel)" : "LEGADO");
   Print("Aviso: nao e possivel garantir lucro em cada candle nem evitar perdas.");
   lastReason = "LAB pronto: analisando ticks.";
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hFastM1 != INVALID_HANDLE) IndicatorRelease(hFastM1);
   if(hSlowM1 != INVALID_HANDLE) IndicatorRelease(hSlowM1);
   if(hFastM5 != INVALID_HANDLE) IndicatorRelease(hFastM5);
   if(hSlowM5 != INVALID_HANDLE) IndicatorRelease(hSlowM5);
   if(hAtrM1  != INVALID_HANDLE) IndicatorRelease(hAtrM1);
   if(hFastM15!= INVALID_HANDLE) IndicatorRelease(hFastM15);
   if(hSlowM15!= INVALID_HANDLE) IndicatorRelease(hSlowM15);
   if(hFastH1 != INVALID_HANDLE) IndicatorRelease(hFastH1);
   if(hSlowH1 != INVALID_HANDLE) IndicatorRelease(hSlowH1);
   if(hAtrM5 != INVALID_HANDLE) IndicatorRelease(hAtrM5);
   if(hAtrM15!= INVALID_HANDLE) IndicatorRelease(hAtrM15);
   if(hAtrH1 != INVALID_HANDLE) IndicatorRelease(hAtrH1);
   EventKillTimer();
   if(EnableTelemetry) WriteReport();
   if(CancelPendingWhenChartRemoved)
   {
      for(int i=OrdersTotal()-1;i>=0;i--)
      {
         ulong ticket=OrderGetTicket(i);
         if(ticket==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol ||
            (ulong)OrderGetInteger(ORDER_MAGIC)!=ExpertMagic) continue;
         ENUM_ORDER_TYPE t=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(t==ORDER_TYPE_BUY_LIMIT || t==ORDER_TYPE_SELL_LIMIT)
            MapCancelPending(ticket,"EA encerrado/removido");
      }
   }
   if(tradesFile != INVALID_HANDLE) FileClose(tradesFile);
   if(logFile != INVALID_HANDLE) FileClose(logFile);
   ObjectDelete(0,"ALIEN_V1050_LEGACY_ZONE_"+IntegerToString((long)ExpertMagic));
   if(mapPrefix!="") ObjectsDeleteAll(0,mapPrefix);
   if(sessionPrefix!="") ObjectsDeleteAll(0,sessionPrefix);
   if(teacherPrefix!="") ObjectsDeleteAll(0,teacherPrefix);
   AlienRestoreTheme();
   Comment("");
}

//+------------------------------------------------------------------+
// SO em hedging: 2a posicao opcional somente quando a primeira esta
// com stop acima do preco de entrada JA cobrindo comissao configurada.
// Nao existe garantia contra slippage e gaps.
bool ProtectedPositionForAddon(int direction)
{
   if(!EnablePyramid ||
      AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return false;
   if(OurPositionCount()!=1 || OurPositionCount()>=MaxOwnPositions)
      return false;
   int allSymbolPositions=0;
   for(int k=PositionsTotal()-1;k>=0;k--)
   {
      ulong other=PositionGetTicket(k);
      if(other>0 && PositionGetString(POSITION_SYMBOL)==_Symbol)
         allSymbolPositions++;
   }
   if(allSymbolPositions!=1) return false;
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=ExpertMagic) continue;
      int d=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1;
      if(d!=direction) return false;
      double v=PositionGetDouble(POSITION_VOLUME);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double floating=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)
                      -RoundTurnCommissionPerLot*v;
      if(sl<=0.0 || floating<PyramidMinProfitMoney) return false;
      double moneyPt=MoneyPerPoint(d>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,v,entry);
      if(moneyPt<=0.0) return false;
      double breakevenPts=(RoundTurnCommissionPerLot*v)/moneyPt + 2.0;
      if(d*(sl-entry)<breakevenPts*_Point) return false;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.time_msc <= 0) return;
   if(BeginningOfDay() != statsDayStart) RefreshDailyStats();

   datetime newBar = iTime(_Symbol, PERIOD_M1, 0);
   if(newBar == 0) return;
   if(newBar!=lastSessionProcessedBar)
      AlienRefreshSessionAMD();
   if(newBar != barStart)
   {
      barStart = newBar;
      barOpen = iOpen(_Symbol, PERIOD_M1, 0);
      if(barOpen <= 0.0) barOpen = tick.bid;
      ticksInBar = 0;
      barFirstTickMs = tick.time_msc;
      enteredThisBar = OneEntryPerM1Candle && WasAlreadyTradedThisBar(barStart);
      entriesThisBar = 0;
      lastScore = 0;
      ++candlesObserved;
   }

   ++ticksInBar;
   AddTick(tick);
   ObserveSweepEvent(tick,newBar);
   TickMetrics shortM = MeasureTicks(tick.time_msc, ShortWindowMs);
   TickMetrics longM  = MeasureTicks(tick.time_msc, LongWindowMs);

   if(cachedMarketBar != newBar || !cachedMarketReady)
   {
      cachedMarketReady=GetMarketFilters(cachedATRPoints,cachedTrendM1,cachedTrendM5);
      if(cachedMarketReady) cachedMarketBar=newBar;
   }
   double atrPts=cachedATRPoints;
   int trendM1=cachedTrendM1, trendM5=cachedTrendM5;
   bool indicatorsReady=cachedMarketReady;
   UpdateSweepDiagnostics(tick,shortM,atrPts,trendM1,trendM5);

   ManageOpenPosition(tick, shortM, atrPts);
   // Sempre gerenciar posicoes existentes antes de examinar novas entradas.
   if(!NewEntriesAllowedBySupervisor())
   {
      lastReason=supervisorMessage;
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }

   if(!AlienSessionEntryAllowed(TimeCurrent()))
   {
      lastReason=AlienInNYBlackout(TimeCurrent())?
        "Horario de cautela NY (sem calendario automatico).":
        "Fora da janela habilitada de operacoes.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }

   if(SweepOnlyTradeMode && BlockIfOtherPendingOnSymbol &&
      SymbolHasForeignPendingOrders())
   {
      lastReason="Existe pendente de outro EA/manual no XAUUSD. Verifique e remova.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(EnableZonePendingOrders && MapPendingOrdersCount()>0)
   {
      lastReason="Ordem antecipada ativa: aguardando toque/cancelamento.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(EnableZonePendingOrders && !EnableMarketEntriesAlongsidePending)
   {
      lastReason="Modo exclusivo de ordens antecipadas nas zonas.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(OneEntryPerM1Candle && enteredThisBar)
   {
      lastReason = "Modo 1/candle: ja entrou neste M1.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   if(MaxEntriesPerM1Candle > 0 && entriesThisBar >= MaxEntriesPerM1Candle)
   {
      lastReason = "Limite configurado de entradas por M1 atingido.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   // No arbitrary per-candle limit when MaxEntriesPerM1Candle = 0.
   // Prevent synchronous duplicate orders / instant churn after close.
   if(lastEntryTimeMsc > 0 && tick.time_msc - lastEntryTimeMsc < MinMsBetweenEntries)
   {
      lastReason = "Aguardando intervalo tecnico entre entradas.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   if(lastExitTimeMsc > 0 && tick.time_msc - lastExitTimeMsc < MinMsAfterExit)
   {
      lastReason = "Aguardando novo tick apos a ultima saida.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   // Perdas em sequencia: pausa curta para nao insistir no mesmo mercado ruim.
   if(LossStreakPauseAfter>0 && LossStreakPauseSeconds>0 &&
      currentLossStreak>=LossStreakPauseAfter &&
      lastCompletedAt>0 && (TimeCurrent()-lastCompletedAt)<LossStreakPauseSeconds)
   {
      lastReason="Pausa curta: sequencia de perdas. Retorno automatico.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   bool existingPosition=SymbolHasAnyPosition();
   bool candidateAddon=existingPosition && EnablePyramid && !DisablePyramidInV10;
   if(existingPosition && !candidateAddon)
   {
      lastReason = "Posicao ja aberta no simbolo: gerenciando.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   if(!indicatorsReady)
   {
      lastReason = "Aguardando historico EMA/ATR M1/M5.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   if(ticksInBar < MinTicksInCandle || tick.time_msc - barFirstTickMs < MinMillisecondsInBar)
   {
      lastReason = "Lendo primeiros ticks do candle.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   double volume = ValidVolume(FixedLot);
   if(!EntryMarketSafe(tick, atrPts, volume))
   {
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   if(longM.changes < MinDirectionalTicks)
   {
      lastReason = "Aguardando mais ticks direcionais.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }

   // Em REVERSOES de liquidez, o impulso longo pode continuar apontando
   // para a DIRECAO DA VARREDURA, enquanto os ticks curtos ja recuperaram.
   // Por isso o evento recente + impulso curto tem prioridade no sweep-only.
   bool freshBuy = EnableLiquiditySweep && RequireObservedSweepEvent &&
                   SweepEventFresh(1,tick.time_msc) &&
                   shortM.movePoints>=MinImpulsePoints;
   bool freshSell= EnableLiquiditySweep && RequireObservedSweepEvent &&
                   SweepEventFresh(-1,tick.time_msc) &&
                   shortM.movePoints<=-MinImpulsePoints;
   int direction = 0;
   if(freshBuy && !freshSell) direction=1;
   else if(freshSell && !freshBuy) direction=-1;
   else if(longM.movePoints >= MinImpulsePoints) direction = 1;
   else if(longM.movePoints <= -MinImpulsePoints) direction = -1;
   else if(shortM.movePoints >= MinImpulsePoints) direction = 1;
   else if(shortM.movePoints <= -MinImpulsePoints) direction = -1;
   bool freshReversal=(direction>0 && freshBuy) || (direction<0 && freshSell);
   double relevantPressure=freshReversal ? shortM.directionPercent : longM.directionPercent;

   if(direction == 0 || relevantPressure < MinDirectionalPercent)
   {
      lastReason = "Impulso ou pressao direcional insuficientes.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   if(MathMax(longM.movePoints*direction,shortM.movePoints*direction) <
      ((tick.ask-tick.bid)/_Point)*MinMoveOverSpread)
   {
      lastReason = "Impulso abaixo do custo do spread.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(RequireTickAlignment && shortM.movePoints * direction <= 0.0)
   {
      lastReason = "Movimento curto nao confirmou o impulso.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }
   // In the previous versions a high directional percentage could refer to
   // the OPPOSITE impulse when entry direction came from the short window.
   if(longM.movePoints*direction < -MinImpulsePoints*0.5 && !freshReversal)
   {
      lastReason="Impulso longo contradiz a direcao da entrada.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if((direction == 1 && !AllowBuy) || (direction == -1 && !AllowSell))
   {
      lastReason = "Direcao desativada nos parametros.";
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }

   double spreadPts = (tick.ask-tick.bid)/_Point;
   double candleDelta = (tick.bid - barOpen)/_Point;
   // Contexto H1/M15 calculado apenas na atualizacao das zonas.
   // Price/score is updated each tick, expensive M5/M15/H1 zone scan only
   // every 2 seconds or when direction flips. Distance is refreshed per tick.
   if(lastZoneScanMsc==0 || tick.time_msc-lastZoneScanMsc>=2000 ||
      lastZoneScanDir!=direction)
   {
      higherTrendM15=TrendFromHandles(hFastM15,hSlowM15);
      higherTrendH1=TrendFromHandles(hFastH1,hSlowH1);
      double zl0=0.0,zh0=0.0,zd0=1e9;
      string zone0="SEM_ZONA";
      cachedZoneId=NearestHTFZone(direction,tick.bid,atrPts,zl0,zh0,zd0,zone0);
      lastZoneName=zone0;lastZoneLower=zl0;lastZoneUpper=zh0;
      lastOpposingRoomPts=RoomToOpposingLiquidity(direction,tick.bid);
      lastZoneScanMsc=tick.time_msc;
      lastZoneScanDir=direction;
      if(!EnableInstitutionalMap) DrawProfessorZone();
   }
   double zl=lastZoneLower,zh=lastZoneUpper;
   double zd=(cachedZoneId>0 ? MathMax(0.0,MathMax(zl-tick.bid,tick.bid-zh))/_Point : 1e9);
   int zoneId=cachedZoneId;
   lastZoneDistance=zd;
   htfDescription=StringFormat("M15=%d H1=%d zona=%s distancia=%.1f room=%.1f",
      higherTrendM15,higherTrendH1,lastZoneName,zd,lastOpposingRoomPts);

   // Avoid buying directly below a recent high or selling just above a low.
   // It does not require all candles to be traded: some have bad economics.
   if(UseHigherTimeframes && lastOpposingRoomPts<spreadPts*MinimumRoomSpreadMult)
   {
      lastReason="Bloqueio: pouca margem de movimento ate liquidez contraria.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }

   TickMetrics scoringLong=longM;
   if(freshReversal && longM.movePoints*direction<0.0)
      scoringLong.directionPercent=shortM.directionPercent;
   lastScore = ScoreSignal(direction, shortM, scoringLong, spreadPts, atrPts,
                           trendM1, trendM5, candleDelta);
   if(UseHigherTimeframes)
   {
      if(higherTrendM15==direction) lastScore+=HTFTrendBonus/2;
      if(higherTrendH1==direction) lastScore+=HTFTrendBonus/2;
      if(higherTrendM15==-direction && higherTrendH1==-direction)
         lastScore-=HTFTrendBonus;
      if(zoneId>0 && zd<=atrPts*ZoneToleranceATR) lastScore+=5;
      lastScore=(int)MathMax(0,MathMin(100,lastScore));
   }
   // Sessao e AMD entram como CONTEXTO, nao como sinal de certeza.
   if(UseSessionEngine && ScoreSessionContext && sessionCode!=3)
      lastScore=(int)MathMin(100,lastScore+ActiveSessionBonus);
   if(UseAMDContext && amdPhaseCode>=2)
   {
      if(amdBias==direction) lastScore=(int)MathMin(100,lastScore+AMDAlignedBonus);
      else if(amdBias==-direction) lastScore=(int)MathMax(0,lastScore-AMDOpposingPenalty);
   }
   if(BlockOppositeConfirmedAMD && amdPhaseCode==3 && amdBias==-direction)
   {
      lastReason="AMD: direcao contraria a expansao confirmada, entrada vetada.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(lastScore < MinimumScore)
   {
      lastReason = StringFormat("Score %d abaixo de %d. Aguardando.", lastScore, MinimumScore);
      Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
      return;
   }

   double setupLevel=0.0;
   string setupExplanation="";
   int signalSetup=SelectSetup(direction,tick,atrPts,trendM1,trendM5,
                               shortM,zoneId,zl,zh,zd,atrPts*ZoneToleranceATR,
                               setupLevel,setupExplanation);
   if(RequireSetupValidation && signalSetup==0)
   {
      lastSetupInfo=setupExplanation;
      if(SweepOnlyTradeMode && StringFind(setupExplanation,"Sweep")>=0)
         lastReason=setupExplanation;
      else
         lastReason="Aguardando SWEEP confirmado ou BOS com reteste (sem entrar no impulso).";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   // V10.89: sinais de PA, BOS, FVG e OB ainda podem ser DESENHADOS;
   // nao podem virar ordens enquanto o experimento SweepOnly estiver ativo.
   if(SweepOnlyTradeMode && signalSetup!=1)
   {
      lastReason="DATA DRIVEN: aguardando LIQUIDITY SWEEP validado.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(signalSetup==1 && atrPts>0.0 &&
      direction*(tick.bid-barOpen)/_Point > atrPts*SweepMaxCandleExtensionATR)
   {
      lastReason="Sweep valido, mas candle ja avancou demais: entrada tardia evitada.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   if(signalSetup==1 && lastScore<SweepMinimumEntryScore)
   {
      lastReason=StringFormat("Sweep: score tecnico %d/%d insuficiente.",
                              lastScore,SweepMinimumEntryScore);
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   ulong activeSweepSeq=direction>0?sweepSeqBuy:sweepSeqSell;
   if(signalSetup==1 && RequireObservedSweepEvent &&
      (activeSweepSeq==0 || activeSweepSeq==lastTradedSweepSeq))
   {
      lastReason="Sweep ja negociado: aguardo evento novo no preco.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   // Uma varredura nova, comprovadamente observada, pode ocorrer perto da
   // mesma regiao. Sem evento novo, a anti-reentrada continua valendo.
   bool distinctSweep=(signalSetup==1 &&
                       RequireObservedSweepEvent && activeSweepSeq>0 &&
                       activeSweepSeq!=lastTradedSweepSeq);
   if(!distinctSweep && signalSetup>0 && signalSetup==lastEntrySetupId && direction==lastEntryDir &&
      MathAbs(tick.bid-lastEntryPrice)/_Point<RepeatSignalResetPts &&
      MathAbs(setupLevel-lastEntryZoneLevel)/_Point<RepeatSignalResetPts)
   {
      lastReason="Mesmo sinal e mesma zona: aguardando deslocamento novo.";
      Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
      return;
   }
   lastSetup=signalSetup;
   lastSetupLevel=setupLevel;
   lastSetupInfo=setupExplanation;

   if(candidateAddon)
   {
      if(lastScore < MinimumScoreForPyramid ||
         trendM1!=direction || trendM5!=direction ||
         !ProtectedPositionForAddon(direction))
      {
         lastReason="Adicao bloqueada: 1a posicao nao protegida ou sinal fraco.";
         Dashboard(tick,longM,shortM,atrPts,trendM1,trendM5);
         return;
      }
   }
   ++opportunitiesFound;
   if(lastSetup>=1 && lastSetup<=5) setupSignals[lastSetup]++;
   bool executed=SendEntry(direction, tick, lastScore, spreadPts,atrPts,
                           shortM,longM,trendM1,trendM5,candidateAddon);
   if(executed && signalSetup==1)
   {
      lastTradedSweepSeq=direction>0?sweepSeqBuy:sweepSeqSell;
      lastSweepTradeBar=barStart;
      lastSweepTradeDirection=direction;
      lastSweepTradeLevel=setupLevel;
      lastSweepTradeExtreme=direction>0?sweepExtremeBuy:sweepExtremeSell;
   }
   if(!executed && PrintDetailedReasons)
      Print("ALIEN V11.2 FREEDOM: sinal elegivel, mas entrada nao executada: ", lastReason);

   Dashboard(tick, longM, shortM, atrPts, trendM1, trendM5);
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if((ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != ExpertMagic) return;

   ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   double net = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) +
                HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                HistoryDealGetDouble(trans.deal, DEAL_FEE);

   if(e == DEAL_ENTRY_IN && EnableZonePendingOrders)
   {
      ulong pid=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
      ulong ot=(ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER);
      if(FindSample(pid)<0 && HistoryOrderSelect(ot))
      {
         ENUM_ORDER_TYPE typ=(ENUM_ORDER_TYPE)HistoryOrderGetInteger(ot,ORDER_TYPE);
         if(typ==ORDER_TYPE_BUY_LIMIT || typ==ORDER_TYPE_SELL_LIMIT)
         {
            MapOnFilledDeal(trans.deal);
            ++entriesSession;
            lastEntryTimeMsc=(long)HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
         }
      }
   }
   if(e == DEAL_ENTRY_OUT || e == DEAL_ENTRY_OUT_BY || e == DEAL_ENTRY_INOUT)
   {
      lastExitTimeMsc = (long)HistoryDealGetInteger(trans.deal, DEAL_TIME_MSC);
      ++exitsSession;
      LogEvent("DEAL_EXIT", StringFormat("deal=%I64u", trans.deal), net);
   }
   RefreshDailyStats();
   ReconcileTrades();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   RefreshDailyEquityBaseline();
   AlienRefreshSessionAMD();
   static datetime lastDrawnSession=0;
   if(TimeCurrent()-lastDrawnSession>=MapRefreshSeconds)
   {
      lastDrawnSession=TimeCurrent();
      AlienDrawSessionMap();
   }
   if(EnableInstitutionalMap) RefreshInstitutionalMap();
   if(EnableZonePendingOrders)
   {
      MapMaintainPendingOrders();
      static datetime lastPendingScan=0;
      if(TimeCurrent()-lastPendingScan>=PendingScanEverySeconds)
      {
         lastPendingScan=TimeCurrent();
         MapMaybePlacePending();
      }
   }
   if(EnableTelemetry)
   {
      static datetime lastTelemetryRun=0;
      if(TimeCurrent()-lastTelemetryRun>=ReportEverySeconds)
      {
         lastTelemetryRun=TimeCurrent();
         RefreshDailyStats();
         ReconcileTrades();
         WriteReport();
      }
   }
}
//+------------------------------------------------------------------+
