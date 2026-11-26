param(
    [Parameter(Mandatory)][string]$Central,
    [Parameter(Mandatory)][string]$LocalState,
    [Parameter(Mandatory)][string]$Python,
    [Parameter(Mandatory)][string]$GitDirectory,
    [switch]$Run
)
$ErrorActionPreference = 'Stop'
$centralPath = [IO.Path]::GetFullPath($Central)
$statePath = [IO.Path]::GetFullPath($LocalState)
if (!(Test-Path -LiteralPath (Join-Path $statePath 'alien.db') -PathType Leaf)) {
    throw 'Estado migrado ausente.'
}
if (!(Test-Path -LiteralPath (Join-Path $statePath 'quant_executor.json') -PathType Leaf)) {
    throw 'Configuracao local do executor ausente.'
}
if (!(Test-Path -LiteralPath $Python -PathType Leaf) -or
    !(Test-Path -LiteralPath (Join-Path $GitDirectory 'git.exe') -PathType Leaf)) {
    throw 'Python ou Git indisponivel.'
}

$supervisor = [IO.Path]::Combine($centralPath, 'supervisor.py')
$heartbeat = [IO.Path]::Combine($centralPath, 'ESTADO\heartbeat.json')
if ($Run) {
    $deadline = [DateTime]::UtcNow.AddMinutes(5)
    while (!(Test-Path -LiteralPath $supervisor -PathType Leaf)) {
        if ([DateTime]::UtcNow -ge $deadline) { throw 'Pasta do Drive indisponivel.' }
        Start-Sleep -Seconds 10
    }
    $env:PATH = "$GitDirectory;$env:PATH"
    & $Python -B $supervisor --continuous --central $centralPath --local-state $statePath
    exit $LASTEXITCODE
}

if (!(Test-Path -LiteralPath $supervisor -PathType Leaf) -or
    !(Test-Path -LiteralPath $heartbeat -PathType Leaf)) {
    throw 'Central sincronizada ou heartbeat anterior indisponivel.'
}
$previous = Get-Content -LiteralPath $heartbeat -Raw | ConvertFrom-Json
$lastSeen = [DateTimeOffset]::Parse($previous.utc)
$quietSeconds = [Math]::Max(360, 2 * [int]$previous.poll_interval_seconds)
if (([DateTimeOffset]::UtcNow - $lastSeen).TotalSeconds -lt $quietSeconds) {
    throw 'Heartbeat recente. Verifique o desligamento do supervisor anterior.'
}
$taskName = 'ALIEN Autonomous Lab Supervisor'
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing -and $existing.State -eq 'Running') { throw 'Supervisor local em execucao.' }

$executable = Join-Path $PSHOME 'powershell.exe'
$argument = '-NoProfile -NonInteractive -WindowStyle Hidden -File "{0}" -Run -Central "{1}" -LocalState "{2}" -Python "{3}" -GitDirectory "{4}"' -f $PSCommandPath,$centralPath,$statePath,$Python,$GitDirectory
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute $executable -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
