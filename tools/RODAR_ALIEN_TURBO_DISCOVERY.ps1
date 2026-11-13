#requires -Version 5.1
# ALIEN TURBO LAB: 9 experimento(s), somente MT5 Strategy Tester portatil.
# NEVER trade in live Goat / RoboForex; never close non-isolated terminals.
param(
 [string]$FromDate="2026.10.21",
 [string]$ToDate="2026.11.12",
 [int]$Deposit=5000,
 [int]$Leverage=100
)
$ErrorActionPreference="Stop"
if($Deposit -ne 5000){throw "Laboratorio TURBO exige US$5000."}
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source=Join-Path $repo "MQL5\Experts\ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5"
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
$setRoot=Join-Path $repo "MQL5\Profiles\Tester"
$install=if(Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe"){"C:\ALIEN_TEST_MT5"}else{Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"}
$isolatedExe=Join-Path $install "terminal64.exe"
foreach($p in @($source,$runner,$isolatedExe)){
 if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Faltou arquivo existente: $p"}
}

# The only process that can be closed has this exact executable path.
function Stop-AlienIsolatedTerminal {
 param([string]$Stage)
 $expected=[IO.Path]::GetFullPath($isolatedExe)
 $matches=@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
  Where-Object {$_.ExecutablePath -and
    ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $expected)})
 foreach($item in $matches){
  $pIdLocal=[int]$item.ProcessId
  Write-Host "Fechando SOMENTE MT5 isolado antes de $Stage, PID $pIdLocal" -ForegroundColor Yellow
  $p=Get-Process -Id $pIdLocal -ErrorAction SilentlyContinue
  if($null -eq $p){continue}
  if($p.MainWindowHandle -ne 0){[void]$p.CloseMainWindow()}
  $exited=$false
  try{$exited=$p.WaitForExit(8000)}catch{$exited=$true}
  if(-not $exited){
    $current=Get-CimInstance Win32_Process -Filter ("ProcessId="+$pIdLocal) -ErrorAction SilentlyContinue
    if($null -ne $current -and $current.ExecutablePath -and
       ([IO.Path]::GetFullPath($current.ExecutablePath) -ieq $expected)){
        Stop-Process -Id $pIdLocal -Force -ErrorAction Stop
    }
  }
 }
 Start-Sleep -Seconds 1
 $remaining=@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
   Where-Object {$_.ExecutablePath -and
      ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $expected)})
 if($remaining.Count -gt 0){throw "MT5 portatil nao encerrou. RoboForex principal nao foi tocado."}
}

# Ordem importa: cada passo muda UM conjunto conhecido de variáveis.
$plans=@(
 @{id="A_BASE";change=@{}},
 @{id="B_FREQUENCY";change=@{MaxDayTrades="1440";CooldownMinutes="0"}},
 @{id="C_ALLDAY";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24"}},
 @{id="D_MULTI5";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";MaxOpenPositions="5"}},
 @{id="E_H1M15";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";MaxOpenPositions="5";RequireH1M15Context="true"}},
 @{id="F_M5SWEEP";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";MaxOpenPositions="5";RequireM5ClosedSweep="true"}},
 @{id="G_M15FVG";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";MaxOpenPositions="5";RequireM15ClosedFVG="true"}},
 @{id="H_RR3";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";MaxOpenPositions="5";RewardRisk="3.0"}},
 @{id="I_RISKSIZED";change=@{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";MaxOpenPositions="5";MaxLot="0.05"}}
)
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$name="ALIEN_TURBO_DISCOVERY_"+$stamp
$resultDir=Join-Path $repo ("results\"+$name)
$zipRoot=Join-Path $repo "PACOTES_MT5"
New-Item -ItemType Directory -Force -Path $resultDir,$zipRoot|Out-Null

$meta=[ordered]@{
 schema="ALIEN_TURBO_DISCOVERY_V1"
 date_utc=(Get-Date).ToUniversalTime().ToString("o")
 statement="ONLY Strategy Tester market fills; candidate outcomes are OHLC M1 approximation"
 assumptions="XAUUSD MetaQuotes-Demo quotes, 5 USD per lot estimated fee not charged by tester"
 capital_usd=5000;symbol="XAUUSD";timeframe="M1";model=4
 start_date=$FromDate;end_date=$ToDate
 risk_max_pct=0.25;risk_max_usd=12.50;floating_guard_usd=35
 source_sha256=(Get-FileHash $source -Algorithm SHA256).Hash
 source_path="ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5"
 test_account_is_not_goat=$true
 experiments=@()
 success=$false
 failure=""
}
$sourceCopy=Join-Path $resultDir "ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5"
Copy-Item -LiteralPath $source -Destination $sourceCopy -Force
$baseInputs=@{}
$expectedSHA=""
try {
 foreach($plan in $plans){
  Stop-AlienIsolatedTerminal -Stage $plan.id
  $profile=Join-Path $setRoot ("ALIEN_TURBO_"+$plan.id+".set")
  if(-not(Test-Path -LiteralPath $profile)){throw "Preset nao existe $profile"}
  $lines=@(Get-Content -LiteralPath $profile -Encoding UTF8)
  $known=@{}
  foreach($line in $lines){
    if($line -notmatch '^[A-Za-z][A-Za-z0-9_]*='){continue}
    $key,$allValue=$line.Split('=',2)
    if($known.ContainsKey($key)){throw "Input duplicado $key em $($plan.id)"}
    $known[$key]=($allValue -split '\|\|',2)[0]
  }
  $mandatory=@("EnableTesterOrders","InitialDepositUsd","RiskLimitPct",
   "RiskMaxUsd","FloatingSafetyUsd","MaxDayTrades","MaxOpenPositions",
   "RequireH1M15Context","RequireM5ClosedSweep","RequireM15ClosedFVG",
   "CooldownMinutes","StartServerHour","EndServerHour","RewardRisk",
   "EnableSignalTape","EnableM1ShadowOutcomes")
  foreach($key in $mandatory){
   if(-not $known.ContainsKey($key)){throw "Preset sem input obrigatorio $key"}
  }
  if($known.EnableTesterOrders -ne "true" -or $known.InitialDepositUsd -ne "5000.0" -or
     $known.RiskLimitPct -ne "0.25" -or $known.RiskMaxUsd -ne "12.50" -or
     $known.FloatingSafetyUsd -ne "35.0" -or $known.EnableSignalTape -ne "true" -or
     $known.EnableM1ShadowOutcomes -ne "true"){
    throw "Preset $($plan.id) altera trava de risco/execucao ou desativa a fita"
  }
  if($plan.id -eq "A_BASE"){$baseInputs=$known}
  foreach($key in @($baseInputs.Keys)){
    if(-not $known.ContainsKey($key)){throw "Input ausente $key"}
    if($key -in @("CSVFileName","TapeCSVFileName","OutcomeCSVFileName")){continue}
    $value=$baseInputs[$key]
    if($plan.change.ContainsKey($key)){$value=$plan.change[$key]}
    if($known[$key] -cne $value){
      throw "Presets divergiram fora do plano: $($plan.id)/$key esperado $value obtido $($known[$key])"
    }
  }
  $testId=$name+"_"+$plan.id
  $names=@{
    CSVFileName=$testId+"_TRADES.csv"
    TapeCSVFileName=$testId+"_CANDIDATES.csv"
    OutcomeCSVFileName=$testId+"_OUTCOMES.csv"
  }
  $frozen=Join-Path $resultDir ($testId+".set")
  $updated=@($lines|ForEach-Object {
    if($_ -match '^(CSVFileName|TapeCSVFileName|OutcomeCSVFileName)='){
      $k=($_ -split '=',2)[0];$k+"="+$names[$k]
    }else{$_}
  })
  [IO.File]::WriteAllLines($frozen,[string[]]$updated,[Text.Encoding]::ASCII)
  Write-Host "TURBO: $($plan.id), teste XAUUSD M1 USD5000, apenas tester" -ForegroundColor Cyan
  $start=Get-Date
  $p=@{
    ExpertPath=$source;Symbol="XAUUSD";Period="M1";Model=4;
    FromDate=$FromDate;ToDate=$ToDate;Deposit=$Deposit;
    Leverage=$Leverage;ReportName=$testId;ExpId=$testId;
    StrategyName=$testId;PresetPath=$frozen;NoCsv=$true;
    SkipCompile=($plan.id -ne "A_BASE")
  }
  & $runner @p
  $ex5=[IO.Path]::ChangeExtension($source,".ex5")
  if(-not(Test-Path -LiteralPath $ex5)){throw "EX5 nao compilado."}
  $sha=(Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash
  if($expectedSHA -and $sha -ne $expectedSHA){
   throw "EX5 mudou entre experimentos. Pacote invalido."
  }
  $expectedSHA=$sha
  $reportOptions=@(
    (Join-Path $install ($testId+".htm")),
    (Join-Path $install ($testId+".html")),
    (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$testId" ($testId+".htm")),
    (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$testId" ($testId+".html"))
  )
  $report=$reportOptions|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
  if(-not $report){throw "Relatorio MT5 nao encontrado: $testId"}
  $html=Join-Path $resultDir ($testId+[IO.Path]::GetExtension($report))
  Copy-Item -LiteralPath $report -Destination $html -Force

  $roots=@(
    (Join-Path $install "Tester"),
    (Join-Path $install "MQL5\Files"),
    (Join-Path $env:APPDATA "MetaQuotes\Tester")
  )
  $outputs=@{}
  foreach($key in @("CSVFileName","TapeCSVFileName","OutcomeCSVFileName")){
    $filename=$names[$key]
    $found=@()
    foreach($root in $roots){
      if(Test-Path -LiteralPath $root){
        $found+=@(Get-ChildItem -LiteralPath $root -File -Recurse -Filter $filename -ErrorAction SilentlyContinue |
          Where-Object {$_.LastWriteTime -ge $start.AddMinutes(-2)})
      }
    }
    $latest=$found|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not $latest){throw "CSV nao encontrado: $filename"}
    $file=Join-Path $resultDir $filename
    Copy-Item -LiteralPath $latest.FullName -Destination $file -Force
    if((Get-Item -LiteralPath $file).Length -lt 30){throw "CSV vazio: $filename"}
    $outputs[$key]=$file
  }
  $tradeRows=Import-Csv -LiteralPath $outputs.CSVFileName -Delimiter ";"
  $candidateRows=Import-Csv -LiteralPath $outputs.TapeCSVFileName -Delimiter ";"
  $outcomeRows=Import-Csv -LiteralPath $outputs.OutcomeCSVFileName -Delimiter ";"
  $fills=@($tradeRows|Where-Object {$_.event -eq "ORDER_FILLED"}).Count
  $in=@($tradeRows|Where-Object {$_.event -eq "DEAL_IN"}).Count
  $out=@($tradeRows|Where-Object {$_.event -eq "DEAL_OUT"}).Count
  $candidateCount=$candidateRows.Count
  $resolved=@($outcomeRows|Where-Object {$_.state -notin @("NO_SLOT","CENSORED_END_NO_FUTURE_DATA")}).Count
  $ambiguous=@($outcomeRows|Where-Object {$_.state -eq "BOTH_TOUCHED_AMBIGUOUS"}).Count
  $meta.experiments+=@([ordered]@{
    variant=$plan.id;changed_inputs=$plan.change
    ex5_sha256=$sha
    preset_sha256=(Get-FileHash $frozen -Algorithm SHA256).Hash
    report_sha256=(Get-FileHash $html -Algorithm SHA256).Hash
    trades_sha256=(Get-FileHash $outputs.CSVFileName -Algorithm SHA256).Hash
    candidates_sha256=(Get-FileHash $outputs.TapeCSVFileName -Algorithm SHA256).Hash
    outcomes_sha256=(Get-FileHash $outputs.OutcomeCSVFileName -Algorithm SHA256).Hash
    filled=$fills;deals_in=$in;deals_out=$out
    candidates=$candidateCount
    shadow_resolved_m1=$resolved;shadow_ambiguous_m1=$ambiguous
  })
  Write-Host "$($plan.id): filled=$fills OUT=$out candidatos=$candidateCount M1_shadow=$resolved ambiguos=$ambiguous" -ForegroundColor Green
 }
 $meta.success=$true
} catch {
 $meta.failure=$_.Exception.Message
 Write-Warning "TURBO interrompido: $($meta.failure). Empacotando evidencias ja prontas."
} finally {
 if($expectedSHA){
  $ex5=[IO.Path]::ChangeExtension($source,".ex5")
  $copy=Join-Path $resultDir "ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.ex5"
  Copy-Item -LiteralPath $ex5 -Destination $copy -Force
  $meta.compiled_sha256=(Get-FileHash $copy -Algorithm SHA256).Hash
 }
 $meta | ConvertTo-Json -Depth 10 |
   Set-Content -LiteralPath (Join-Path $resultDir "MANIFESTO.json") -Encoding UTF8
 $zip=Join-Path $zipRoot ($name+".zip")
 Compress-Archive -Path (Join-Path $resultDir "*") -DestinationPath $zip -CompressionLevel Optimal -Force
 Write-Host "PACOTE TURBO: $zip" -ForegroundColor Cyan
 Write-Host "Concluidos: $($meta.experiments.Count) de $($plans.Count)"
 Start-Process explorer.exe -ArgumentList ('"'+$zipRoot+'"')|Out-Null
}
if(-not $meta.success){
 throw "ALIEN TURBO teve execucao parcial. Envie o ZIP produzido e o erro ao ChatGPT; nao altere o MT5 principal."
}
Write-Host "ALIEN TURBO: 9 estudos concluidos; anexe ZIP para auditoria de custos e de sinais." -ForegroundColor Green
