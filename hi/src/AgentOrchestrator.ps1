Set-StrictMode -Version Latest

function Load-StructuredTable {
    param(
        [Parameter(Mandatory=$true)][string]$DataDir,
        [Parameter(Mandatory=$true)][string]$BaseName
    )
    $jsonPath = Join-Path $DataDir "$BaseName.json"
    $csvPath = Join-Path $DataDir "$BaseName.csv"
    if (Test-Path -LiteralPath $jsonPath) {
        $parsed = Read-JsonUtf8 -Path $jsonPath
        return [ordered]@{
            rows = @($parsed)
            file_name = "$BaseName.json"
            file_path = $jsonPath
            sha256 = Get-FileSha256 -Path $jsonPath
        }
    } elseif (Test-Path -LiteralPath $csvPath) {
        $parsed = Read-CsvUtf8 -Path $csvPath
        return [ordered]@{
            rows = @($parsed)
            file_name = "$BaseName.csv"
            file_path = $csvPath
            sha256 = Get-FileSha256 -Path $csvPath
        }
    }
    return [ordered]@{
        rows = @()
        file_name = "MISSING_$BaseName"
        file_path = ""
        sha256 = ""
    }
}

function Invoke-NamedAgentTool {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ToolName,
        [string]$ApplicantId = ""
    )
    switch ($ToolName) {
        "tool_load_and_extract_dossier" {
            return (Invoke-ToolLoadAndExtractDossier -Context $Context -ApplicantId $ApplicantId)
        }
        "tool_check_identity_and_territory" {
            if (-not $Context.WorkState.Contains($ApplicantId)) {
                [void](Invoke-ToolLoadAndExtractDossier -Context $Context -ApplicantId $ApplicantId)
            }
            return (Invoke-ToolCheckIdentityAndTerritory -Context $Context -ApplicantId $ApplicantId)
        }
        "tool_check_mandatory_and_policy_gates" {
            if (-not $Context.WorkState.Contains($ApplicantId) -or -not $Context.WorkState[$ApplicantId].Contains("identity_territory")) {
                [void](Invoke-NamedAgentTool -Context $Context -ToolName "tool_check_identity_and_territory" -ApplicantId $ApplicantId)
            }
            return (Invoke-ToolCheckMandatoryAndPolicyGates -Context $Context -ApplicantId $ApplicantId)
        }
        "tool_evaluate_criteria_and_priority" {
            if (-not $Context.WorkState.Contains($ApplicantId) -or -not $Context.WorkState[$ApplicantId].Contains("gates")) {
                [void](Invoke-NamedAgentTool -Context $Context -ToolName "tool_check_mandatory_and_policy_gates" -ApplicantId $ApplicantId)
            }
            return (Invoke-ToolEvaluateCriteriaAndPriority -Context $Context -ApplicantId $ApplicantId)
        }
        "tool_determine_escalation_and_recommendation" {
            if (-not $Context.WorkState.Contains($ApplicantId) -or -not $Context.WorkState[$ApplicantId].Contains("scoring")) {
                [void](Invoke-NamedAgentTool -Context $Context -ToolName "tool_evaluate_criteria_and_priority" -ApplicantId $ApplicantId)
            }
            return (Invoke-ToolDetermineEscalationAndRecommendation -Context $Context -ApplicantId $ApplicantId)
        }
        "tool_draft_partner_communication" {
            if (-not $Context.WorkState.Contains($ApplicantId) -or -not $Context.WorkState[$ApplicantId].Contains("decision")) {
                [void](Invoke-NamedAgentTool -Context $Context -ToolName "tool_determine_escalation_and_recommendation" -ApplicantId $ApplicantId)
            }
            return (Invoke-ToolDraftPartnerCommunication -Context $Context -ApplicantId $ApplicantId)
        }
        "tool_generate_regional_summary_and_plan" {
            return (Invoke-ToolGenerateRegionalSummaryAndPlan -Context $Context -IncludeDraftPreviews $true)
        }
        default {
            throw "Unknown tool name: $ToolName"
        }
    }
}

function Invoke-PartnerEvaluationAgent {
    param(
        [Parameter(Mandatory=$true)][string]$RootDir,
        [Parameter(Mandatory=$true)][string]$DataDir,
        [string]$RulesPath = "",
        [string]$SchemaPath = "",
        [string]$RunId = "",
        [string]$Mode = "auto",
        [string]$LlmProvider = "gemini",
        [string]$ApiKey = "",
        [string]$ModelName = "",
        [string]$OpenAIBaseUrl = "https://api.openai.com/v1",
        [bool]$SaveOutputs = $true
    )
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = "run_" + [DateTime]::Now.ToString("yyyyMMdd_HHmmss")
    }
    if ([string]::IsNullOrWhiteSpace($RulesPath)) {
        $RulesPath = Join-Path $RootDir "config\rules_config.json"
    }
    if ([string]::IsNullOrWhiteSpace($SchemaPath)) {
        $SchemaPath = Join-Path $RootDir "config\schema_mapping.json"
    }
    $msgPath = Join-Path $RootDir "config\messages_vi.json"

    $rules = Read-JsonUtf8 -Path $RulesPath
    $schema = Read-JsonUtf8 -Path $SchemaPath
    $messages = Read-JsonUtf8 -Path $msgPath

    $appTable = Load-StructuredTable -DataDir $DataDir -BaseName "applicants"
    $epTable = Load-StructuredTable -DataDir $DataDir -BaseName "existing_partners"
    $posTable = Load-StructuredTable -DataDir $DataDir -BaseName "existing_pos"
    $verTable = Load-StructuredTable -DataDir $DataDir -BaseName "verification_results"

    # Also support standalone .txt dossiers folder even if applicants.json/csv is missing
    $rawApplicants = @($appTable.rows)
    if (@($rawApplicants).Count -eq 0) {
        $dossiersDir = Join-Path $DataDir "dossiers"
        if (Test-Path -LiteralPath $dossiersDir) {
            $txtFiles = @(Get-ChildItem -LiteralPath $dossiersDir -Filter "*.txt" | Sort-Object Name)
            $rawApplicants = @($txtFiles | ForEach-Object {
                [PSCustomObject]@{
                    applicant_id = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    dossier_file = "dossiers/$($_.Name)"
                }
            })
            $appTable.file_name = "dossiers/*.txt"
        }
    }

    $auditLogs = New-Object System.Collections.ArrayList
    $context = [ordered]@{
        RunId = $RunId
        RootDir = $RootDir
        DataDir = $DataDir
        Rules = $rules
        SchemaMapping = $schema
        Messages = $messages
        RawApplicants = $rawApplicants
        ApplicantsSourceName = $appTable.file_name
        ExistingPartners = @($epTable.rows)
        ExistingPos = @($posTable.rows)
        VerificationResults = @($verTable.rows)
        WorkState = [ordered]@{}
        AuditLogs = $auditLogs
        Summary = $null
    }

    # Resolve execution mode
    $effectiveApiKey = $ApiKey
    if ([string]::IsNullOrWhiteSpace($effectiveApiKey)) {
        if ($LlmProvider -eq "openai") { $effectiveApiKey = $env:OPENAI_API_KEY }
        else { $effectiveApiKey = $env:GEMINI_API_KEY }
    }
    $effectiveMode = "local_agent_orchestrator"
    if ($Mode -eq "llm" -or ($Mode -eq "auto" -and -not [string]::IsNullOrWhiteSpace($effectiveApiKey))) {
        if (-not [string]::IsNullOrWhiteSpace($effectiveApiKey)) {
            $effectiveMode = if ($LlmProvider -eq "openai") { "openai_function_calling" } else { "gemini_function_calling" }
        }
    }

    [void](Add-AuditEvent -LogList $auditLogs -RunId $RunId -EventType "DATA_LOADED" `
        -SkillName "orchestrator" -ToolName "load_dataset" -ApplicantId "ALL" `
        -ToolArgs ([ordered]@{ data_dir = $DataDir; mode = $effectiveMode }) `
        -EvidenceRefs @($appTable.file_name, $epTable.file_name, $posTable.file_name, $verTable.file_name) `
        -RuleIds @("DATA_INTEGRITY_HASH") `
        -ToolResultSummary ([ordered]@{
            applicants_count = @($rawApplicants).Count
            existing_partners_count = @($epTable.rows).Count
            existing_pos_count = @($posTable.rows).Count
            verification_rows_count = @($verTable.rows).Count
            input_hashes = [ordered]@{
                applicants = $appTable.sha256
                existing_partners = $epTable.sha256
                existing_pos = $posTable.sha256
                verification_results = $verTable.sha256
                rules_config = (Get-FileSha256 -Path $RulesPath)
            }
        }))

    foreach ($rec in $rawApplicants) {
        $appId = [string](Get-AliasedField -Obj $rec -Aliases @($schema.applicants_field_aliases.applicant_id) -Default "")
        if ([string]::IsNullOrWhiteSpace($appId)) { continue }

        if ($effectiveMode -eq "gemini_function_calling") {
            try {
                $mName = if ([string]::IsNullOrWhiteSpace($ModelName)) { "gemini-2.5-flash" } else { $ModelName }
                [void](Invoke-GeminiFunctionCallingForApplicant -Context $context -ApplicantId $appId -ApiKey $effectiveApiKey -ModelName $mName)
            } catch {
                [void](Add-AuditEvent -LogList $auditLogs -RunId $RunId -EventType "LLM_FALLBACK" `
                    -SkillName "llm_orchestrator" -ToolName "gemini_api" -ApplicantId $appId `
                    -ToolResultSummary ("LLM call failed, safely falling back to local tool pipeline: " + $_.Exception.Message))
            }
        } elseif ($effectiveMode -eq "openai_function_calling") {
            try {
                $mName = if ([string]::IsNullOrWhiteSpace($ModelName)) { "gpt-4o-mini" } else { $ModelName }
                [void](Invoke-OpenAIFunctionCallingForApplicant -Context $context -ApplicantId $appId -ApiKey $effectiveApiKey -ModelName $mName -BaseUrl $OpenAIBaseUrl)
            } catch {
                [void](Add-AuditEvent -LogList $auditLogs -RunId $RunId -EventType "LLM_FALLBACK" `
                    -SkillName "llm_orchestrator" -ToolName "openai_api" -ApplicantId $appId `
                    -ToolResultSummary ("LLM call failed, safely falling back to local tool pipeline: " + $_.Exception.Message))
            }
        }

        # Deterministic completeness guarantee across all 3 skills & 6 per-applicant tools
        $requiredSequence = @(
            @{ skill = "partner_identity_territory_screening"; tool = "tool_load_and_extract_dossier"; key = "profile" },
            @{ skill = "partner_identity_territory_screening"; tool = "tool_check_identity_and_territory"; key = "identity_territory" },
            @{ skill = "partner_identity_territory_screening"; tool = "tool_check_mandatory_and_policy_gates"; key = "gates" },
            @{ skill = "partner_scoring_priority_and_escalation"; tool = "tool_evaluate_criteria_and_priority"; key = "scoring" },
            @{ skill = "partner_scoring_priority_and_escalation"; tool = "tool_determine_escalation_and_recommendation"; key = "decision" },
            @{ skill = "partner_reporting_coordination_and_drafting"; tool = "tool_draft_partner_communication"; key = "draft" }
        )
        foreach ($step in $requiredSequence) {
            $alreadyDone = ($context.WorkState.Contains($appId) -and $context.WorkState[$appId].Contains($step.key))
            if (-not $alreadyDone) {
                [void](Add-AuditEvent -LogList $auditLogs -RunId $RunId -EventType "SKILL_STEP" `
                    -SkillName $step.skill -ToolName $step.tool -ApplicantId $appId `
                    -ToolArgs ([ordered]@{ applicant_id = $appId }) -ToolResultSummary "Invoking skill tool")
                [void](Invoke-NamedAgentTool -Context $context -ToolName $step.tool -ApplicantId $appId)
            }
        }
    }

    # Final Skill 3 regional aggregation & verification plan
    [void](Add-AuditEvent -LogList $auditLogs -RunId $RunId -EventType "SKILL_STEP" `
        -SkillName "partner_reporting_coordination_and_drafting" -ToolName "tool_generate_regional_summary_and_plan" -ApplicantId "ALL" `
        -ToolResultSummary "Aggregating regional tables, escalations, and department verification plan")
    $summary = Invoke-NamedAgentTool -Context $context -ToolName "tool_generate_regional_summary_and_plan"

    $applicantsList = @($context.WorkState.Keys | ForEach-Object { $context.WorkState[$_] })
    $finalPayload = [ordered]@{
        run_id = $RunId
        executed_at = [DateTimeOffset]::UtcNow.ToString("o")
        execution_mode = $effectiveMode
        data_dir = $DataDir
        rules_version = $rules.schema_version
        summary = $summary
        applicants = $applicantsList
        audit_log_count = $auditLogs.Count
        audit_logs = @($auditLogs)
    }

    if ($SaveOutputs) {
        $outDir = Join-Path (Join-Path $RootDir "outputs") $RunId
        if (-not (Test-Path -LiteralPath $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        $logPath = Join-Path (Join-Path $RootDir "logs") "$RunId.jsonl"
        Save-AuditLogJsonl -LogList $auditLogs -Path $logPath

        $jsonOutPath = Join-Path $outDir "ket_qua_danh_gia.json"
        Write-Utf8File -Path $jsonOutPath -Content ($finalPayload | ConvertTo-Json -Depth 15) -WithBom $false

        $mdReport = Build-MarkdownReport -Payload $finalPayload -Messages $messages
        Write-Utf8File -Path (Join-Path $outDir "bao_cao_tong_hop.md") -Content $mdReport -WithBom $false

        Export-RegionalCsv -Summary $summary -Path (Join-Path $outDir "bang_de_xuat_khu_vuc.csv")
        Export-VerificationPlanCsv -Summary $summary -Path (Join-Path $outDir "ke_hoach_xac_minh.csv")

        $finalPayload["output_files"] = [ordered]@{
            output_dir = $outDir
            json = $jsonOutPath
            markdown = (Join-Path $outDir "bao_cao_tong_hop.md")
            regional_csv = (Join-Path $outDir "bang_de_xuat_khu_vuc.csv")
            verification_csv = (Join-Path $outDir "ke_hoach_xac_minh.csv")
            audit_jsonl = $logPath
        }
    }

    return $finalPayload
}

function Build-MarkdownReport {
    param(
        [Parameter(Mandatory=$true)]$Payload,
        [Parameter(Mandatory=$true)]$Messages
    )
    $h = $Messages.report_headings
    $s = $Payload.summary
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("# $($h.title)")
    [void]$sb.AppendLine("- $($h.meta_company)")
    [void]$sb.AppendLine("- Run ID: ``$($Payload.run_id)`` | Mode: ``$($Payload.execution_mode)`` | Time: $($Payload.executed_at)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## $($h.sec1_overview)")
    [void]$sb.AppendLine("| $($h.tbl_metric) | $($h.tbl_value) |")
    [void]$sb.AppendLine("|---|---|")
    [void]$sb.AppendLine("| $($h.m_total) | $($s.total_applicants) |")
    [void]$sb.AppendLine("| $($h.m_continue) | $($s.continue_count) |")
    [void]$sb.AppendLine("| $($h.m_supplement) | $($s.supplement_count) |")
    [void]$sb.AppendLine("| $($h.m_not_continue) | $($s.not_continue_count) |")
    [void]$sb.AppendLine("| $($h.m_escalation) | $($s.escalation_count) |")
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## $($h.sec2_regional)")
    foreach ($rg in $s.regional_summary) {
        [void]$sb.AppendLine("### $($rg.region) ($($rg.total): $($rg.continue_count) $($h.m_continue) / $($rg.supplement_count) $($h.m_supplement) / $($rg.not_continue_count) $($h.m_not_continue))")
        [void]$sb.AppendLine("| $($h.col_id) | $($h.col_partner) | $($h.col_area) | $($h.col_vscore) | $($h.col_cscore) | $($h.col_prio) | $($h.col_rec) | $($h.col_esc) |")
        [void]$sb.AppendLine("|---|---|---|---:|---:|---|---|---|")
        foreach ($row in $rg.partners) {
            $escFlag = if ($row.requires_escalation) { ($row.escalation_codes -join ", ") } else { [string]$Messages.labels.none_label }
            [void]$sb.AppendLine("| $($row.applicant_id) | $($row.partner_name) | $($row.province_district) | $($row.verified_score) | $($row.claimed_score) | $($row.priority) | $($row.recommendation) | $escFlag |")
        }
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("## $($h.sec3_escalations)")
    foreach ($esc in $s.escalation_register) {
        [void]$sb.AppendLine("### $($esc.applicant_id) - $($esc.partner_name) ($($esc.region))")
        foreach ($e in $esc.escalations) {
            [void]$sb.AppendLine("- **[$($e.code)] $($e.label)** -> $($h.lbl_escalation): **$($e.escalate_to)**")
            [void]$sb.AppendLine("  - $($h.lbl_detail): $($e.detail)")
        }
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("## $($h.sec4_verification)")
    [void]$sb.AppendLine("| $($h.col_dept) | $($h.col_id) | $($h.col_partner) | $($h.col_region) | $($h.col_status) | $($h.col_task) |")
    [void]$sb.AppendLine("|---|---|---|---|---|---|")
    foreach ($vt in $s.verification_plan) {
        [void]$sb.AppendLine("| $($vt.department) | $($vt.applicant_id) | $($vt.partner_name) | $($vt.region) | $($vt.current_status) | $($vt.task) |")
    }
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## $($h.sec5_dossiers)")
    foreach ($app in $Payload.applicants) {
        $p = $app.profile
        $d = $app.decision
        $sc = $app.scoring
        [void]$sb.AppendLine("### $($p.applicant_id) - $($p.partner_name) [$($d.recommendation_label) | $($d.priority_label)]")
        [void]$sb.AppendLine("- $($h.col_region): $($p.region) | $($h.col_area): $($p.pos_address) | MST: $($p.tax_id)")
        [void]$sb.AppendLine("- $($h.lbl_score_line): **$($sc.verified_score)/100** ($($h.lbl_claimed_line): $($sc.claimed_score)/100)")
        [void]$sb.AppendLine("- **$($h.lbl_basis):**")
        foreach ($eb in $d.evidence_basis) { [void]$sb.AppendLine("  - $eb") }
        [void]$sb.AppendLine("- **$($h.lbl_failed):**")
        if (@($d.failed_and_conflict_items).Count -eq 0) { [void]$sb.AppendLine("  - $($Messages.labels.none_missing_label)") }
        else { foreach ($fc in $d.failed_and_conflict_items) { [void]$sb.AppendLine("  - $fc") } }
        [void]$sb.AppendLine("- **$($h.lbl_unknown):**")
        if (@($d.unknown_or_missing_items).Count -eq 0) { [void]$sb.AppendLine("  - $($Messages.labels.none_missing_label)") }
        else { foreach ($uk in $d.unknown_or_missing_items) { [void]$sb.AppendLine("  - $uk") } }
        [void]$sb.AppendLine("- **$($h.lbl_verify):**")
        if (@($d.verification_tasks).Count -eq 0) { [void]$sb.AppendLine("  - $($Messages.labels.no_verification_needed.TrimStart('- '))") }
        else { foreach ($vt in $d.verification_tasks) { [void]$sb.AppendLine("  - [$($vt.department)] $($vt.task)") } }
        [void]$sb.AppendLine("- **$($h.lbl_draft):**")
        [void]$sb.AppendLine("  - $($h.lbl_subject): ``$($app.draft.subject)``")
        [void]$sb.AppendLine('```text')
        [void]$sb.AppendLine($app.draft.body)
        [void]$sb.AppendLine('```')
        [void]$sb.AppendLine("")
    }

    return $sb.ToString()
}

function Export-RegionalCsv {
    param($Summary, [string]$Path)
    $rows = New-Object System.Collections.ArrayList
    foreach ($rg in $Summary.regional_summary) {
        foreach ($p in $rg.partners) {
            [void]$rows.Add([PSCustomObject]@{
                khu_vuc = $rg.region
                ma_ho_so = $p.applicant_id
                ten_doi_tac = $p.partner_name
                dia_ban = $p.province_district
                diem_thuc_chung = $p.verified_score
                diem_tu_khai = $p.claimed_score
                muc_uu_tien = $p.priority
                de_xuat = $p.recommendation
                chuyen_tham_quyen = if ($p.requires_escalation) { ($p.escalation_codes -join "; ") } else { "Khong" }
            })
        }
    }
    $csvContent = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
    Write-Utf8File -Path $Path -Content $csvContent -WithBom $true
}

function Export-VerificationPlanCsv {
    param($Summary, [string]$Path)
    $rows = @($Summary.verification_plan | ForEach-Object {
        [PSCustomObject]@{
            bo_phan = $_.department
            ma_ho_so = $_.applicant_id
            ten_doi_tac = $_.partner_name
            khu_vuc = $_.region
            trang_thai_hien_tai = $_.current_status
            muc_uu_tien = $_.priority
            nhiem_vu_xac_minh = $_.task
        }
    })
    $csvContent = if (@($rows).Count -gt 0) { ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n" } else { "bo_phan,ma_ho_so,ten_doi_tac,khu_vuc,trang_thai_hien_tai,muc_uu_tien,nhiem_vu_xac_minh" }
    Write-Utf8File -Path $Path -Content $csvContent -WithBom $true
}
