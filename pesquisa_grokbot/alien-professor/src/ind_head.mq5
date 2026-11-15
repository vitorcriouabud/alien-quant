//+------------------------------------------------------------------+
//| ALIEN_PROFESSOR.mq5                                              |
//| Indicador de APOIO À DECISÃO para operador manual.               |
//| NÃO envia ordens, NÃO fecha posições, NÃO usa AlgoTrading.       |
//| XAUUSD e índices (.US500Cash, .USTECHCash, .DE40Cash)            |
//+------------------------------------------------------------------+
#property copyright "ALIEN - Vitor Lima"
#property version   "1.00"
#property description "Professor: contexto H1, liquidez (PDH/PDL, Ásia, Londres, semana, topos/fundos iguais), varridas, BOS, FVG, volume, nota 0-10, plano com lote pelo risco e disciplina do dia. Só ajuda - quem decide é você. Nunca opera."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

