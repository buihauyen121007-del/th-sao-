Set-StrictMode -Version Latest

function Get-SafeRelativePath {
    param([string]$RelativePath)
    $clean = $RelativePath.Replace('\', '/').TrimStart('/')
    if ($clean.Contains('..') -or [System.IO.Path]::IsPathRooted($clean)) {
        throw "Invalid relative path: $RelativePath"
    }
    return $clean
}

function Test-IsProtectedDataset {
    param([string]$DatasetName)
    $clean = ($DatasetName -replace '\\', '/').Trim().Trim('/')
    return ($clean -in @("sample_exam_pack", "tests/test_dataset", "test_dataset"))
}

function Assert-ValidSlug {
    param(
        [string]$Value,
        [string]$FieldName
    )
    $v = if ($null -eq $Value) { "" } else { $Value.Trim() }
    if ([string]::IsNullOrWhiteSpace($v) -or $v -notmatch '^[A-Za-z0-9_-]{1,50}$') {
        throw ("Invalid {0}: only letters, digits, '-' and '_' are allowed (1-50 chars)." -f $FieldName)
    }
    return $v
}

function Write-CsvUtf8NoBom {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [AllowEmptyCollection()][array]$Rows,
        [string]$HeaderLine = ""
    )
    $items = @($Rows | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) {
        Write-Utf8File -Path $Path -Content ($HeaderLine + "`r`n") -WithBom $false
        return
    }
    $csvLines = @($items | ConvertTo-Csv -NoTypeInformation)
    Write-Utf8File -Path $Path -Content (($csvLines -join "`r`n") + "`r`n") -WithBom $false
}

function ConvertTo-JsonArrayUtf8 {
    param([AllowEmptyCollection()][array]$Items)
    $arr = @($Items | Where-Object { $null -ne $_ })
    if ($arr.Count -eq 0) {
        return "[]"
    }
    if ($arr.Count -eq 1) {
        return ("[`r`n" + ($arr[0] | ConvertTo-Json -Depth 10) + "`r`n]")
    }
    return ($arr | ConvertTo-Json -Depth 10)
}

function Build-DefaultDossierText {
    param($Body)
    $uTitle = [Regex]::Unescape('H\u1ed2 S\u01a0 \u0110\u0102NG K\u00dd \u0110\u1ed0I T\u00c1C PH\u00c2N PH\u1ed0I - \u0110\u1ea0I TH\u00c0NH')
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add($uTitle)

    $pairs = @(
        @("M\u00e3 h\u1ed3 s\u01a1", "applicant_id", ""),
        @("T\u00ean \u0111\u1ed1i t\u00e1c", "partner_name", ""),
        @("M\u00e3 s\u1ed1 thu\u1ebf", "tax_id", ""),
        @("Ng\u01b0\u1eddi \u0111\u1ea1i di\u1ec7n", "representative", ""),
        @("\u0110i\u1ec7n tho\u1ea1i", "phone", ""),
        @("Email", "email", ""),
        @("Khu v\u1ef1c", "region", ""),
        @("T\u1ec9nh/Th\u00e0nh", "province", ""),
        @("Qu\u1eadn/Huy\u1ec7n", "district", ""),
        @("Ph\u01b0\u1eddng/X\u00e3", "ward", ""),
        @("\u0110\u1ecba ch\u1ec9 \u0111i\u1ec3m b\u00e1n", "pos_address", "")
    )
    foreach ($p in $pairs) {
        $val = [string](Get-PropValue -Obj $Body -Name $p[1] -Default "")
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            [void]$lines.Add(([Regex]::Unescape($p[0]) + ": " + $val.Trim()))
        }
    }

    $area = [string](Get-PropValue -Obj $Body -Name "showroom_area_m2" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($area)) {
        [void]$lines.Add(([Regex]::Unescape("Di\u1ec7n t\u00edch tr\u01b0ng b\u00e0y: ") + $area.Trim() + " m2"))
    }
    $tech = [string](Get-PropValue -Obj $Body -Name "warranty_technicians" -Default "")
    $wNotes = [string](Get-PropValue -Obj $Body -Name "warranty_notes" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($tech) -or -not [string]::IsNullOrWhiteSpace($wNotes)) {
        $wParts = New-Object System.Collections.ArrayList
        if (-not [string]::IsNullOrWhiteSpace($tech)) {
            [void]$wParts.Add(([Regex]::Unescape("C\u00f3 ") + $tech.Trim() + [Regex]::Unescape(" k\u1ef9 thu\u1eadt vi\u00ean")))
        }
        if (-not [string]::IsNullOrWhiteSpace($wNotes)) {
            [void]$wParts.Add($wNotes.Trim())
        }
        [void]$lines.Add(([Regex]::Unescape("N\u0103ng l\u1ef1c b\u1ea3o h\u00e0nh: ") + ($wParts -join "; ")))
    }
    $purch = [string](Get-PropValue -Obj $Body -Name "monthly_purchase_vnd_million" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($purch)) {
        [void]$lines.Add(([Regex]::Unescape("K\u1ebf ho\u1ea1ch nh\u1eadp h\u00e0ng: ") + $purch.Trim() + [Regex]::Unescape(" tri\u1ec7u \u0111\u1ed3ng/th\u00e1ng")))
    }
    $cDays = [string](Get-PropValue -Obj $Body -Name "requested_credit_days" -Default "")
    $cLim = [string](Get-PropValue -Obj $Body -Name "requested_credit_limit_vnd_million" -Default "")
    $mkt = [string](Get-PropValue -Obj $Body -Name "requested_marketing_support_pct" -Default "")
    $commParts = New-Object System.Collections.ArrayList
    if (-not [string]::IsNullOrWhiteSpace($cDays)) { [void]$commParts.Add(([Regex]::Unescape("C\u00f4ng n\u1ee3 ") + $cDays.Trim() + [Regex]::Unescape(" ng\u00e0y"))) }
    if (-not [string]::IsNullOrWhiteSpace($cLim)) { [void]$commParts.Add(([Regex]::Unescape("h\u1ea1n m\u1ee9c c\u00f4ng n\u1ee3 ") + $cLim.Trim() + [Regex]::Unescape(" tri\u1ec7u \u0111\u1ed3ng"))) }
    if (-not [string]::IsNullOrWhiteSpace($mkt)) { [void]$commParts.Add(([Regex]::Unescape("h\u1ed7 tr\u1ee3 th\u01b0\u01a1ng m\u1ea1i ") + $mkt.Trim() + "%")) }
    if ($commParts.Count -gt 0) {
        [void]$lines.Add(([Regex]::Unescape("Y\u00eau c\u1ea7u h\u1ed7 tr\u1ee3 th\u01b0\u01a1ng m\u1ea1i: ") + ($commParts -join ", ")))
    }
    $notes = [string](Get-PropValue -Obj $Body -Name "notes" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($notes)) {
        [void]$lines.Add(([Regex]::Unescape("Ghi ch\u00fa: ") + $notes.Trim()))
    }
    return ($lines -join "`r`n")
}

function Initialize-WritableDatasetDir {
    param(
        [Parameter(Mandatory=$true)][string]$RootDir,
        [Parameter(Mandatory=$true)][string]$TargetDir,
        [string]$BaseDataset = "sample_exam_pack",
        [bool]$IncludeSampleApplicants = $false
    )
    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    $dossiersDir = Join-Path $TargetDir "dossiers"
    if (-not (Test-Path -LiteralPath $dossiersDir)) {
        New-Item -ItemType Directory -Path $dossiersDir -Force | Out-Null
    }

    $dataRoot = Join-Path $RootDir "data"
    $baseDir = if ($BaseDataset -eq "tests/test_dataset") {
        Join-Path $RootDir "tests\test_dataset"
    } else {
        $safeBase = Assert-ValidSlug -Value $BaseDataset -FieldName "base_dataset"
        Join-Path $dataRoot $safeBase
    }
    if (-not (Test-Path -LiteralPath $baseDir)) {
        $baseDir = Join-Path $dataRoot "sample_exam_pack"
    }

    foreach ($refCsv in @("existing_partners.csv", "existing_pos.csv")) {
        $dst = Join-Path $TargetDir $refCsv
        $src = Join-Path $baseDir $refCsv
        if (-not (Test-Path -LiteralPath $dst) -and (Test-Path -LiteralPath $src)) {
            Copy-Item -LiteralPath $src -Destination $dst -Force
        }
    }

    $appJsonPath = Join-Path $TargetDir "applicants.json"
    $verCsvPath = Join-Path $TargetDir "verification_results.csv"
    if (-not (Test-Path -LiteralPath $appJsonPath)) {
        $srcApps = Join-Path $baseDir "applicants.json"
        if ($IncludeSampleApplicants -and (Test-Path -LiteralPath $srcApps)) {
            Copy-Item -LiteralPath $srcApps -Destination $appJsonPath -Force
            $srcDossiers = Join-Path $baseDir "dossiers"
            if (Test-Path -LiteralPath $srcDossiers) {
                Copy-Item -Path (Join-Path $srcDossiers "*.txt") -Destination $dossiersDir -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Utf8File -Path $appJsonPath -Content "[]" -WithBom $false
        }
    }
    if (-not (Test-Path -LiteralPath $verCsvPath)) {
        $srcVer = Join-Path $baseDir "verification_results.csv"
        if ($IncludeSampleApplicants -and (Test-Path -LiteralPath $srcVer)) {
            Copy-Item -LiteralPath $srcVer -Destination $verCsvPath -Force
        } else {
            Write-Utf8File -Path $verCsvPath -Content "applicant_id,identity_verified,pos_verified,warranty_verified,financial_verified,verified_by,verification_date,verification_notes`r`n" -WithBom $false
        }
    }
}

function Get-DatasetApplicantSummaries {
    param(
        [Parameter(Mandatory=$true)][string]$RootDir,
        [Parameter(Mandatory=$true)][string]$DatasetName
    )
    $dataDir = if ($DatasetName -eq "tests/test_dataset") {
        Join-Path $RootDir "tests\test_dataset"
    } else {
        $safe = Assert-ValidSlug -Value $DatasetName -FieldName "dataset_name"
        Join-Path (Join-Path $RootDir "data") $safe
    }

    $items = New-Object System.Collections.ArrayList
    $maxNum = 0
    if (Test-Path -LiteralPath $dataDir) {
        $appJsonPath = Join-Path $dataDir "applicants.json"
        $rows = @(if (Test-Path -LiteralPath $appJsonPath) { Read-JsonUtf8 -Path $appJsonPath })
        if (@($rows).Count -eq 0 -and (Test-Path -LiteralPath (Join-Path $dataDir "dossiers"))) {
            $rows = @(Get-ChildItem -LiteralPath (Join-Path $dataDir "dossiers") -Filter "*.txt" | Sort-Object Name | ForEach-Object {
                [PSCustomObject]@{
                    applicant_id = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    dossier_file = "dossiers/$($_.Name)"
                }
            })
        }
        foreach ($r in $rows) {
            if ($null -eq $r) { continue }
            $id = [string](Get-PropValue -Obj $r -Name "applicant_id" -Default "")
            if ([string]::IsNullOrWhiteSpace($id)) { continue }
            if ($id -match '^HS(\d+)$') {
                $n = [int]$Matches[1]
                if ($n -gt $maxNum) { $maxNum = $n }
            }
            $pName = [string](Get-PropValue -Obj $r -Name "partner_name" -Default "")
            $reg = [string](Get-PropValue -Obj $r -Name "region" -Default "")
            $sub = [string](Get-PropValue -Obj $r -Name "submitted_at" -Default "")
            $dFile = [string](Get-PropValue -Obj $r -Name "dossier_file" -Default "")
            if ([string]::IsNullOrWhiteSpace($dFile)) { $dFile = "dossiers/$id.txt" }
            $txtPath = Join-Path $dataDir ($dFile.Replace('/', '\'))
            if (-not (Test-Path -LiteralPath $txtPath)) {
                $altTxt = Join-Path (Join-Path $dataDir "dossiers") "$id.txt"
                if (Test-Path -LiteralPath $altTxt) { $txtPath = $altTxt }
            }
            if (([string]::IsNullOrWhiteSpace($pName) -or [string]::IsNullOrWhiteSpace($reg)) -and (Test-Path -LiteralPath $txtPath)) {
                $rawTxt = Read-Utf8Text -Path $txtPath
                if ([string]::IsNullOrWhiteSpace($pName) -and $rawTxt -match '(?im)^T[^:\r\n]*\u0111\u1ed1i t\u00e1c\s*:\s*(.+)$') {
                    $pName = $Matches[1].Trim()
                }
                if ([string]::IsNullOrWhiteSpace($reg) -and $rawTxt -match '(?im)^Khu v\u1ef1c\s*:\s*(.+)$') {
                    $reg = $Matches[1].Trim()
                }
            }
            $attFiles = @(Get-PropValue -Obj $r -Name "attachment_files" -Default @())
            if (@($attFiles).Count -eq 0) {
                $candAttDir = Join-Path (Join-Path $dataDir "attachments") $id
                if (Test-Path -LiteralPath $candAttDir) {
                    $attFiles = @(Get-ChildItem -LiteralPath $candAttDir | Select-Object -ExpandProperty Name)
                }
            }
            [void]$items.Add([ordered]@{
                applicant_id = $id
                partner_name = $pName
                region = $reg
                submitted_at = $sub
                dossier_file = $dFile
                attachment_files = @($attFiles)
            })
        }
    }
    $nextNum = $maxNum + 1
    $nextId = "HS{0:D3}" -f $nextNum
    return [ordered]@{
        dataset_name = $DatasetName
        exists = (Test-Path -LiteralPath $dataDir)
        is_protected = (Test-IsProtectedDataset -DatasetName $DatasetName)
        count = $items.Count
        next_id = $nextId
        items = $items.ToArray()
    }
}

function Invoke-WebRoute {
    param(
        [Parameter(Mandatory=$true)][string]$RootDir,
        [Parameter(Mandatory=$true)][int]$Port,
        [Parameter(Mandatory=$true)][string]$Method,
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$RawBody = ""
    )
    $WebDir = Join-Path $RootDir "web"
    $ConfigDir = Join-Path $RootDir "config"
    $DataRoot = Join-Path $RootDir "data"
    $OutputsRoot = Join-Path $RootDir "outputs"

    try {
        if ($Method -eq "OPTIONS") {
            return [ordered]@{ status = 200; content_type = "text/plain; charset=utf-8"; body = "" }
        }
        elseif ($Method -eq "GET" -and ($Path -eq "/" -or $Path -eq "/index.html")) {
            $html = Read-Utf8Text -Path (Join-Path $WebDir "index.html")
            return [ordered]@{ status = 200; content_type = "text/html; charset=utf-8"; body = $html }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/styles.css") {
            $css = Read-Utf8Text -Path (Join-Path $WebDir "styles.css")
            return [ordered]@{ status = 200; content_type = "text/css; charset=utf-8"; body = $css }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/app.js") {
            $js = Read-Utf8Text -Path (Join-Path $WebDir "app.js")
            return [ordered]@{ status = 200; content_type = "application/javascript; charset=utf-8"; body = $js }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/kawaii-bakery.jpg") {
            $imgPath = Join-Path $WebDir "kawaii-bakery.jpg"
            if (-not (Test-Path -LiteralPath $imgPath)) {
                return [ordered]@{ status = 404; content_type = "text/plain; charset=utf-8"; body = "Not found" }
            }
            $bytes = [System.IO.File]::ReadAllBytes($imgPath)
            return [ordered]@{ status = 200; content_type = "image/jpeg"; body = ""; body_bytes = $bytes }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/favicon.ico") {
            $svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ff7ab0"/><stop offset="100%" stop-color="#ffc1da"/></linearGradient></defs><rect width="32" height="32" rx="8" fill="url(#g)" stroke="#6e3a54" stroke-width="2"/><text x="16" y="21" font-size="13" font-family="Arial" font-weight="bold" fill="#fff" text-anchor="middle">DT</text></svg>'
            return [ordered]@{ status = 200; content_type = "image/svg+xml; charset=utf-8"; body = $svg }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/api/health") {
            $payload = [ordered]@{
                status = "ok"
                host = "localhost"
                port = $Port
                url = "http://localhost:$Port/"
                server_time = [DateTimeOffset]::UtcNow.ToString("o")
            }
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = ($payload | ConvertTo-Json -Depth 5) }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/api/config") {
            $rules = Read-JsonUtf8 -Path (Join-Path $ConfigDir "rules_config.json")
            $schema = Read-JsonUtf8 -Path (Join-Path $ConfigDir "schema_mapping.json")
            $payload = [ordered]@{ rules = $rules; schema = $schema }
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = ($payload | ConvertTo-Json -Depth 12) }
        }
        elseif ($Method -eq "POST" -and $Path -eq "/api/config") {
            $parsed = $RawBody | ConvertFrom-Json
            if ($null -ne (Get-PropValue -Obj $parsed -Name "rules" -Default $null)) {
                $rulesJson = $parsed.rules | ConvertTo-Json -Depth 12
                Write-Utf8File -Path (Join-Path $ConfigDir "rules_config.json") -Content $rulesJson -WithBom $false
            }
            if ($null -ne (Get-PropValue -Obj $parsed -Name "schema" -Default $null)) {
                $schemaJson = $parsed.schema | ConvertTo-Json -Depth 12
                Write-Utf8File -Path (Join-Path $ConfigDir "schema_mapping.json") -Content $schemaJson -WithBom $false
            }
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = (@{ saved = $true } | ConvertTo-Json) }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/api/datasets") {
            $datasets = New-Object System.Collections.ArrayList
            if (Test-Path -LiteralPath $DataRoot) {
                foreach ($d in (Get-ChildItem -LiteralPath $DataRoot -Directory | Sort-Object Name)) {
                    [void]$datasets.Add([ordered]@{ name = $d.Name; path = $d.FullName; source = "data" })
                }
            }
            $testDs = Join-Path $RootDir "tests\test_dataset"
            if (Test-Path -LiteralPath $testDs) {
                [void]$datasets.Add([ordered]@{ name = "tests/test_dataset"; path = $testDs; source = "tests" })
            }
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = (@{ datasets = @($datasets) } | ConvertTo-Json -Depth 5) }
        }
        elseif ($Method -eq "GET" -and $Path -eq "/api/runs") {
            $runs = New-Object System.Collections.ArrayList
            if (Test-Path -LiteralPath $OutputsRoot) {
                foreach ($d in (Get-ChildItem -LiteralPath $OutputsRoot -Directory | Sort-Object Name -Descending | Select-Object -First 20)) {
                    $jPath = Join-Path $d.FullName "ket_qua_danh_gia.json"
                    if (Test-Path -LiteralPath $jPath) {
                        [void]$runs.Add([ordered]@{ run_id = $d.Name; created = $d.CreationTime.ToString("o") })
                    }
                }
            }
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = (@{ runs = @($runs) } | ConvertTo-Json -Depth 5) }
        }
        elseif ($Method -eq "GET" -and $Path.StartsWith("/api/runs/")) {
            $rid = [System.Uri]::UnescapeDataString($Path.Substring("/api/runs/".Length).Trim('/'))
            $safeRid = Get-SafeRelativePath -RelativePath $rid
            $jPath = Join-Path (Join-Path $OutputsRoot $safeRid) "ket_qua_danh_gia.json"
            if (-not (Test-Path -LiteralPath $jPath)) {
                return [ordered]@{ status = 404; content_type = "application/json; charset=utf-8"; body = (@{ error = "Run not found" } | ConvertTo-Json) }
            }
            $jsonText = Read-Utf8Text -Path $jPath
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = $jsonText }
        }
        elseif ($Method -eq "POST" -and $Path -eq "/api/run") {
            $body = if ([string]::IsNullOrWhiteSpace($RawBody)) { [PSCustomObject]@{} } else { $RawBody | ConvertFrom-Json }
            $dsName = [string](Get-PropValue -Obj $body -Name "dataset_name" -Default "sample_exam_pack")
            $dataDir = if ($dsName -eq "tests/test_dataset") {
                Join-Path $RootDir "tests\test_dataset"
            } else {
                $safeDs = Get-SafeRelativePath -RelativePath $dsName
                Join-Path $DataRoot $safeDs
            }
            if (-not (Test-Path -LiteralPath $dataDir)) {
                return [ordered]@{ status = 400; content_type = "application/json; charset=utf-8"; body = (@{ error = "Dataset directory not found: $dsName" } | ConvertTo-Json) }
            }
            $mode = [string](Get-PropValue -Obj $body -Name "mode" -Default "auto")
            $provider = [string](Get-PropValue -Obj $body -Name "llm_provider" -Default "gemini")
            $apiKey = [string](Get-PropValue -Obj $body -Name "api_key" -Default "")
            $modelName = [string](Get-PropValue -Obj $body -Name "model_name" -Default "")
            $saveOutputsVal = Get-PropValue -Obj $body -Name "save_outputs" -Default $true
            $saveOutputs = [bool]$saveOutputsVal

            $result = Invoke-PartnerEvaluationAgent -RootDir $RootDir -DataDir $dataDir `
                -Mode $mode -LlmProvider $provider -ApiKey $apiKey -ModelName $modelName -SaveOutputs $saveOutputs
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = ($result | ConvertTo-Json -Depth 15) }
        }
        elseif ($Method -eq "POST" -and $Path -eq "/api/run-uploaded") {
            $body = $RawBody | ConvertFrom-Json
            $uploadId = "uploaded_" + [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
            $uploadDir = Join-Path $DataRoot $uploadId
            New-Item -ItemType Directory -Path $uploadDir -Force | Out-Null

            $filesObj = $body.files
            foreach ($prop in $filesObj.PSObject.Properties) {
                $rel = Get-SafeRelativePath -RelativePath $prop.Name
                $targetPath = Join-Path $uploadDir ($rel.Replace('/', '\'))
                Write-Utf8File -Path $targetPath -Content ([string]$prop.Value) -WithBom $false
            }

            $customRulesPath = ""
            if ($null -ne (Get-PropValue -Obj $body -Name "rules_override" -Default $null)) {
                $customRulesPath = Join-Path $uploadDir "_rules_override.json"
                Write-Utf8File -Path $customRulesPath -Content ($body.rules_override | ConvertTo-Json -Depth 12) -WithBom $false
            }
            $customSchemaPath = ""
            if ($null -ne (Get-PropValue -Obj $body -Name "schema_override" -Default $null)) {
                $customSchemaPath = Join-Path $uploadDir "_schema_override.json"
                Write-Utf8File -Path $customSchemaPath -Content ($body.schema_override | ConvertTo-Json -Depth 12) -WithBom $false
            }

            $mode = [string](Get-PropValue -Obj $body -Name "mode" -Default "auto")
            $provider = [string](Get-PropValue -Obj $body -Name "llm_provider" -Default "gemini")
            $apiKey = [string](Get-PropValue -Obj $body -Name "api_key" -Default "")
            $modelName = [string](Get-PropValue -Obj $body -Name "model_name" -Default "")
            $saveOutputsVal = Get-PropValue -Obj $body -Name "save_outputs" -Default $true
            $saveOutputs = [bool]$saveOutputsVal

            $result = Invoke-PartnerEvaluationAgent -RootDir $RootDir -DataDir $uploadDir -RulesPath $customRulesPath -SchemaPath $customSchemaPath `
                -Mode $mode -LlmProvider $provider -ApiKey $apiKey -ModelName $modelName -SaveOutputs $saveOutputs
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = ($result | ConvertTo-Json -Depth 15) }
        }
        elseif ($Method -eq "GET" -and $Path.StartsWith("/api/dossiers/")) {
            $dsRaw = [System.Uri]::UnescapeDataString($Path.Substring("/api/dossiers/".Length).Trim('/'))
            if ([string]::IsNullOrWhiteSpace($dsRaw)) { $dsRaw = "custom_dossiers" }
            $summary = Get-DatasetApplicantSummaries -RootDir $RootDir -DatasetName $dsRaw
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = ($summary | ConvertTo-Json -Depth 8) }
        }
        elseif ($Method -eq "GET" -and $Path.StartsWith("/api/attachments/")) {
            $attRel = [System.Uri]::UnescapeDataString($Path.Substring("/api/attachments/".Length).Trim('/'))
            $parts = $attRel.Split('/')
            if ($parts.Length -ge 3) {
                $safeDs = Assert-ValidSlug -Value $parts[0] -FieldName "dataset"
                $safeApp = Assert-ValidSlug -Value $parts[1] -FieldName "applicant"
                $safeFile = [System.IO.Path]::GetFileName($parts[2])
                $filePath = Join-Path (Join-Path (Join-Path $DataRoot $safeDs) "attachments") (Join-Path $safeApp $safeFile)
                if (Test-Path -LiteralPath $filePath) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                    $cType = switch ($ext) {
                        ".pdf"  { "application/pdf" }
                        ".png"  { "image/png" }
                        ".jpg"  { "image/jpeg" }
                        ".jpeg" { "image/jpeg" }
                        ".webp" { "image/webp" }
                        ".txt"  { "text/plain; charset=utf-8" }
                        ".json" { "application/json; charset=utf-8" }
                        ".csv"  { "text/csv; charset=utf-8" }
                        default { "application/octet-stream" }
                    }
                    return [ordered]@{ status = 200; content_type = $cType; body = ""; body_bytes = $bytes }
                }
            }
            return [ordered]@{ status = 404; content_type = "application/json; charset=utf-8"; body = (@{ error = "Attachment not found" } | ConvertTo-Json) }
        }
        elseif ($Method -eq "POST" -and $Path -eq "/api/dossiers/create") {
            $body = if ([string]::IsNullOrWhiteSpace($RawBody)) { [PSCustomObject]@{} } else { $RawBody | ConvertFrom-Json }
            $dsRaw = [string](Get-PropValue -Obj $body -Name "dataset_name" -Default "custom_dossiers")
            if ([string]::IsNullOrWhiteSpace($dsRaw)) { $dsRaw = "custom_dossiers" }
            if (Test-IsProtectedDataset -DatasetName $dsRaw) {
                $msg = [Regex]::Unescape('Kh\u00f4ng \u0111\u01b0\u1ee3c s\u1eeda tr\u1ef1c ti\u1ebfp b\u1ed9 d\u1eef li\u1ec7u chu\u1ea9n (sample_exam_pack / test_dataset). H\u00e3y l\u01b0u v\u00e0o custom_dossiers ho\u1eb7c b\u1ed9 d\u1eef li\u1ec7u ri\u00eang.')
                return [ordered]@{ status = 400; content_type = "application/json; charset=utf-8"; body = (@{ error = $msg } | ConvertTo-Json) }
            }
            $datasetName = Assert-ValidSlug -Value $dsRaw -FieldName "dataset_name"
            $baseDataset = [string](Get-PropValue -Obj $body -Name "base_dataset" -Default "sample_exam_pack")
            $includeSample = [bool](Get-PropValue -Obj $body -Name "include_sample_applicants" -Default $false)
            $overwrite = [bool](Get-PropValue -Obj $body -Name "overwrite" -Default $false)

            $targetDir = Join-Path $DataRoot $datasetName
            Initialize-WritableDatasetDir -RootDir $RootDir -TargetDir $targetDir -BaseDataset $baseDataset -IncludeSampleApplicants $includeSample

            $appIdRaw = [string](Get-PropValue -Obj $body -Name "applicant_id" -Default "")
            if ([string]::IsNullOrWhiteSpace($appIdRaw)) {
                $curSum = Get-DatasetApplicantSummaries -RootDir $RootDir -DatasetName $datasetName
                $appIdRaw = [string]$curSum.next_id
            }
            $appId = Assert-ValidSlug -Value $appIdRaw -FieldName "applicant_id"

            $appJsonPath = Join-Path $targetDir "applicants.json"
            $existingApps = @(Read-JsonUtf8 -Path $appJsonPath | Where-Object { $null -ne $_ })
            $dup = $false
            foreach ($ex in $existingApps) {
                $exId = [string](Get-PropValue -Obj $ex -Name "applicant_id" -Default "")
                if ($exId -eq $appId) { $dup = $true; break }
            }
            if ($dup -and (-not $overwrite)) {
                $dupMsg = ([Regex]::Unescape('M\u00e3 h\u1ed3 s\u01a1 ') + $appId + [Regex]::Unescape(' \u0111\u00e3 t\u1ed3n t\u1ea1i trong ') + $datasetName + [Regex]::Unescape('. H\u00e3y ch\u1ecdn m\u00e3 kh\u00e1c ho\u1eb7c b\u1eadt c\u1eadp nh\u1eadt.'))
                return [ordered]@{ status = 400; content_type = "application/json; charset=utf-8"; body = (@{ error = $dupMsg } | ConvertTo-Json) }
            }

            $rawTextIn = [string](Get-PropValue -Obj $body -Name "raw_text" -Default "")
            $dossierText = if (-not [string]::IsNullOrWhiteSpace($rawTextIn)) { $rawTextIn.Trim() } else { Build-DefaultDossierText -Body $body }
            $dossierRel = "dossiers/$appId.txt"
            Write-Utf8File -Path (Join-Path (Join-Path $targetDir "dossiers") "$appId.txt") -Content ($dossierText + "`r`n") -WithBom $false

            $submittedAt = [string](Get-PropValue -Obj $body -Name "submitted_at" -Default "")
            if ([string]::IsNullOrWhiteSpace($submittedAt)) { $submittedAt = [DateTime]::Now.ToString("yyyy-MM-dd") }

            $newRec = [ordered]@{
                applicant_id = $appId
                submitted_at = $submittedAt.Trim()
                dossier_file = $dossierRel
            }
            foreach ($sf in @("partner_name", "tax_id", "representative", "phone", "email", "region", "province", "district", "ward", "pos_address", "warranty_notes")) {
                $sv = [string](Get-PropValue -Obj $body -Name $sf -Default "")
                if (-not [string]::IsNullOrWhiteSpace($sv)) {
                    $newRec[$sf] = $sv.Trim()
                }
            }
            foreach ($nf in @("latitude", "longitude", "showroom_area_m2", "warranty_technicians", "monthly_purchase_vnd_million", "requested_credit_days", "requested_credit_limit_vnd_million", "requested_marketing_support_pct")) {
                $nv = Get-PropValue -Obj $body -Name $nf -Default $null
                $parsedNum = Try-ParseDoubleInvariant -Value $nv
                if (-not [double]::IsNaN($parsedNum)) {
                    $newRec[$nf] = $parsedNum
                }
            }

            $attachments = @(Get-PropValue -Obj $body -Name "attachments" -Default @())
            $savedAttachments = New-Object System.Collections.ArrayList
            if (@($attachments).Count -gt 0) {
                $attDir = Join-Path (Join-Path $targetDir "attachments") $appId
                if (-not (Test-Path -LiteralPath $attDir)) {
                    New-Item -ItemType Directory -Path $attDir -Force | Out-Null
                }
                foreach ($att in $attachments) {
                    if ($null -eq $att) { continue }
                    $rawName = [string](Get-PropValue -Obj $att -Name "name" -Default "")
                    $safeName = [System.IO.Path]::GetFileName($rawName)
                    if ([string]::IsNullOrWhiteSpace($safeName)) { continue }
                    $b64 = [string](Get-PropValue -Obj $att -Name "content_base64" -Default "")
                    if (-not [string]::IsNullOrWhiteSpace($b64)) {
                        $filePath = Join-Path $attDir $safeName
                        try {
                            $bytes = [System.Convert]::FromBase64String($b64)
                            [System.IO.File]::WriteAllBytes($filePath, $bytes)
                            [void]$savedAttachments.Add($safeName)
                        } catch {}
                    }
                }
            }
            if ($savedAttachments.Count -gt 0) {
                $newRec["attachment_files"] = $savedAttachments.ToArray()
            }

            $nextApps = New-Object System.Collections.ArrayList
            foreach ($ex in $existingApps) {
                $exId = [string](Get-PropValue -Obj $ex -Name "applicant_id" -Default "")
                if ($exId -ne $appId) { [void]$nextApps.Add($ex) }
            }
            [void]$nextApps.Add([PSCustomObject]$newRec)
            Write-Utf8File -Path $appJsonPath -Content (ConvertTo-JsonArrayUtf8 -Items @($nextApps)) -WithBom $false

            $verCsvPath = Join-Path $targetDir "verification_results.csv"
            $verRows = @(Read-CsvUtf8 -Path $verCsvPath | Where-Object { $null -ne $_ })
            $nextVerRows = New-Object System.Collections.ArrayList
            foreach ($vr in $verRows) {
                $vid = [string](Get-PropValue -Obj $vr -Name "applicant_id" -Default "")
                if ([string]::IsNullOrWhiteSpace($vid) -or $vid -eq $appId) { continue }
                [void]$nextVerRows.Add([PSCustomObject]@{
                    applicant_id = $vid
                    identity_verified = [string](Get-PropValue -Obj $vr -Name "identity_verified" -Default "")
                    pos_verified = [string](Get-PropValue -Obj $vr -Name "pos_verified" -Default "")
                    warranty_verified = [string](Get-PropValue -Obj $vr -Name "warranty_verified" -Default "")
                    financial_verified = [string](Get-PropValue -Obj $vr -Name "financial_verified" -Default "")
                    verified_by = [string](Get-PropValue -Obj $vr -Name "verified_by" -Default "")
                    verification_date = [string](Get-PropValue -Obj $vr -Name "verification_date" -Default "")
                    verification_notes = [string](Get-PropValue -Obj $vr -Name "verification_notes" -Default "")
                })
            }
            $includeVer = [bool](Get-PropValue -Obj $body -Name "include_verification" -Default $false)
            $verObj = Get-PropValue -Obj $body -Name "verification" -Default $null
            if ($includeVer -and $null -ne $verObj) {
                [void]$nextVerRows.Add([PSCustomObject]@{
                    applicant_id = $appId
                    identity_verified = [string](Get-PropValue -Obj $verObj -Name "identity_verified" -Default "NOT_SUBMITTED")
                    pos_verified = [string](Get-PropValue -Obj $verObj -Name "pos_verified" -Default "NOT_SUBMITTED")
                    warranty_verified = [string](Get-PropValue -Obj $verObj -Name "warranty_verified" -Default "NOT_SUBMITTED")
                    financial_verified = [string](Get-PropValue -Obj $verObj -Name "financial_verified" -Default "NOT_SUBMITTED")
                    verified_by = [string](Get-PropValue -Obj $verObj -Name "verified_by" -Default "")
                    verification_date = [string](Get-PropValue -Obj $verObj -Name "verification_date" -Default $submittedAt)
                    verification_notes = [string](Get-PropValue -Obj $verObj -Name "verification_notes" -Default "")
                })
            }
            Write-CsvUtf8NoBom -Path $verCsvPath -Rows @($nextVerRows) -HeaderLine "applicant_id,identity_verified,pos_verified,warranty_verified,financial_verified,verified_by,verification_date,verification_notes"

            $afterSummary = Get-DatasetApplicantSummaries -RootDir $RootDir -DatasetName $datasetName
            $respPayload = [ordered]@{
                saved = $true
                dataset_name = $datasetName
                applicant_id = $appId
                dossier_file = $dossierRel
                dossier_text = $dossierText
                summary = $afterSummary
            }
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = ($respPayload | ConvertTo-Json -Depth 10) }
        }
        elseif ($Method -eq "POST" -and $Path -eq "/api/dossiers/delete") {
            $body = if ([string]::IsNullOrWhiteSpace($RawBody)) { [PSCustomObject]@{} } else { $RawBody | ConvertFrom-Json }
            $dsRaw = [string](Get-PropValue -Obj $body -Name "dataset_name" -Default "")
            if (Test-IsProtectedDataset -DatasetName $dsRaw) {
                $msg = [Regex]::Unescape('Kh\u00f4ng \u0111\u01b0\u1ee3c x\u00f3a h\u1ed3 s\u01a1 trong b\u1ed9 d\u1eef li\u1ec7u chu\u1ea9n.')
                return [ordered]@{ status = 400; content_type = "application/json; charset=utf-8"; body = (@{ error = $msg } | ConvertTo-Json) }
            }
            $datasetName = Assert-ValidSlug -Value $dsRaw -FieldName "dataset_name"
            $appId = Assert-ValidSlug -Value ([string](Get-PropValue -Obj $body -Name "applicant_id" -Default "")) -FieldName "applicant_id"
            $targetDir = Join-Path $DataRoot $datasetName
            if (-not (Test-Path -LiteralPath $targetDir)) {
                return [ordered]@{ status = 404; content_type = "application/json; charset=utf-8"; body = (@{ error = "Dataset not found" } | ConvertTo-Json) }
            }

            $appJsonPath = Join-Path $targetDir "applicants.json"
            if (Test-Path -LiteralPath $appJsonPath) {
                $existingApps = @(Read-JsonUtf8 -Path $appJsonPath | Where-Object { $null -ne $_ -and ([string](Get-PropValue -Obj $_ -Name "applicant_id" -Default "")) -ne $appId })
                Write-Utf8File -Path $appJsonPath -Content (ConvertTo-JsonArrayUtf8 -Items $existingApps) -WithBom $false
            }
            $txtFile = Join-Path (Join-Path $targetDir "dossiers") "$appId.txt"
            if (Test-Path -LiteralPath $txtFile) { Remove-Item -LiteralPath $txtFile -Force }
            $attFolder = Join-Path (Join-Path $targetDir "attachments") $appId
            if (Test-Path -LiteralPath $attFolder) { Remove-Item -LiteralPath $attFolder -Recurse -Force -ErrorAction SilentlyContinue }

            $verCsvPath = Join-Path $targetDir "verification_results.csv"
            if (Test-Path -LiteralPath $verCsvPath) {
                $verRows = @(Read-CsvUtf8 -Path $verCsvPath | Where-Object { $null -ne $_ -and ([string](Get-PropValue -Obj $_ -Name "applicant_id" -Default "")) -ne $appId })
                $keepRows = @($verRows | ForEach-Object {
                    [PSCustomObject]@{
                        applicant_id = [string](Get-PropValue -Obj $_ -Name "applicant_id" -Default "")
                        identity_verified = [string](Get-PropValue -Obj $_ -Name "identity_verified" -Default "")
                        pos_verified = [string](Get-PropValue -Obj $_ -Name "pos_verified" -Default "")
                        warranty_verified = [string](Get-PropValue -Obj $_ -Name "warranty_verified" -Default "")
                        financial_verified = [string](Get-PropValue -Obj $_ -Name "financial_verified" -Default "")
                        verified_by = [string](Get-PropValue -Obj $_ -Name "verified_by" -Default "")
                        verification_date = [string](Get-PropValue -Obj $_ -Name "verification_date" -Default "")
                        verification_notes = [string](Get-PropValue -Obj $_ -Name "verification_notes" -Default "")
                    }
                })
                Write-CsvUtf8NoBom -Path $verCsvPath -Rows $keepRows -HeaderLine "applicant_id,identity_verified,pos_verified,warranty_verified,financial_verified,verified_by,verification_date,verification_notes"
            }

            $afterSummary = Get-DatasetApplicantSummaries -RootDir $RootDir -DatasetName $datasetName
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = (@{ deleted = $true; summary = $afterSummary } | ConvertTo-Json -Depth 10) }
        }
        elseif ($Method -eq "POST" -and $Path -eq "/api/run-tests") {
            $testScript = Join-Path $RootDir "tests\run_tests.ps1"
            if (-not (Test-Path -LiteralPath $testScript)) {
                return [ordered]@{ status = 404; content_type = "application/json; charset=utf-8"; body = (@{ error = "Test script not found" } | ConvertTo-Json) }
            }
            $testOutJson = & $testScript -ReturnJson
            return [ordered]@{ status = 200; content_type = "application/json; charset=utf-8"; body = $testOutJson }
        }
        else {
            return [ordered]@{ status = 404; content_type = "application/json; charset=utf-8"; body = (@{ error = "Endpoint not found: $Method $Path" } | ConvertTo-Json) }
        }
    } catch {
        $errPayload = [ordered]@{ error = $_.Exception.Message; path = $Path }
        return [ordered]@{ status = 500; content_type = "application/json; charset=utf-8"; body = ($errPayload | ConvertTo-Json -Depth 4) }
    }
}

