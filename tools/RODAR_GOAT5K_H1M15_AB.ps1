#requires -Version 5.1
# ALIEN H1/M15 A/B: mesmo EA/EX5, ordens APENAS no Strategy Tester MT5 isolado.
param(
 [string]$FromDate="2026.10.21",
 [string]$ToDate="2026.11.12",
 [int]$Deposit=5000,
 [int]$Leverage=100
)
$ErrorActionPreference="Stop"
if($Deposit -ne 5000) {throw "A/B exige deposito USD5000 no testador."}
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$src=Join-Path $repo "MQL5\Experts\ALIEN_GOAT5K_H1M15_AB_TESTER.mq5"
$sets=Join-Path $repo "MQL5\Profiles\Tester"
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
$install=if(Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe"){"C:\ALIEN_TEST_MT5"}else{Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"}
$terminal=Join-Path $install "terminal64.exe"
foreach($path in @($src,$runner,$terminal)){
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Arquivo necessario ausente: $path"}
}
$runTime=Get-Date -Format "yyyyMMdd_HHmmss"
$packDir=Join-Path $repo "PACOTES_MT5"
$dir=Join-Path $repo ("results\ALIEN_H1M15_AB_"+$runTime)
New-Item -ItemType Directory -Force -Path $packDir,$dir|Out-Null

# Fecha somente MT5 de teste se necessario. NUNCA o terminal RoboForex principal.
$isolated=@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue|
 Where-Object {$_.ExecutablePath -and $_.ExecutablePath -ieq $terminal})
foreach($process in $isolated){
 Write-Host "Encerrando somente MT5 ALIEN isolado PID $($process.ProcessId)" -ForegroundColor Yellow
 $p=Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
 if($null -ne $p){
  if($p.MainWindowHandle -ne 0){[void]$p.CloseMainWindow()}
  Start-Sleep -Seconds 2
  $p=Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
  if($null -ne $p){Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop}
 }
}
$plans=@(
 @{label="A_BASE"; preset="ALIEN_GOAT5K_H1M15_A_BASE.set"; context="false"},
 @{label="B_CONTEXT"; preset="ALIEN_GOAT5K_H1M15_B_CONTEXT.set"; context="true"}
)
$manifest=[ordered]@{
 schema="ALIEN_H1M15_EXECUTION_AB_V1"
 created_utc=(Get-Date).ToUniversalTime().ToString("o")
 broker="MetaQuotes-Demo Strategy Tester, NAO Goat"
 statement="Deals simulated by MT5 tester only, no broker live orders"
 symbol="XAUUSD";period="M1";model=4
 requested_dates=($FromDate+" - "+$ToDate)
 deposit=5000;risk_pct=0.25;target_rr=2.0
 max_stop_points=180;max_spread_points=45
 maximum_daily_trades=6;max_simultaneous=1
 fee_usd_per_lot_roundtrip_assumption=5.0
 source_sha256=(Get-FileHash $src -Algorithm SHA256).Hash
 experiments=@()
}
$firstExeHash=""
$baseNormalized=$null
foreach($plan in $plans){
 $originalSet=Join-Path $sets $plan.preset
 if(-not(Test-Path -LiteralPath $originalSet)){throw "Preset ausente: $originalSet"}
 $name="ALIEN_H1M15_"+$plan.label+"_"+$runTime
 $eventsName=$name+"_EVENTS.csv"
 $frozenSet=Join-Path $dir ($name+".set")
 $sourceLines=@(Get-Content -LiteralPath $originalSet -Encoding UTF8)
 $actual=@($sourceLines|ForEach-Object {
  if($_ -match "^CSVFileName="){"CSVFileName="+$eventsName}else{$_}
 })
 $contextLines=@($actual|Where-Object {$_ -match "^RequireH1M15Context="})
 $orderLines=@($actual|Where-Object {$_ -match "^EnableTesterOrders="})
 if($contextLines.Count -ne 1 -or
    -not $contextLines[0].StartsWith("RequireH1M15Context="+$plan.context+"||")){
    throw "Modo AB incorreto ou duplicado: $($plan.label)"
 }
 if($orderLines.Count -ne 1 -or -not $orderLines[0].StartsWith("EnableTesterOrders=true||")){
    throw "Este teste exige ordem habilitada SOMENTE no Strategy Tester."
 }
 if(@($actual|Where-Object {$_ -match "^CSVFileName=.*\|\|"}).Count -gt 0){
    throw "CSV string nao pode conter metadados ||."
 }
 # Comparar todos os outros campos: somente modo + nome CSV podem variar.
 $normal=@($actual|Where-Object {
   $_ -notmatch "^RequireH1M15Context=" -and $_ -notmatch "^CSVFileName="
 })
 if($null -eq $baseNormalized){$baseNormalized=$normal}
 else{
   $difference=@(Compare-Object -ReferenceObject $baseNormalized -DifferenceObject $normal)
   if($difference.Count -gt 0){throw "AB difere em mais de um parametro de estrategia."}
 }
 [IO.File]::WriteAllLines($frozenSet,[string[]]$actual,[Text.Encoding]::ASCII)

 Write-Host "ALIEN A/B: $($plan.label) | $FromDate - $ToDate | USD$Deposit" -ForegroundColor Cyan
 $started=Get-Date
 $par=@{
   ExpertPath=$src;Symbol="XAUUSD";Period="M1";Model=4
   FromDate=$FromDate;ToDate=$ToDate;Deposit=$Deposit;Leverage=$Leverage
   ReportName=$name;ExpId=$name;StrategyName=$name
   PresetPath=$frozenSet;NoCsv=$true;SkipCompile=($plan.label -eq "B_CONTEXT")
 }
 & $runner @par
 if($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0){
    throw "Run-Backtest retornou codigo $LASTEXITCODE para $($plan.label)"
 }
 $ex5=[IO.Path]::ChangeExtension($src,".ex5")
 if(-not(Test-Path -LiteralPath $ex5)){throw "EX5 ausente apos compilacao."}
 $hash=(Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash
 if($firstExeHash -and $hash -ne $firstExeHash){
    throw "EX5 mudou entre A e B, comparacao invalida."
 }
 $firstExeHash=$hash

 $candidateReports=@(
   (Join-Path $install ($name+".htm")),
   (Join-Path $install ($name+".html")),
   (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".htm")),
   (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".html"))
 )
 $report=$candidateReports|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
 if(-not $report){throw "Sem HTML para $name. Veja o log do testador."}
 $html=Join-Path $dir ($name+[IO.Path]::GetExtension($report))
 Copy-Item -LiteralPath $report -Destination $html -Force

 $roots=@(
   (Join-Path $install "Tester"),
   (Join-Path $install "MQL5\Files"),
   (Join-Path $env:APPDATA "MetaQuotes\Tester")
 )
 $found=@()
 foreach($root in $roots){
   if(Test-Path -LiteralPath $root){
     $found+=@(Get-ChildItem -LiteralPath $root -File -Recurse -Filter $eventsName -ErrorAction SilentlyContinue |
       Where-Object {$_.LastWriteTime -ge $started.AddMinutes(-2)})
   }
 }
 $latest=$found|Sort-Object LastWriteTime -Descending|Select-Object -First 1
 if(-not $latest){throw "Sem CSV para $name"}
 $csvPath=Join-Path $dir $eventsName
 Copy-Item -LiteralPath $latest.FullName -Destination $csvPath -Force
 if((Get-Item -LiteralPath $csvPath).Length -lt 30){throw "CSV vazio para $name"}

 $rows=Import-Csv -LiteralPath $csvPath -Delimiter ";"
 $filled=@($rows|Where-Object {$_.event -eq "ORDER_FILLED"}).Count
 $entryDeals=@($rows|Where-Object {$_.event -eq "DEAL_IN"}).Count
 $exitDeals=@($rows|Where-Object {$_.event -eq "DEAL_OUT"}).Count
 $contextVeto=@($rows|Where-Object {$_.event -eq "VETO_CONTEXTO"}).Count
 $contextPass=@($rows|Where-Object {$_.event -eq "CONTEXTO_APROVADO"}).Count
 $manifest.experiments+=@([ordered]@{
    label=$plan.label
    required_context=($plan.context -eq "true")
    ex5_sha256=$hash
    preset_sha256=(Get-FileHash -LiteralPath $frozenSet -Algorithm SHA256).Hash
    report_sha256=(Get-FileHash -LiteralPath $html -Algorithm SHA256).Hash
    event_log_sha256=(Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash
    filled_orders=$filled
    entry_deals=$entryDeals
    exit_deals=$exitDeals
    rejected_by_context=$contextVeto
    accepted_by_context=$contextPass
 })
 Write-Host "$($plan.label): fills=$filled dealsIN=$entryDeals dealsOUT=$exitDeals vetoContexto=$contextVeto" -ForegroundColor Green
}
$manifest | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $dir "MANIFESTO.json") -Encoding UTF8
$zip=Join-Path $packDir ("ALIEN_H1M15_AB_"+$runTime+".zip")
Compress-Archive -Path (Join-Path $dir "*") -DestinationPath $zip -CompressionLevel Optimal -Force
Write-Host "ALIEN H1/M15 A/B concluido | ZIP: $zip" -ForegroundColor Green
Write-Host "Envie o ZIP para auditar fills, custos e qualidade dos dados. Nao publique no GitHub."
Start-Process explorer.exe -ArgumentList ('"'+$packDir+'"')|Out-Null
