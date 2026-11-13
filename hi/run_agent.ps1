param(
    [string]$DataDir = "",
    [string]$RulesPath = "",
    [string]$SchemaPath = "",
    [string]$Mode = "auto",
    [string]$LlmProvider = "gemini",
    [string]$ApiKey = "",
    [string]$ModelName = "",
    [string]$OpenAIBaseUrl = "https://api.openai.com/v1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($DataDir)) {
    $DataDir = Join-Path $RootDir "data\sample_exam_pack"
}
if (-not [System.IO.Path]::IsPathRooted($DataDir)) {
    $DataDir = Join-Path $RootDir $DataDir
}

. (Join-Path $RootDir "src\AgentCommon.ps1")
. (Join-Path $RootDir "src\AgentTools.ps1")
. (Join-Path $RootDir "src\AgentLLM.ps1")
. (Join-Path $RootDir "src\AgentOrchestrator.ps1")

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$result = Invoke-PartnerEvaluationAgent `
    -RootDir $RootDir `
    -DataDir $DataDir `
    -RulesPath $RulesPath `
    -SchemaPath $SchemaPath `
    -Mode $Mode `
    -LlmProvider $LlmProvider `
    -ApiKey $ApiKey `
    -ModelName $ModelName `
    -OpenAIBaseUrl $OpenAIBaseUrl `
    -SaveOutputs $true

Write-Host "=== DAI THANH AI AGENT COMPLETED ===" -ForegroundColor Green
Write-Host ("Run ID         : {0}" -f $result.run_id)
Write-Host ("Execution Mode : {0}" -f $result.execution_mode)
Write-Host ("Total Dossiers : {0}" -f $result.summary.total_applicants)
Write-Host ("Continue       : {0}" -f $result.summary.continue_count)
Write-Host ("Supplement     : {0}" -f $result.summary.supplement_count)
Write-Host ("Not Continue   : {0}" -f $result.summary.not_continue_count)
Write-Host ("Escalations    : {0}" -f $result.summary.escalation_count)
Write-Host ("Audit Events   : {0}" -f $result.audit_log_count)
Write-Host ("Output Dir     : {0}" -f $result.output_files.output_dir)
Write-Host ("Audit Log      : {0}" -f $result.output_files.audit_jsonl)

