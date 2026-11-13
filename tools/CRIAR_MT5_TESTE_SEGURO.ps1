#requires -Version 5.1
# Cria um MT5 PORTATIL para testes, sem copiar contas, senhas ou dados do terminal em uso.
# Copia apenas arquivos de programa; a primeira conexao deve ser feita numa conta DEMO.
$ErrorActionPreference="Stop"
$dest=Join-Path $env:LOCALAPPDATA "ALIEN_TEST_MT5"
if (Test-Path (Join-Path $dest "terminal64.exe")) {
    Write-Host "MT5 de teste ja preparado: $dest" -ForegroundColor Green
    exit 0
}
$sources=@(
    "C:\Program Files\RoboForex MT5 Terminal",
    "C:\Program Files\MetaTrader 5",
    "C:\Program Files (x86)\MetaTrader 5"
)
$source=$sources | Where-Object {Test-Path (Join-Path $_ "terminal64.exe")} | Select-Object -First 1
if (-not $source) {
    throw "Nenhuma instalacao MT5 encontrada. Verifique a pasta do MT5 existente, sem instalar outro."
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Write-Host "Copiando binarios do MT5 para: $dest" -ForegroundColor Cyan
Write-Host "Origem: $source | pasta original NAO sera modificada"
$excludes=@(
    (Join-Path $source "config"),(Join-Path $source "bases"),
    (Join-Path $source "MQL5"),(Join-Path $source "Tester"),
    (Join-Path $source "tester"),(Join-Path $source "logs"),
    (Join-Path $source "Profiles"),(Join-Path $source "profiles")
)
# Robocopy retorna 0..7 em sucesso, >=8 em erro.
& robocopy.exe $source $dest /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD $excludes
if ($LASTEXITCODE -ge 8) {throw "Falha ao criar copia isolada: robocopy $LASTEXITCODE"}
if (-not (Test-Path (Join-Path $dest "terminal64.exe"))) {
    throw "A copia nao produziu terminal64.exe em $dest"
}
Write-Host "AMBIENTE DE TESTE CRIADO: $dest" -ForegroundColor Green
Write-Host "SEM importar contas, logins ou historico do terminal em uso."
Write-Host "Abra o terminal de teste e conecte uma conta DEMO para baixar ticks da corretora."
