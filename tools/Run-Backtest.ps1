# ALIEN LAB - Automated Strategy Tester Runner for MQL5 Experts
param(
    [Parameter(Mandatory=$true)][string]$ExpertPath,
    [string]$Symbol = "XAUUSD",
    [string]$Period = "M1",
    [string]$FromDate = "2026.10.21",
    [string]$ToDate = "2026.11.07",
    [int]$Model = 4, # 4 = Real Ticks, 1 = OHLC M1
    [int]$Deposit = 10000,
    [int]$Leverage = 100,
    [int]$ExecutionMode = 0, # 0 = normal, -1 = random delay
    [string]$ReportName = "ALIEN_TEST",
    [string]$ExpId = "",
    [string]$StrategyName = "",
    [string]$PresetPath = "", # Opcional: usar arquivo .set fixo para experimento controlado
    [string]$CsvPath = "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\EXPERIMENTOS.csv",
    [switch]$NoCsv = $false,
    [switch]$SkipCompile = $false
)

$ErrorActionPreference = "Stop"
# Backtests rodam SEMPRE na instalacao PORTATIL isolada (C:\ALIEN_TEST_MT5), nunca no MT5 ao vivo.
# (ShutdownTerminal=1 neste script fechava o MT5 de operacao real.)
$liveInstall = "C:\Program Files\RoboForex MT5 Terminal"
$install = if (Test-Path "C:\ALIEN_TEST_MT5\terminal64.exe") {
    "C:\ALIEN_TEST_MT5"
} else {
    Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"
}
if (-not (Test-Path (Join-Path $install "terminal64.exe"))) {
    throw "MT5 de teste nao encontrado em $install. Execute tools\CRIAR_MT5_TESTE_SEGURO.ps1. Nao use o MT5 de conta real."
}
$terminal = Join-Path $install "terminal64.exe"
$editor = Join-Path $liveInstall "metaeditor64.exe"   # so compila; nao mexe no terminal ao vivo
$dataRoot = $install                                    # modo /portable: dados ficam na propria pasta

if (-not (Test-Path $ExpertPath)) { throw "Expert nao encontrado: $ExpertPath" }
if (-not (Test-Path $terminal)) { throw "Terminal MT5 nao encontrado: $terminal" }
if (-not (Test-Path $editor)) { throw "MetaEditor MT5 nao encontrado: $editor" }

Write-Host "=== ALIEN LAB TEST RUNNER ===" -ForegroundColor Cyan
Write-Host "Ativo: $Symbol | TF: $Period | De: $FromDate Ate: $ToDate | Modelo: $Model | Deposito: $Deposit"

# 1. Compilar Expert para pasta de testes
$testDir = Join-Path $dataRoot "MQL5\Experts\ALIEN_LAB_EXCLUSIVO_TESTADOR"
if (-not (Test-Path $testDir)) { New-Item -ItemType Directory -Path $testDir -Force | Out-Null }
$expertName = [System.IO.Path]::GetFileNameWithoutExtension($ExpertPath)
$targetEx5 = Join-Path $testDir ($expertName + ".ex5")
$compileLog = Join-Path $env:TEMP "compile_$expertName.log"

if (-not $SkipCompile) {
Write-Host "Compilando $expertName..." -ForegroundColor Yellow
$procComp = Start-Process -FilePath $editor -ArgumentList "/compile:`"$ExpertPath`" /log:`"$compileLog`"" -Wait -PassThru
if (-not (Test-Path $compileLog)) { throw "MetaEditor nao gerou log." }
$logContent = Get-Content $compileLog -Raw
if ($logContent -notmatch "(?:Result|Resultado)\s*:\s*0\s+(?:errors?|erros?)") {
    Write-Host $logContent -ForegroundColor Red
    throw "Compilacao falhou com erros."
}
Write-Host "Compilacao OK (0 erros)." -ForegroundColor Green

} else {
    Write-Host "Usando EX5 congelado sem recompilar: $expertName" -ForegroundColor Cyan
}

# Se a compilacao foi gerada na pasta de origem, mover/copiar para ALIEN_LAB_EXCLUSIVO_TESTADOR
$originEx5 = [System.IO.Path]::ChangeExtension($ExpertPath, ".ex5")
if (Test-Path $originEx5) {
    Copy-Item $originEx5 $targetEx5 -Force
} else {
    throw "EX5 de origem ausente: $originEx5. Nao executar usando binario antigo."
}

# 2. Sincronizar .set do repositorio ou criar padrao
$setDir = Join-Path $dataRoot "MQL5\Profiles\Tester"
if (-not (Test-Path $setDir)) { New-Item -ItemType Directory -Path $setDir -Force | Out-Null }
$setFile = Join-Path $setDir ($expertName + ".set")

$repoSet = "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\MQL5\Profiles\Tester\$expertName.set"
if ($PresetPath) {
    if (-not (Test-Path -LiteralPath $PresetPath -PathType Leaf)) {
        throw "Preset personalizado nao encontrado: $PresetPath"
    }
    $frozen = (Resolve-Path -LiteralPath $PresetPath).Path
    Copy-Item -LiteralPath $frozen -Destination $setFile -Force
    Write-Host "Preset congelado usado: $frozen" -ForegroundColor Green
} elseif (Test-Path $repoSet) {
    Copy-Item $repoSet $setFile -Force
    Write-Host "Parametros .set sincronizados do repositorio: $repoSet" -ForegroundColor Green
} elseif (-not (Test-Path $setFile)) {
    "; Default parameters" | Out-File -FilePath $setFile -Encoding ASCII
}

# 3. Criar arquivo .ini para inicializacao do MT5
$iniPath = Join-Path $env:TEMP ("CONFIG_" + $expertName + ".ini")
$lines = @(
    "[Common]",
    "NewsEnable=0",
    "",
    "[Experts]",
    "AllowLiveTrading=0",
    "AllowDllImport=0",
    "Enabled=1",
    "",
    "[Tester]",
    ("Expert=ALIEN_LAB_EXCLUSIVO_TESTADOR\" + $expertName),
    ("ExpertParameters=" + $expertName + ".set"),
    ("Symbol=" + $Symbol),
    ("Period=" + $Period),
    ("Model=" + $Model),
    ("ExecutionMode=" + $ExecutionMode),
    "Optimization=0",
    ("FromDate=" + $FromDate),
    ("ToDate=" + $ToDate),
    "ForwardMode=0",
    ("Report=" + $ReportName),
    "ReplaceReport=1",
    "ShutdownTerminal=1",
    ("Deposit=" + $Deposit),
    "Currency=USD",
    ("Leverage=1:" + $Leverage),
    "UseLocal=1",
    "UseRemote=0",
    "UseCloud=0",
    "Visual=0"
)
[System.IO.File]::WriteAllLines($iniPath, [string[]]$lines, [System.Text.Encoding]::ASCII)
Write-Host "Config gravada em $iniPath"

# 4. Executar Terminal MT5
Write-Host "Iniciando simulacao no MT5..." -ForegroundColor Cyan
$start = Get-Date
$arg = '/portable /config:"' + $iniPath + '"'
$proc = Start-Process -FilePath $terminal -WorkingDirectory $install -ArgumentList $arg -PassThru

# Monitorar execucao
while (-not $proc.HasExited) {
    Start-Sleep -Seconds 3
    $elapsed = [math]::Round(((Get-Date) - $start).TotalSeconds)
    Write-Host "Simulacao em andamento... (${elapsed}s)" -NoNewline
    Write-Host "`r" -NoNewline
}
Write-Host "`nMT5 finalizou com codigo de saida: $($proc.ExitCode)" -ForegroundColor Green

# 5. Localizar relatorio gerado
Start-Sleep -Seconds 2
$candPaths = @(
    (Join-Path $dataRoot ($ReportName + ".htm")),
    (Join-Path $dataRoot ($ReportName + ".html")),
    (Join-Path (Join-Path $dataRoot "reports") ($ReportName + ".htm")),
    (Join-Path (Join-Path $dataRoot "reports") ($ReportName + ".html"))
)

$finalReport = $null
foreach ($p in $candPaths) {
    if (Test-Path $p) { $finalReport = $p; break }
}

if (-not $finalReport) {
    Write-Host "AVISO: Relatorio nao encontrado nas pastas esperadas. Verificando logs..." -ForegroundColor Red
    $logFile = Get-ChildItem -Path (Join-Path $dataRoot "logs") -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($logFile) { Get-Content $logFile.FullName -Tail 20 | Write-Host }
    exit 1
}

# Copiar relatorio e imagens para ALIEN_LAB\results
$destResultDir = "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\results\$ReportName"
if (-not (Test-Path $destResultDir)) { New-Item -ItemType Directory -Path $destResultDir -Force | Out-Null }
Copy-Item $finalReport -Destination $destResultDir -Force
Get-ChildItem -Path (Split-Path $finalReport) -Filter "$ReportName*.png" | Copy-Item -Destination $destResultDir -Force
Get-ChildItem -Path (Split-Path $finalReport) -Filter "$ReportName*.gif" | Copy-Item -Destination $destResultDir -Force

Write-Host "Relatorio gerado e arquivado em: $destResultDir" -ForegroundColor Green


Write-Host "Relatorio gerado: $finalReport" -ForegroundColor Green

# 6. Parse e Gravacao Automatica via parse_and_record_results.py
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = "C:\Users\notebook\.gemini\antigravity\scratch\ALIEN_LAB\tools" }
$parserScript = Join-Path $scriptDir "parse_and_record_results.py"

$reportToParse = Join-Path $destResultDir (Split-Path $finalReport -Leaf)
if (-not (Test-Path $reportToParse)) { $reportToParse = $finalReport }

if (Test-Path $parserScript) {
    Write-Host "`n=== METRICAS E CONSOLIDACAO DO TESTE ===" -ForegroundColor Cyan
    $pArgs = @($parserScript, "--report", $reportToParse)
    
    $effectiveExpId = if ($ExpId) { $ExpId } else { $ReportName }
    $pArgs += @("--exp-id", $effectiveExpId)
    
    $effectiveStrategy = if ($StrategyName) { $StrategyName } else { $expertName }
    $pArgs += @("--strategy", $effectiveStrategy)
    
    if (-not $NoCsv -and $CsvPath) {
        $pArgs += @("--csv", $CsvPath)
    }
    
    & python @pArgs
} else {
    Write-Host "AVISO: Parser unificado ($parserScript) nao encontrado. Exibindo resumo basico:" -ForegroundColor Yellow
    $content = Get-Content -Path $finalReport -Raw
    $profit = if ($content -match '(?:Total Net Profit|Lucro L[^q<]*quido Total)[:\s]*</td>\s*<td[^>]*><b>(.*?)</b>') { $matches[1] } else { "N/A" }
    $pf = if ($content -match '(?:Profit Factor|Fator de Lucro)[:\s]*</td>\s*<td[^>]*><b>(.*?)</b>') { $matches[1] } else { "N/A" }
    $trades = if ($content -match '(?:Total Trades|Total de Neg[^o<]*cios)[:\s]*</td>\s*<td[^>]*><b>(.*?)</b>') { $matches[1] } else { "N/A" }
    $dd = if ($content -match '(?:Maximal Drawdown|Rebaixamento M[^a<]*ximo)[:\s]*</td>\s*<td[^>]*><b>(.*?)</b>') { $matches[1] } else { "N/A" }

    Write-Host "=== RESULTADOS DA SIMULACAO ===" -ForegroundColor Yellow
    Write-Host "Lucro Liquido: $profit USD"
    Write-Host "Fator de Lucro: $pf"
    Write-Host "Total de Trades: $trades"
    Write-Host "Drawdown Maximo: $dd"
}
