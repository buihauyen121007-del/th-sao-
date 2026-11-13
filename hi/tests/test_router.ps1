Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $RootDir "src\AgentCommon.ps1")
. (Join-Path $RootDir "src\AgentTools.ps1")
. (Join-Path $RootDir "src\AgentLLM.ps1")
. (Join-Path $RootDir "src\AgentOrchestrator.ps1")
. (Join-Path $RootDir "src\WebServerRouter.ps1")

function Assert-Route {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    if (-not $Condition) {
        throw "ROUTE_ASSERT_FAIL [$Name]: $Detail"
    }
    Write-Output ("[PASS] {0}: {1}" -f $Name, $Detail)
}

$rHealth = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/api/health"
$healthObj = $rHealth.body | ConvertFrom-Json
Assert-Route "GET /api/health" ($rHealth.status -eq 200 -and $healthObj.status -eq "ok" -and $healthObj.url -eq "http://localhost:8055/") $rHealth.body

$rHtml = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/"
Assert-Route "GET /" ($rHtml.status -eq 200 -and $rHtml.content_type.Contains("text/html") -and $rHtml.body.Contains("serverStatusPill") -and $rHtml.body.Contains("tab-flowchart") -and $rHtml.body.Contains("flowchartSvg") -and $rHtml.body.Contains("kawaii-bakery.jpg")) ("len=" + $rHtml.body.Length)

$rCss = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/styles.css"
Assert-Route "GET /styles.css" ($rCss.status -eq 200 -and $rCss.content_type.Contains("text/css")) ("len=" + $rCss.body.Length)

$rJs = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/app.js"
Assert-Route "GET /app.js" ($rJs.status -eq 200 -and $rJs.content_type.Contains("application/javascript") -and $rJs.body.Contains("saveSchemaBtn") -and $rJs.body.Contains("flowchartMeta")) ("len=" + $rJs.body.Length)

$rImg = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/kawaii-bakery.jpg"
Assert-Route "GET /kawaii-bakery.jpg" ($rImg.status -eq 200 -and $rImg.content_type -eq "image/jpeg" -and $rImg.body_bytes.Length -gt 50000) ("bytes=" + $rImg.body_bytes.Length)

$rFav = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/favicon.ico"
Assert-Route "GET /favicon.ico" ($rFav.status -eq 200 -and $rFav.content_type.Contains("image/svg+xml")) ("len=" + $rFav.body.Length)

$rCfg = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/api/config"
$cfgObj = $rCfg.body | ConvertFrom-Json
Assert-Route "GET /api/config" ($rCfg.status -eq 200 -and @($cfgObj.rules.regions).Count -eq 3 -and $null -ne $cfgObj.schema.applicants_field_aliases) ("regions=" + @($cfgObj.rules.regions).Count)

$rDs = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/api/datasets"
$dsObj = $rDs.body | ConvertFrom-Json
Assert-Route "GET /api/datasets" ($rDs.status -eq 200 -and @($dsObj.datasets).Count -ge 2) ("count=" + @($dsObj.datasets).Count)

$rRun = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/run" -RawBody '{"dataset_name":"sample_exam_pack","mode":"local","save_outputs":false}'
$runObj = $rRun.body | ConvertFrom-Json
Assert-Route "POST /api/run" ($rRun.status -eq 200 -and $runObj.summary.total_applicants -eq 10 -and $runObj.summary.continue_count -eq 3) ("total=" + $runObj.summary.total_applicants)

$customSchema = $cfgObj.schema
$customSchema.applicants_field_aliases.applicant_id = @("ma_hs_thi") + @($customSchema.applicants_field_aliases.applicant_id)
$customSchema.applicants_field_aliases.partner_name = @("ten_doi_tac_thi") + @($customSchema.applicants_field_aliases.partner_name)

$expectedPartnerName = [Regex]::Unescape('C\u00f4ng ty Upload Localhost')
$upDossierTxt = [Regex]::Unescape('M\u00e3 h\u1ed3 s\u01a1: UP01\nM\u00e3 s\u1ed1 thu\u1ebf: 8888777766\nKhu v\u1ef1c: Mi\u1ec1n B\u1eafc\nT\u1ec9nh/Th\u00e0nh: H\u00e0 N\u1ed9i\nQu\u1eadn/Huy\u1ec7n: Long Bi\u00ean\n\u0110\u1ecba ch\u1ec9 \u0111i\u1ec3m b\u00e1n: 100 Nguy\u1ec5n V\u0103n C\u1eeb, Long Bi\u00ean, H\u00e0 N\u1ed9i\nDi\u1ec7n t\u00edch tr\u01b0ng b\u00e0y: 90 m2\nN\u0103ng l\u1ef1c b\u1ea3o h\u00e0nh: C\u00f3 2 k\u1ef9 thu\u1eadt vi\u00ean\nK\u1ebf ho\u1ea1ch nh\u1eadp h\u00e0ng: 300 tri\u1ec7u\nY\u00eau c\u1ea7u h\u1ed7 tr\u1ee3 th\u01b0\u01a1ng m\u1ea1i: C\u00f4ng n\u1ee3 30 ng\u00e0y, h\u1ea1n m\u1ee9c c\u00f4ng n\u1ee3 300 tri\u1ec7u, h\u1ed7 tr\u1ee3 th\u01b0\u01a1ng m\u1ea1i 4%')
$upBody = @{
    mode = "local"
    save_outputs = $false
    schema_override = $customSchema
    files = @{
        "applicants.json" = '[{"ma_hs_thi":"UP01","ten_doi_tac_thi":"C\u00f4ng ty Upload Localhost","dossier_file":"dossiers/UP01.txt"}]'
        "UP01.txt" = $upDossierTxt
        "existing_partners.csv" = "partner_id,partner_name,tax_id,representative,phone,email,region,status"
        "existing_pos.csv" = "pos_id,partner_id,partner_name,region,province,district,ward,address,latitude,longitude,protection_scope,protection_radius_km"
        "verification_results.csv" = "applicant_id,identity_verified,pos_verified,warranty_verified,financial_verified,verified_by,verification_date,verification_notes`nUP01,VERIFIED_PASS,VERIFIED_PASS,VERIFIED_PASS,VERIFIED_PASS,All,2026-11-11,OK"
    }
} | ConvertTo-Json -Depth 10
$rUp = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/run-uploaded" -RawBody $upBody
$upObj = $rUp.body | ConvertFrom-Json
if ($upObj.data_dir -and (Test-Path -LiteralPath $upObj.data_dir)) {
    Remove-Item -LiteralPath $upObj.data_dir -Recurse -Force -ErrorAction SilentlyContinue
}
Assert-Route "POST /api/run-uploaded (dossier fallback + schema_override)" ($rUp.status -eq 200 -and $upObj.applicants[0].profile.applicant_id -eq "UP01" -and $upObj.applicants[0].profile.partner_name -eq $expectedPartnerName -and $upObj.applicants[0].decision.recommendation_code -eq "CONTINUE") ("id=" + $upObj.applicants[0].profile.applicant_id + ", rec=" + $upObj.applicants[0].decision.recommendation_code)

$rTests = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/run-tests" -RawBody '{}'
$tstObj = $rTests.body | ConvertFrom-Json
Assert-Route "POST /api/run-tests" ($rTests.status -eq 200 -and $tstObj.passed -eq 10 -and $tstObj.failed -eq 0) ("passed=" + $tstObj.passed + "/" + $tstObj.total)

$rProt = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/dossiers/create" -RawBody '{"dataset_name":"sample_exam_pack","applicant_id":"HS999","partner_name":"Blocked"}'
Assert-Route "POST /api/dossiers/create (protected block)" ($rProt.status -eq 400) ("status=" + $rProt.status)

$testCreateDs = "_router_test_create_ds"
$testCreateDir = Join-Path (Join-Path $RootDir "data") $testCreateDs
if (Test-Path -LiteralPath $testCreateDir) {
    Remove-Item -LiteralPath $testCreateDir -Recurse -Force -ErrorAction SilentlyContinue
}
try {
    $createBody = @{
        dataset_name = $testCreateDs
        base_dataset = "sample_exam_pack"
        include_sample_applicants = $false
        applicant_id = "HS099"
        partner_name = "Cong ty Test Tao Ho So"
        tax_id = "0109998877"
        region = "Mien Bac"
        province = "Ha Noi"
        district = "Ha Dong"
        pos_address = "88 Tran Phu Ha Dong Ha Noi"
        latitude = "20.9719"
        longitude = "105.7764"
        showroom_area_m2 = "120"
        warranty_technicians = "3"
        monthly_purchase_vnd_million = "380"
        requested_credit_days = "30"
        requested_credit_limit_vnd_million = "380"
        requested_marketing_support_pct = "4"
        include_verification = $true
        verification = @{
            identity_verified = "VERIFIED_PASS"
            pos_verified = "VERIFIED_PASS"
            warranty_verified = "VERIFIED_PASS"
            financial_verified = "VERIFIED_PASS"
            verified_by = "All"
            verification_date = "2026-11-12"
            verification_notes = "OK"
        }
        attachments = @(
            @{
                name = "test_doc.txt"
                content_base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("Test evidence content"))
            }
        )
    } | ConvertTo-Json -Depth 6
    $rCr = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/dossiers/create" -RawBody $createBody
    if ($rCr.status -ne 200) { throw ("CREATE_FAIL status=" + $rCr.status + " body=" + $rCr.body) }
    $crObj = $rCr.body | ConvertFrom-Json
    Assert-Route "POST /api/dossiers/create" ($rCr.status -eq 200 -and $crObj.saved -and $crObj.applicant_id -eq "HS099" -and $crObj.summary.next_id -eq "HS100") ("id=" + $crObj.applicant_id + ", next=" + $crObj.summary.next_id)

    $rAtt = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path ("/api/attachments/" + $testCreateDs + "/HS099/test_doc.txt")
    Assert-Route "GET /api/attachments/..." ($rAtt.status -eq 200 -and $rAtt.body_bytes.Length -gt 0) ("bytes=" + $rAtt.body_bytes.Length)

    $rGetDs = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path ("/api/dossiers/" + $testCreateDs)
    if ($rGetDs.status -ne 200) { throw ("GET_DS_FAIL status=" + $rGetDs.status + " body=" + $rGetDs.body) }
    $getDsObj = $rGetDs.body | ConvertFrom-Json
    Assert-Route "GET /api/dossiers/{dataset}" ($rGetDs.status -eq 200 -and $getDsObj.count -eq 1 -and $getDsObj.items[0].applicant_id -eq "HS099") ("count=" + $getDsObj.count)

    $rRunCustom = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/run" -RawBody ('{"dataset_name":"' + $testCreateDs + '","mode":"local","save_outputs":false}')
    if ($rRunCustom.status -ne 200) { throw ("RUN_CREATED_FAIL status=" + $rRunCustom.status + " body=" + $rRunCustom.body) }
    $runCustomObj = $rRunCustom.body | ConvertFrom-Json
    Assert-Route "POST /api/run (created dossier)" ($rRunCustom.status -eq 200 -and $runCustomObj.summary.total_applicants -eq 1 -and $runCustomObj.applicants[0].decision.recommendation_code -eq "CONTINUE") ("rec=" + $runCustomObj.applicants[0].decision.recommendation_code)

    $rDel = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "POST" -Path "/api/dossiers/delete" -RawBody ('{"dataset_name":"' + $testCreateDs + '","applicant_id":"HS099"}')
    if ($rDel.status -ne 200) { throw ("DEL_FAIL status=" + $rDel.status + " body=" + $rDel.body) }
    $delObj = $rDel.body | ConvertFrom-Json
    Assert-Route "POST /api/dossiers/delete" ($rDel.status -eq 200 -and $delObj.deleted -and $delObj.summary.count -eq 0) ("remaining=" + $delObj.summary.count)
} finally {
    if (Test-Path -LiteralPath $testCreateDir) {
        Remove-Item -LiteralPath $testCreateDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$r404 = Invoke-WebRoute -RootDir $RootDir -Port 8055 -Method "GET" -Path "/api/does-not-exist"
Assert-Route "GET 404" ($r404.status -eq 404) ("status=" + $r404.status)

Write-Output "ALL_ROUTER_CHECKS_PASSED"

