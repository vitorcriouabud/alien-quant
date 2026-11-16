# ALIEN - ATUALIZAR em 2 cliques: baixa a versao mais nova do GitHub e instala.
# Sua configuracao (MQL5\Files\ALIEN_config.txt) NUNCA e apagada.
# Para seguir outra branch no futuro, troque so a linha $branch abaixo.
$ErrorActionPreference = "Stop"
$repo = "vitorcriouabud/alien-quant"
$branch = "alien-professor-v12-3"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$tmp = Join-Path $env:TEMP ("ALIEN_ATUALIZAR_" + (Get-Date -Format "yyyyMMddHHmmss"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp "alien.zip"
$url = "https://codeload.github.com/$repo/zip/refs/heads/$branch"
Write-Host "Baixando a versao mais nova do GitHub ($branch)..."
try { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing }
catch { Write-Host "Nao consegui baixar. Confira a internet e tente de novo." -ForegroundColor Red; exit 1 }
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory -Recurse | Where-Object { $_.Name -eq "alien_professor" } | Select-Object -First 1
if ($null -eq $src) { Write-Host "O download veio sem a pasta alien_professor. Nada foi mudado." -ForegroundColor Red; exit 1 }
$kit = Join-Path $tmp "kit"
New-Item -ItemType Directory -Force -Path $kit | Out-Null
foreach ($f in @("ALIEN_PROFESSOR.mq5", "ALIEN_PROFESSOR_AUTO.mq5", "ALIEN_PROFESSOR_TELEGRAM.mq5", "MUDANCAS.md", "README_PT.md")) {
  $s = Join-Path $src.FullName $f; if (Test-Path $s) { Copy-Item $s $kit -Force }
}
Copy-Item (Join-Path $src.FullName "kit\INSTALAR.ps1") $kit -Force
$kc = Join-Path $src.FullName "kit\ALIEN_conhecimento.txt"; if (Test-Path $kc) { Copy-Item $kc $kit -Force }
$gg = Join-Path $src.FullName "GUIA_DO_GRAFICO.md"; if (Test-Path $gg) { Copy-Item $gg $kit -Force }
$pre = Join-Path $src.FullName "kit\presets"
if (Test-Path $pre) { Copy-Item $pre (Join-Path $kit "presets") -Recurse -Force }
$ver = ""
$m = Join-Path $kit "MUDANCAS.md"
if (Test-Path $m) { $ver = (Get-Content $m | Where-Object { $_ -match "^## Vers" } | Select-Object -First 1) -replace "^## ", "" }
Write-Host ("Versao baixada: " + $ver) -ForegroundColor Green
$ErrorActionPreference = "Continue"
& (Join-Path $kit "INSTALAR.ps1") -Compilar
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
Copy-Item $m (Join-Path $aqui "MUDANCAS.md") -Force -ErrorAction SilentlyContinue
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "O que mudou: abra o MUDANCAS.md. No Telegram toque em Status para ver a versao nova." -ForegroundColor Green
