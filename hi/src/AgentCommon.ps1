Set-StrictMode -Version Latest

function Read-Utf8Text {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content,
        [bool]$WithBom = $false
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $enc = New-Object System.Text.UTF8Encoding($WithBom)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Read-JsonUtf8 {
    param([Parameter(Mandatory=$true)][string]$Path)
    $raw = Read-Utf8Text -Path $Path
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json)
}

function Read-CsvUtf8 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    if ($null -eq $lines -or $lines.Count -eq 0) { return @() }
    # Remove UTF-8 BOM if present on first line
    if ($lines[0].Length -gt 0 -and [int][char]$lines[0][0] -eq 0xFEFF) {
        $lines[0] = $lines[0].Substring(1)
    }
    $nonEmpty = @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($nonEmpty.Count -le 1) { return @() }
    return @($nonEmpty | ConvertFrom-Csv)
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Remove-VietnameseDiacritics {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    $replaced = $Text.Replace([char]0x0111, 'd').Replace([char]0x0110, 'D')
    $decomposed = $replaced.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $decomposed.ToCharArray()) {
        $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function Normalize-MatchText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $ascii = (Remove-VietnameseDiacritics -Text $Text).ToLowerInvariant()
    $ascii = [regex]::Replace($ascii, '[^a-z0-9\s]', ' ')
    $ascii = [regex]::Replace($ascii, '\s+', ' ').Trim()
    return $ascii
}

function Normalize-AdminUnit {
    param([string]$Text)
    $norm = Normalize-MatchText -Text $Text
    if ([string]::IsNullOrEmpty($norm)) { return "" }
    $prefixes = @('thanh pho ', 'tp ', 'tinh ', 'quan ', 'huyen ', 'thi xa ', 'tx ', 'phuong ', 'xa ', 'thi tran ', 'tt ')
    foreach ($p in $prefixes) {
        if ($norm.StartsWith($p)) {
            $norm = $norm.Substring($p.Length).Trim()
        }
    }
    return $norm
}

function Normalize-CompanyName {
    param([string]$Text)
    $norm = Normalize-MatchText -Text $Text
    if ([string]::IsNullOrEmpty($norm)) { return "" }
    $stopTokens = @('cong ty', 'tnhh', 'co phan', 'cp', 'cua hang', 'ho kinh doanh', 'hkd', 'trung tam', 'sieu thi', 'doanh nghiep', 'tm', 'dv')
    foreach ($tok in $stopTokens) {
        $norm = [regex]::Replace($norm, "\b$tok\b", ' ')
    }
    return ([regex]::Replace($norm, '\s+', ' ').Trim())
}

function Normalize-Phone {
    param([string]$Phone)
    if ([string]::IsNullOrWhiteSpace($Phone)) { return "" }
    $digits = [regex]::Replace($Phone, '[^0-9]', '')
    if ($digits.StartsWith('84') -and $digits.Length -ge 11) {
        $digits = '0' + $digits.Substring(2)
    }
    return $digits
}

function Get-LevenshteinSimilarity {
    param([string]$A, [string]$B)
    $s1 = Normalize-CompanyName -Text $A
    $s2 = Normalize-CompanyName -Text $B
    if ([string]::IsNullOrEmpty($s1) -or [string]::IsNullOrEmpty($s2)) { return 0.0 }
    if ($s1 -eq $s2) { return 1.0 }

    $n = $s1.Length
    $m = $s2.Length
    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }

    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $cost = if ($s1[$i - 1] -eq $s2[$j - 1]) { 0 } else { 1 }
            $del = $d[($i - 1), $j] + 1
            $ins = $d[$i, ($j - 1)] + 1
            $sub = $d[($i - 1), ($j - 1)] + $cost
            $minVal = [Math]::Min($del, [Math]::Min($ins, $sub))
            $d[$i, $j] = $minVal
        }
    }
    $maxLen = [Math]::Max($n, $m)
    return [Math]::Round(1.0 - ($d[$n, $m] / [double]$maxLen), 4)
}

function Get-HaversineDistanceKm {
    param(
        [double]$Lat1, [double]$Lon1,
        [double]$Lat2, [double]$Lon2
    )
    $r = 6371.0
    $dLat = ($Lat2 - $Lat1) * [Math]::PI / 180.0
    $dLon = ($Lon2 - $Lon1) * [Math]::PI / 180.0
    $a = [Math]::Sin($dLat / 2.0) * [Math]::Sin($dLat / 2.0) +
         [Math]::Cos($Lat1 * [Math]::PI / 180.0) * [Math]::Cos($Lat2 * [Math]::PI / 180.0) *
         [Math]::Sin($dLon / 2.0) * [Math]::Sin($dLon / 2.0)
    $c = 2.0 * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt(1.0 - $a))
    return [Math]::Round($r * $c, 3)
}

function Get-PropValue {
    param(
        $Obj,
        [string]$Name,
        $Default = $null
    )
    if ($null -eq $Obj) { return $Default }
    if ($Obj -is [System.Collections.IDictionary]) {
        if ($Obj.Contains($Name)) { return $Obj[$Name] }
        return $Default
    }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $Default
}

function Get-AliasedField {
    param(
        $Obj,
        [string[]]$Aliases,
        $Default = $null
    )
    if ($null -eq $Obj -or $null -eq $Aliases) { return $Default }
    foreach ($alias in $Aliases) {
        $val = Get-PropValue -Obj $Obj -Name $alias -Default $null
        if ($null -ne $val -and -not ($val -is [string] -and [string]::IsNullOrWhiteSpace($val))) {
            return $val
        }
    }
    return $Default
}

function Try-ParseDoubleInvariant {
    param($Value, [double]$Default = [double]::NaN)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [double] -or $Value -is [int] -or $Value -is [long] -or $Value -is [decimal]) {
        return [double]$Value
    }
    $s = ([string]$Value).Trim().Replace(',', '.')
    if ([string]::IsNullOrWhiteSpace($s)) { return $Default }
    $out = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$out)) {
        return $out
    }
    return $Default
}

function Add-AuditEvent {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.ArrayList]$LogList,
        [Parameter(Mandatory=$true)][string]$RunId,
        [Parameter(Mandatory=$true)][string]$EventType,
        [string]$SkillName = "",
        [string]$ToolName = "",
        [string]$ApplicantId = "",
        $ToolArgs = $null,
        $ToolResultSummary = $null,
        [string[]]$RuleIds = @(),
        [string[]]$EvidenceRefs = @(),
        [int]$DurationMs = 0
    )
    $entry = [ordered]@{
        seq = ($LogList.Count + 1)
        run_id = $RunId
        timestamp = [DateTimeOffset]::UtcNow.ToString("o")
        event_type = $EventType
        skill_name = $SkillName
        tool_name = $ToolName
        applicant_id = $ApplicantId
        tool_args = $ToolArgs
        rule_ids_applied = @($RuleIds)
        evidence_refs = @($EvidenceRefs)
        result_summary = $ToolResultSummary
        duration_ms = $DurationMs
    }
    [void]$LogList.Add($entry)
    return $entry
}

function Save-AuditLogJsonl {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()][System.Collections.ArrayList]$LogList,
        [Parameter(Mandatory=$true)][string]$Path
    )
    $lines = New-Object System.Collections.ArrayList
    foreach ($item in $LogList) {
        $jsonLine = ($item | ConvertTo-Json -Depth 8 -Compress)
        [void]$lines.Add($jsonLine)
    }
    Write-Utf8File -Path $Path -Content ($lines -join "`n") -WithBom $false
}
