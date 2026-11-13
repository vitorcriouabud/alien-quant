#requires -Version 5.1
# ALIEN GOAT5K - EXECUTION BENCHMARK: ORDENS SIMULADAS NO STRATEGY TESTER (0 ORDENS REAIS)
param(
 [string]$FromDate="2026.10.21",
 [string]$ToDate="2026.11.12",
 [int]$Deposit=5000,
 [int]$Leverage=100
)
$ErrorActionPreference="Stop"
if($Deposit -ne 5000){throw "Deposito do testador deve ser USD 5000."}
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source=Join-Path $repo "MQL5\Experts\ALIEN_GOAT5K_EXECUTION_TESTER.mq5"
$profile=Join-Path $repo "MQL5\Profiles\Tester\ALIEN_GOAT5K_EXECUTION_TESTER.set"
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
foreach($item in @($source,$profile,$runner)){
 if(-not(Test-Path -LiteralPath $item -PathType Leaf)){throw "Nao existe $item"}
}
$install=if(Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe"){"C:\ALIEN_TEST_MT5"}else{Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"}
$testExe=Join-Path $install "terminal64.exe"
if(-not(Test-Path -LiteralPath $testExe)){throw "MT5 ISOLADO nao instalado em $install"}
Write-Host "ALIEN GOAT5K EXECUTION: Strategy Tester MetaQuotes-Demo; NUNCA GOAT REAL." -ForegroundColor Yellow
$procs=@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
    Where-Object {$_.ExecutablePath -and $_.ExecutablePath -ieq $testExe})
foreach($item in $procs){
 Write-Host "Fechando somente MT5 de testes PID $($item.ProcessId)" -ForegroundColor Yellow
 $p=Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
 if($null -ne $p){
  if($p.MainWindowHandle -ne 0){[void]$p.CloseMainWindow()}
  Start-Sleep -Seconds 2
  $p=Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
  if($null -ne $p){Stop-Process -Id $item.ProcessId -Force}
 }
}
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$name="ALIEN_GOAT5K_EXECUTION_"+$stamp
$work=Join-Path $repo ("results\"+$name)
$zipDir=Join-Path $repo "PACOTES_MT5"
New-Item -ItemType Directory -Force -Path $work,$zipDir | Out-Null
$csvName=$name+"_EVENTS.csv"
$frozenSet=Join-Path $work ($name+".set")
$lines=@(Get-Content -LiteralPath $profile -Encoding UTF8 | ForEach-Object {
 if($_ -match "^CSVFileName="){"CSVFileName="+$csvName}else{$_}
})
if(@($lines|Where-Object {$_ -match "^CSVFileName=.*\|\|"}).Count -gt 0){
 throw "Input string CSV mal formatado"
}
$enabled=@($lines|Where-Object {$_ -match "^EnableTesterOrders=true\|\|"})
if($enabled.Count -ne 1){throw "Preset nao tem execucao no TESTER ativada"}
[IO.File]::WriteAllLines($frozenSet,[string[]]$lines,[Text.Encoding]::ASCII)
Write-Host "Compilando e simulando ordens de mercado no testador..." -ForegroundColor Cyan
$parameters=@{
 ExpertPath=$source;Symbol="XAUUSD";Period="M1";Model=4;
 FromDate=$FromDate;ToDate=$ToDate;Deposit=$Deposit;Leverage=$Leverage;
 ReportName=$name;ExpId=$name;StrategyName="ALIEN_EXEC_TESTER";
 PresetPath=$frozenSet;NoCsv=$true
}
$started=Get-Date
& $runner @parameters
if($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null){
 throw "Falha no runner: exitcode=$LASTEXITCODE"
}
$ex5=[IO.Path]::ChangeExtension($source,".ex5")
if(-not(Test-Path -LiteralPath $ex5)){throw "EX5 nao foi compilado"}
$reportLocations=@(
 (Join-Path $install ($name+".htm")),
 (Join-Path $install ($name+".html")),
 (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".htm")),
 (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".html"))
)
$report=$reportLocations|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
if(-not $report){throw "Relatorio MT5 nao encontrado. Veja log do agente."}
$reportCopy=Join-Path $work ($name+[IO.Path]::GetExtension($report))
Copy-Item -LiteralPath $report -Destination $reportCopy -Force
$roots=@(
 (Join-Path $install "Tester"),
 (Join-Path $install "MQL5\Files"),
 (Join-Path $env:APPDATA "MetaQuotes\Tester")
)
$found=@()
foreach($root in $roots){
 if(Test-Path -LiteralPath $root){
  $found+=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $csvName -ErrorAction SilentlyContinue |
            Where-Object {$_.LastWriteTime -ge $started.AddMinutes(-2)})
 }
}
$last=$found|Sort-Object LastWriteTime -Descending|Select-Object -First 1
if(-not $last){throw "CSV de execucoes nao encontrado: $csvName"}
$csvCopy=Join-Path $work $csvName
Copy-Item -LiteralPath $last.FullName -Destination $csvCopy -Force
if((Get-Item $csvCopy).Length -lt 30){throw "CSV de execucoes vazio"}
$rows=Import-Csv -LiteralPath $csvCopy -Delimiter ";"
$attempts=@($rows|Where-Object {$_.event -eq "ORDER_ATTEMPT"}).Count
$filled=@($rows|Where-Object {$_.event -eq "ORDER_FILLED"}).Count
$dealsIn=@($rows|Where-Object {$_.event -eq "DEAL_IN"}).Count
$dealsOut=@($rows|Where-Object {$_.event -eq "DEAL_OUT"}).Count
$manifest=[ordered]@{
 schema="alien-goat5k-execution-v1"
 created_utc=(Get-Date).ToUniversalTime().ToString("o")
 statement="Orders ONLY in MT5 Strategy Tester; NOT LIVE GOAT fills"
 strategy="experimental M1 local breakout with 2R, not previous ALIEN 4R system"
 source_broker="MetaQuotes-Demo; verify report account/server"
 period="M1";symbol="XAUUSD";real_ticks_requested=$true
 deposit_usd=5000
 risk_max_pct=0.25
 target_rr=2
 spread_cap_points=45
 max_stop_points=180
 max_positions=1
 fee_per_lot_roundtrip_assumption_usd=5
 start=$FromDate;end=$ToDate
 attempts=$attempts;orders_reported_filled=$filled
 deal_in_rows=$dealsIn;deal_out_rows=$dealsOut
 source_sha256=(Get-FileHash $source -Algorithm SHA256).Hash
 compiled_sha256=(Get-FileHash $ex5 -Algorithm SHA256).Hash
 preset_sha256=(Get-FileHash $frozenSet -Algorithm SHA256).Hash
 report_sha256=(Get-FileHash $reportCopy -Algorithm SHA256).Hash
 event_log_sha256=(Get-FileHash $csvCopy -Algorithm SHA256).Hash
 note="Verify report bars, real ticks, fills and balance; no claims of edge or Goat rule compliance"
}
$manifest | ConvertTo-Json -Depth 5 |
 Set-Content -LiteralPath (Join-Path $work "MANIFESTO.json") -Encoding UTF8
$zip=Join-Path $zipDir ($name+".zip")
Compress-Archive -Path (Join-Path $work "*") -DestinationPath $zip -CompressionLevel Optimal -Force
Write-Host "ALIEN EXECUTION TESTER TERMINOU" -ForegroundColor Green
Write-Host "Attempts=$attempts | Filled=$filled | Deals IN=$dealsIn | Deals OUT=$dealsOut"
if($filled -eq 0){Write-Warning "Zero execucoes. Envie o ZIP/CSV para diagnostico, sem afrouxar controles automaticamente."}
Write-Host "ZIP: $zip"
Start-Process explorer.exe -ArgumentList ('"'+$zipDir+'"') | Out-Null
