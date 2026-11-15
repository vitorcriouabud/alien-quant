# ALIEN PROFESSOR - copia indicador, robô AUTO, EA Telegram, robô dos índices e presets para todos os MT5 deste PC.
# Não mexe em conta, senha nem configuração. Só copia arquivos.
$ErrorActionPreference = "Continue"
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
Write-Host ""
if (-not (Test-Path $base)) {
  Write-Host "Não achei a pasta do MT5 em $base" -ForegroundColor Red
  Write-Host "Abra o MT5 uma vez e rode de novo. Ou: no MT5, Arquivo > Abrir pasta de dados, e copie os arquivos na mão (veja README_PT.md)."
  exit 1
}
$pastas = Get-ChildItem $base -Directory | Where-Object { Test-Path (Join-Path $_.FullName "MQL5") }
if ($pastas.Count -eq 0) { Write-Host "Nenhum MT5 encontrado em $base" -ForegroundColor Red; exit 1 }
$n = 0
foreach ($p in $pastas) {
  $mql = Join-Path $p.FullName "MQL5"
  $orig = Join-Path $p.FullName "origin.txt"
  $nome = if (Test-Path $orig) { (Get-Content $orig -Raw).Trim() } else { $p.Name }
  $ind = Join-Path $mql "Indicators\ALIEN"; $exp = Join-Path $mql "Experts\ALIEN"; $pre = Join-Path $mql "Presets"
  New-Item -ItemType Directory -Force -Path $ind, $exp, $pre | Out-Null
  Copy-Item (Join-Path $aqui "ALIEN_PROFESSOR.ex5") $ind -Force
  Copy-Item (Join-Path $aqui "ALIEN_PROFESSOR.mq5") $ind -Force
  foreach ($f in "ALIEN_PROFESSOR_AUTO.ex5","ALIEN_PROFESSOR_AUTO.mq5","ALIEN_PROFESSOR_TELEGRAM.ex5","ALIEN_PROFESSOR_TELEGRAM.mq5") {
    $src = Join-Path $aqui $f; if (Test-Path $src) { Copy-Item $src $exp -Force }
  }
  Get-ChildItem (Join-Path $aqui "presets") -Filter *.set -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName $pre -Force }
  # robô dos índices (ALIEN_INDICES_V1) - pasta indices\
  $idx = Join-Path $aqui "indices"
  if (Test-Path $idx) {
    foreach ($f in "ALIEN_INDICES_V1.ex5","ALIEN_INDICES_V1.mq5") { $src = Join-Path $idx $f; if (Test-Path $src) { Copy-Item $src $exp -Force } }
    $src = Join-Path $idx "ALIEN_INDICES_V1.set"; if (Test-Path $src) { Copy-Item $src $pre -Force }
  }
  Write-Host "OK  ->  $nome" -ForegroundColor Green
  Write-Host "     $mql"
  $n++
}
Write-Host ""
Write-Host "Instalado em $n MT5." -ForegroundColor Yellow
Write-Host ""
Write-Host "AGORA, NO MT5:" -ForegroundColor Yellow
Write-Host " 1. Feche e abra o MT5 (ou no Navegador: botão direito > Atualizar)."
Write-Host " 2. INDICADOR: Navegador > Indicadores > ALIEN > ALIEN_PROFESSOR. Arraste no gráfico M1 do XAUUSD."
Write-Host " 3. ROBÔ: Navegador > Expert Advisors > ALIEN > ALIEN_PROFESSOR_AUTO. Use SÓ em conta DEMO primeiro."
Write-Host "    Na janela do robô: aba Parâmetros > Carregar > ALIEN_PROFESSOR_AUTO_seguro.set"
Write-Host " 4. TELEGRAM/IA: Ferramentas > Opções > Expert Advisors > marque 'Permitir WebRequest' e adicione:"
Write-Host "      https://api.telegram.org"
Write-Host "      https://api.x.ai"
Write-Host "      https://generativelanguage.googleapis.com"
Write-Host "    No Telegram mande /ajuda pro seu bot para ver os comandos."
Write-Host " 5. ÍNDICES: Expert Advisors > ALIEN > ALIEN_INDICES_V1 em UM gráfico do .US500Cash (D1)."
Write-Host "    Carregar > ALIEN_INDICES_V1.set. Precisa de ~US$ 3.200. Rode 1 mês em DEMO antes."
Write-Host ""
Write-Host "AVISO: no teste de 10 anos os sinais deste robô PERDERAM dinheiro. Leia o README_PT.md." -ForegroundColor Red
Write-Host ""
