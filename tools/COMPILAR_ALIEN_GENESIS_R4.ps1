# Compilador unico ALIEN R4 - nao executa terminal nem ordens
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ea = Join-Path $repo "MQL5\Experts\ALIEN_GENESIS_MTF_R4_DEMO.mq5"
if (-not (Test-Path $ea)) { throw "Fonte MQ5 nao encontrado: $ea" }
$locations = @(
  "C:\Program Files\RoboForex MT5 Terminal\metaeditor64.exe",
  "C:\Program Files\MetaTrader 5\metaeditor64.exe",
  "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe",
  "C:\ALIEN_TEST_MT5\metaeditor64.exe"
)
$editor = $locations | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $editor) { throw "MetaEditor64 nao encontrado na instalacao atual." }
$log = Join-Path $repo "ALIEN_R4_COMPILE.log"
$arguments = '/compile:"' + $ea + '" /log:"' + $log + '"'
Start-Process -FilePath $editor -ArgumentList $arguments -Wait -PassThru | Out-Null
if (-not (Test-Path $log)) { throw "MetaEditor nao gerou log: $log" }
$txt = Get-Content $log -Raw -Encoding Default
Write-Output $txt
if ($txt -notmatch '(?i)(?:result|resultado)\s*:\s*0\s+(?:errors?|erros?)') {
   throw "Compilacao nao comprovada. Conferir log acima."
}
$ex5 = [System.IO.Path]::ChangeExtension($ea,'.ex5')
if (-not (Test-Path $ex5)) { throw "MetaEditor nao deixou binario EX5 ao lado do MQ5." }
$shaSource = (Get-FileHash $ea -Algorithm SHA256).Hash
$shaExe = (Get-FileHash $ex5 -Algorithm SHA256).Hash
Write-Output "SOURCE SHA256: $shaSource"
Write-Output "EX5 SHA256: $shaExe"
Write-Output "Sem ordens, sem terminal ativo: compilacao apenas."
