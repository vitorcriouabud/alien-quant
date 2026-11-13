#requires -Version 5.1
# ALIEN R4.3 - duas simulacoes shadow, nenhuma ordem.
param(
  [string]$FromDate="2026.10.21",
  [string]$ToDate="2026.11.07",
  [int]$Deposit=10000,
  [int]$Leverage=100
)
$ErrorActionPreference="Stop"
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source=Join-Path $repo "MQL5\Experts\ALIEN_R43_EARLY_M1_SHADOW.mq5"
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
$presets=Join-Path $repo "MQL5\Profiles\Tester"
$terminal=if(Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe") {"C:\ALIEN_TEST_MT5"} else {Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"}
foreach($p in @($source,$runner,(Join-Path $terminal "terminal64.exe"))){
 if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Arquivo ausente: $p"}
}
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$dest=Join-Path $repo ("results\ALIEN_R43_AB_"+$stamp)
$packageDir=Join-Path $repo "PACOTES_MT5"
New-Item -ItemType Directory -Force -Path $dest,$packageDir | Out-Null
$modes=@(
 @{tag="A_DESLOCAMENTO";set="ALIEN_R43_A_DESLOCAMENTO.set";micro="false"},
 @{tag="B_MICROBREAK";set="ALIEN_R43_B_MICROBREAK.set";micro="true"}
)
$manifest=[ordered]@{
 schema="alien-r43-ab-v1"
 date_utc=(Get-Date).ToUniversalTime().ToString("o")
 strategy="Hypothetical only - no orders"
 symbol="XAUUSD"
 timeframe="M1"
 model=4
 start=$FromDate
 end=$ToDate
 experiments=@()
}
$firstSource="";$firstExe=""
foreach($mode in $modes){
 $base=Join-Path $presets $mode.set
 if(-not(Test-Path $base)){throw "Preset nao encontrado: $base"}
 $name="ALIEN_R43_"+$mode.tag+"_"+$stamp
 $eventsName=$name+"_EVENTS.csv"
 $shadowName=$name+"_SHADOW.csv"
 $frozen=Join-Path $dest ($name+".set")
 $text=@(Get-Content -LiteralPath $base -Encoding UTF8 | ForEach-Object {
   if($_ -match "^CSVFileName="){"CSVFileName="+$eventsName}
   elseif($_ -match "^ShadowCSVFileName="){"ShadowCSVFileName="+$shadowName}
   else {$_}
 })
 [IO.File]::WriteAllLines($frozen,[string[]]$text,[Text.Encoding]::ASCII)
 if(@($text | Where-Object {$_ -match '^(CSVFileName|ShadowCSVFileName)=.*\|\|'}).Count){
  throw "Input string CSV invalido. Abortando."
 }
 $matches=@($text | Where-Object {$_ -like "UseEarlyMicroBreak=*" })
 if($matches.Count -ne 1 -or -not $matches[0].StartsWith("UseEarlyMicroBreak="+$mode.micro+"||")){
   throw "Input de modo M1 incorreto."
 }
 $began=Get-Date
 $params=@{
  ExpertPath=$source; Symbol="XAUUSD"; Period="M1"; Model=4;
  FromDate=$FromDate; ToDate=$ToDate; Deposit=$Deposit; Leverage=$Leverage;
  ReportName=$name; ExpId=$name; StrategyName=$name;
  PresetPath=$frozen; NoCsv=$true; SkipCompile=($mode.micro -eq "true")
 }
 Write-Host ("Iniciando ALIEN R4.3 "+$mode.tag) -ForegroundColor Cyan
 & $runner @params
 $exe=[IO.Path]::ChangeExtension($source,".ex5")
 if(-not(Test-Path $exe)){throw "Compilacao EX5 ausente."}
 $hs=(Get-FileHash $source -Algorithm SHA256).Hash
 $he=(Get-FileHash $exe -Algorithm SHA256).Hash
 if($firstSource -and $firstSource -ne $hs){throw "MQ5 alterado entre A e B"}
 if($firstExe -and $firstExe -ne $he){throw "EX5 alterado entre A e B"}
 $firstSource=$hs;$firstExe=$he
 $possible=@(
  (Join-Path $terminal ($name+".htm")),
  (Join-Path $terminal ($name+".html")),
  (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".htm")),
  (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".html"))
 )
 $report=$possible | Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1
 if(-not $report){throw "Sem relatorio HTML: $name"}
 $html=Join-Path $dest ($name+[IO.Path]::GetExtension($report))
 Copy-Item $report $html -Force
 $roots=@((Join-Path $terminal "tester"),(Join-Path $env:APPDATA "MetaQuotes\Tester"),(Join-Path $terminal "MQL5\Files"))
 $copied=@()
 foreach($csv in @($eventsName,$shadowName)){
  $all=@()
  foreach($root in $roots){
   if(Test-Path $root){
    $all+=@(Get-ChildItem -LiteralPath $root -Filter $csv -File -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -ge $began.AddMinutes(-2)})
   }
  }
  $found=$all | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(-not $found){throw "Nao achou CSV: $csv"}
  $target=Join-Path $dest $csv
  Copy-Item $found.FullName $target -Force
  if((Get-Item $target).Length -lt 30){throw "CSV vazio: $csv"}
  $copied+=$target
 }
 $manifest.experiments+=@([ordered]@{
  mode=$mode.tag
  source_sha256=$hs
  exe_sha256=$he
  set_sha256=(Get-FileHash $frozen -Algorithm SHA256).Hash
  report_sha256=(Get-FileHash $html -Algorithm SHA256).Hash
  events_sha256=(Get-FileHash $copied[0] -Algorithm SHA256).Hash
  shadow_sha256=(Get-FileHash $copied[1] -Algorithm SHA256).Hash
 })
}
$manifest | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $dest "MANIFESTO.json") -Encoding UTF8
$zip=Join-Path $packageDir ("ALIEN_R43_AB_"+$stamp+".zip")
Compress-Archive -Path (Join-Path $dest "*") -DestinationPath $zip -Force
Write-Host ("ALIEN R4.3: ZIP privado pronto em "+$zip) -ForegroundColor Green
Start-Process explorer.exe -ArgumentList ('"'+$packageDir+'"')
