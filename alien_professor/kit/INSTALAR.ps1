# ALIEN PROFESSOR - instala no MT5 da RoboForex (so UM terminal).
# Copia indicador, robos e presets para MQL5\...\ALIEN, apaga copias velhas soltas
# e libera o WebRequest (Telegram e Gemini). Nao mexe em conta nem senha.
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
if (Get-Process -Name terminal64 -ErrorAction SilentlyContinue) {
  Write-Host "O MT5 esta aberto. Feche o MT5 (no X) e aperte Enter para continuar." -ForegroundColor Yellow
  Read-Host | Out-Null
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
  else { Write-Host "Mantive a sua configuracao pessoal que ja existia (ALIEN_config.txt)." }
}
Write-Host ("OK -> " + $nome) -ForegroundColor Green
Write-Host ("     " + $exp)

# ---- WebRequest: libera Telegram e Gemini no config\common.ini (MT5 fechado) ----
$urls = @("https://api.telegram.org", "https://generativelanguage.googleapis.com")
$ini = Join-Path $p.FullName "config\common.ini"
$webOk = $false
try {
  if (Test-Path $ini) {
    $bytes = [System.IO.File]::ReadAllBytes($ini)
    $uni = ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)
    if ($uni) { $enc = [System.Text.Encoding]::Unicode } else { $enc = New-Object System.Text.UTF8Encoding($false) }
    $txt = $enc.GetString($bytes)
    if ($uni -and $txt.Length -gt 0 -and $txt[0] -eq [char]0xFEFF) { $txt = $txt.Substring(1) }
    Copy-Item $ini ($ini + ".bak") -Force
    $lines = New-Object System.Collections.ArrayList
    foreach ($l in ($txt -split "`r?`n")) { [void]$lines.Add($l) }
    $sec = -1; $fim = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i].Trim() -eq "[Experts]") { $sec = $i; continue }
      if ($sec -ge 0 -and $i -gt $sec -and $lines[$i].Trim().StartsWith("[")) { $fim = $i; break }
    }
    if ($sec -lt 0) {
      [void]$lines.Add("[Experts]"); $sec = $lines.Count - 1; $fim = $lines.Count
    }
    $iWeb = -1; $iUrl = -1
    for ($i = $sec + 1; $i -lt $fim; $i++) {
      if ($lines[$i] -match "^WebRequest=") { $iWeb = $i }
      if ($lines[$i] -match "^WebRequestUrl=") { $iUrl = $i }
    }
    $atuais = @()
    if ($iUrl -ge 0) { $atuais = @(($lines[$iUrl] -replace "^WebRequestUrl=", "") -split ";" | Where-Object { $_ -ne "" }) }
    foreach ($u in $urls) { if ($atuais -notcontains $u) { $atuais += $u } }
    $novaUrl = "WebRequestUrl=" + ($atuais -join ";")
    if ($iUrl -ge 0) { $lines[$iUrl] = $novaUrl } else { $lines.Insert($fim, $novaUrl) }
    if ($iWeb -ge 0) { $lines[$iWeb] = "WebRequest=1" } else { $lines.Insert($sec + 1, "WebRequest=1") }
    $out = ($lines -join "`r`n")
    if ($uni) { [System.IO.File]::WriteAllText($ini, $out, (New-Object System.Text.UnicodeEncoding($false, $true))) }
    else { [System.IO.File]::WriteAllText($ini, $out, $enc) }
    $webOk = $true
  }
} catch { $webOk = $false }
if ($webOk) {
  Write-Host "WebRequest liberado para Telegram e Gemini (backup em config\common.ini.bak)." -ForegroundColor Green
} else {
  Write-Host "Nao consegui liberar o WebRequest sozinho: no MT5 va em Ferramentas > Opcoes > Expert Advisors, marque Permitir WebRequest e adicione https://api.telegram.org e https://generativelanguage.googleapis.com" -ForegroundColor Yellow
}

$temVitor = (Test-Path $cfgDst)
Write-Host ""
Write-Host "Pronto! Abra o MT5 e arraste ALIEN_PROFESSOR_AUTO (pasta Consultor expert > ALIEN) no grafico XAUUSD M1." -ForegroundColor Green
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
