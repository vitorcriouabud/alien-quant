# ALIEN - envia o codigo do robo (.mq5) e os diarios de aprendizado (ALIEN_*.csv)
# para o GitHub, na branch alien-dados de vitorcriouabud/alien-quant.
# NUNCA envia .ex5, .set, chaves ou token. Nunca mexe na branch principal.
$ErrorActionPreference = "Continue"
$repo = "https://github.com/vitorcriouabud/alien-quant.git"
$branch = "alien-dados"
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
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "Git nao instalado. Abra o PowerShell e rode: winget install Git.Git   (depois rode este arquivo de novo)" -ForegroundColor Yellow
  exit 1
}
$p = Escolhe-Terminal
if ($null -eq $p) { exit 1 }
$mql = Join-Path $p.FullName "MQL5"
$dir = Join-Path $env:LOCALAPPDATA "ALIEN_GIT\alien-quant"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
if (-not (Test-Path (Join-Path $dir ".git"))) {
  git init -q
  git remote add origin $repo
}
git fetch -q origin $branch 2>$null
if ($LASTEXITCODE -eq 0) { git checkout -q -B $branch FETCH_HEAD } else { git symbolic-ref HEAD ("refs/heads/" + $branch) }
$cur = (git symbolic-ref --short HEAD).Trim()
if ($cur -ne $branch) { Write-Host "Nao estou na branch $branch. Parei por seguranca." -ForegroundColor Red; exit 1 }

# .gitignore: nada de compilado, preset, config ou memoria de conversa
$gi = "*.ex5`n*.set`n*.ini`n*.log`n*.bak`n*memoria*`n*chat*`n*.txt`n"
[System.IO.File]::WriteAllText((Join-Path $dir ".gitignore"), $gi)

# trava antes do commit (pre-commit): bloqueia chave Google (AIza...), token de bot (numeros:AA...) e chave AQ.
$hook = "#!/bin/sh`n" +
  "if git diff --cached -U0 | grep -E -q 'AIza[0-9A-Za-z_-]{20,}|[0-9]{8,10}:AA[0-9A-Za-z_-]{20,}|AQ\.[0-9A-Za-z_-]{20,}'; then`n" +
  "  echo 'ALIEN: achei algo parecido com chave/token. Nao vou subir.'; exit 1; fi`nexit 0`n"
New-Item -ItemType Directory -Force -Path (Join-Path $dir ".git\hooks") | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dir ".git\hooks\pre-commit"), $hook)

New-Item -ItemType Directory -Force -Path (Join-Path $dir "fonte"), (Join-Path $dir "dados") | Out-Null
Get-ChildItem (Join-Path $mql "Experts\ALIEN") -Filter *.mq5 -ErrorAction SilentlyContinue | Copy-Item -Destination (Join-Path $dir "fonte") -Force
Get-ChildItem (Join-Path $mql "Indicators\ALIEN") -Filter *.mq5 -ErrorAction SilentlyContinue | Copy-Item -Destination (Join-Path $dir "fonte") -Force
Get-ChildItem (Join-Path $mql "Files") -Filter "ALIEN_*.csv" -ErrorAction SilentlyContinue | Copy-Item -Destination (Join-Path $dir "dados") -Force

# confere de novo aqui (alem do pre-commit): arquivo com cara de chave nao entra
$padrao = 'AIza[0-9A-Za-z_-]{20,}|[0-9]{8,10}:AA[0-9A-Za-z_-]{20,}|AQ\.[0-9A-Za-z_-]{20,}'
Get-ChildItem (Join-Path $dir "fonte"), (Join-Path $dir "dados") -File | ForEach-Object {
  if (Select-String -Path $_.FullName -Pattern $padrao -Quiet) {
    Write-Host ("Tirei " + $_.Name + " (parece ter chave/token).") -ForegroundColor Yellow
    Remove-Item $_.FullName -Force
  }
}
git add -A .gitignore fonte dados
git -c user.name="ALIEN Vitor" -c user.email="alien@localhost" commit -q -m ("dados ALIEN " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
if ($LASTEXITCODE -ne 0) { Write-Host "Nada novo para subir (ou a trava de seguranca bloqueou)." -ForegroundColor Yellow; exit 0 }
Write-Host "Enviando... (na primeira vez abre a janela de login do GitHub)"
git push -u origin $branch
if ($LASTEXITCODE -eq 0) { Write-Host "Pronto! Subiu para a branch alien-dados." -ForegroundColor Green } else { Write-Host "Nao consegui enviar. Confira a internet e o login do GitHub e rode de novo." -ForegroundColor Red }
