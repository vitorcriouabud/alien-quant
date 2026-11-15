# VIGIA_MT5.ps1 - mantém o MetaTrader 5 aberto.
# A cada 60 s confere se o terminal64.exe está rodando e respondendo.
# Fechou ou travou -> abre de novo (o MT5 reabre os gráficos e robôs do último perfil).
# Uso:  VIGIA_MT5.ps1            (vigia)
#       VIGIA_MT5.ps1 -Instalar  (configura e liga no logon do Windows)
#       VIGIA_MT5.ps1 -Remover   (desliga o vigia)
param([switch]$Instalar, [switch]$Remover, [string]$TerminalPath = "", [string]$BackupDir = "", [string]$GitRepo = "", [switch]$TestarGit)
$ErrorActionPreference = "Continue"
$dir  = Join-Path $env:LOCALAPPDATA "ALIEN_VIGIA"
$cfg  = Join-Path $dir "VIGIA_CONFIG.txt"
$log  = Join-Path $dir "vigia_log.txt"
$task = "ALIEN_VIGIA_MT5"
$bcfg = Join-Path $dir "VIGIA_BACKUP.txt"
$bmark = Join-Path $dir "ultimo_backup.txt"
# backup diário (opcional): diários/aprendizado CSV + prints + relatórios do testador
function Backup-Diario {
  if (-not (Test-Path $bcfg)) { return }
  $dest = (Get-Content $bcfg -Raw).Trim(); if (-not $dest) { return }
  $hoje = Get-Date -Format "yyyy-MM-dd"
  if ((Test-Path $bmark) -and ((Get-Content $bmark -Raw).Trim() -eq $hoje)) { return }
  $q = Split-Path $dest -Qualifier -ErrorAction SilentlyContinue
  if ($q -and -not (Test-Path ($q + "\"))) { Log "backup pulado: unidade $q não está ligada"; return }
  $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"
  $n = 0
  Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $t = $_.FullName; $alvo = Join-Path $dest (Join-Path $hoje $_.Name)
    $files = @()
    $files += Get-ChildItem (Join-Path $t "MQL5\Files") -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "ALIEN_*" -or $_.Name -like "APROF_*" }
    $files += Get-ChildItem (Join-Path $t "Tester") -Recurse -File -Include *.htm,*.html,*.xml -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "*\bases\*" }
    $files += Get-ChildItem $t -File -Include *.htm,*.html -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) {
      New-Item -ItemType Directory -Force -Path $alvo | Out-Null
      foreach ($f in $files) { Copy-Item $f.FullName $alvo -Force -ErrorAction SilentlyContinue; $n++ }
    }
  }
  Set-Content -Path $bmark -Value $hoje -Encoding ASCII
  Log "backup feito em $dest\$hoje ($n arquivos)"
}
New-Item -ItemType Directory -Force -Path $dir | Out-Null

function Log($m) {
  $l = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
  Add-Content -Path $log -Value $l -Encoding UTF8
  if ((Get-Item $log).Length -gt 2MB) { Move-Item $log ($log + ".old") -Force }
}

$gcfg = Join-Path $dir "VIGIA_GIT.txt"
$gmark = Join-Path $dir "ultimo_git.txt"
# arquivo parece ter segredo? (token Telegram, chave de IA, senha) -> não sobe
function Tem-Segredo($f) {
  $t = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
  if (-not $t) { return $false }
  return ($t -match '\d{8,}:AA[\w-]{20,}' -or $t -match 'xai-[\w]{20,}' -or $t -match 'AQ\.[\w-]{20,}' -or $t -match 'sk-[\w-]{20,}' -or $t -match 'AIza[\w-]{20,}' -or $t -match '(?i)senha|password')
}
# sincroniza os CSVs do ALIEN com o repositório privado do GitHub (1x por dia)
function Git-Sync([switch]$Forcar) {
  if (-not (Test-Path $gcfg)) { return }
  $repo = (Get-Content $gcfg -Raw).Trim(); if (-not $repo) { return }
  $hoje = Get-Date -Format "yyyy-MM-dd"
  if (-not $Forcar -and (Test-Path $gmark) -and ((Get-Content $gmark -Raw).Trim() -eq $hoje)) { return }
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { Log "git não instalado - sincronização pulada"; return }
  $local = Join-Path $dir ("git\" + ($repo -replace '/','_'))
  if (-not (Test-Path (Join-Path $local ".git"))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $local) | Out-Null
    & git clone --quiet "https://github.com/$repo.git" $local 2>&1 | ForEach-Object { Log "git: $_" }
    if (-not (Test-Path (Join-Path $local ".git"))) { Log "git clone falhou (faça o login: rode VIGIA_MT5.ps1 -TestarGit)"; return }
  }
  Push-Location $local
  try {
    & git pull --quiet --rebase 2>&1 | ForEach-Object { Log "git: $_" }
    $base = Join-Path $env:APPDATA "MetaQuotes\Terminal"; $n = 0; $pulados = 0
    Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $src = Join-Path $_.FullName "MQL5\Files"
      $alvo = Join-Path $local ("alien_dados\" + $_.Name.Substring(0, [Math]::Min(8, $_.Name.Length)))
      Get-ChildItem $src -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "ALIEN_*.csv" -or $_.Name -like "APROF_SINAL_*.txt" } | ForEach-Object {
        if (Tem-Segredo $_) { $pulados++; Log "NÃO subi $($_.Name): parece ter segredo"; return }
        New-Item -ItemType Directory -Force -Path $alvo | Out-Null
        Copy-Item $_.FullName $alvo -Force; $n++
      }
    }
    & git add alien_dados 2>&1 | Out-Null
    $mud = & git status --porcelain alien_dados
    if ($mud) {
      & git -c user.name="ALIEN VIGIA" -c user.email="alien-vigia@users.noreply.github.com" commit --quiet -m "alien_dados $hoje ($n arquivos)" 2>&1 | ForEach-Object { Log "git: $_" }
      & git push --quiet 2>&1 | ForEach-Object { Log "git: $_" }
      if ($LASTEXITCODE -eq 0) { Log "git: enviado ($n arquivos, $pulados pulados)"; Set-Content -Path $gmark -Value $hoje -Encoding ASCII }
      else { Log "git push falhou (login do GitHub? rode VIGIA_MT5.ps1 -TestarGit)" }
    } else { Log "git: nada novo"; Set-Content -Path $gmark -Value $hoje -Encoding ASCII }
  } finally { Pop-Location }
}
function Achar-Terminais {
  $l = @()
  Get-Process terminal64 -ErrorAction SilentlyContinue | ForEach-Object { if ($_.Path) { $l += $_.Path } }
  foreach ($b in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "C:\", "D:\")) {
    if ($b -and (Test-Path $b)) {
      Get-ChildItem $b -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $t = Join-Path $_.FullName "terminal64.exe"; if (Test-Path $t) { $l += $t }
      }
    }
  }
  $l | Select-Object -Unique
}

if ($TestarGit) {
  if ($GitRepo) { Set-Content -Path $gcfg -Value $GitRepo -Encoding UTF8 }
  if (-not (Test-Path $gcfg)) { Set-Content -Path $gcfg -Value "vitorcriouabud/bud-central-sync" -Encoding UTF8 }
  Write-Host "Testando sincronização com GitHub (pode abrir a janela de login do GitHub)..."
  Git-Sync -Forcar
  Get-Content $log -Tail 8
  exit 0
}
if ($Remover) {
  try { Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction Stop; Write-Host "Tarefa removida." } catch {}
  $st = Join-Path ([Environment]::GetFolderPath("Startup")) "ALIEN_VIGIA.cmd"; if (Test-Path $st) { Remove-Item $st -Force }
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*VIGIA_MT5.ps1*" -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  Write-Host "Vigia desligado." -ForegroundColor Yellow
  exit 0
}

if ($Instalar) {
  Write-Host ""
  Write-Host "=== ALIEN VIGIA - instalar ===" -ForegroundColor Yellow
  $path = $TerminalPath
  if (-not $path) {
    $ts = @(Achar-Terminais)
    if ($ts.Count -eq 0) {
      $path = Read-Host "Não achei o MT5. Cole o caminho do terminal64.exe (ex.: C:\Program Files\RoboForex MT5 Terminal\terminal64.exe)"
    } elseif ($ts.Count -eq 1) { $path = $ts[0]; Write-Host "MT5 encontrado: $path" }
    else {
      Write-Host "Achei mais de um MT5:"; for ($i=0; $i -lt $ts.Count; $i++) { Write-Host ("  [{0}] {1}" -f ($i+1), $ts[$i]) }
      $n = Read-Host "Digite o número do MT5 que o robô usa"; $path = $ts[[int]$n - 1]
    }
  }
  if (-not (Test-Path $path)) { Write-Host "Caminho inválido: $path" -ForegroundColor Red; exit 1 }
  Set-Content -Path $cfg -Value $path -Encoding UTF8
  if (-not $BackupDir) { $BackupDir = Read-Host "Backup diário (opcional): pasta destino, ex. D:\ALIEN_BACKUP  (Enter = sem backup)" }
  if ($BackupDir) { Set-Content -Path $bcfg -Value $BackupDir -Encoding UTF8; Write-Host "Backup diário em: $BackupDir (se a unidade não estiver ligada, pula)" }
  elseif (Test-Path $bcfg) { Remove-Item $bcfg -Force }
  if (-not $GitRepo) {
    $r = Read-Host "Enviar os CSVs do ALIEN 1x por dia pro seu GitHub PRIVADO? Enter = vitorcriouabud/bud-central-sync, n = não"
    if ($r -eq "n" -or $r -eq "N") { $GitRepo = "" } elseif ($r) { $GitRepo = $r } else { $GitRepo = "vitorcriouabud/bud-central-sync" }
  }
  if ($GitRepo) {
    Set-Content -Path $gcfg -Value $GitRepo -Encoding UTF8
    if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host "GitHub: $GitRepo (pasta alien_dados/). Testando agora (faça o login se abrir a janela)..."; Git-Sync -Forcar }
    else { Write-Host "git não está instalado - instale em https://git-scm.com e rode: VIGIA_MT5.ps1 -TestarGit" -ForegroundColor Yellow }
  } elseif (Test-Path $gcfg) { Remove-Item $gcfg -Force }
  $me = Join-Path $dir "VIGIA_MT5.ps1"
  Copy-Item $MyInvocation.MyCommand.Path $me -Force
  $arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$me`""
  $ok = $false
  try {
    $a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
    $t = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $task -Action $a -Trigger $t -Settings $s -Description "ALIEN: mantém o MT5 aberto" -Force -ErrorAction Stop | Out-Null
    $ok = $true; Write-Host "Tarefa '$task' criada (liga sozinha quando você entra no Windows)." -ForegroundColor Green
  } catch {
    $st = Join-Path ([Environment]::GetFolderPath("Startup")) "ALIEN_VIGIA.cmd"
    Set-Content -Path $st -Value "@start `"`" /min powershell.exe $arg" -Encoding ASCII
    Write-Host "Sem permissão pra Tarefa Agendada; coloquei na pasta Inicializar do Windows: $st" -ForegroundColor Green
  }
  Start-Process powershell.exe -ArgumentList $arg -WindowStyle Hidden
  Write-Host "Vigia ligado agora. Log: $log"
  Write-Host ""
  Write-Host "FALTA VOCÊ FAZER (1 vez):" -ForegroundColor Yellow
  Write-Host " 1. Não deixar o PC dormir. Abra o 'Prompt de Comando' e cole:"
  Write-Host "      powercfg /change standby-timeout-ac 0"
  Write-Host "      powercfg /change hibernate-timeout-ac 0"
  Write-Host "      powercfg /change monitor-timeout-ac 10   (a tela pode apagar, o PC não)"
  Write-Host " 2. MT5 com login automático: no login da conta marque 'Salvar senha'."
  Write-Host " 3. No MT5: deixe o gráfico com o robô aberto e o botão 'Algo Trading' verde, depois feche pelo X"
  Write-Host "    (assim o MT5 salva o perfil e reabre tudo igual)."
  Write-Host " 4. Windows entrar sozinho (opcional): Win+R > netplwiz > desmarque 'Os usuários devem inserir...'."
  Write-Host " Para desligar o vigia: VIGIA_MT5.ps1 -Remover"
  exit 0
}

# ---------------- modo vigia ----------------
if (-not $TerminalPath) { if (Test-Path $cfg) { $TerminalPath = (Get-Content $cfg -Raw).Trim() } }
if (-not $TerminalPath -or -not (Test-Path $TerminalPath)) { Log "ERRO: caminho do terminal64.exe não configurado. Rode VIGIA_INSTALAR.bat."; exit 1 }
# só um vigia por vez
$outros = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*VIGIA_MT5.ps1*" -and $_.CommandLine -notlike "*-Instalar*" -and $_.ProcessId -ne $PID }
if ($outros) { exit 0 }
Log "vigia começou: $TerminalPath"
if ($BackupDir) { Set-Content -Path $bcfg -Value $BackupDir -Encoding UTF8 }
$travado = 0
while ($true) {
  try { Backup-Diario } catch { Log "erro no backup: $_" }
  try { Git-Sync } catch { Log "erro no git: $_" }
  $p = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $TerminalPath } | Select-Object -First 1
  if (-not $p) {
    Log "MT5 fechado -> abrindo de novo"
    Start-Process -FilePath $TerminalPath -WorkingDirectory (Split-Path $TerminalPath)
    $travado = 0
    Start-Sleep -Seconds 90
    continue
  }
  $p.Refresh()
  if (-not $p.Responding) {
    $travado++
    Log "MT5 não responde ($travado/3)"
    if ($travado -ge 3) {
      Log "MT5 travado -> fechando e abrindo de novo"
      Stop-Process -Id $p.Id -Force
      Start-Sleep -Seconds 5
      Start-Process -FilePath $TerminalPath -WorkingDirectory (Split-Path $TerminalPath)
      $travado = 0
      Start-Sleep -Seconds 90
      continue
    }
  } else { $travado = 0 }
  Start-Sleep -Seconds 60
}
