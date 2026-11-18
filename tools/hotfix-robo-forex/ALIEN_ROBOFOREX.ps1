# ALIEN_ROBOFOREX.ps1 - correcao integral do preparador
# COMPATIVEL: Windows PowerShell 5.1. Nao inicia negociacao, nao troca conta.
param(
    [string]$Acao = "Preparar",
    [string]$Modo = "",
    [string]$Action = "",
    [string]$Mode = "",
    [string]$Operacao = ""
)

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log = Join-Path $Raiz "ALIEN_DIAGNOSTICO.txt"
$Saida = Join-Path $Raiz "ENVIAR_AO_CHATGPT"
New-Item -ItemType Directory -Path $Saida -Force | Out-Null

function Registro([string]$Mensagem) {
    $linha = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " " + $Mensagem
    Write-Host $linha
    Add-Content -LiteralPath $Log -Value $linha -Encoding UTF8
}
function LocalizarTerminal {
    $candidatos = @(
        "C:\Program Files\RoboForex MT5 Terminal\terminal64.exe",
        "C:\Program Files (x86)\RoboForex MT5 Terminal\terminal64.exe"
    )
    foreach ($p in $candidatos) {
        if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
    }
    $processos = @(Get-Process -Name "terminal64" -ErrorAction SilentlyContinue)
    foreach ($processo in $processos) {
        try {
            $caminho = $processo.Path
            if ($caminho -and ($caminho -match "RoboForex") -and (Test-Path -LiteralPath $caminho -PathType Leaf)) {
                return $caminho
            }
        } catch {}
    }
    throw "RoboForex terminal64.exe nao encontrado. Confira se esta instalado."
}
function LocalizarDados([string]$Instalacao, [string]$Terminal) {
    $principal = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path -LiteralPath $principal -PathType Container)) {
        throw "Pasta MetaQuotes nao encontrada em APPDATA."
    }
    $pastas = @(Get-ChildItem -LiteralPath $principal -Directory -ErrorAction Stop)
    foreach ($pasta in $pastas) {
        $origem = Join-Path $pasta.FullName "origin.txt"
        if (-not (Test-Path -LiteralPath $origem -PathType Leaf)) { continue }
        $conteudo = (Get-Content -LiteralPath $origem -Raw -ErrorAction Stop).Trim()
        $conteudo = $conteudo.TrimStart([char]0xFEFF)
        $combina = $false
        if ($conteudo -ieq $Instalacao) { $combina = $true }
        if ($conteudo -ieq $Terminal) { $combina = $true }
        if ($conteudo.StartsWith($Instalacao + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
            $combina = $true
        }
        if (-not $combina) { continue }
        $experts = Join-Path $pasta.FullName "MQL5\Experts"
        if (Test-Path -LiteralPath $experts -PathType Container) {
            return $pasta.FullName
        }
    }
    $portableExperts = Join-Path $Instalacao "MQL5\Experts"
    if (Test-Path -LiteralPath $portableExperts -PathType Container) { return $Instalacao }
    throw "Pasta de dados RoboForex nao identificada com seguranca. No MT5 use Arquivo > Abrir Pasta de Dados."
}
function LocalizarFonte {
    $nome = "GOLDTREND_AUDITADO_DEMO_V3_30.mq5"
    $fontes = @(Get-ChildItem -LiteralPath $Raiz -File -Recurse -Filter $nome -ErrorAction SilentlyContinue)
    if ($fontes.Count -eq 0) {
        throw "Nao achei $nome na pasta extraida. Mantenha este PS1 junto dos arquivos do ZIP anterior."
    }
    return $fontes[0].FullName
}
function Coletar([string]$Dados) {
    if (Test-Path -LiteralPath $Log) {
        Copy-Item -LiteralPath $Log -Destination (Join-Path $Saida "ALIEN_DIAGNOSTICO.txt") -Force
    }
    if ($Dados) {
        $tester = Join-Path $Dados "Tester\logs"
        if (Test-Path -LiteralPath $tester -PathType Container) {
            $arquivos = @(Get-ChildItem -LiteralPath $tester -File -Filter "*.log" |
                Sort-Object LastWriteTime -Descending | Select-Object -First 2)
            foreach ($f in $arquivos) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $Saida ("MT5_" + $f.Name)) -Force
            }
        }
    }
    $arquivoZip = Join-Path $Raiz "ENVIAR_AO_CHATGPT.zip"
    if (Test-Path -LiteralPath $arquivoZip) {
        $arquivoZip = Join-Path $Raiz ("ENVIAR_AO_CHATGPT_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".zip")
    }
    Compress-Archive -Path (Join-Path $Saida "*") -DestinationPath $arquivoZip -Force
    Registro ("Relatorio para enviar: " + $arquivoZip)
}
try {
    Registro "ALIEN: preparando RoboForex instalado. Sem login novo, sem ordem, sem fechar MT5."
    $terminal = LocalizarTerminal
    $instalacao = Split-Path -Parent $terminal
    Registro ("Terminal localizado: " + $terminal)
    $dados = LocalizarDados -Instalacao $instalacao -Terminal $terminal
    Registro ("Pasta de dados: " + $dados)

    $acaoEfetiva = @($Acao, $Modo, $Action, $Mode, $Operacao) -join " "
    if ($acaoEfetiva -match "(?i)colet") {
        Coletar -Dados $dados
        exit 0
    }

    $fonte = LocalizarFonte
    $conteudoFonte = Get-Content -LiteralPath $fonte -Raw -ErrorAction Stop
    if (($conteudoFonte -notmatch "MQL_TESTER") -or ($conteudoFonte -notmatch "ACCOUNT_TRADE_MODE_DEMO")) {
        throw "Protecoes MQL_TESTER e ACCOUNT_TRADE_MODE_DEMO nao encontradas. Nao instalarei este EA."
    }
    $hash = (Get-FileHash -LiteralPath $fonte -Algorithm SHA256).Hash.Substring(0,8)
    $pastaDestino = Join-Path $dados "MQL5\Experts\ALIEN_LAB_SOMENTE_TESTADOR"
    New-Item -ItemType Directory -Path $pastaDestino -Force | Out-Null
    $nomeDestino = "GOLDTREND_AUDITADO_DEMO_" + $hash + ".mq5"
    $destino = Join-Path $pastaDestino $nomeDestino
    if (-not (Test-Path -LiteralPath $destino -PathType Leaf)) {
        Copy-Item -LiteralPath $fonte -Destination $destino
    }
    Registro ("Fonte preservada em: " + $destino)

    $editor = Join-Path $instalacao "metaeditor64.exe"
    if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
        throw "MetaEditor nao encontrado: $editor"
    }
    $logCompilacao = Join-Path $Saida "COMPILACAO_MT5.log"
    if (Test-Path -LiteralPath $logCompilacao) { Remove-Item -LiteralPath $logCompilacao -Force }
    $argumentos = '/compile:"' + $destino + '" /log:"' + $logCompilacao + '"'
    Registro "Compilando somente o EA de teste..."
    $execucao = Start-Process -FilePath $editor -ArgumentList $argumentos -Wait -PassThru
    $ex5 = [System.IO.Path]::ChangeExtension($destino, ".ex5")
    if (-not (Test-Path -LiteralPath $ex5 -PathType Leaf)) {
        throw "MetaEditor executou, mas EX5 nao foi criado. Veja COMPILACAO_MT5.log."
    }
    Registro ("EX5 criado. Codigo preservado, compilacao concluida. ExitCode: " + $execucao.ExitCode)
    Registro "Abra Strategy Tester (Ctrl+R). Selecione ALIEN_LAB_SOMENTE_TESTADOR e marque Cada tick baseado em ticks reais."
    Registro "Este programa NAO inicia operacoes nem muda sua conta."
    Coletar -Dados $dados
    exit 0
}
catch {
    Registro ("ERRO: " + $_.Exception.Message)
    try { Coletar -Dados $dados } catch { Registro ("Falhou coleta: " + $_.Exception.Message) }
    exit 1
}