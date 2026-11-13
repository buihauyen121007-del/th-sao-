param(
    [switch]$ReturnJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$TestDataDir = Join-Path $RootDir "tests\test_dataset"
$SampleDataDir = Join-Path $RootDir "data\sample_exam_pack"

. (Join-Path $RootDir "src\AgentCommon.ps1")
. (Join-Path $RootDir "src\AgentTools.ps1")
. (Join-Path $RootDir "src\AgentLLM.ps1")
. (Join-Path $RootDir "src\AgentOrchestrator.ps1")

$cases = New-Object System.Collections.ArrayList

function Add-TestAssertion {
    param(
        [string]$Category,
        [string]$TestId,
        [string]$Description,
        [bool]$Condition,
        [string]$Detail
    )
    [void]$cases.Add([ordered]@{
        category = $Category
        test_id = $TestId
        description = $Description
        passed = $Condition
        detail = $Detail
    })
}

# Run Agent on test_dataset
$testRun = Invoke-PartnerEvaluationAgent -RootDir $RootDir -DataDir $TestDataDir -Mode "local" -RunId "test_suite_run" -SaveOutputs $false
$byId = @{}
foreach ($a in $testRun.applicants) {
    $byId[$a.profile.applicant_id] = $a
}

# 1. Normal cases
$t1 = $byId["T_NORM_CONTINUE"]
Add-TestAssertion -Category "Normal" -TestId "T_NORM_CONTINUE" `
    -Description "Verified compliant partner scores >= 85 and gets CONTINUE P1 with 0 escalations" `
    -Condition ($t1.decision.recommendation_code -eq "CONTINUE" -and $t1.decision.priority_code -eq "P1" -and (-not $t1.decision.requires_human_escalation) -and $t1.scoring.verified_score -ge 85) `
    -Detail ("rec={0}, prio={1}, vScore={2}, esc={3}" -f $t1.decision.recommendation_code, $t1.decision.priority_code, $t1.scoring.verified_score, $t1.decision.requires_human_escalation)

$t2 = $byId["T_NORM_REJECT"]
Add-TestAssertion -Category "Normal" -TestId "T_NORM_REJECT" `
    -Description "Weak partner failing POS & warranty verification gets NOT_CONTINUE (REJECT)" `
    -Condition ($t2.decision.recommendation_code -eq "NOT_CONTINUE" -and $t2.decision.priority_code -eq "REJECT") `
    -Detail ("rec={0}, prio={1}, vScore={2}" -f $t2.decision.recommendation_code, $t2.decision.priority_code, $t2.scoring.verified_score)

# 2. Missing data & unverified high commitment
$t3 = $byId["T_MISS_UNVERIFIED_COMMIT"]
Add-TestAssertion -Category "Missing Data" -TestId "T_MISS_UNVERIFIED_COMMIT" `
    -Description "1.2B VND/mo commitment without verification must trigger warning, cap score, and NEVER auto-CONTINUE" `
    -Condition ($t3.profile.monthly_purchase_vnd_million -eq 1200 -and $t3.gates.unverified_high_commitment_warning -and $t3.decision.recommendation_code -eq "SUPPLEMENT" -and ($t3.scoring.verified_score -lt $t3.scoring.claimed_score) -and ($t3.decision.escalation_codes -contains "MISSING_EVIDENCE")) `
    -Detail ("purchase={0}M, warn={1}, rec={2}, verified={3} < claimed={4}" -f $t3.profile.monthly_purchase_vnd_million, $t3.gates.unverified_high_commitment_warning, $t3.decision.recommendation_code, $t3.scoring.verified_score, $t3.scoring.claimed_score)

$t4 = $byId["T_MISS_FIELDS"]
Add-TestAssertion -Category "Missing Data" -TestId "T_MISS_FIELDS" `
    -Description "Missing tax_id, area, technicians, GPS, and verification row must be reported explicitly and routed to SUPPLEMENT" `
    -Condition ($t4.decision.recommendation_code -eq "SUPPLEMENT" -and (-not $t4.profile.verification.record_found) -and (@($t4.profile.missing_fields).Count -ge 4) -and ($t4.decision.escalation_codes -contains "MISSING_EVIDENCE")) `
    -Detail ("missing_count={0}, ver_found={1}, rec={2}" -f @($t4.profile.missing_fields).Count, $t4.profile.verification.record_found, $t4.decision.recommendation_code)

# 3. Rule boundary cases
$t5 = $byId["T_BND_CREDIT_EXACT_PASS"]
Add-TestAssertion -Category "Rule Boundary" -TestId "T_BND_CREDIT_EXACT_PASS" `
    -Description "Exact ceiling (30 days, 500M limit, 5.0% support, 40m2, 1 tech, 150M purchase) passes policy and reaches CONTINUE P2" `
    -Condition ($t5.gates.policy_compliant -and $t5.gates.mandatory_passed -and $t5.decision.recommendation_code -eq "CONTINUE" -and $t5.decision.priority_code -eq "P2") `
    -Detail ("policy_ok={0}, mandatory_ok={1}, vScore={2}, rec={3}" -f $t5.gates.policy_compliant, $t5.gates.mandatory_passed, $t5.scoring.verified_score, $t5.decision.recommendation_code)

$t6 = $byId["T_BND_CREDIT_OVER_1"]
Add-TestAssertion -Category "Rule Boundary" -TestId "T_BND_CREDIT_OVER_1" `
    -Description "Exceeding policy by +1 unit (31 days, 501M, 5.1%) triggers POLICY_EXCEEDED and escalates to Finance/BD Head" `
    -Condition ((-not $t6.gates.policy_compliant) -and ($t6.decision.escalation_codes -contains "POLICY_EXCEEDED") -and $t6.decision.recommendation_code -eq "SUPPLEMENT" -and $t6.decision.priority_code -eq "HOLD") `
    -Detail ("violations={0}, esc={1}, rec={2}" -f @($t6.gates.policy_violations).Count, ($t6.decision.escalation_codes -join ","), $t6.decision.recommendation_code)

$t7 = $byId["T_BND_RADIUS_EXACT_CONFLICT"]
Add-TestAssertion -Category "Rule Boundary" -TestId "T_BND_RADIUS_EXACT_CONFLICT" `
    -Description "POS at ~4.99 km (<= 5.0 km protection radius) triggers TERRITORY_CONFLICT even in different district" `
    -Condition ($t7.identity_territory.territory_status -eq "CONFLICT" -and ($t7.decision.escalation_codes -contains "TERRITORY_CONFLICT") -and $t7.decision.recommendation_code -eq "SUPPLEMENT") `
    -Detail ("nearest_km={0}, terr_status={1}, esc={2}" -f $t7.identity_territory.nearest_existing_pos.distance_km, $t7.identity_territory.territory_status, ($t7.decision.escalation_codes -join ","))

$t8 = $byId["T_BND_RADIUS_JUST_OUTSIDE"]
Add-TestAssertion -Category "Rule Boundary" -TestId "T_BND_RADIUS_JUST_OUTSIDE" `
    -Description "POS at ~5.17 km (> 5.0 km protection radius) in different district is CLEAR and gets CONTINUE" `
    -Condition ($t8.identity_territory.territory_status -eq "CLEAR" -and $t8.decision.recommendation_code -eq "CONTINUE") `
    -Detail ("nearest_km={0}, terr_status={1}, rec={2}" -f $t8.identity_territory.nearest_existing_pos.distance_km, $t8.identity_territory.territory_status, $t8.decision.recommendation_code)

$t9 = $byId["T_BND_TAX_DUPLICATE"]
Add-TestAssertion -Category "Rule Boundary" -TestId "T_BND_TAX_DUPLICATE" `
    -Description "Renamed applicant with different address/phone but matching existing Tax ID triggers IDENTITY_DUPLICATE and NOT_CONTINUE" `
    -Condition ($t9.identity_territory.identity_status -eq "CONFIRMED_DUPLICATE" -and ($t9.decision.escalation_codes -contains "IDENTITY_DUPLICATE") -and $t9.decision.recommendation_code -eq "NOT_CONTINUE") `
    -Detail ("id_status={0}, esc={1}, rec={2}" -f $t9.identity_territory.identity_status, ($t9.decision.escalation_codes -join ","), $t9.decision.recommendation_code)

# 4. Architecture, Multi-skill Audit Trail & Sample Pack End-to-End Verification
$sampleRun = Invoke-PartnerEvaluationAgent -RootDir $RootDir -DataDir $SampleDataDir -Mode "local" -RunId "test_sample_pack" -SaveOutputs $false
$skillsSeen = @($sampleRun.audit_logs | ForEach-Object { $_.skill_name } | Where-Object { $_ -like "partner_*" } | Select-Object -Unique)
$toolsSeen = @($sampleRun.audit_logs | ForEach-Object { $_.tool_name } | Where-Object { $_ -like "tool_*" } | Select-Object -Unique)

Add-TestAssertion -Category "Audit & Skills" -TestId "T_ARCH_SKILLS_TOOLS" `
    -Description "Sample exam pack executes >= 2 coordinated skills (3 built) and all 7 business tools with full audit log" `
    -Condition (@($skillsSeen).Count -ge 3 -and @($toolsSeen).Count -eq 7 -and $sampleRun.summary.total_applicants -eq 10 -and $sampleRun.summary.regional_summary.Count -eq 3) `
    -Detail ("skills={0}, tools={1}, sample_total={2}, regions={3}" -f @($skillsSeen).Count, @($toolsSeen).Count, $sampleRun.summary.total_applicants, $sampleRun.summary.regional_summary.Count)

$passedCount = @($cases | Where-Object { $_.passed }).Count
$failedCount = @($cases | Where-Object { -not $_.passed }).Count
$summaryObj = [ordered]@{
    executed_at = [DateTimeOffset]::UtcNow.ToString("o")
    total = $cases.Count
    passed = $passedCount
    failed = $failedCount
    cases = @($cases)
}

if ($ReturnJson) {
    return ($summaryObj | ConvertTo-Json -Depth 10)
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host ("=== SELF-TEST SUITE RESULTS: {0}/{1} PASSED ({2} FAILED) ===" -f $passedCount, $cases.Count, $failedCount)
foreach ($c in $cases) {
    $tag = if ($c.passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($c.passed) { "Green" } else { "Red" }
    Write-Host ("{0} [{1}] {2}: {3} -> {4}" -f $tag, $c.category, $c.test_id, $c.description, $c.detail) -ForegroundColor $color
}

if ($failedCount -gt 0) {
    exit 1
}
exit 0

