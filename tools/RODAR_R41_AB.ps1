#requires -Version 5.1
# ALIEN R4.1: A/B sequencial e testador MT5 portatil, sem conta real.
param(
  [string]$FromDate="2026.10.21",
  [string]$ToDate="2026.11.07",
  [int]$Deposit=10000,
  [int]$Leverage=100
)
$ErrorActionPreference="Stop"
$repo=(Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$source=Join-Path $repo "MQL5\Experts\ALIEN_GENESIS_MTF_R41_DEMO.mq5"
$runner=Join-Path $repo "tools\Run-Backtest.ps1"
$preDir=Join-Path $repo "MQL5\Profiles\Tester"
if (-not (Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe")) {
  throw "Terminal TESTADOR portatil ausente em C:\ALIEN_TEST_MT5. NAO use terminal real."
}
if (-not (Test-Path $runner) -or -not (Test-Path $source)) {
  throw "Arquivos do projeto ausentes."
}
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"
$dest=Join-Path $repo ("results\R41_AB_"+$stamp)
$packageDir=Join-Path $repo "PACOTES_MT5"
New-Item -ItemType Directory -Force -Path $dest,$packageDir | Out-Null
$experiments=@(
  @{tag="A_BASELINE"; preset=(Join-Path $preDir "ALIEN_R41_A_BASELINE.set")},
  @{tag="B_RETESTE"; preset=(Join-Path $preDir "ALIEN_R41_B_RETESTE.set")}
)
$rows=@()
$knownSourceSha=""
$knownExeSha=""
foreach($exp in $experiments) {
  if (-not (Test-Path -LiteralPath $exp.preset)) { throw "Preset ausente: $($exp.preset)" }
  $name="ALIEN_R41_"+$exp.tag+"_"+$stamp
  $csvName=$name+".csv"
  $workingSet=Join-Path $dest ($name+".set")
  $lines=Get-Content -LiteralPath $exp.preset -Encoding UTF8
  $replace="CSVFileName="+$csvName+"||"+$csvName+"||0||"+$csvName+"||N"
  $changed=@($lines | ForEach-Object { if($_ -match '^CSVFileName=') {$replace} else {$_} })
  [System.IO.File]::WriteAllLines($workingSet,[string[]]$changed,[System.Text.Encoding]::ASCII)
  $start=Get-Date
  Write-Host ("=== ALIEN R4.1 | "+$exp.tag+" | "+$FromDate+" - "+$ToDate+" ===") -ForegroundColor Cyan
  $parameters=@{
    ExpertPath=$source; Symbol="XAUUSD"; Period="M1"; Model=4;
    FromDate=$FromDate; ToDate=$ToDate; Deposit=$Deposit;
    Leverage=$Leverage; ReportName=$name; ExpId=$name;
    StrategyName=("ALIEN_R41_"+$exp.tag);
    PresetPath=$workingSet; NoCsv=$true;
    SkipCompile=($exp.tag -eq "B_RETESTE")
  }
  & $runner @parameters
  $ex5=[IO.Path]::ChangeExtension($source,".ex5")
  if (-not (Test-Path -LiteralPath $ex5 -PathType Leaf)) {
    throw "EX5 nao existe apos compilar: $ex5"
  }
  $sourceSha=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
  $exeSha=(Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash
  if ($knownSourceSha -ne "" -and $sourceSha -ne $knownSourceSha) {
    throw "Codigo MQ5 mudou entre A e B. Comparacao invalida."
  }
  if ($knownExeSha -ne "" -and $exeSha -ne $knownExeSha) {
    throw "EX5 diferente entre A e B. Comparacao invalida."
  }
  $knownSourceSha=$sourceSha
  $knownExeSha=$exeSha
  $reportCandidates=@(
    (Join-Path "C:\ALIEN_TEST_MT5" ($name+".htm")),
    (Join-Path "C:\ALIEN_TEST_MT5" ($name+".html")),
    (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".htm")),
    (Join-Path "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$name" ($name+".html"))
  )
  $report=$reportCandidates | Where-Object {Test-Path -LiteralPath $_} | Select-Object -First 1
  if (-not $report) {throw "Relatorio de "+$name+" nao localizado. Inspecione logs MT5."}
  $copyReport=Join-Path $dest ($name+[IO.Path]::GetExtension($report))
  Copy-Item -LiteralPath $report -Destination $copyReport -Force

  $testRoots=@(
     (Join-Path $env:APPDATA "MetaQuotes\Tester"),
     "C:\ALIEN_TEST_MT5\Tester",
     "C:\ALIEN_TEST_MT5\MQL5\Files"
  )
  $candidates=@()
  foreach($root in $testRoots) {
    if(Test-Path $root) {
      $candidates+=@(Get-ChildItem -LiteralPath $root -Filter $csvName -File -Recurse -ErrorAction SilentlyContinue |
                      Where-Object {$_.LastWriteTime -ge $start.AddMinutes(-2)})
    }
  }
  $latest=$candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $copiedCsv=""
  if($latest){
     $copiedCsv=Join-Path $dest $csvName
     Copy-Item -LiteralPath $latest.FullName -Destination $copiedCsv -Force
  } else {
     Write-Warning "CSV do experimento $name nao encontrado. Resultado incompleto."
  }
  $rows+=@{
     experiment=$name; mode=$exp.tag; model=4;
     interval=($FromDate+" - "+$ToDate);
     source_sha256=$sourceSha; ex5_sha256=$exeSha;
     preset_sha256=(Get-FileHash $workingSet -Algorithm SHA256).Hash;
     report_sha256=(Get-FileHash $copyReport -Algorithm SHA256).Hash;
     csv_present=($copiedCsv -ne "");
     csv_sha256=$(if($copiedCsv){(Get-FileHash $copiedCsv -Algorithm SHA256).Hash}else{""})
  }
}
$manifest=@{
 schema="alien-r41-ab-v1"; generated=(Get-Date).ToUniversalTime().ToString("o");
 warning="Verificar no HTML % ticks reais e custos. Nao publicar relatorios no GitHub.";
 experiments=$rows
}
$json=ConvertTo-Json -InputObject $manifest -Depth 8
[IO.File]::WriteAllText((Join-Path $dest "MANIFESTO.json"),$json,[Text.Encoding]::UTF8)
$zip=Join-Path $packageDir ("ALIEN_R41_AB_"+$stamp+".zip")
Compress-Archive -Path (Join-Path $dest "*") -DestinationPath $zip -CompressionLevel Optimal -Force
Write-Host "ALIEN R4.1 A/B: arquivo privado pronto em: $zip" -ForegroundColor Green
Write-Host "Anexe este ZIP no ChatGPT. Nao publique em repositorio publico."
Start-Process explorer.exe -ArgumentList ('"'+$packageDir+'"') | Out-Null
