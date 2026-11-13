#requires -Version 5.1
# ALIEN R4.4 STOP PAIR SHADOW LAB - somente Strategy Tester, sem ordens.
# Um teste, um ZIP privado: eventos, desfechos hipoteticos, relatorio e hashes.
param(
  [string]$FromDate="2026.10.21",
  [string]$ToDate="2026.11.07",
  [int]$Deposit=10000,
  [int]$Leverage=100
)
$ErrorActionPreference="Stop"
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source=Join-Path $repo "MQL5\Experts\ALIEN_R44_LOCAL_STOP_SHADOW.mq5"
$baseSet=Join-Path $repo "MQL5\Profiles\Tester\ALIEN_R44_PAIR_PAIR.set"
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
if(-not (Test-Path -LiteralPath $source) -or -not (Test-Path -LiteralPath $baseSet) -or -not (Test-Path -LiteralPath $runner)) {
  throw "Arquivos do R4.4 ausentes. Abra PowerShell na pasta correta do projeto."
}
$testInstall=if(Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe"){
 "C:\ALIEN_TEST_MT5"
}else{
 Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"
}
if(-not (Test-Path (Join-Path $testInstall "terminal64.exe"))){
 throw "MT5 isolado nao encontrado. Este script nao usa a instalacao de operacao."
}
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$name="ALIEN_R44_PAIR_"+$stamp
$dest=Join-Path $repo ("results\"+$name)
$zipDir=Join-Path $repo "PACOTES_MT5"
New-Item -ItemType Directory -Force -Path $dest,$zipDir | Out-Null
$eventsName=$name+"_EVENTS.csv"
$shadowName=$name+"_OUTCOMES.csv"
$setFile=Join-Path $dest ($name+".set")
$sourceLines=Get-Content -LiteralPath $baseSet -Encoding UTF8
$changed=@($sourceLines | ForEach-Object {
 if($_ -match "^CSVFileName=") { "CSVFileName="+$eventsName }
 elseif($_ -match "^ShadowCSVFileName=") { "ShadowCSVFileName="+$shadowName }
 else {$_}
})
if(@($changed | Where-Object {$_ -match "^(CSVFileName|ShadowCSVFileName)=.*\|\|"}).Count -ne 0){
 throw "Preset CSV invalido: metadados || proibidos para input string."
}
[IO.File]::WriteAllLines($setFile,[string[]]$changed,[Text.Encoding]::ASCII)
Write-Host "=== ALIEN R4.4 STOP PAIR SHADOW LAB | SEM ORDENS ===" -ForegroundColor Cyan
Write-Host "Conta de teste isolada: $testInstall"
Write-Host "Arquivo de eventos: $eventsName"
Write-Host "Arquivo de desfechos: $shadowName"
$parameters=@{
 ExpertPath=$source; Symbol="XAUUSD"; Period="M1"; Model=4;
 FromDate=$FromDate; ToDate=$ToDate; Deposit=$Deposit;
 Leverage=$Leverage; ReportName=$name;
 ExpId=$name; StrategyName="ALIEN_R44_PAIR";
 PresetPath=$setFile; NoCsv=$true
}
& $runner @parameters

$reportCandidates=@(
 (Join-Path $testInstall ($name+".htm")),
 (Join-Path $testInstall ($name+".html")),
 (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".htm")),
 (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".html"))
)
$report=$reportCandidates | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | Select-Object -First 1
if(-not $report){throw "MT5 nao gerou relatorio HTML do R4.4. Consulte logs do agente."}
$reportCopy=Join-Path $dest ($name+[IO.Path]::GetExtension($report))
Copy-Item -LiteralPath $report -Destination $reportCopy -Force
$roots=@(
 (Join-Path $env:APPDATA "MetaQuotes\Tester"),
 (Join-Path $testInstall "Tester"),
 (Join-Path $testInstall "MQL5\Files")
)
$foundFiles=@()
foreach($filename in @($eventsName,$shadowName)){
 $candidates=@()
 foreach($root in $roots) {
  if(Test-Path -LiteralPath $root){
   $candidates+=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $filename -ErrorAction SilentlyContinue)
  }
 }
 $last=$candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 if(-not $last) {throw "CSV faltando: $filename. O experimento nao pode ser concluido."}
 Copy-Item -LiteralPath $last.FullName -Destination (Join-Path $dest $filename) -Force
 $copied=Join-Path $dest $filename
 if((Get-Item -LiteralPath $copied).Length -lt 25){
   throw "CSV vazio ou mal formado: $filename"
 }
 $foundFiles+=$copied
}
$ex5=[IO.Path]::ChangeExtension($source,".ex5")
if(-not (Test-Path -LiteralPath $ex5)) {throw "EX5 nao localizado apos compilacao."}
$shadowData=Import-Csv -LiteralPath (Join-Path $dest $shadowName) -Delimiter ";"
$openCount=@($shadowData | Where-Object {$_.state -eq "OPEN"}).Count
$closeCount=@($shadowData | Where-Object {$_.state -in @("SL","TP","TIMEOUT","GAP_TIMEOUT","CALC_ERROR","CENSURADO_FIM_DADOS")}).Count
$noPivotCount=@($shadowData | Where-Object {$_.state -eq "SEM_PIVO_LOCAL"}).Count
$m5Open=@($shadowData | Where-Object {$_.state -eq "OPEN" -and $_.stop_model -eq "STOP_M5"}).Count
$localOpen=@($shadowData | Where-Object {$_.state -eq "OPEN" -and $_.stop_model -eq "STOP_M1_LOCAL"}).Count
$manifest=[ordered]@{
 schema="alien-r44-shadow-v1"
 created_utc=(Get-Date).ToUniversalTime().ToString("o")
 symbol="XAUUSD";period="M1";model=4;
 start=$FromDate;end=$ToDate;
 statement="SHADOW: simulated counterfactual outcomes; no broker fills, no live trades"
 source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
 ex5_sha256=(Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash
 preset_sha256=(Get-FileHash -LiteralPath $setFile -Algorithm SHA256).Hash
 report_sha256=(Get-FileHash -LiteralPath $reportCopy -Algorithm SHA256).Hash
 events_sha256=(Get-FileHash -LiteralPath $foundFiles[0] -Algorithm SHA256).Hash
 shadow_sha256=(Get-FileHash -LiteralPath $foundFiles[1] -Algorithm SHA256).Hash
 shadow_open=$openCount;shadow_closed=$closeCount;shadow_m5_open=$m5Open;shadow_local_open=$localOpen;shadow_local_no_pivot=$noPivotCount
 warning="Verificar ticks reais no HTML e taxa do broker. Nao publicar no GitHub publico."
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $dest "MANIFESTO.json") -Encoding UTF8
$zip=Join-Path $zipDir ($name+".zip")
Compress-Archive -Path (Join-Path $dest "*") -DestinationPath $zip -CompressionLevel Optimal -Force
Write-Host ""
Write-Host "ALIEN R4.4: pacote gerado!" -ForegroundColor Green
Write-Host "Sinais M5=$m5Open | Local=$localOpen | Sem pivo=$noPivotCount | Desfechos=$closeCount"
Write-Host "Pacote: $zip"
Write-Host "Anexe este ZIP no ChatGPT. Nao publique o historico no GitHub."
Start-Process explorer.exe -ArgumentList ('"'+$zipDir+'"') | Out-Null
