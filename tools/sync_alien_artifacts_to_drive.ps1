param(
    [int]$IntervalMinutes = 15
)

$ErrorActionPreference = "Stop"

# This tool only COPIES files to the locally synchronized Google Drive folder.
# It never edits/deletes originals, connects to MT5, or sends trading orders.
$DriveRoot = "G:\Meu Drive\ALIEN - Transferencia Automatica"
$MaxFileBytes = 100MB
$MinFileAgeSeconds = 45
$ExcludedNamePattern = "(?i)password|senha|secret|token|credential|credencial|wallet|apikey|api_key|private.?key"
$AllowedExtensions = @(
    ".csv", ".json", ".log", ".txt", ".htm", ".html",
    ".mq5", ".mqh", ".set", ".zip", ".md"
)

function Add-Candidate {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$SourceRoot,
        [string]$DestinationFolder,
        [string]$FilterMode
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $AllowedExtensions -contains $_.Extension.ToLowerInvariant()
        } |
        ForEach-Object {
            $file = $_
            $relative = $file.FullName.Substring($SourceRoot.TrimEnd('\').Length).TrimStart('\')
            $relevant = ($file.Name -notmatch $ExcludedNamePattern)

            if ($FilterMode -eq "AlienNamed") {
                $relevant = ($file.FullName -match "(?i)ALIEN|XAUUSD|TICK|REPORT|RELATORIO|EXP[0-9]|DEBRIEF|TESTER")
            }

            if ($relevant) {
                $List.Add([pscustomobject]@{
                    Source = $file.FullName
                    Relative = $relative
                    DestinationFolder = $DestinationFolder
                    Length = $file.Length
                    ModifiedUtc = $file.LastWriteTimeUtc
                })
            }
        }
}

function Get-Candidates {
    $items = New-Object 'System.Collections.Generic.List[object]'
    $commonFiles = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"

    # MT5 Common\Files: only files whose path/name is clearly ALIEN/XAUUSD related.
    Add-Candidate -List $items -SourceRoot $commonFiles -DestinationFolder "01_MT5_COMMON_FILES" -FilterMode "AlienNamed"

    # Some MT5 installations keep ALIEN artifacts inside a terminal-specific MQL5\Files folder.
    $terminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path -LiteralPath $terminalRoot -PathType Container) {
        Get-ChildItem -LiteralPath $terminalRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $mqlFiles = Join-Path $_.FullName "MQL5\Files"
                Add-Candidate -List $items -SourceRoot $mqlFiles -DestinationFolder ("02_MT5_FILES\" + $_.Name) -FilterMode "AlienNamed"
            }
    }

    # Downloads: only folders explicitly named for ALIEN or the handoff package.
    $downloads = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path -LiteralPath $downloads -PathType Container) {
        Get-ChildItem -LiteralPath $downloads -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "(?i)^(ALIEN|ENVIAR_AO_CHATGPT)" } |
            ForEach-Object {
                Add-Candidate -List $items -SourceRoot $_.FullName -DestinationFolder ("03_DOWNLOADS\" + $_.Name) -FilterMode "All"
            }

        # Also include directly downloaded ALIEN handoff/report files.
        Get-ChildItem -LiteralPath $downloads -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -match "(?i)ALIEN|ENVIAR_AO_CHATGPT|XAUUSD.*(REPORT|TICK|DATA)" -and
                ($AllowedExtensions -contains $_.Extension.ToLowerInvariant())
            } |
            ForEach-Object {
                $items.Add([pscustomobject]@{
                    Source = $_.FullName
                    Relative = $_.Name
                    DestinationFolder = "03_DOWNLOADS"
                    Length = $_.Length
                    ModifiedUtc = $_.LastWriteTimeUtc
                })
            }
    }

    return $items
}

function Invoke-OneSync {
    if (-not (Test-Path -LiteralPath $DriveRoot -PathType Container)) {
        throw "Pasta do Google Drive nao encontrada: $DriveRoot. Confirme se o Drive para computador esta aberto e sincronizado."
    }

    $candidates = Get-Candidates
    $copied = 0
    $unchanged = 0
    $skipped = 0
    $errors = 0
    $now = Get-Date

    foreach ($item in $candidates) {
        try {
            $source = Get-Item -LiteralPath $item.Source -ErrorAction Stop

            if (($now - $source.LastWriteTime).TotalSeconds -lt $MinFileAgeSeconds) {
                $skipped++
                continue
            }

            if ($source.Length -gt $MaxFileBytes) {
                $skipped++
                Write-Host ("IGNORADO (>100 MB): " + $source.Name) -ForegroundColor Yellow
                continue
            }

            $destinationDirectory = Join-Path $DriveRoot $item.DestinationFolder
            $destinationPath = Join-Path $destinationDirectory $item.Relative
            $parent = Split-Path -Parent $destinationPath

            if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
                $existing = Get-Item -LiteralPath $destinationPath
                if ($existing.Length -eq $source.Length -and
                    $existing.LastWriteTimeUtc -eq $source.LastWriteTimeUtc) {
                    $unchanged++
                    continue
                }
            }

            $temporaryPath = $destinationPath + ".alien-sync-part"
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
            }

            [System.IO.File]::Copy($source.FullName, $temporaryPath, $true)
            $copiedFile = Get-Item -LiteralPath $temporaryPath
            if ($copiedFile.Length -ne $source.Length) {
                throw "Tamanho diferente apos copia"
            }

            Move-Item -LiteralPath $temporaryPath -Destination $destinationPath -Force
            (Get-Item -LiteralPath $destinationPath).LastWriteTimeUtc = $source.LastWriteTimeUtc
            $copied++
            Write-Host ("COPIADO: " + $source.Name) -ForegroundColor Green
        }
        catch {
            $errors++
            Write-Host ("FALHA: " + $item.Source + " | " + $_.Exception.Message) -ForegroundColor Red
        }
    }

    $statusPath = Join-Path $DriveRoot "STATUS_DA_SINCRONIZACAO.txt"
    $status = @(
        "ALIEN - SINCRONIZACAO LOCAL PARA GOOGLE DRIVE"
        ("Ultima verificacao: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
        ("Arquivos encontrados: " + $candidates.Count)
        ("Copiados/atualizados: " + $copied)
        ("Ja estavam atualizados: " + $unchanged)
        ("Ignorados (recentes ou acima de 100 MB): " + $skipped)
        ("Falhas de leitura/copia: " + $errors)
        ""
        "Somente copia. Nenhum original foi alterado ou apagado."
        "Nenhuma conexao MT5, ordem ou operacao financeira e executada.
Nomes que indicam senha, token, credencial ou chave privada sao excluidos."
        "Arquivos acima de 100 MB sao ignorados para evitar sincronizacao enorme sem autorizacao."
    )
    Set-Content -LiteralPath $statusPath -Value $status -Encoding UTF8

    Write-Host ""
    Write-Host ("Resumo: copiados {0} | sem alteracao {1} | ignorados {2} | falhas {3}" -f $copied, $unchanged, $skipped, $errors) -ForegroundColor Cyan
    Write-Host ("Destino: " + $DriveRoot)
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "ALIEN - SINCRONIZADOR DE ARQUIVOS PARA GOOGLE DRIVE" -ForegroundColor Cyan
Write-Host "Somente leitura na origem; copia para G:; sem ordens MT5." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

while ($true) {
    try {
        Invoke-OneSync
    }
    catch {
        Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    }

    Write-Host ""
    Write-Host ("Proxima verificacao em {0} minutos. Ctrl+C para encerrar." -f $IntervalMinutes) -ForegroundColor Yellow
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
