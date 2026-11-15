# Kit de teste com um clique - MT5 Strategy Tester (ticks reais)
# So roda o testador. Nao entra em conta real e nao mexe na mesa.
#Requires -Version 5.0

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-KitDir {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host (">>> " + $Message) -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host ("    " + $Message) -ForegroundColor Green
}

function Write-WarnMsg([string]$Message) {
    Write-Host ("    " + $Message) -ForegroundColor Yellow
}

function Write-ErrMsg([string]$Message) {
    Write-Host ("    " + $Message) -ForegroundColor Red
}

function Normalize-PathSafe([string]$PathText) {
    if ([string]::IsNullOrWhiteSpace($PathText)) { return "" }
    $t = $PathText.Trim().Trim('"')
    try { return [System.IO.Path]::GetFullPath($t).TrimEnd('\') } catch { return $t.TrimEnd('\') }
}

function Read-ConfigFile([string]$ConfigPath) {
    $map = @{}
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Nao achei o arquivo CONFIG.txt na pasta do kit."
    }
    $lines = Get-Content -LiteralPath $ConfigPath -Encoding UTF8
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if ($line -eq "" -or $line.StartsWith(";") -or $line.StartsWith("#")) { continue }
        $eq = $line.IndexOf("=")
        if ($eq -lt 1) { continue }
        $key = $line.Substring(0, $eq).Trim()
        $val = $line.Substring($eq + 1).Trim().Trim('"')
        $map[$key] = $val
    }

    $aliases = @{
        'MT5_CAMINHO'  = @('TerminalPath', 'Terminal', 'CaminhoMT5')
        'Experto'      = @('Expert', 'EA', 'Robo')
        'ArquivoSet'   = @('ExpertParameters', 'Set', 'SetFile')
        'Ativo'        = @('Symbol', 'Simbolo')
        'TempoGrafico' = @('Period', 'Timeframe', 'TF')
        'DataInicio'   = @('FromDate', 'Inicio')
        'DataFim'      = @('ToDate', 'Fim')
        'Deposito'     = @('Deposit')
        'Moeda'        = @('Currency')
        'Alavancagem'  = @('Leverage')
        'Modelo'       = @('Model')
    }
    foreach ($canon in $aliases.Keys) {
        if (-not $map.ContainsKey($canon) -or [string]::IsNullOrWhiteSpace([string]$map[$canon])) {
            foreach ($alt in $aliases[$canon]) {
                if ($map.ContainsKey($alt) -and -not [string]::IsNullOrWhiteSpace([string]$map[$alt])) {
                    $map[$canon] = $map[$alt]
                    break
                }
            }
        }
    }

    # Nunca aceitar credenciais - este kit so roda o testador.
    foreach ($blocked in @('Login', 'Password', 'Senha', 'Server', 'CertPassword', 'ProxyPassword', 'MQL5Password')) {
        if ($map.ContainsKey($blocked) -and -not [string]::IsNullOrWhiteSpace([string]$map[$blocked])) {
            Write-WarnMsg "Ignorei a linha $blocked no CONFIG.txt. Este kit nao entra em conta nenhuma."
            $map.Remove($blocked)
        }
    }
    return $map
}

function Get-ConfigValue($map, [string]$Key, [string]$Default) {
    if ($map.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$map[$Key])) {
        return [string]$map[$Key]
    }
    return $Default
}

function Get-TerminalCandidates([string]$Override) {
    $list = New-Object System.Collections.Generic.List[string]
    function Add-Cand([string]$p) {
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        $n = Normalize-PathSafe $p
        if ($n -and -not $list.Contains($n)) { [void]$list.Add($n) }
    }

    if ($Override) {
        $o = Normalize-PathSafe $Override
        if ($o -and (Test-Path -LiteralPath $o -PathType Container)) {
            Add-Cand (Join-Path $o "terminal64.exe")
            Add-Cand (Join-Path $o "terminal.exe")
        } else {
            Add-Cand $o
        }
    }

    $pf  = ${env:ProgramFiles}
    $pfx = ${env:ProgramFiles(x86)}
    $known = @(
        (Join-Path $pf  "RoboForex MT5 Terminal\terminal64.exe"),
        (Join-Path $pf  "RoboForex - MetaTrader 5\terminal64.exe"),
        (Join-Path $pf  "RoboForex Ltd\RoboForex MT5 Terminal\terminal64.exe"),
        (Join-Path $pf  "RoboForex\MetaTrader 5\terminal64.exe"),
        (Join-Path $pf  "MetaTrader 5\terminal64.exe"),
        (Join-Path $pf  "MetaTrader 5 Terminal\terminal64.exe")
    )
    if ($pfx) {
        $known += @(
            (Join-Path $pfx "RoboForex MT5 Terminal\terminal64.exe"),
            (Join-Path $pfx "RoboForex - MetaTrader 5\terminal64.exe"),
            (Join-Path $pfx "MetaTrader 5\terminal64.exe")
        )
    }
    foreach ($k in $known) { Add-Cand $k }

    foreach ($base in @($pf, $pfx)) {
        if (-not $base -or -not (Test-Path -LiteralPath $base)) { continue }
        Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'RoboForex|MetaTrader|MT5' } |
            ForEach-Object {
                Add-Cand (Join-Path $_.FullName "terminal64.exe")
                Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue |
                    ForEach-Object { Add-Cand (Join-Path $_.FullName "terminal64.exe") }
            }
    }

    $originRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path -LiteralPath $originRoot) {
        Get-ChildItem -LiteralPath $originRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $originFile = Join-Path $_.FullName "origin.txt"
            if (Test-Path -LiteralPath $originFile) {
                $origin = (Get-Content -LiteralPath $originFile -TotalCount 2 -ErrorAction SilentlyContinue | Select-Object -First 1)
                if ($origin) { Add-Cand (Join-Path $origin.Trim() "terminal64.exe") }
            }
        }
    }

    $hint = Join-Path $env:APPDATA "MetaQuotes\Terminal\5FFA568149E88FCD5B44D926DCFEAA79\origin.txt"
    if (Test-Path -LiteralPath $hint) {
        $origin = (Get-Content -LiteralPath $hint -TotalCount 1 -ErrorAction SilentlyContinue)
        if ($origin) { Add-Cand (Join-Path $origin.Trim() "terminal64.exe") }
    }

    foreach ($rootKey in @(
        "HKCU:\Software\MetaQuotes\Terminal",
        "HKLM:\SOFTWARE\MetaQuotes\Terminal",
        "HKLM:\SOFTWARE\WOW6432Node\MetaQuotes\Terminal"
    )) {
        if (-not (Test-Path $rootKey)) { continue }
        Get-ChildItem $rootKey -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($vn in @("Path", "InstallPath", "DataPath", "(default)")) {
                try {
                    $v = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).$vn
                    if ($v) { Add-Cand (Join-Path $v "terminal64.exe") }
                } catch {}
            }
        }
    }

    return $list
}

function Find-Terminal64([string]$Override) {
    $cands = Get-TerminalCandidates $Override
    $found = @()
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { $found += $c }
    }
    if ($found.Count -eq 0) { return $null }

    $robo = @($found | Where-Object { $_ -match 'RoboForex' })
    if ($robo.Count -ge 1) { return $robo[0] }
    return $found[0]
}

function Find-DataFolder([string]$InstallDir) {
    $installN = Normalize-PathSafe $InstallDir
    $originRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path -LiteralPath $originRoot) {
        $matches = @()
        Get-ChildItem -LiteralPath $originRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $originFile = Join-Path $_.FullName "origin.txt"
            if (Test-Path -LiteralPath $originFile) {
                $origin = (Get-Content -LiteralPath $originFile -TotalCount 1 -ErrorAction SilentlyContinue)
                if ($origin -and (Normalize-PathSafe $origin) -ieq $installN) {
                    $matches += $_.FullName
                }
            }
        }
        if ($matches.Count -ge 1) { return $matches[0] }
    }

    $portableMql = Join-Path $InstallDir "MQL5"
    if (Test-Path -LiteralPath $portableMql) { return $InstallDir }

    return $null
}

function Get-RunningTerminals {
    $procs = @()
    foreach ($name in @("terminal64", "terminal")) {
        $procs += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    }
    return @($procs | Where-Object { $_ })
}

function Wait-UntilMt5Closed([string]$InstallDir) {
    $installN = Normalize-PathSafe $InstallDir
    while ($true) {
        $running = Get-RunningTerminals
        if ($running.Count -eq 0) { return }

        $sameDir = @()
        foreach ($p in $running) {
            try {
                $pDir = Normalize-PathSafe (Split-Path $p.Path -Parent)
                if ($pDir -and ($pDir -ieq $installN)) { $sameDir += $p }
            } catch { $sameDir += $p }
        }
        if ($sameDir.Count -eq 0) {
            Write-WarnMsg "Tem outro MetaTrader aberto, mas e de outra pasta. Vou seguir com o da RoboForex."
            return
        }

        Write-Host ""
        Write-Host "  O MetaTrader esta aberto. Nao da para rodar o teste com ele aberto." -ForegroundColor Yellow
        Write-Host "  Feche o MetaTrader (X na janela dele) e volte aqui." -ForegroundColor Yellow
        Write-Host "  Isso NAO opera sua conta. So precisa fecha-lo para o testador iniciar." -ForegroundColor Yellow
        Write-Host ""
        $ans = Read-Host "  Feche o MT5 e aperte ENTER (ou digite SAIR para cancelar)"
        if ($ans -and $ans.Trim().ToUpper() -eq "SAIR") {
            throw "Cancelado: o MetaTrader ainda estava aberto."
        }
    }
}

function Find-ExpertRelative([string]$DataDir, [string]$InstallDir, [string]$KitDir, [string]$ExpertName) {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ExpertName)
    if (-not $fileName) { $fileName = $ExpertName }
    $target = $fileName + ".ex5"

    $kitEx5 = Join-Path $KitDir $target
    if (Test-Path -LiteralPath $kitEx5) {
        $destDir = Join-Path $DataDir "MQL5\Experts"
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        $dest = Join-Path $destDir $target
        Copy-Item -LiteralPath $kitEx5 -Destination $dest -Force
        Write-Ok ("Copiei o robo da pasta do kit para o MetaTrader: " + $target)
        return $fileName
    }

    $roots = @()
    foreach ($r in @((Join-Path $DataDir "MQL5\Experts"), (Join-Path $InstallDir "MQL5\Experts"))) {
        if (Test-Path -LiteralPath $r) { $roots += $r }
    }
    foreach ($r in $roots) {
        $hit = Get-ChildItem -LiteralPath $r -Filter $target -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) {
            $rel = $hit.FullName.Substring($r.Length).TrimStart('\', '/')
            $dir  = [System.IO.Path]::GetDirectoryName($rel)
            $base = [System.IO.Path]::GetFileNameWithoutExtension($rel)
            if ([string]::IsNullOrEmpty($dir)) { return $base }
            return ($dir.TrimEnd('\') + '\' + $base)
        }
    }
    return $null
}

function Resolve-SetFile([string]$KitDir, [string]$DataDir, [string]$InstallDir, [string]$SetName) {
    if ([string]::IsNullOrWhiteSpace($SetName)) { return $null }
    $justName = [System.IO.Path]::GetFileName($SetName)
    $candidates = @(
        $SetName,
        (Join-Path $KitDir $SetName),
        (Join-Path $KitDir $justName),
        (Join-Path $DataDir ("MQL5\Profiles\Tester\" + $justName)),
        (Join-Path $InstallDir ("MQL5\Profiles\Tester\" + $justName))
    )
    $source = $null
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { $source = $c; break }
    }
    if (-not $source) { return $null }

    foreach ($root in @($DataDir, $InstallDir)) {
        $destDir = Join-Path $root "MQL5\Profiles\Tester"
        try {
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop | Out-Null
            }
            Copy-Item -LiteralPath $source -Destination (Join-Path $destDir $justName) -Force -ErrorAction Stop
        } catch {
            # Pasta de instalacao em Program Files pode recusar escrita. Tudo bem.
        }
    }
    return @{ Source = $source; FileName = $justName }
}

function Write-TesterIni([string]$IniPath, $settings) {
    $dir = Split-Path $IniPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $lines = @(
        "; Gerado pelo kit de teste de um clique. Apenas Strategy Tester.",
        "; Nao contem login, senha ou dados de conta.",
        "[Common]",
        "NewsEnable=0",
        "",
        "[Experts]",
        "AllowLiveTrading=0",
        "AllowDllImport=0",
        "Enabled=1",
        "Account=0",
        "Profile=0",
        "",
        "[Tester]",
        ("Expert=" + $settings.Expert),
        $(if ($settings.ExpertParameters) { "ExpertParameters=" + $settings.ExpertParameters } else { "; ExpertParameters nao informado" }),
        ("Symbol=" + $settings.Symbol),
        ("Period=" + $settings.Period),
        ("Model=" + $settings.Model),
        "ExecutionMode=0",
        "Optimization=0",
        ("FromDate=" + $settings.FromDate),
        ("ToDate=" + $settings.ToDate),
        "ForwardMode=0",
        ("Report=" + $settings.Report),
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        ("Deposit=" + $settings.Deposit),
        ("Currency=" + $settings.Currency),
        ("Leverage=" + $settings.Leverage),
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "Visual=0"
    )
    [System.IO.File]::WriteAllLines($IniPath, [string[]]$lines, [System.Text.Encoding]::ASCII)
}

function Ensure-ReportsFolder([string]$DataDir, [string]$InstallDir) {
    foreach ($root in @($DataDir, $InstallDir)) {
        if (-not $root) { continue }
        $rep = Join-Path $root "reports"
        try {
            if (-not (Test-Path -LiteralPath $rep)) {
                New-Item -ItemType Directory -Path $rep -Force -ErrorAction Stop | Out-Null
            }
        } catch {}
    }
}

function Get-ReportFiles([string]$DataDir, [string]$InstallDir, [string]$ReportName, [datetime]$StartedAt) {
    $bases = @(
        (Join-Path $DataDir "reports"),
        $DataDir,
        (Join-Path $InstallDir "reports"),
        $InstallDir
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $found = @()
    foreach ($b in $bases) {
        $found += @(Get-ChildItem -LiteralPath $b -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.BaseName -like ($ReportName + "*") -and
                @('.htm', '.html', '.png', '.gif', '.xml') -contains $_.Extension.ToLower()
            })
    }

    if ($found.Count -eq 0) {
        foreach ($b in $bases) {
            $found += @(Get-ChildItem -LiteralPath $b -File -ErrorAction SilentlyContinue |
                Where-Object {
                    @('.htm', '.html') -contains $_.Extension.ToLower() -and
                    $_.LastWriteTime -ge $StartedAt.AddMinutes(-1)
                })
        }
    }

    $uniq = @{}
    $list = @()
    foreach ($f in $found) {
        if (-not $uniq.ContainsKey($f.FullName)) {
            $uniq[$f.FullName] = $true
            $list += $f
        }
    }
    return $list
}

function Get-TesterLogs([string]$DataDir, [datetime]$StartedAt) {
    $logDir = Join-Path $DataDir "Tester\logs"
    if (-not (Test-Path -LiteralPath $logDir)) { return @() }
    $logs = @(Get-ChildItem -LiteralPath $logDir -File -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $StartedAt.AddHours(-1) })
    if ($logs.Count -eq 0) {
        $logs = @(Get-ChildItem -LiteralPath $logDir -File -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 2)
    }
    return $logs
}

function Read-ReportSnippet([string]$HtmlPath) {
    $info = @{ Quality = ""; Model = ""; Profit = ""; Trades = ""; Expert = "" }
    if (-not (Test-Path -LiteralPath $HtmlPath)) { return $info }
    $text = $null
    foreach ($enc in @([System.Text.Encoding]::Unicode, [System.Text.Encoding]::UTF8, [System.Text.Encoding]::GetEncoding(1252))) {
        try {
            $raw = [System.IO.File]::ReadAllText($HtmlPath, $enc)
            if ($raw -and ($raw.Length -gt 50)) { $text = $raw; break }
        } catch {}
    }
    if (-not $text) { return $info }
    $plain = [regex]::Replace($text, '<[^>]+>', ' ')
    $plain = [regex]::Replace($plain, '\s+', ' ')
    if ($plain -match 'Qualidade do hist[^\s]{0,8}:\s*([^<]{0,80})') { $info.Quality = $Matches[1].Trim() }
    elseif ($plain -match 'History Quality:\s*([^<]{0,80})') { $info.Quality = $Matches[1].Trim() }
    if ($plain -match '(\d+%\s+de ticks reais)') { $info.Quality = $Matches[1].Trim() }
    elseif ($plain -match '(\d+%\s+real ticks)') { $info.Quality = $Matches[1].Trim() }
    if ($plain -match 'Modelagem:\s*([^ ][^<]{0,80}?)(?:\s{2,}| Qualidade| History|$)') { $info.Model = $Matches[1].Trim() }
    if ($plain -match 'Expert Advisor \(Rob[^\)]*\):\s*([A-Za-z0-9_\\.\-]+)') { $info.Expert = $Matches[1].Trim() }
    if ($plain -match 'Lucro L[^\s]{0,12}quido Total[:\s]+([^\s]{1,40})') { $info.Profit = $Matches[1].Trim() }
    elseif ($plain -match 'Total Net Profit[:\s]+([^\s]{1,40})') { $info.Profit = $Matches[1].Trim() }
    if ($plain -match 'Total de Neg[^\s]{0,12}cios[:\s]+([0-9.]+)') { $info.Trades = $Matches[1].Trim() }
    elseif ($plain -match 'Total Trades[:\s]+([0-9.]+)') { $info.Trades = $Matches[1].Trim() }
    return $info
}

function New-ResumoFile([string]$Path, $ctx) {
    $lines = @(
        "RESUMO DO TESTE - kit de um clique",
        "===================================",
        ("Data/hora no Windows: " + $ctx.Stamp),
        "Fuso: o fuso configurado neste computador.",
        "",
        ("Experto: " + $ctx.Expert),
        ("Caminho relativo do EA: " + $ctx.ExpertRel),
        ("Ativo: " + $ctx.Symbol),
        ("Tempo grafico: " + $ctx.Period),
        ("Periodo: " + $ctx.FromDate + " a " + $ctx.ToDate),
        ("Modelo: " + $ctx.Model + "  (4 = cada tick baseado em ticks reais)"),
        ("Deposito: " + $ctx.Deposit + " " + $ctx.Currency),
        ("Alavancagem: " + $ctx.Leverage),
        ("Arquivo .set: " + $ctx.SetName),
        "",
        ("MT5 (terminal64.exe): " + $ctx.Terminal),
        ("Pasta de instalacao: " + $ctx.InstallDir),
        ("Pasta de dados: " + $ctx.DataDir),
        ("Arquivo tester.ini: " + $ctx.IniPath),
        "",
        "MODO: apenas Strategy Tester.",
        "AllowLiveTrading=0",
        "UseRemote=0  UseCloud=0  Visual=0  Optimization=0  ShutdownTerminal=1",
        "Este kit NAO entrou em conta real e NAO mexeu na conta da mesa.",
        "",
        ("MT5 encerrou com codigo: " + $ctx.ExitCode),
        ("Tempo de execucao: " + $ctx.Elapsed),
        ("Relatorio HTML encontrado: " + $ctx.ReportFound),
        ("Qualidade do historico (se lida no HTML): " + $ctx.Quality),
        ("Modelagem (se lida no HTML): " + $ctx.ModelText),
        ("Lucro liquido (se lido no HTML): " + $ctx.Profit),
        ("Total de negocios (se lido no HTML): " + $ctx.Trades),
        "",
        "Observacoes:",
        "- Na primeira vez o MT5 baixa os ticks reais; isso pode demorar.",
        "- Confira no HTML a linha de qualidade do historico / ticks reais.",
        "- O .set veio dos parametros que voce ja usou na V11 (comissao no .set = 0).",
        "- Relatorio oficial fica na pasta da plataforma ou na pasta de dados,",
        "  em geral em reports\<nome>.htm, com PNGs ao lado (mesmo nome).",
        "- Logs do testador: pasta de dados\Tester\logs\aaaammdd.log",
        "",
        "Arquivos neste zip:",
        $ctx.FileList
    )
    $utf8 = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllLines($Path, [string[]]$lines, $utf8)
}

# ===================== MAIN =====================

$exitCode = 0
$KitDir = Get-KitDir
Set-Location -LiteralPath $KitDir

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "    TESTE COM TICKS REAIS  -  um clique" -ForegroundColor Cyan
Write-Host "    Nao opera conta real nem conta da mesa" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan

try {
    Write-Step "Lendo o CONFIG.txt"
    $cfg = Read-ConfigFile (Join-Path $KitDir "CONFIG.txt")

    $expertName = Get-ConfigValue $cfg "Experto" "ALIEN_V11_SCALPER"
    $symbol     = Get-ConfigValue $cfg "Ativo" "XAUUSD"
    $period     = Get-ConfigValue $cfg "TempoGrafico" "M1"
    $fromDate   = Get-ConfigValue $cfg "DataInicio" "2026.08.01"
    $toDate     = Get-ConfigValue $cfg "DataFim" "2026.11.13"
    $deposit    = Get-ConfigValue $cfg "Deposito" "10000"
    $currency   = Get-ConfigValue $cfg "Moeda" "USD"
    $leverage   = Get-ConfigValue $cfg "Alavancagem" "1:100"
    $model      = Get-ConfigValue $cfg "Modelo" "4"
    $setName    = Get-ConfigValue $cfg "ArquivoSet" "ALIEN_V11_SCALPER.set"
    $mt5Path    = Get-ConfigValue $cfg "MT5_CAMINHO" ""

    if ($leverage -notmatch '^\d+:\d+$') {
        if ($leverage -match '^\d+$') { $leverage = "1:" + $leverage }
    }
    if ($model -ne "4") {
        Write-WarnMsg "O CONFIG esta com Modelo=$model. O teste que vale e o Modelo=4 (ticks reais)."
        $go = Read-Host "    Aperte ENTER para continuar mesmo assim, ou digite SAIR"
        if ($go -and $go.Trim().ToUpper() -eq "SAIR") { throw "Cancelado: modelo diferente de 4." }
    }

    Write-Ok ("Robo: $expertName  |  Ativo: $symbol  |  Tempo: $period")
    Write-Ok ("Periodo: $fromDate a $toDate  |  Modelo: $model  |  Deposito: $deposit $currency")

    Write-Step "Procurando o MetaTrader 5"
    $terminal = Find-Terminal64 $mt5Path
    if (-not $terminal) {
        throw @"
Nao achei o MetaTrader 5 neste computador.
Abra o arquivo CONFIG.txt com o Bloco de Notas e cole o caminho da pasta do MT5 na linha MT5_CAMINHO=
Exemplo:
MT5_CAMINHO=C:\Program Files\RoboForex MT5 Terminal
"@
    }
    $installDir = Normalize-PathSafe (Split-Path $terminal -Parent)
    Write-Ok "Achei o MT5 em: $installDir"

    $dataDir = Find-DataFolder $installDir
    if (-not $dataDir) {
        throw "Achei o MT5, mas nao achei a pasta de dados (onde ficam os robos e os relatorios). Abra o MT5 uma vez, va em Arquivo > Abrir pasta de dados, feche o MT5 e rode o TESTAR.bat de novo."
    }
    Write-Ok "Pasta de dados: $dataDir"

    Write-Step "Conferindo se o MetaTrader esta aberto"
    Wait-UntilMt5Closed $installDir
    Write-Ok "MetaTrader fechado. Pode seguir."

    Write-Step "Procurando o robo $expertName"
    $expertRel = Find-ExpertRelative $dataDir $installDir $KitDir $expertName
    if (-not $expertRel) {
        throw @"
Nao achei o robo $expertName no seu MetaTrader.
Confira em Navegador > Expert Advisors se o nome esta igual.
Ou copie o arquivo $expertName.ex5 para esta pasta do kit e rode de novo.
"@
    }
    Write-Ok ("Robo encontrado: " + $expertRel)

    Write-Step "Preparando o arquivo .set"
    $setInfo = Resolve-SetFile $KitDir $dataDir $installDir $setName
    if ($setInfo) {
        Write-Ok ("Vou usar o .set: " + $setInfo.Source)
    } else {
        Write-WarnMsg "Nao achei o arquivo .set. O testador vai usar a ultima configuracao salva do robo, ou os valores padrao."
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmm"
    $reportName = "KIT_TESTE_1CLIQUE_" + $stamp
    Ensure-ReportsFolder $dataDir $installDir

    $workDir = Join-Path $KitDir "trabalho"
    if (-not (Test-Path -LiteralPath $workDir)) { New-Item -ItemType Directory -Path $workDir -Force | Out-Null }
    $iniPath = Join-Path $workDir "tester.ini"

    $iniSettings = @{
        Expert           = $expertRel
        ExpertParameters = $(if ($setInfo) { $setInfo.FileName } else { $null })
        Symbol           = $symbol
        Period           = $period
        Model            = $model
        FromDate         = $fromDate
        ToDate           = $toDate
        Report           = ("reports\" + $reportName)
        Deposit          = $deposit
        Currency         = $currency
        Leverage         = $leverage
    }
    Write-TesterIni $iniPath $iniSettings
    Write-Ok "Configuracao do testador gravada."

    Write-Host ""
    Write-Host "    Vou iniciar o teste agora." -ForegroundColor White
    Write-Host "    Na primeira vez o MT5 baixa os ticks reais." -ForegroundColor White
    Write-Host "    Isso pode demorar bastante. Nao feche esta janela." -ForegroundColor White
    Write-Host "    Deixe o computador ligado, com internet." -ForegroundColor White
    Write-Host ""

    $startedAt = Get-Date
    $arg = '/config:"{0}"' -f $iniPath
    $proc = Start-Process -FilePath $terminal -WorkingDirectory $installDir -ArgumentList $arg -PassThru
    if (-not $proc) { throw "Nao consegui iniciar o MetaTrader." }

    $lastMsg = -1
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 15
        $mins = [int]((Get-Date) - $startedAt).TotalMinutes
        if ($mins -ne $lastMsg) {
            $lastMsg = $mins
            if ($mins -le 0) {
                Write-Host "    Teste em andamento... (menos de 1 minuto)"
            } else {
                Write-Host ("    Teste em andamento... " + $mins + " min. Pode demorar, isso e normal.")
                if (($mins % 5) -eq 0) {
                    Write-Host "    Se o teste ja acabou e o MetaTrader ficou aberto, feche ele para eu juntar o relatorio."
                }
            }
        }
    }

    $elapsed = (Get-Date) - $startedAt
    $elapsedText = ("{0:00}h {1:00}min {2:00}s" -f [int]$elapsed.TotalHours, $elapsed.Minutes, $elapsed.Seconds)
    Write-Ok ("O MetaTrader terminou o teste. Tempo: $elapsedText  |  codigo: " + $proc.ExitCode)

    if ($elapsed.TotalSeconds -lt 8) {
        Write-WarnMsg "O MT5 fechou rapido demais. Pode ter faltado o robo, o ativo, ou os ticks. Vou juntar os registros mesmo assim."
    }

    Start-Sleep -Seconds 3

    Write-Step "Juntando o relatorio, as imagens, o .set e os registros"
    $reportFiles = Get-ReportFiles $dataDir $installDir $reportName $startedAt
    $testerLogs  = Get-TesterLogs $dataDir $startedAt

    $collectDir = Join-Path $workDir ("coleta_" + $stamp)
    if (Test-Path -LiteralPath $collectDir) { Remove-Item -LiteralPath $collectDir -Recurse -Force }
    New-Item -ItemType Directory -Path $collectDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $collectDir "logs") -Force | Out-Null

    $copied = @()
    foreach ($f in $reportFiles) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $collectDir $f.Name) -Force
        $copied += $f.Name
    }
    foreach ($f in $testerLogs) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $collectDir "logs\$($f.Name)") -Force
        $copied += ("logs/" + $f.Name)
    }
    Copy-Item -LiteralPath $iniPath -Destination (Join-Path $collectDir "tester.ini") -Force
    $copied += "tester.ini"
    Copy-Item -LiteralPath (Join-Path $KitDir "CONFIG.txt") -Destination (Join-Path $collectDir "CONFIG.txt") -Force
    $copied += "CONFIG.txt"
    if ($setInfo -and (Test-Path -LiteralPath $setInfo.Source)) {
        Copy-Item -LiteralPath $setInfo.Source -Destination (Join-Path $collectDir $setInfo.FileName) -Force
        $copied += $setInfo.FileName
    }

    $htmlFile = $reportFiles | Where-Object { @('.htm', '.html') -contains $_.Extension.ToLower() } | Select-Object -First 1
    $quality = ""; $modelText = ""; $profit = ""; $trades = ""
    if ($null -ne $htmlFile) {
        $snip = Read-ReportSnippet $htmlFile.FullName
        $quality   = $snip.Quality
        $modelText = $snip.Model
        $profit    = $snip.Profit
        $trades    = $snip.Trades
        if ($quality) { Write-Ok ("Qualidade do historico no relatorio: " + $quality) }
    } else {
        Write-WarnMsg "Nao achei o relatorio HTML. Vou mandar no zip o que tiver (ini, .set e registros)."
        $termLogDir = Join-Path $dataDir "logs"
        if (Test-Path -LiteralPath $termLogDir) {
            $tlogs = @(Get-ChildItem -LiteralPath $termLogDir -File -Filter "*.log" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -ge $startedAt.AddHours(-1) } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 2)
            foreach ($f in $tlogs) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $collectDir ("logs\terminal_" + $f.Name)) -Force
                $copied += ("logs/terminal_" + $f.Name)
            }
        }
    }

    $resumoPath = Join-Path $collectDir "RESUMO.txt"
    $ctx = @{
        Stamp      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Expert     = $expertName
        ExpertRel  = $expertRel
        Symbol     = $symbol
        Period     = $period
        FromDate   = $fromDate
        ToDate     = $toDate
        Model      = $model
        Deposit    = $deposit
        Currency   = $currency
        Leverage   = $leverage
        SetName    = $(if ($setInfo) { $setInfo.FileName } else { "(nao encontrado)" })
        Terminal   = $terminal
        InstallDir = $installDir
        DataDir    = $dataDir
        IniPath    = $iniPath
        ExitCode   = $proc.ExitCode
        Elapsed    = $elapsedText
        ReportFound= $(if ($null -ne $htmlFile) { "sim - " + $htmlFile.Name } else { "NAO" })
        Quality    = $(if ($quality) { $quality } else { "(nao lida)" })
        ModelText  = $(if ($modelText) { $modelText } else { "(nao lida)" })
        Profit     = $(if ($profit) { $profit } else { "(nao lido)" })
        Trades     = $(if ($trades) { $trades } else { "(nao lido)" })
        FileList   = (($copied | Sort-Object | ForEach-Object { "  - " + $_ }) -join [Environment]::NewLine)
    }
    New-ResumoFile $resumoPath $ctx
    $copied += "RESUMO.txt"

    Write-Step "Criando o zip na Area de Trabalho"
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
        $desktop = [Environment]::GetFolderPath("UserProfile")
        Write-WarnMsg "Nao achei a Area de Trabalho. Vou salvar o zip na sua pasta de usuario."
    }
    $zipName = "RESULTADO_PARA_O_GROK_" + (Get-Date -Format "yyyy-MM-dd_HHmm") + ".zip"
    $zipPath = Join-Path $desktop $zipName
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

    Compress-Archive -Path (Join-Path $collectDir "*") -DestinationPath $zipPath -Force
    if (-not (Test-Path -LiteralPath $zipPath)) { throw "Nao consegui criar o zip." }

    Write-Host ""
    Write-Host "  Pronto. O zip esta aqui:" -ForegroundColor Green
    Write-Host ("  " + $zipPath) -ForegroundColor Green
    Write-Host ""
    Write-Host "  E esse arquivo que voce me envia." -ForegroundColor Green
    Write-Host ""

    try { Start-Process "explorer.exe" -ArgumentList @("/select,`"$zipPath`"") } catch {
        try { Start-Process "explorer.exe" -ArgumentList @($desktop) } catch {}
    }

    if ($null -eq $htmlFile) { $exitCode = 2 }

} catch {
    $exitCode = 1
    Write-Host ""
    Write-ErrMsg ("Deu um problema: " + $_.Exception.Message)
    Write-Host ""
    Write-Host "  Se mesmo assim aparecer um zip na Area de Trabalho, pode me enviar." -ForegroundColor Yellow
    Write-Host "  Se nao aparecer, me mande um print desta janela." -ForegroundColor Yellow
    Write-Host ""
}

exit $exitCode
