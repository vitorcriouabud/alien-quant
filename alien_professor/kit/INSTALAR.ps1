# ALIEN PROFESSOR - instala no MT5 da RoboForex (so UM terminal).
# Copia indicador, robos e presets para MQL5\...\ALIEN, apaga copias velhas soltas
# e libera o WebRequest (Telegram e Gemini). Nao mexe em conta nem senha.
param([switch]$Compilar)
$ErrorActionPreference = "Continue"
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
# ---- escolhe UM terminal: RoboForex (origin.txt); se nao achar, o unico; se tiver varios, pergunta ----
function Nome-Terminal($p) {
  $orig = Join-Path $p.FullName "origin.txt"
  if (Test-Path $orig) { return ((Get-Content $orig -Raw -ErrorAction SilentlyContinue) -replace "`0","").Trim() }
  return $p.Name
}
function Escolhe-Terminal {
  $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
  if (-not (Test-Path $base)) { Write-Host "Nao achei o MT5 em $base. Abra o MT5 uma vez, feche e rode de novo." -ForegroundColor Red; return $null }
  $todas = @(Get-ChildItem $base -Directory | Where-Object { Test-Path (Join-Path $_.FullName "MQL5") })
  if ($todas.Count -eq 0) { Write-Host "Nenhum MT5 encontrado em $base" -ForegroundColor Red; return $null }
  $robo = @($todas | Where-Object { (Nome-Terminal $_) -match "RoboForex" })
  $lista = $todas
  if ($robo.Count -eq 1) { return $robo[0] }
  if ($robo.Count -gt 1) { $lista = $robo }
  elseif ($todas.Count -eq 1) { return $todas[0] }
  Write-Host "Achei mais de um MT5. Qual e o seu?" -ForegroundColor Yellow
  for ($i = 0; $i -lt $lista.Count; $i++) { Write-Host ("  " + ($i + 1) + ") " + (Nome-Terminal $lista[$i])) }
  $n = Read-Host "Digite o numero e aperte Enter"
  $k = 0; if (-not [int]::TryParse($n, [ref]$k) -or $k -lt 1 -or $k -gt $lista.Count) { Write-Host "Numero invalido. Rode de novo." -ForegroundColor Red; return $null }
  return $lista[$k - 1]
}
Write-Host ""
# v12.7: o MT5 regrava a configuracao quando fecha -> tem que estar FECHADO, senao ele desfaz tudo
$tent = 0
while (Get-Process -Name terminal64 -ErrorAction SilentlyContinue) {
  $tent++
  if ($tent -ge 2) {
    $r = Read-Host "O MT5 continua aberto. Digite S e Enter para eu fechar ele pra voce (ou so Enter depois de fechar no X)"
    if ($r -match "^[sS]") { Get-Process -Name terminal64 -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }; Start-Sleep -Seconds 6
      Get-Process -Name terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
  } else {
    Write-Host "O MT5 esta aberto. Feche o MT5 (no X) e aperte Enter para continuar." -ForegroundColor Yellow
    Read-Host | Out-Null
  }
}
$p = Escolhe-Terminal
if ($null -eq $p) { exit 1 }
$nome = Nome-Terminal $p
$mql = Join-Path $p.FullName "MQL5"
$ind = Join-Path $mql "Indicators\ALIEN"
$exp = Join-Path $mql "Experts\ALIEN"
$pre = Join-Path $mql "Presets"
$tester = Join-Path $mql "Profiles\Tester"
New-Item -ItemType Directory -Force -Path $ind, $exp, $pre, $tester | Out-Null

# copias velhas soltas (fora da pasta ALIEN) confundem: apaga
foreach ($d in @((Join-Path $mql "Experts"), (Join-Path $mql "Indicators"))) {
  Get-ChildItem $d -File -Filter "ALIEN_PROFESSOR*" -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".ex5", ".mq5" } | ForEach-Object {
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    Write-Host ("Apaguei copia velha: " + $_.Name)
  }
}

foreach ($f in @("ALIEN_PROFESSOR.ex5","ALIEN_PROFESSOR.mq5")) { $s = Join-Path $aqui $f; if (Test-Path $s) { Copy-Item $s $ind -Force } }
foreach ($f in @("ALIEN_PROFESSOR_AUTO.ex5","ALIEN_PROFESSOR_AUTO.mq5","ALIEN_PROFESSOR_TELEGRAM.ex5","ALIEN_PROFESSOR_TELEGRAM.mq5")) {
  $s = Join-Path $aqui $f; if (Test-Path $s) { Copy-Item $s $exp -Force }
}
$presetDir = Join-Path $aqui "presets"
if (Test-Path $presetDir) {
  Get-ChildItem $presetDir -Filter *.set -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName $pre -Force; Copy-Item $_.FullName $tester -Force }
}
$idx = Join-Path $aqui "indices"
if (Test-Path $idx) {
  foreach ($f in @("ALIEN_INDICES_V1.ex5","ALIEN_INDICES_V1.mq5")) { $s = Join-Path $idx $f; if (Test-Path $s) { Copy-Item $s $exp -Force } }
  $s = Join-Path $idx "ALIEN_INDICES_V1.set"; if (Test-Path $s) { Copy-Item $s $pre -Force; Copy-Item $s $tester -Force }
}
# configuracao pessoal (token, chat, chaves): so copia se ainda NAO existir -> atualizar nunca apaga a sua
$cfgSrc = Join-Path $aqui "config\ALIEN_config.txt"
$cfgDst = Join-Path $mql "Files\ALIEN_config.txt"
if (Test-Path $cfgSrc) {
  New-Item -ItemType Directory -Force -Path (Join-Path $mql "Files") | Out-Null
  if (-not (Test-Path $cfgDst)) { Copy-Item $cfgSrc $cfgDst; Write-Host "Configuracao pessoal instalada (MQL5\Files\ALIEN_config.txt)." -ForegroundColor Green }
  else {
    Write-Host "Mantive a sua configuracao pessoal que ja existia (ALIEN_config.txt)."
    # v12.7: completa o que falta (token, chat, chaves, opcoes). Linha que ja tem valor NUNCA e trocada.
    $atual = @(Get-Content $cfgDst -ErrorAction SilentlyContinue)
    $novas = @(); $mudou = $false
    foreach ($linha in (Get-Content $cfgSrc)) {
      if ($linha -notmatch "^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$") { continue }
      $k = $Matches[1]; $v = $Matches[2].Trim(); if ($v -eq "") { continue }
      if (@("telegram_token","telegram_chat_id","telegram_grupo_id","gemini_chave_1","gemini_chave_2","xai_chave","telegram_ordens","autonomo") -notcontains $k.ToLower()) { continue }   # "modo" e outras escolhas suas: nao mexo
      $i = -1
      for ($j = 0; $j -lt $atual.Count; $j++) { if ($atual[$j] -match ("^\s*" + $k + "\s*=")) { $i = $j; break } }
      if ($i -lt 0) { $novas += $linha; $mudou = $true }
      elseif (($atual[$i] -replace "^[^=]*=", "").Trim() -eq "") { $atual[$i] = $linha; $mudou = $true }
    }
    if ($mudou) {
      Copy-Item $cfgDst ($cfgDst + ".bak") -Force
      Set-Content -Path $cfgDst -Value ($atual + $novas) -Encoding Default
      Write-Host "Completei o que faltava na configuracao (backup em ALIEN_config.txt.bak). Chave que ja existia nao mudei." -ForegroundColor Green
    }
  }
}
# v12.6: conhecimento do Alier (texto que a IA consulta). So copia se nao existir: se voce editar, atualizar nao apaga.
$kSrc = Join-Path $aqui "ALIEN_conhecimento.txt"
$kDst = Join-Path $mql "Files\ALIEN_conhecimento.txt"
if (Test-Path $kSrc) {
  New-Item -ItemType Directory -Force -Path (Join-Path $mql "Files") | Out-Null
  if (-not (Test-Path $kDst)) { Copy-Item $kSrc $kDst; Write-Host "Conhecimento do Alier instalado (MQL5\Files\ALIEN_conhecimento.txt)." -ForegroundColor Green }
}
Write-Host ("OK -> " + $nome) -ForegroundColor Green
Write-Host ("     " + $exp)

# ---- ATUALIZAR: compila os .mq5 baixados com o MetaEditor do proprio MT5 ----
if ($Compilar) {
  $inst = $nome
  $me = Join-Path $inst "metaeditor64.exe"
  if (-not (Test-Path $me)) { $me = Join-Path $inst "MetaEditor64.exe" }
  if (-not (Test-Path $me)) {
    Write-Host "Nao achei o MetaEditor. Abra o MT5, va no Navegador, botao direito no robo ALIEN_PROFESSOR_AUTO > Modificar e aperte F7." -ForegroundColor Yellow
  } else {
    $alvos = @((Join-Path $exp "ALIEN_PROFESSOR_AUTO.mq5"), (Join-Path $exp "ALIEN_PROFESSOR_TELEGRAM.mq5"), (Join-Path $ind "ALIEN_PROFESSOR.mq5"))
    foreach ($a in $alvos) {
      if (-not (Test-Path $a)) { continue }
      $log = [System.IO.Path]::ChangeExtension($a, ".log")
      Remove-Item $log -Force -ErrorAction SilentlyContinue
      Start-Process -FilePath $me -ArgumentList ('/compile:"' + $a + '"'), '/log' -Wait -WindowStyle Hidden
      $res = ""
      if (Test-Path $log) { $res = (Get-Content $log -ErrorAction SilentlyContinue | Where-Object { $_ -match "Result:" } | Select-Object -Last 1) }
      if ($res -match "Result: 0 error") { Write-Host ("Compilado: " + (Split-Path $a -Leaf)) -ForegroundColor Green }
      else { Write-Host ("Nao consegui compilar " + (Split-Path $a -Leaf) + " " + $res) -ForegroundColor Red }
    }
  }
}

# ---- v12.7: conexao automatica (Telegram e IA) ----
# O MT5 guarda a lista de sites do WebRequest CRIPTOGRAFADA. Escrever o site em texto nao funciona
# (testado) e as versoes antigas deste instalador ESTRAGAVAM a lista que voce tinha posto a mao.
# Agora: o robo conecta pelo proprio Windows (precisa de "Permitir importacao de DLL"), e aqui:
#  1) liga AllowDllImport=1 no config\common.ini
#  2) conserta a linha WebRequestUrl que as versoes antigas estragaram (tira so o texto que elas puseram)
#  3) no grafico onde o ALIEN ja esta, marca "permitir DLL" (senao o MT5 nao carrega o robo novo)
function Le-Texto($arq) {
  $bytes = [System.IO.File]::ReadAllBytes($arq)
  $uni = ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)
  if ($uni) { $t = [System.Text.Encoding]::Unicode.GetString($bytes) } else { $t = (New-Object System.Text.UTF8Encoding($false)).GetString($bytes) }
  if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
  return @{ Texto = $t; Uni = $uni }
}
function Grava-Texto($arq, $txt, $uni) {
  if ($uni) { [System.IO.File]::WriteAllText($arq, $txt, (New-Object System.Text.UnicodeEncoding($false, $true))) }
  else { [System.IO.File]::WriteAllText($arq, $txt, (New-Object System.Text.UTF8Encoding($false))) }
}
$ini = Join-Path $p.FullName "config\common.ini"
$webOk = $false
try {
  $uni = $true; $txt = ""
  if (Test-Path $ini) { $l = Le-Texto $ini; $txt = $l.Texto; $uni = $l.Uni; Copy-Item $ini ($ini + ".bak") -Force }
  else { New-Item -ItemType Directory -Force -Path (Split-Path $ini) | Out-Null }
  $lines = New-Object System.Collections.ArrayList
  foreach ($x in ($txt -split "`r?`n")) { [void]$lines.Add($x) }
  while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq "") { $lines.RemoveAt($lines.Count - 1) }
  $sec = -1; $fim = $lines.Count
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "[Experts]") { $sec = $i; continue }
    if ($sec -ge 0 -and $i -gt $sec -and $lines[$i].Trim().StartsWith("[")) { $fim = $i; break }
  }
  if ($sec -lt 0) { [void]$lines.Add("[Experts]"); $sec = $lines.Count - 1; $fim = $lines.Count }
  $iDll = -1; $iWeb = -1
  for ($i = $fim - 1; $i -gt $sec; $i--) {
    if ($lines[$i] -match "^AllowDllImport=") { $iDll = $i }
    elseif ($lines[$i] -match "^WebRequest=") { $iWeb = $i }
    elseif ($lines[$i] -match "^WebRequestUrl=") {
      # conserta: tira os enderecos em texto que o instalador antigo grudou na lista criptografada
      $partes = @(($lines[$i] -replace "^WebRequestUrl=", "") -split "[;,]" | Where-Object { $_ -ne "" -and $_ -notmatch "^https?://" })
      if ($partes.Count -eq 0) { $lines.RemoveAt($i); $fim--; if ($iDll -gt $i) { $iDll-- }; if ($iWeb -gt $i) { $iWeb-- } }
      else { $lines[$i] = "WebRequestUrl=" + ($partes -join ";") }
    }
  }
  if ($iDll -ge 0) { $lines[$iDll] = "AllowDllImport=1" } else { $lines.Insert($sec + 1, "AllowDllImport=1"); $fim++; if ($iWeb -ge 0) { $iWeb++ } }
  if ($iWeb -ge 0) { $lines[$iWeb] = "WebRequest=1" } else { $lines.Insert($sec + 1, "WebRequest=1") }
  Grava-Texto $ini (($lines -join "`r`n") + "`r`n") $uni
  $webOk = $true
} catch { $webOk = $false }
# graficos salvos (perfis e modelos) com o ALIEN: liga o bit "permitir DLL" (4) do expertmode
$nGraf = 0
$pastas = @((Join-Path $mql "Profiles\Charts"), (Join-Path $mql "Profiles\Templates"), (Join-Path $p.FullName "Profiles\Charts"), (Join-Path $p.FullName "Profiles\Templates"))
foreach ($pa in $pastas) {
  if (-not (Test-Path $pa)) { continue }
  Get-ChildItem $pa -Recurse -File -Include *.chr, *.tpl -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $l = Le-Texto $_.FullName
      if ($l.Texto -notmatch "ALIEN_PROFESSOR") { return }
      $ls = $l.Texto -split "`r?`n"; $dentro = $false; $alien = $false; $iMode = -1; $mudou = $false
      for ($i = 0; $i -lt $ls.Count; $i++) {
        $x = $ls[$i].Trim()
        if ($x -eq "<expert>") { $dentro = $true; $alien = $false; $iMode = -1; continue }
        if (-not $dentro) { continue }
        if ($x -match "^(name|path)=.*ALIEN_PROFESSOR") { $alien = $true }
        if ($x -match "^expertmode=") { $iMode = $i }
        if ($x -eq "<inputs>" -or $x -eq "</expert>") {
          if ($alien -and $iMode -ge 0) {
            $m = 0; [void][int]::TryParse(($ls[$iMode].Trim() -replace "^expertmode=", ""), [ref]$m)
            if (($m -band 4) -eq 0) { $ls[$iMode] = "expertmode=" + ($m -bor 4); $mudou = $true }
          }
          $dentro = $false
        }
      }
      if ($mudou) { Copy-Item $_.FullName ($_.FullName + ".bak") -Force; Grava-Texto $_.FullName ($ls -join "`r`n") $l.Uni; $nGraf++ }
    } catch { }
  }
}
if ($webOk) {
  Write-Host "Conexao automatica ligada (Telegram e IA). Nao precisa mexer em nada no MT5." -ForegroundColor Green
  if ($nGraf -gt 0) { Write-Host ("Ajustei " + $nGraf + " grafico(s) salvo(s) com o ALIEN pra ele abrir sozinho.") -ForegroundColor Green }
} else {
  Write-Host "Nao consegui ligar a conexao sozinho. No MT5: Ferramentas > Opcoes > Expert Advisors > marque 'Permitir importacao de DLL'." -ForegroundColor Yellow
}

$temVitor = (Test-Path $cfgDst)
Write-Host ""
Write-Host "Pronto! Abra o MT5. Se o ALIEN ja estava no grafico, ele volta sozinho, atualizado e conectado." -ForegroundColor Green
Write-Host "Se nao estava: arraste ALIEN_PROFESSOR_AUTO (Consultor expert > ALIEN) no grafico XAUUSD M1 e deixe marcado Permitir importacao de DLL."
if ($temVitor) {
  Write-Host "Sua configuracao (Telegram, IA e chat) esta em MQL5\Files\ALIEN_config.txt. Nao precisa mexer em parametro."
} else {
  Write-Host "Use SO em conta DEMO. Coloque token do Telegram e chave Gemini em MQL5\Files\ALIEN_config.txt (ou na aba Parametros) e mande /start pro bot."
}
Write-Host "Use so UM robo: ALIEN_PROFESSOR_AUTO. Nao ligue o ALIEN_PROFESSOR_TELEGRAM junto (ia mandar tudo dobrado)."
Write-Host "Se o robo nao aparecer no Navegador: botao direito em Consultor expert > Atualizar."
Write-Host ""
Write-Host "AVISO: no teste de 10 anos os sinais automaticos do ouro PERDERAM dinheiro. Leia o README_PT.md." -ForegroundColor Red
Write-Host ""
