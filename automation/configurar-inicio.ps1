param([ValidateSet('Instalar','Remover')][string]$Acao='Instalar')
$ErrorActionPreference='Stop'
$startup=[Environment]::GetFolderPath('Startup')
$atalho=Join-Path $startup 'ALIEN Monitor Local.lnk'
if($Acao -eq 'Remover') {
    if(Test-Path -LiteralPath $atalho) { Remove-Item -LiteralPath $atalho }
    Write-Host 'Inicio automatico do monitor removido.'
    exit 0
}
$bat=Join-Path $PSScriptRoot 'INICIAR_MONITOR.bat'
if(-not (Test-Path -LiteralPath $bat)) { throw 'Extraia o pacote inteiro antes de configurar.' }
if(-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js nao encontrado no PATH.' }
$shell=New-Object -ComObject WScript.Shell
$link=$shell.CreateShortcut($atalho)
$link.TargetPath=$bat
$link.WorkingDirectory=$PSScriptRoot
$link.Description='Monitor local dos relatorios do ALIEN; nao envia ordens.'
$link.Save()
Write-Host 'Monitor configurado para iniciar apos seu login no Windows.'
Write-Host 'Mantenha esta pasta no mesmo lugar. O computador precisa estar ligado e acordado.'
