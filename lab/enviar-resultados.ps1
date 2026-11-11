$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot 'resultados'
$last=Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending | Select-Object -First 1
if(-not $last){throw 'Sem resultados. Execute primeiro TESTE_INICIAL.bat.'}
$dest=Join-Path $PSScriptRoot 'ENVIAR_TESTES_ALIEN.zip'
Compress-Archive -Path (Join-Path $last.FullName '*') -DestinationPath $dest -Force
Write-Host "Pacote para enviar: $dest"
