[Net.ServicePointManager]::Expect100Continue = $false
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ServerScript = Join-Path $RootDir "src\WebServer.ps1"
$Port = 8065

function Invoke-HttpGetText {
    param([string]$Url)
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $null
    $wc.Encoding = [System.Text.Encoding]::UTF8
    try {
        return $wc.DownloadString($Url)
    } finally {
        $wc.Dispose()
    }
}

function Invoke-HttpPostJson {
    param([string]$Url, [string]$JsonBody)
    $wc = New-Object System.Net.WebClient
    $wc.Proxy = $null
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add("Content-Type", "application/json; charset=utf-8")
    try {
        return $wc.UploadString($Url, "POST", $JsonBody)
    } finally {
        $wc.Dispose()
    }
}

$rs = [runspacefactory]::CreateRunspace()
$rs.Open()
$ps = [powershell]::Create()
$ps.Runspace = $rs
[void]$ps.AddScript("param(`$scriptPath, `$port); Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; & `$scriptPath -Port `$port")
[void]$ps.AddArgument($ServerScript)
[void]$ps.AddArgument($Port)

$async = $ps.BeginInvoke()

try {
    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 300
        try {
            $hText = Invoke-HttpGetText -Url "http://localhost:$Port/api/health"
            $h = $hText | ConvertFrom-Json
            if ($h.status -eq "ok") { $ready = $true; break }
        } catch {
            # keep waiting
        }
    }
    if (-not $ready) {
        $errs = ($ps.Streams.Error | ForEach-Object { $_.ToString() }) -join " | "
        $reason = if ($ps.InvocationStateInfo.Reason) { $ps.InvocationStateInfo.Reason.ToString() } else { "none" }
        throw "WebServer failed to start on port $Port. State=$($ps.InvocationStateInfo.State) Reason=$reason Errors=$errs"
    }

    $htmlText = Invoke-HttpGetText -Url "http://localhost:$Port/"
    $cssText = Invoke-HttpGetText -Url "http://localhost:$Port/styles.css"
    $jsText = Invoke-HttpGetText -Url "http://localhost:$Port/app.js"
    $cfgResp = (Invoke-HttpGetText -Url "http://localhost:$Port/api/config") | ConvertFrom-Json
    $dsResp = (Invoke-HttpGetText -Url "http://localhost:$Port/api/datasets") | ConvertFrom-Json

    $runResp = (Invoke-HttpPostJson -Url "http://localhost:$Port/api/run" -JsonBody '{"dataset_name":"sample_exam_pack","mode":"local"}') | ConvertFrom-Json
    $tstResp = (Invoke-HttpPostJson -Url "http://localhost:$Port/api/run-tests" -JsonBody '{}') | ConvertFrom-Json

    $upObj = @{
        mode = "local"
        files = @{
            "applicants.json" = '[{"applicant_id":"UP01","partner_name":"Cty Test Upload","tax_id":"9999888877","region":"Mien Bac","province":"Ha Noi","district":"Long Bien","pos_address":"10 Nguyen Van Cu","showroom_area_m2":100,"warranty_technicians":2,"monthly_purchase_vnd_million":300,"requested_credit_days":30,"requested_credit_limit_vnd_million":300,"requested_marketing_support_pct":4}]'
            "existing_partners.csv" = "partner_id,partner_name,tax_id,representative,phone,email,region,status"
            "existing_pos.csv" = "pos_id,partner_id,partner_name,region,province,district,ward,address,latitude,longitude,protection_scope,protection_radius_km"
            "verification_results.csv" = "applicant_id,identity_verified,pos_verified,warranty_verified,financial_verified,verified_by,verification_date,verification_notes`nUP01,VERIFIED_PASS,VERIFIED_PASS,VERIFIED_PASS,VERIFIED_PASS,All,2026-11-11,OK"
        }
    }
    $upResp = (Invoke-HttpPostJson -Url "http://localhost:$Port/api/run-uploaded" -JsonBody ($upObj | ConvertTo-Json -Depth 6)) | ConvertFrom-Json

    # Clean up temporary upload test artifacts
    if ($upResp.data_dir -and (Test-Path -LiteralPath $upResp.data_dir)) {
        Remove-Item -LiteralPath $upResp.data_dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($upResp.output_files -and $upResp.output_files.output_dir -and (Test-Path -LiteralPath $upResp.output_files.output_dir)) {
        Remove-Item -LiteralPath $upResp.output_files.output_dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($upResp.output_files -and $upResp.output_files.audit_jsonl -and (Test-Path -LiteralPath $upResp.output_files.audit_jsonl)) {
        Remove-Item -LiteralPath $upResp.output_files.audit_jsonl -Force -ErrorAction SilentlyContinue
    }

    Write-Output ("HTML_LEN={0} CSS_LEN={1} JS_LEN={2} CONFIG_REGIONS={3} DATASETS={4} RUN_TOTAL={5} TESTS={6}/{7} UPLOAD_REC={8}" -f `
        $htmlText.Length, $cssText.Length, $jsText.Length, `
        @($cfgResp.rules.regions).Count, @($dsResp.datasets).Count, `
        $runResp.summary.total_applicants, $tstResp.passed, $tstResp.total, `
        $upResp.applicants[0].decision.recommendation_code)
} finally {
    $ps.Stop()
    $ps.Dispose()
    $rs.Close()
    $rs.Dispose()
}
