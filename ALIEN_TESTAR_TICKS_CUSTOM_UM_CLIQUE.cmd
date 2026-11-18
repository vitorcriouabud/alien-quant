@echo off
setlocal
set "ALIEN_SELF=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[System.IO.File]::ReadAllText($env:ALIEN_SELF); $m=':ALIEN_PS_PAYLOAD:'; $p=$t.LastIndexOf($m); if($p -lt 0){throw 'Pacote incompleto'}; & ([ScriptBlock]::Create($t.Substring($p+$m.Length)))"
set "RC=%errorlevel%"
echo.
echo ALIEN: processamento encerrado. Codigo %RC%.
echo Se apareceu ENVIAR_AO_CHATGPT_ALIEN_TICKS.zip, envie esse arquivo no chat.
pause
exit /b %RC%
:ALIEN_PS_PAYLOAD:
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $env:ALIEN_SELF
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$saida = Join-Path $raiz ('ALIEN_TICK_LOGS_' + $stamp)
New-Item -ItemType Directory -Force -Path $saida | Out-Null
$log = Join-Path $saida 'EXECUCAO.txt'
$zip = Join-Path $raiz 'ENVIAR_AO_CHATGPT_ALIEN_TICKS.zip'
$falhou = $false
function Mensagem([string]$texto) {
    $linha = (Get-Date -Format 'HH:mm:ss') + ' ' + $texto
    Write-Host $linha
    Add-Content -LiteralPath $log -Value $linha -Encoding UTF8
}
function DadosDaInstalacao([string]$instalacao) {
    $meta = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    $preferencial = Join-Path $meta '5FFA568149E88FCD5B44D926DCFEAA79'
    if ((Test-Path (Join-Path $preferencial 'MQL5\Experts')) -and
        (Test-Path (Join-Path $preferencial 'bases\Custom'))) { return $preferencial }
    foreach ($dir in @(Get-ChildItem -LiteralPath $meta -Directory -ErrorAction Stop)) {
        $origem = Join-Path $dir.FullName 'origin.txt'
        if (-not (Test-Path -LiteralPath $origem)) { continue }
        $texto = (Get-Content -LiteralPath $origem -Raw).Trim().TrimStart([char]0xFEFF)
        if ($texto.TrimEnd('\') -ieq $instalacao.TrimEnd('\')) { return $dir.FullName }
    }
    throw 'Nao achei a pasta de dados deste RoboForex.'
}
$mq5 = @'
//+------------------------------------------------------------------+
//| ALIEN_TICK_AUDITOR_001 - diagnostico, SEM ORDENS                  |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
long total_ticks=0;
long ticks_invalidos=0;
long tempo_regrediu=0;
long minutos_distintos=0;
long ultimo_ms=0;
long minuto_atual=-1;
datetime primeiro=0;
datetime ultimo=0;
double menor_spread=DBL_MAX;
double maior_spread=0.0;
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print("ALIEN_TICK_ERRO=Este EA funciona apenas no Strategy Tester.");
      return(INIT_FAILED);
   }
   long personalizado=SymbolInfoInteger(_Symbol,SYMBOL_CUSTOM);
   PrintFormat("ALIEN_TICK_INICIO simbolo=%s personalizado=%d",_Symbol,(int)personalizado);
   PrintFormat("ALIEN_TICK_CONTRATO tamanho=%.2f lote_minimo=%.3f passo=%.3f tick_size=%.5f tick_value=%.5f",
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),
      SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));
   if(personalizado==0)
   {
      Print("ALIEN_TICK_ERRO=Ativo nao e personalizado. Selecione Custom no Testador.");
      int n=SymbolsTotal(false);
      for(int i=0;i<n;i++)
      {
         string nome=SymbolName(i,false);
         if(SymbolInfoInteger(nome,SYMBOL_CUSTOM)!=0 && StringFind(nome,"XAU")>=0)
            Print("ALIEN_CUSTOM_ENCONTRADO=",nome);
      }
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}
void OnTick()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) {ticks_invalidos++;return;}
   total_ticks++;
   if(primeiro==0) primeiro=t.time;
   ultimo=t.time;
   if(t.bid<=0 || t.ask<=0 || t.ask<t.bid) ticks_invalidos++;
   if(ultimo_ms>0 && t.time_msc<ultimo_ms) tempo_regrediu++;
   ultimo_ms=t.time_msc;
   long minuto=(long)t.time/60;
   if(minuto!=minuto_atual) {minutos_distintos++;minuto_atual=minuto;}
   if(t.bid>0 && t.ask>=t.bid)
   {
      double spread=t.ask-t.bid;
      if(spread<menor_spread) menor_spread=spread;
      if(spread>maior_spread) maior_spread=spread;
   }
}
void OnDeinit(const int reason)
{
   if(menor_spread==DBL_MAX) menor_spread=-1;
   PrintFormat("ALIEN_TICK_RESUMO simbolo=%s ticks=%I64d minutos=%I64d invalidos=%I64d tempo_regrediu=%I64d primeiro=%s ultimo=%s spread_min=%.5f spread_max=%.5f motivo=%d",
      _Symbol,total_ticks,minutos_distintos,ticks_invalidos,tempo_regrediu,
      TimeToString(primeiro,TIME_DATE|TIME_SECONDS),
      TimeToString(ultimo,TIME_DATE|TIME_SECONDS),
      menor_spread,maior_spread,reason);
   Print("ALIEN_TICK_NOTA=Contagem OnTick nao comprova sozinha origem real; validar diario do testador e lacunas.");
}
//+------------------------------------------------------------------+
'@
try {
    Mensagem 'ALIEN - INICIO DA AUDITORIA DOS TICKS PERSONALIZADOS. NENHUMA ORDEM SERA ENVIADA.'
    $terminal = 'C:\Program Files\RoboForex MT5 Terminal\terminal64.exe'
    if (-not (Test-Path -LiteralPath $terminal)) { throw 'RoboForex MT5 nao encontrado no caminho usado anteriormente.' }
    $instalacao = Split-Path -Parent $terminal
    $dados = DadosDaInstalacao $instalacao
    Mensagem ('RoboForex: ' + $terminal)
    Mensagem ('Pasta de dados: ' + $dados)
    $custom = Join-Path $dados 'bases\Custom'
    if (-not (Test-Path -LiteralPath $custom)) { throw 'Nao encontrei a base Custom no MT5.' }
    $customFiles = @(Get-ChildItem -LiteralPath $custom -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'ticks.dat' -or $_.Extension -eq '.tkc' })
    Mensagem ('Arquivos de ticks encontrados em Custom: ' + $customFiles.Count)
    foreach ($f in @($customFiles | Select-Object -First 8)) { Mensagem ('Ticks Custom: ' + $f.FullName) }

    $destinoDir = Join-Path $dados 'MQL5\Experts\ALIEN_LAB_SOMENTE_TESTADOR'
    New-Item -ItemType Directory -Path $destinoDir -Force | Out-Null
    $src = Join-Path $destinoDir 'ALIEN_TICK_AUDITOR_001.mq5'
    [System.IO.File]::WriteAllText($src,$mq5,[System.Text.Encoding]::UTF8)
    $editor = Join-Path $instalacao 'metaeditor64.exe'
    if (-not (Test-Path -LiteralPath $editor)) { throw 'MetaEditor ausente.' }
    $cLog = Join-Path $saida 'COMPILACAO.log'
    $antes = Get-Date
    $argumentos = '/compile:"' + $src + '" /log:"' + $cLog + '"'
    Mensagem 'Compilando auditor MQL5 sem ordens...'
    $p = Start-Process -FilePath $editor -ArgumentList $argumentos -PassThru -Wait
    Mensagem ('MetaEditor ExitCode=' + $p.ExitCode + ' (o log decide se compilou)')
    $ex5 = [System.IO.Path]::ChangeExtension($src,'.ex5')
    if (-not (Test-Path -LiteralPath $cLog)) {
        $alternativo = [System.IO.Path]::ChangeExtension($src,'.log')
        if (Test-Path -LiteralPath $alternativo) { Copy-Item $alternativo $cLog -Force }
    }
    if (-not (Test-Path -LiteralPath $cLog)) { throw 'MetaEditor nao gerou log de compilacao.' }
    $texto = Get-Content -LiteralPath $cLog -Raw
    $erros = [regex]::Match($texto,'(\d+)\s+errors?')
    if (-not $erros.Success -or [int]$erros.Groups[1].Value -ne 0) { throw 'Compilacao nao comprovou 0 errors. Veja COMPILACAO.log.' }
    if (-not (Test-Path -LiteralPath $ex5)) { throw 'EX5 nao foi gerado.' }
    if ((Get-Item $ex5).LastWriteTime -lt $antes.AddSeconds(-4)) { throw 'EX5 antigo: compilacao nao atualizou o arquivo.' }
    Mensagem 'COMPILACAO CONFIRMADA: 0 errors e EX5 atualizado.'

    $ini = Join-Path $saida 'TESTE_CUSTOM.ini'
    $nomeRelatorio = 'ALIEN_TICKS_' + $stamp
    $iniTexto = @"
[Experts]
AllowLiveTrading=0
AllowDllImport=0

[Tester]
Expert=ALIEN_LAB_SOMENTE_TESTADOR\ALIEN_TICK_AUDITOR_001
Period=M1
Model=4
FromDate=2024.02.05
ToDate=2024.02.12
Deposit=5000
Currency=USD
Leverage=1:100
Optimization=0
ForwardMode=0
Visual=0
ExecutionMode=0
UseLocal=1
UseRemote=0
UseCloud=0
Report=$nomeRelatorio
ReplaceReport=1
ShutdownTerminal=1
"@
    [System.IO.File]::WriteAllText($ini,$iniTexto,[System.Text.Encoding]::ASCII)
    Mensagem 'SIMBOLO: sera usado o ultimo selecionado no Testador do MT5.'
    Mensagem 'Se o ultimo ativo nao for Custom, o auditor rejeitara o teste e registrara o erro.'
    Mensagem 'PERIODO: 05 a 12/02/2024, M1, Model=4 (ticks reais), sem ordens.'
    $abertos = @(Get-Process -Name 'terminal64' -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -ieq $terminal } catch { $false }
    })
    if($abertos.Count -gt 0) {
        Write-Host ''
        Write-Host '>>> FECHE NORMALMENTE A JANELA DO ROBOFOREX. O PROGRAMA CONTINUARA SOZINHO.' -ForegroundColor Yellow
        while(@(Get-Process -Name 'terminal64' -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -ieq $terminal } catch { $false }
        }).Count -gt 0) { Start-Sleep -Seconds 3 }
    }
    Mensagem 'Iniciando o Strategy Tester no RoboForex original...'
    $testArgs = '/config:"' + $ini + '"'
    $teste = Start-Process -FilePath $terminal -ArgumentList $testArgs -PassThru
    if(-not $teste.WaitForExit(1200000)) {
        Mensagem 'O MT5 ainda esta executando. Nao encerrarei o processo a forca; verificarei os logs disponiveis.'
    } else {
        Mensagem ('MT5 terminou. ExitCode=' + $teste.ExitCode)
    }
    $relatorios = @()
    foreach ($pasta in @($instalacao,$dados,(Join-Path $dados 'Tester'))) {
        if(Test-Path -LiteralPath $pasta) {
            $relatorios += @(Get-ChildItem -LiteralPath $pasta -Filter ($nomeRelatorio + '*.htm') -File -ErrorAction SilentlyContinue)
        }
    }
    foreach ($r in $relatorios) {
        Copy-Item -LiteralPath $r.FullName -Destination (Join-Path $saida $r.Name) -Force
        Mensagem ('Relatorio encontrado: ' + $r.FullName)
    }
    if($relatorios.Count -eq 0) { Mensagem 'ATENCAO: nao achei HTML. O diario de testes pode explicar.' }
    $pastaLogs = Join-Path $dados 'Tester\logs'
    if(Test-Path -LiteralPath $pastaLogs) {
        foreach ($f in @(Get-ChildItem -LiteralPath $pastaLogs -Filter '*.log' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3)) {
            Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $saida ('TESTER_' + $f.Name)) -Force
            try {
                $linhas = @(Get-Content -LiteralPath $f.FullName | Select-String -Pattern 'ALIEN_TICK_|ALIEN_CUSTOM_' | Select-Object -Last 150)
                if($linhas.Count -gt 0) { $linhas | ForEach-Object { $_.Line } | Add-Content -LiteralPath (Join-Path $saida 'MARCADORES_ALIEN.txt') }
            } catch {}
        }
    }
    if(-not (Test-Path (Join-Path $saida 'MARCADORES_ALIEN.txt'))) {
        Mensagem 'ATENCAO: sem marcadores ALIEN_TICK nos logs coletados. Nao afirmarei que o backtest rodou.'
    }
    Mensagem 'A coleta terminou. Falta validar os registros antes de concluir cobertura de ticks.'
}
catch {
    $falhou = $true
    Mensagem ('FALHA DIAGNOSTICADA: ' + $_.Exception.Message)
}
finally {
    try {
        if(Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
        Compress-Archive -Path (Join-Path $saida '*') -DestinationPath $zip -Force
        Write-Host ''
        Write-Host ('DIAGNOSTICO: ' + $zip) -ForegroundColor Green
    } catch { Write-Host ('Falha ao criar ZIP: ' + $_.Exception.Message) -ForegroundColor Red }
}
if($falhou) { exit 1 }
exit 0
