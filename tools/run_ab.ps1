# A/B em ticks reais, janela longa, instalacao ISOLADA (nao toca no MT5 ao vivo)
$ErrorActionPreference = "Continue"
$tools = "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools"
$exp = "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Experts"
$from = "2026.10.21"
$to = "2026.11.06"

& "$tools\Run-Backtest.ps1" -ExpertPath "$exp\ALIEN_V11_2_GOAT_10K.mq5" -FromDate $from -ToDate $to `
    -ReportName "EXP_019_V11_2_GOAT_AB" -ExpId "EXP-019" -StrategyName "ALIEN V11.2 GOAT 10K (A/B janela longa)"

& "$tools\Run-Backtest.ps1" -ExpertPath "$exp\ALIEN_V12_1_INSTITUTIONAL.mq5" -FromDate $from -ToDate $to `
    -ReportName "EXP_020_V12_1_AB" -ExpId "EXP-020" -StrategyName "ALIEN V12.1 INSTITUTIONAL (A/B janela longa)"

Write-Host "AB CONCLUIDO"
