param(
    [ValidateSet("Executar","Coletar")]
    [string]$Acao = "Executar"
)
$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$Resultado = Join-Path $Raiz "RESULTADOS_ALIEN"
New-Item -ItemType Directory -Path $Resultado -Force | Out-Null
$Log = Join-Path $Resultado "DIAGNOSTICO.txt"
Set-Content -LiteralPath $Log -Value "ALIEN - RoboForex instalado - teste somente em DEMO" -Encoding UTF8

function Registro([string]$Mensagem) {
    $linha = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $Mensagem
    Write-Host $linha
    Add-Content -LiteralPath $Log -Value $linha -Encoding UTF8
}
function EncontrarTerminal {
    $candidatos = @(
        "C:\Program Files\RoboForex MT5 Terminal\terminal64.exe",
        "C:\Program Files (x86)\RoboForex MT5 Terminal\terminal64.exe"
    )
    foreach ($caminho in $candidatos) {
        if (Test-Path -LiteralPath $caminho -PathType Leaf) { return $caminho }
    }
    foreach ($processo in @(Get-Process -Name terminal64 -ErrorAction SilentlyContinue)) {
        try {
            $caminho = $processo.Path
            if ($caminho -and $caminho -match "RoboForex" -and (Test-Path -LiteralPath $caminho -PathType Leaf)) {
                return $caminho
            }
        } catch {}
    }
    throw "Nao achei RoboForex terminal64.exe. Nenhum arquivo da sua instalacao foi alterado."
}
function EncontrarDados([string]$Instalacao, [string]$Terminal) {
    $raizDados = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path -LiteralPath $raizDados -PathType Container)) {
        throw "Nao achei a pasta de dados MetaQuotes do Windows."
    }
    foreach ($pasta in @(Get-ChildItem -LiteralPath $raizDados -Directory -ErrorAction Stop)) {
        $origem = Join-Path $pasta.FullName "origin.txt"
        if (-not (Test-Path -LiteralPath $origem -PathType Leaf)) { continue }
        try {
            $texto = (Get-Content -LiteralPath $origem -Raw -ErrorAction Stop).Trim().TrimStart([char]0xFEFF)
            $compativel = ($texto -ieq $Instalacao) -or ($texto -ieq $Terminal) -or
                          ($texto.TrimEnd([char]'\') -ieq $Instalacao.TrimEnd([char]'\'))
            if ($compativel -and (Test-Path -LiteralPath (Join-Path $pasta.FullName "MQL5\Experts") -PathType Container)) {
                return $pasta.FullName
            }
        } catch {}
    }
    $portable = Join-Path $Instalacao "MQL5\Experts"
    if (Test-Path -LiteralPath $portable -PathType Container) { return $Instalacao }
    throw "Nao identifiquei com seguranca a pasta de dados deste RoboForex. Parei sem instalar em outra conta."
}
function Coletar([string]$Dados, [string]$Instalacao) {
    if ($Dados) {
        $logs = Join-Path $Dados "Tester\logs"
        if (Test-Path -LiteralPath $logs -PathType Container) {
            try {
                $recentes = @(Get-ChildItem -LiteralPath $logs -Filter "*.log" -File |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 2)
                foreach ($arquivo in $recentes) {
                    $linhas = Get-Content -LiteralPath $arquivo.FullName -Tail 700 -ErrorAction Stop
                    $linhas | Set-Content -LiteralPath (Join-Path $Resultado ("TESTER_" + $arquivo.Name + ".txt")) -Encoding UTF8
                }
            } catch { Registro ("Aviso: nao foi possivel coletar logs: " + $_.Exception.Message) }
        }
    }
    foreach ($origem in @($Instalacao, $Resultado)) {
        if (-not $origem -or -not (Test-Path -LiteralPath $origem -PathType Container)) { continue }
        $relatorios = @(Get-ChildItem -LiteralPath $origem -Filter "ALIEN_ROBO_RESULTADO*.htm" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        foreach ($arquivo in $relatorios) {
            if ($arquivo.DirectoryName -ne $Resultado) {
                Copy-Item -LiteralPath $arquivo.FullName -Destination (Join-Path $Resultado $arquivo.Name) -Force
            }
        }
    }
    $zip = Join-Path $Raiz "ENVIAR_AO_CHATGPT.zip"
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $Resultado "*") -DestinationPath $zip -Force
    Write-Host ""
    Write-Host ("DIAGNOSTICO CRIADO: " + $zip) -ForegroundColor Green
}
$Dados = ""
$Instalacao = ""
try {
    Registro "Iniciando no RoboForex ja instalado. Nenhuma conta ou senha sera alterada."
    $Terminal = EncontrarTerminal
    $Instalacao = Split-Path -Parent $Terminal
    $Dados = EncontrarDados -Instalacao $Instalacao -Terminal $Terminal
    Registro ("Programa: " + $Terminal)
    Registro ("Dados corretos: " + $Dados)
    if ($Acao -eq "Coletar") {
        Coletar -Dados $Dados -Instalacao $Instalacao
        exit 0
    }
    $Fonte = Join-Path $Raiz "GOLDTREND_LAB_DEMO_V0_10.mq5"
    if (-not (Test-Path -LiteralPath $Fonte -PathType Leaf)) { throw "Arquivo MQ5 nao esta junto do iniciador. Extraia o ZIP inteiro." }
    $textoFonte = Get-Content -LiteralPath $Fonte -Raw -ErrorAction Stop
    if ($textoFonte -notmatch "InpEnableDemoOrders\s*=\s*false" -or
        $textoFonte -notmatch "ACCOUNT_TRADE_MODE_DEMO") {
        throw "Fonte nao passou pela checagem de seguranca DEMO. Instalacao cancelada."
    }
    $hash = (Get-FileHash -LiteralPath $Fonte -Algorithm SHA256).Hash.Substring(0,10)
    $nomeBase = "GOLDTREND_DEMO_" + $hash
    $destFolder = Join-Path $Dados "MQL5\Experts\ALIEN_LAB_SOMENTE_TESTADOR"
    New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    $destino = Join-Path $destFolder ($nomeBase + ".mq5")
    if (Test-Path -LiteralPath $destino -PathType Leaf) {
        $hashDestino = (Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash
        $hashFonte = (Get-FileHash -LiteralPath $Fonte -Algorithm SHA256).Hash
        if ($hashDestino -ne $hashFonte) { throw "Fonte ja existente foi alterada; nada sera sobrescrito." }
    } else {
        Copy-Item -LiteralPath $Fonte -Destination $destino -ErrorAction Stop
    }
    Registro ("Fonte isolada: " + $destino)
    $editor = Join-Path $Instalacao "metaeditor64.exe"
    if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) { throw "MetaEditor64 nao encontrado junto do RoboForex." }
    $logCompilacao = Join-Path $Resultado "COMPILACAO_MT5.log"
    if (Test-Path -LiteralPath $logCompilacao) { Remove-Item -LiteralPath $logCompilacao -Force }
    Registro "Compilando no MetaEditor da sua RoboForex..."
    $inicioCompilacao = Get-Date
    $argumentos = '/compile:"' + $destino + '" /log:"' + $logCompilacao + '"'
    $compilador = Start-Process -FilePath $editor -ArgumentList $argumentos -Wait -PassThru -ErrorAction Stop
    $ex5 = [System.IO.Path]::ChangeExtension($destino, ".ex5")
    if (-not (Test-Path -LiteralPath $ex5 -PathType Leaf)) {
        throw "MetaEditor nao gerou EX5. Veja COMPILACAO_MT5.log no ZIP."
    }
    if ((Get-Item -LiteralPath $ex5).LastWriteTime -lt $inicioCompilacao.AddSeconds(-3)) {
        throw "EX5 e antigo; compilacao recente nao foi confirmada."
    }
    if (Test-Path -LiteralPath $logCompilacao -PathType Leaf) {
        $textoLog = Get-Content -LiteralPath $logCompilacao -Raw -ErrorAction Stop
        if ($textoLog -match "(?im)\b[1-9][0-9]*\s+(?:errors?|erros?)\b") {
            throw "O MetaEditor registrou erros de compilacao. Consulte COMPILACAO_MT5.log."
        }
    }
    Registro ("EX5 recente encontrado: " + $ex5 + " / ExitCode " + $compilador.ExitCode)
    $setFolder = Join-Path $Dados "MQL5\Profiles\Tester"
    New-Item -ItemType Directory -Path $setFolder -Force | Out-Null
    $setName = $nomeBase + "_ALIEN_DEMO.set"
    $setFile = Join-Path $setFolder $setName
    $setTexto = @'
InpEnableDemoOrders=true||false||0||true||N
InpRiskPercent=0.25||0.25||0.01||1||N
InpMaxTradesDay=1||1||1||5||N
'@
    if (-not (Test-Path -LiteralPath $setFile -PathType Leaf)) {
        Set-Content -LiteralPath $setFile -Value $setTexto -Encoding ASCII
    }
    $ini = Join-Path $Resultado "CONFIG_TESTADOR.ini"
    $iniTexto = @"
[Tester]
Expert=ALIEN_LAB_SOMENTE_TESTADOR\$nomeBase.ex5
ExpertParameters=$setName
Symbol=XAUUSD
Period=M1
Model=4
Optimization=0
FromDate=2026.11.13
ToDate=2026.11.18
Deposit=5000
Currency=USD
Leverage=1:100
Visual=0
Report=ALIEN_ROBO_RESULTADO_$hash
ReplaceReport=1
ShutdownTerminal=1
"@
    Set-Content -LiteralPath $ini -Value $iniTexto -Encoding ASCII
    $abertos = @(Get-Process -Name terminal64 -ErrorAction SilentlyContinue)
    if ($abertos.Count -gt 0) {
        Registro "RoboForex aberto. NAO vou fecha-lo, trocar conta ou interromper operacoes."
        Registro "Preparacao concluida. Para rodar TESTE AUTOMATICO, feche o RoboForex e execute 01_INICIAR_ALIEN.bat novamente."
        Coletar -Dados $Dados -Instalacao $Instalacao
        exit 0
    }
    Registro "MT5 fechado: iniciando Strategy Tester na mesma instalacao com o login salvo."
    Registro "Conta real nao executara ordens: EA verifica ACCOUNT_TRADE_MODE_DEMO."
    $parametros = '/config:"' + $ini + '"'
    $teste = Start-Process -FilePath $Terminal -ArgumentList $parametros -PassThru -ErrorAction Stop
    $terminou = $teste.WaitForExit(1200000)
    if (-not $terminou) {
        Registro "O MT5 continua aberto apos o tempo de coleta. Nao foi encerrado a forca."
        Registro "Quando finalizar, use 02_COLETAR_RESULTADOS.bat."
    } else {
        Registro ("MT5 finalizou o processamento; ExitCode=" + $teste.ExitCode)
    }
    Coletar -Dados $Dados -Instalacao $Instalacao
    exit 0
}
catch {
    Registro ("ERRO: " + $_.Exception.Message)
    try { Coletar -Dados $Dados -Instalacao $Instalacao }
    catch { Write-Host ("Falha ao criar ZIP: " + $_.Exception.Message) -ForegroundColor Red }
    exit 1
}