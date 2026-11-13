param(
    [int]$Port = 8055,
    [switch]$OpenBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LogsDir = Join-Path $RootDir "logs"
if (-not (Test-Path -LiteralPath $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}
$ServerLogPath = Join-Path $LogsDir "server.log"

function Write-ServerLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f ([DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")), $Message
    try {
        [System.IO.File]::AppendAllText($ServerLogPath, $line + "`r`n", [System.Text.Encoding]::UTF8)
    } catch {}
}

$workerScript = {
    param(
        [string]$RootDir,
        [int]$Port,
        [System.Net.Sockets.TcpClient]$Client
    )
    Set-StrictMode -Version Latest

    if (-not (Get-Command Invoke-WebRoute -ErrorAction SilentlyContinue)) {
        . (Join-Path $RootDir "src\AgentCommon.ps1")
        . (Join-Path $RootDir "src\AgentTools.ps1")
        . (Join-Path $RootDir "src\AgentLLM.ps1")
        . (Join-Path $RootDir "src\AgentOrchestrator.ps1")
        . (Join-Path $RootDir "src\WebServerRouter.ps1")
    }

    function Read-WorkerHttpRequest {
        param([Parameter(Mandatory=$true)][System.Net.Sockets.NetworkStream]$Stream)
        $ms = New-Object System.IO.MemoryStream
        $buf = New-Object byte[] 8192
        $headerEndIdx = -1

        try {
            while ($true) {
                $n = $Stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $ms.Write($buf, 0, $n)
                $bytes = $ms.ToArray()
                for ($i = 0; $i -le ($bytes.Length - 4); $i++) {
                    if ($bytes[$i] -eq 13 -and $bytes[$i+1] -eq 10 -and $bytes[$i+2] -eq 13 -and $bytes[$i+3] -eq 10) {
                        $headerEndIdx = $i
                        break
                    }
                }
                if ($headerEndIdx -ge 0) { break }
                if ($ms.Length -gt 65536) { return $null }
            }

            if ($headerEndIdx -lt 0) { return $null }

            $allBytes = $ms.ToArray()
            $headerText = [System.Text.Encoding]::ASCII.GetString($allBytes, 0, $headerEndIdx)
            $headerLines = $headerText -split "`r`n"
            $reqLineParts = $headerLines[0] -split " "
            $method = $reqLineParts[0].ToUpperInvariant()
            $rawUrl = if ($reqLineParts.Length -ge 2) { $reqLineParts[1] } else { "/" }
            $path = ($rawUrl -split '\?')[0]

            $contentLength = 0
            $expectContinue = $false
            if ($headerLines.Length -gt 1) {
                foreach ($line in $headerLines[1..($headerLines.Length - 1)]) {
                    $colon = $line.IndexOf(':')
                    if ($colon -gt 0) {
                        $k = $line.Substring(0, $colon).Trim().ToLowerInvariant()
                        $v = $line.Substring($colon + 1).Trim()
                        if ($k -eq "content-length") {
                            [void][int]::TryParse($v, [ref]$contentLength)
                        } elseif ($k -eq "expect" -and $v.ToLowerInvariant().Contains("100-continue")) {
                            $expectContinue = $true
                        }
                    }
                }
            }

            $bodyStart = $headerEndIdx + 4
            $bodyStream = New-Object System.IO.MemoryStream
            $alreadyHave = $allBytes.Length - $bodyStart
            if ($alreadyHave -gt 0) {
                $take = if ($contentLength -gt 0) { [Math]::Min($alreadyHave, $contentLength) } else { $alreadyHave }
                $bodyStream.Write($allBytes, $bodyStart, $take)
            }

            if ($expectContinue -and $bodyStream.Length -lt $contentLength) {
                $contBytes = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 100 Continue`r`n`r`n")
                $Stream.Write($contBytes, 0, $contBytes.Length)
                $Stream.Flush()
            }

            $Stream.ReadTimeout = 30000
            while ($bodyStream.Length -lt $contentLength) {
                $remaining = $contentLength - [int]$bodyStream.Length
                $readLen = [Math]::Min($buf.Length, $remaining)
                $n = $Stream.Read($buf, 0, $readLen)
                if ($n -le 0) { break }
                $bodyStream.Write($buf, 0, $n)
            }

            $bodyText = [System.Text.Encoding]::UTF8.GetString($bodyStream.ToArray())
            $bodyStream.Dispose()

            return [ordered]@{
                method = $method
                path = $path
                body = $bodyText
            }
        } catch {
            return $null
        } finally {
            $ms.Dispose()
        }
    }

    function Send-WorkerHttpResponse {
        param(
            [Parameter(Mandatory=$true)][System.Net.Sockets.NetworkStream]$Stream,
            [int]$StatusCode = 200,
            [string]$ContentType = "application/json; charset=utf-8",
            [string]$Body = "",
            [byte[]]$BodyBytes = $null
        )
        $reason = switch ($StatusCode) {
            200 { "OK" }
            400 { "Bad Request" }
            404 { "Not Found" }
            default { "Internal Server Error" }
        }
        $outBytes = if ($null -ne $BodyBytes) { $BodyBytes } else { [System.Text.Encoding]::UTF8.GetBytes($Body) }
        $headers = "HTTP/1.1 $StatusCode $reason`r`n" +
                   "Content-Type: $ContentType`r`n" +
                   "Content-Length: $($outBytes.Length)`r`n" +
                   "Access-Control-Allow-Origin: *`r`n" +
                   "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
                   "Access-Control-Allow-Headers: Content-Type`r`n" +
                   "Cache-Control: no-store`r`n" +
                   "Connection: close`r`n`r`n"
        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
        $Stream.Write($headerBytes, 0, $headerBytes.Length)
        if ($outBytes.Length -gt 0) {
            $Stream.Write($outBytes, 0, $outBytes.Length)
        }
        $Stream.Flush()
    }

    try {
        $Client.ReceiveTimeout = 5000
        $Client.SendTimeout = 30000
        $stream = $Client.GetStream()
        $req = Read-WorkerHttpRequest -Stream $stream
        if ($null -ne $req) {
            $resp = Invoke-WebRoute -RootDir $RootDir -Port $Port -Method $req.method -Path $req.path -RawBody $req.body
            $rawBytes = if ($resp.Contains("body_bytes")) { [byte[]]$resp.body_bytes } else { $null }
            $bodyText = if ($resp.Contains("body")) { [string]$resp.body } else { "" }
            Send-WorkerHttpResponse -Stream $stream -StatusCode $resp.status -ContentType $resp.content_type -Body $bodyText -BodyBytes $rawBytes
        }
    } catch {
        # Client disconnected or socket reset; ignore cleanly so server stays alive
    } finally {
        try { $Client.Close() } catch {}
        try { $Client.Dispose() } catch {}
    }
}

$listeners = New-Object System.Collections.ArrayList
$activePort = $Port
$bound = $false

for ($candidatePort = $Port; $candidatePort -le ($Port + 10); $candidatePort++) {
    $v4 = $null
    $v6 = $null
    try {
        $v4 = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $candidatePort)
        $v4.Start()
        [void]$listeners.Add($v4)

        try {
            $v6 = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::IPv6Loopback, $candidatePort)
            $v6.Start()
            [void]$listeners.Add($v6)
        } catch {
            # IPv6 loopback optional if disabled on host
        }
        $activePort = $candidatePort
        $bound = $true
        break
    } catch {
        if ($v4) { try { $v4.Stop() } catch {} }
        if ($v6) { try { $v6.Stop() } catch {} }
        $listeners.Clear()
    }
}

if (-not $bound) {
    $msg = "Failed to bind localhost ports $Port..$($Port + 10)."
    Write-ServerLog $msg
    throw $msg
}

$pool = [runspacefactory]::CreateRunspacePool(1, 8)
$pool.Open()
$pendingTasks = New-Object System.Collections.ArrayList

$localhostUrl = "http://localhost:${activePort}/"
Write-ServerLog "Server started at $localhostUrl (127.0.0.1 & ::1)"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Dai Thanh Partner AI Agent Web Server is RUNNING" -ForegroundColor Green
Write-Host " URL : $localhostUrl  (also http://127.0.0.1:${activePort}/)" -ForegroundColor Yellow
Write-Host " Log : $ServerLogPath" -ForegroundColor Gray
Write-Host " Press Ctrl+C in this window to stop the server." -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan

if ($OpenBrowser) {
    try {
        Start-Process $localhostUrl | Out-Null
    } catch {
        $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
        if (Test-Path -LiteralPath $chromePath) {
            Start-Process $chromePath -ArgumentList $localhostUrl | Out-Null
        }
    }
}

try {
    while ($true) {
        $handledAny = $false
        foreach ($l in $listeners) {
            while ($l.Pending()) {
                $handledAny = $true
                $client = $l.AcceptTcpClient()
                $psWorker = [powershell]::Create()
                $psWorker.RunspacePool = $pool
                [void]$psWorker.AddScript($workerScript).AddArgument($RootDir).AddArgument($activePort).AddArgument($client)
                $handle = $psWorker.BeginInvoke()
                [void]$pendingTasks.Add([PSCustomObject]@{ ps = $psWorker; handle = $handle })
            }
        }

        # Reap completed worker tasks
        for ($i = $pendingTasks.Count - 1; $i -ge 0; $i--) {
            $t = $pendingTasks[$i]
            if ($t.handle.IsCompleted) {
                try { [void]$t.ps.EndInvoke($t.handle) } catch {}
                try { $t.ps.Dispose() } catch {}
                $pendingTasks.RemoveAt($i)
            }
        }

        if (-not $handledAny) {
            Start-Sleep -Milliseconds 15
        }
    }
} finally {
    Write-ServerLog "Server stopping..."
    foreach ($l in $listeners) {
        try { $l.Stop() } catch {}
    }
    foreach ($t in $pendingTasks) {
        try { $t.ps.Stop() } catch {}
        try { $t.ps.Dispose() } catch {}
    }
    try { $pool.Close(); $pool.Dispose() } catch {}
}
