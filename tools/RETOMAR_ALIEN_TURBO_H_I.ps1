#requires -Version 5.1
# ALIEN TURBO: APENAS retomar H_RR3 e I_RISKSIZED apos sucesso A-G.
# Nunca envia ordens reais e nao encerra MT5 RoboForex principal.
param(
 [string]$ZipOriginal="",
 [string]$FromDate="2026.10.21",
 [string]$ToDate="2026.11.12"
)
$ErrorActionPreference="Stop"
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source=Join-Path $repo "MQL5\Experts\ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5"
$compiled=[IO.Path]::ChangeExtension($source,".ex5")
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
$profileDir=Join-Path $repo "MQL5\Profiles\Tester"
$packRoot=Join-Path $repo "PACOTES_MT5"
$install=if(Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe"){"C:\ALIEN_TEST_MT5"}else{Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"}
$terminal=Join-Path $install "terminal64.exe"
foreach($path in @($source,$runner,$terminal)){
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Arquivo necessario ausente: $path"}
}
if(-not(Test-Path -LiteralPath $packRoot)){throw "PACOTES_MT5 nao existe"}
if(-not $ZipOriginal){
 $candidates=@(Get-ChildItem -LiteralPath $packRoot -Filter "ALIEN_TURBO_DISCOVERY_*.zip" -File |
   Where-Object {$_.BaseName -match '^ALIEN_TURBO_DISCOVERY_\d{8}_\d{6}$'} |
   Sort-Object LastWriteTime -Descending)
 foreach($candidate in $candidates){
  try{
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $zipRead=[System.IO.Compression.ZipFile]::OpenRead($candidate.FullName)
   try{
    $entry=$zipRead.GetEntry("MANIFESTO.json")
    if($null -eq $entry){continue}
    $read=New-Object IO.StreamReader($entry.Open())
    try{$item=$read.ReadToEnd()|ConvertFrom-Json}finally{$read.Dispose()}
    if($item.schema -eq "ALIEN_TURBO_DISCOVERY_V1" -and
       @($item.experiments).Count -eq 7 -and
       @($item.experiments|Select-Object -ExpandProperty variant) -join ',' -eq
       "A_BASE,B_FREQUENCY,C_ALLDAY,D_MULTI5,E_H1M15,F_M5SWEEP,G_M15FVG"){
       $ZipOriginal=$candidate.FullName;break
    }
   }finally{$zipRead.Dispose()}
  }catch{continue}
 }
}
if(-not $ZipOriginal -or -not(Test-Path -LiteralPath $ZipOriginal -PathType Leaf)){
 throw "Nao encontrei o pacote parcial A-G com 7 testes. Mantenha o ZIP em PACOTES_MT5."
}
$originalName=[IO.Path]::GetFileNameWithoutExtension($ZipOriginal)
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$folder=Join-Path $repo ("results\TURBO_RESUME_"+$stamp)
New-Item -ItemType Directory -Force -Path $folder|Out-Null
Expand-Archive -LiteralPath $ZipOriginal -DestinationPath $folder -Force
$manifestPath=Join-Path $folder "MANIFESTO.json"
if(-not(Test-Path $manifestPath)){throw "Original sem MANIFESTO"}
$m=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
if($m.schema -ne "ALIEN_TURBO_DISCOVERY_V1" -or @($m.experiments).Count -ne 7){
 throw "Original nao e o pacote A-G de 7 testes"
}
$required=@("A_BASE","B_FREQUENCY","C_ALLDAY","D_MULTI5","E_H1M15","F_M5SWEEP","G_M15FVG")
foreach($v in $required){
 if($v -notin @($m.experiments|Select-Object -ExpandProperty variant)){
  throw "Falta resultado $v no pacote original"
 }
}
if($m.start_date -ne $FromDate -or $m.end_date -ne $ToDate){
 throw "Nao alterar datas do teste retomado. Original $($m.start_date) - $($m.end_date)"
}
$archivedSource=Join-Path $folder "ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.mq5"
$archivedEX5=Join-Path $folder "ALIEN_GOAT5K_TURBO_DISCOVERY_TESTER.ex5"
foreach($artifact in @($archivedSource,$archivedEX5)){
 if(-not(Test-Path -LiteralPath $artifact)){throw "Arquivo faltante do ZIP: $artifact"}
}
if((Get-FileHash -LiteralPath $archivedSource -Algorithm SHA256).Hash -ne $m.source_sha256 -or
   (Get-FileHash -LiteralPath $archivedEX5 -Algorithm SHA256).Hash -ne $m.compiled_sha256){
 throw "Hashes da fonte/binario originais nao conferem: NAO executar"
}
foreach($ex in $m.experiments){
 $stem=$originalName+"_"+$ex.variant
 $archivePaths=@{
  preset_sha256=(Join-Path $folder ($stem+".set"))
  report_sha256=(Join-Path $folder ($stem+".htm"))
  trades_sha256=(Join-Path $folder ($stem+"_TRADES.csv"))
  candidates_sha256=(Join-Path $folder ($stem+"_CANDIDATES.csv"))
  outcomes_sha256=(Join-Path $folder ($stem+"_OUTCOMES.csv"))
 }
 foreach($key in $archivePaths.Keys){
  $file=$archivePaths[$key]
  if(-not(Test-Path -LiteralPath $file)){throw "Faltou $file"}
  if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $ex.$key){
   throw "Hash invalido no arquivo $file; preservar original e nao prosseguir."
  }
 }
 if($ex.ex5_sha256 -ne $m.compiled_sha256){
  throw "EX5 original nao foi constante no $($ex.variant)"
 }
}
# Reusar EX5 congelado. Nunca sobrescrever uma fonte diferente do usuario:
# se ele editou depois do run, criar backups locais antes de restaurar bytes
# do pacote A-G para reproduzir exatamente as mesmas entradas e saidas.
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $m.source_sha256){
 $backup=Join-Path $folder "FONTE_ATUAL_ANTES_RESTAURACAO.mq5"
 Copy-Item -LiteralPath $source -Destination $backup -Force
 Copy-Item -LiteralPath $archivedSource -Destination $source -Force
 Write-Warning "Fonte local diferia. Backup em $backup; restaurada fonte exata do ZIP."
}
if(Test-Path -LiteralPath $compiled){
 if((Get-FileHash -LiteralPath $compiled -Algorithm SHA256).Hash -ne $m.compiled_sha256){
  Copy-Item -LiteralPath $compiled -Destination (Join-Path $folder "EX5_ATUAL_ANTES_RESTAURACAO.ex5") -Force
 }
}
Copy-Item -LiteralPath $archivedEX5 -Destination $compiled -Force
$m|Add-Member -NotePropertyName run_name -NotePropertyValue $originalName -Force
$m|Add-Member -NotePropertyName original_zip -NotePropertyValue ([IO.Path]::GetFileName($ZipOriginal)) -Force
$m|Add-Member -NotePropertyName resumed_utc -NotePropertyValue ((Get-Date).ToUniversalTime().ToString("o")) -Force
$m.success=$false
$m.failure=""
$plans=@("H_RR3","I_RISKSIZED")
$failure=""

function Wait-OnlyIsolatedMT5 {
 param([string]$Step)
 $expected=[IO.Path]::GetFullPath($terminal)
 # O terminal anterior frequentemente demora a desaparecer da lista
 # de processos MESMO apos "shutdown with 0" no journal do MT5.
 for($cycle=0;$cycle -lt 25;$cycle++){
  $processes=@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
     Where-Object {$_.ExecutablePath -and
       ([IO.Path]::GetFullPath($_.ExecutablePath) -ieq $expected)})
  if($processes.Count -eq 0){return}
  foreach($item in $processes){
   $thePid=[int]$item.ProcessId
   $target=Get-Process -Id $thePid -ErrorAction SilentlyContinue
   if($null -eq $target){continue}
   if($target.MainWindowHandle -ne 0){[void]$target.CloseMainWindow()}
   # Revalidar a identidade ANTES de finalizar forçado.
   if($cycle -ge 5){
    $current=Get-CimInstance Win32_Process -Filter ("ProcessId="+$thePid) -ErrorAction SilentlyContinue
    if($null -ne $current -and $current.ExecutablePath -and
       ([IO.Path]::GetFullPath($current.ExecutablePath) -ieq $expected)){
       Stop-Process -Id $thePid -Force -ErrorAction SilentlyContinue
    }
   }
  }
  Start-Sleep -Seconds 1
 }
 throw "Terminal de TESTE ainda aberto antes de $Step. O RoboForex nao foi tocado."
}

try{
 foreach($variant in $plans){
  Wait-OnlyIsolatedMT5 -Step $variant
  $profile=Join-Path $profileDir ("ALIEN_TURBO_"+$variant+".set")
  if(-not(Test-Path -LiteralPath $profile)){throw "Preset ausente: $profile"}
  $lines=@(Get-Content -LiteralPath $profile -Encoding UTF8)
  $inputs=@{}
  foreach($line in $lines){
   if($line -notmatch '^[A-Za-z][A-Za-z0-9_]*='){continue}
   $k,$value=$line.Split('=',2)
   if($inputs.ContainsKey($k)){throw "Input duplicado: $k"}
   $inputs[$k]=($value -split '\|\|',2)[0]
  }
  foreach($k in @("EnableTesterOrders","InitialDepositUsd","RiskLimitPct",
                  "RiskMaxUsd","FloatingSafetyUsd","MaxDayTrades",
                  "MaxOpenPositions","MaxLot","RewardRisk",
                  "EnableSignalTape","EnableM1ShadowOutcomes")){
   if(-not $inputs.ContainsKey($k)){throw "Input ausente: $k"}
  }
  if($inputs.EnableTesterOrders -ne "true" -or $inputs.InitialDepositUsd -ne "5000.0" -or
     $inputs.RiskLimitPct -ne "0.25" -or $inputs.RiskMaxUsd -ne "12.50" -or
     $inputs.FloatingSafetyUsd -ne "35.0" -or $inputs.EnableSignalTape -ne "true" -or
     $inputs.EnableM1ShadowOutcomes -ne "true"){
      throw "Parametros de risco/fita alterados em $variant"
  }
  if($variant -eq "H_RR3" -and ($inputs.RewardRisk -ne "3.0" -or $inputs.MaxLot -ne "0.02")){
    throw "Preset H deve ser RR3 / MaxLot0.02"
  }
  if($variant -eq "I_RISKSIZED" -and ($inputs.RewardRisk -ne "2.0" -or $inputs.MaxLot -ne "0.05")){
    throw "Preset I deve ser RR2 / MaxLot0.05"
  }
  $testName=$originalName+"_"+$variant
  $shortStem="AT_"+$stamp+"_"+$variant
  $names=@{
    CSVFileName=$shortStem+"_T.csv"
    TapeCSVFileName=$shortStem+"_C.csv"
    OutcomeCSVFileName=$shortStem+"_O.csv"
  }
  $archiveSuffix=@{
    CSVFileName="_TRADES.csv"
    TapeCSVFileName="_CANDIDATES.csv"
    OutcomeCSVFileName="_OUTCOMES.csv"
  }
  $frozen=Join-Path $folder ($testName+".set")
  $modified=@($lines|ForEach-Object {
    if($_ -match '^(CSVFileName|TapeCSVFileName|OutcomeCSVFileName)='){
      $k=($_ -split '=',2)[0]
      $k+"="+$names[$k]
    }else{$_}
  })
  [IO.File]::WriteAllLines($frozen,[string[]]$modified,[Text.Encoding]::ASCII)
  Write-Host "ALIEN TURBO: retomando SOMENTE $variant" -ForegroundColor Cyan
  $started=Get-Date
  $parameters=@{
     ExpertPath=$source;Symbol="XAUUSD";Period="M1";Model=4;
     FromDate=$FromDate;ToDate=$ToDate;Deposit=5000;Leverage=100;
     ReportName=$testName;ExpId=$testName;StrategyName=$testName;
     PresetPath=$frozen;NoCsv=$true;SkipCompile=$true
  }
  & $runner @parameters
  if((Get-FileHash -LiteralPath $compiled -Algorithm SHA256).Hash -ne $m.compiled_sha256){
    throw "EX5 mudou antes ou depois do teste $variant"
  }
  $candidates=@(
   (Join-Path $install ($testName+".htm")),
   (Join-Path $install ($testName+".html")),
   (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$testName" ($testName+".htm")),
   (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$testName" ($testName+".html"))
  )
  $htmlSource=$candidates|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1
  if(-not $htmlSource){throw "HTML MT5 nao foi criado para $variant"}
  $html=Join-Path $folder ($testName+[IO.Path]::GetExtension($htmlSource))
  Copy-Item -LiteralPath $htmlSource -Destination $html -Force
  $roots=@(
    (Join-Path $install "Tester"),
    (Join-Path $install "MQL5\Files"),
    (Join-Path $env:APPDATA "MetaQuotes\Tester")
  )
  $outputs=@{}
  foreach($key in @("CSVFileName","TapeCSVFileName","OutcomeCSVFileName")){
    $fileName=$names[$key]
    $found=@()
    foreach($root in $roots){
      if(Test-Path -LiteralPath $root){
        $found+=@(Get-ChildItem -LiteralPath $root -File -Recurse -Filter $fileName -ErrorAction SilentlyContinue |
           Where-Object {$_.LastWriteTime -ge $started.AddMinutes(-2)})
      }
    }
    $latest=$found|Sort-Object LastWriteTime -Descending|Select-Object -First 1
    if(-not $latest){throw "CSV nao encontrado $fileName"}
    $archiveFile=Join-Path $folder ($testName+$archiveSuffix[$key])
    Copy-Item -LiteralPath $latest.FullName -Destination $archiveFile -Force
    if((Get-Item -LiteralPath $archiveFile).Length -lt 30){
       throw "CSV vazio: $fileName"
    }
    $outputs[$key]=$archiveFile
  }
  $tradeRows=@(Import-Csv -LiteralPath $outputs.CSVFileName -Delimiter ";")
  $signalRows=@(Import-Csv -LiteralPath $outputs.TapeCSVFileName -Delimiter ";")
  $outcomeRows=@(Import-Csv -LiteralPath $outputs.OutcomeCSVFileName -Delimiter ";")
  $entryCount=@($tradeRows|Where-Object {$_.event -eq "DEAL_IN"}).Count
  $exitCount=@($tradeRows|Where-Object {$_.event -eq "DEAL_OUT"}).Count
  $filledCount=@($tradeRows|Where-Object {$_.event -eq "ORDER_FILLED"}).Count
  $resolved=@($outcomeRows|Where-Object {$_.state -notin @("NO_SLOT","CENSORED_END_NO_FUTURE_DATA")}).Count
  $ambiguous=@($outcomeRows|Where-Object {$_.state -eq "BOTH_TOUCHED_AMBIGUOUS"}).Count
  $entry=[pscustomobject]@{
     variant=$variant
     changed_inputs=$(if($variant -eq "H_RR3"){
       @{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";
         MaxOpenPositions="5";RewardRisk="3.0"}
     }else{
       @{MaxDayTrades="1440";CooldownMinutes="0";StartServerHour="0";EndServerHour="24";
         MaxOpenPositions="5";MaxLot="0.05"}
     })
     ex5_sha256=$m.compiled_sha256
     preset_sha256=(Get-FileHash -LiteralPath $frozen -Algorithm SHA256).Hash
     report_sha256=(Get-FileHash -LiteralPath $html -Algorithm SHA256).Hash
     trades_sha256=(Get-FileHash -LiteralPath $outputs.CSVFileName -Algorithm SHA256).Hash
     candidates_sha256=(Get-FileHash -LiteralPath $outputs.TapeCSVFileName -Algorithm SHA256).Hash
     outcomes_sha256=(Get-FileHash -LiteralPath $outputs.OutcomeCSVFileName -Algorithm SHA256).Hash
     filled=$filledCount
     deals_in=$entryCount
     deals_out=$exitCount
     candidates=$signalRows.Count
     shadow_resolved_m1=$resolved
     shadow_ambiguous_m1=$ambiguous
  }
  $m.experiments+=@($entry)
  Write-Host "$variant: orders=$filledCount, closes=$exitCount, M1 sinais=$($signalRows.Count)" -ForegroundColor Green
 }
 if(@($m.experiments).Count -ne 9){
   throw "Retomada incompleta: $(@($m.experiments).Count) de 9"
 }
 $m.success=$true
} catch{
 $failure=$_.Exception.Message
 $m.failure=$failure
 Write-Warning "Falha na retomada: $failure. Os 7 resultados A-G estao preservados."
} finally{
 $m|ConvertTo-Json -Depth 10|
   Set-Content -LiteralPath $manifestPath -Encoding UTF8
 $zipOut=Join-Path $packRoot ($originalName+"_RETOMADO_"+$stamp+".zip")
 Compress-Archive -Path (Join-Path $folder "*") -DestinationPath $zipOut -CompressionLevel Optimal -Force
 Write-Host "ZIP DA RETOMADA: $zipOut" -ForegroundColor Cyan
 Write-Host "Resultados reunidos: $(@($m.experiments).Count) de 9" -ForegroundColor Cyan
 Start-Process explorer.exe -ArgumentList ('"'+$packRoot+'"')|Out-Null
}
if($failure){throw "Envie ZIP de retomada e erro: $failure"}
Write-Host "ALIEN TURBO: 9 de 9 concluidos. Envie ZIP RETOMADO ao ChatGPT!" -ForegroundColor Green
