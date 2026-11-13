Set-StrictMode -Version Latest

function Invoke-GeminiFunctionCallingForApplicant {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        [string]$ModelName = "gemini-2.5-flash"
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/${ModelName}:generateContent?key=$ApiKey"

    $toolDecls = @(Get-AgentToolSchemas | Where-Object { $_.name -ne "tool_generate_regional_summary_and_plan" } | ForEach-Object {
        [ordered]@{
            name = $_.name
            description = $_.description
            parameters = $_.parameters
        }
    })

    $systemInstruction = @"
You are the Dai Thanh Partner Evaluation AI Agent executing 3 coordinated business skills:
1. partner_identity_territory_screening (tools: tool_load_and_extract_dossier, tool_check_identity_and_territory, tool_check_mandatory_and_policy_gates)
2. partner_scoring_priority_and_escalation (tools: tool_evaluate_criteria_and_priority, tool_determine_escalation_and_recommendation)
3. partner_reporting_coordination_and_drafting (tool: tool_draft_partner_communication)

For applicant_id '$ApplicantId', execute all 6 tools in logical sequence.
NEVER invent scores, verification results, or facts; rely strictly on tool results.
After all 6 tools have completed, provide a concise Vietnamese executive summary (3-4 sentences) explaining the evidence, missing data, escalation triggers (if any), and final recommendation.
"@

    $contents = New-Object System.Collections.ArrayList
    [void]$contents.Add([ordered]@{
        role = "user"
        parts = @([ordered]@{ text = "Please evaluate partner dossier '$ApplicantId' using the required tools in order and explain the decision in Vietnamese." })
    })

    $maxTurns = 10
    $finalReasoning = ""
    for ($turn = 1; $turn -le $maxTurns; $turn++) {
        $payload = [ordered]@{
            system_instruction = [ordered]@{ parts = @([ordered]@{ text = $systemInstruction }) }
            contents = @($contents)
            tools = @([ordered]@{ functionDeclarations = $toolDecls })
            toolConfig = [ordered]@{ functionCallingConfig = [ordered]@{ mode = "AUTO" } }
            generationConfig = [ordered]@{ temperature = 0.1 }
        }
        $bodyJson = $payload | ConvertTo-Json -Depth 15
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

        [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "LLM_REQUEST" `
            -SkillName "llm_orchestrator" -ToolName "gemini_api" -ApplicantId $ApplicantId `
            -ToolArgs ([ordered]@{ model = $ModelName; turn = $turn }) -ToolResultSummary "Sending request to Gemini API")

        $resp = Invoke-RestMethod -Uri $endpoint -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyBytes -TimeoutSec 45
        $candidate = $resp.candidates[0]
        $modelContent = $candidate.content
        [void]$contents.Add($modelContent)

        $fnCalls = @($modelContent.parts | Where-Object { $null -ne (Get-PropValue -Obj $_ -Name "functionCall" -Default $null) })
        if (@($fnCalls).Count -eq 0) {
            $textParts = @($modelContent.parts | ForEach-Object { Get-PropValue -Obj $_ -Name "text" -Default "" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $finalReasoning = ($textParts -join "`n").Trim()
            break
        }

        $fnResponses = New-Object System.Collections.ArrayList
        foreach ($part in $fnCalls) {
            $fc = $part.functionCall
            $toolName = [string]$fc.name
            $argId = [string](Get-PropValue -Obj $fc.args -Name "applicant_id" -Default $ApplicantId)
            if ([string]::IsNullOrWhiteSpace($argId)) { $argId = $ApplicantId }

            $toolOut = Invoke-NamedAgentTool -Context $Context -ToolName $toolName -ApplicantId $argId
            [void]$fnResponses.Add([ordered]@{
                functionResponse = [ordered]@{
                    name = $toolName
                    response = [ordered]@{ result = $toolOut }
                }
            })
        }
        [void]$contents.Add([ordered]@{
            role = "user"
            parts = @($fnResponses)
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($finalReasoning) -and $Context.WorkState.Contains($ApplicantId)) {
        $Context.WorkState[$ApplicantId]["ai_reasoning"] = $finalReasoning
    }
    return $finalReasoning
}

function Invoke-OpenAIFunctionCallingForApplicant {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId,
        [Parameter(Mandatory=$true)][string]$ApiKey,
        [string]$ModelName = "gpt-4o-mini",
        [string]$BaseUrl = "https://api.openai.com/v1"
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $endpoint = "$($BaseUrl.TrimEnd('/'))/chat/completions"

    $tools = @(Get-AgentToolSchemas | Where-Object { $_.name -ne "tool_generate_regional_summary_and_plan" } | ForEach-Object {
        [ordered]@{
            type = "function"
            function = [ordered]@{
                name = $_.name
                description = $_.description
                parameters = $_.parameters
            }
        }
    })

    $messages = New-Object System.Collections.ArrayList
    [void]$messages.Add([ordered]@{
        role = "system"
        content = "You are the Dai Thanh Partner Evaluation AI Agent. Execute the 6 screening, scoring, escalation, and drafting tools in order for the requested applicant_id, then summarize the evidence-based conclusion in Vietnamese."
    })
    [void]$messages.Add([ordered]@{
        role = "user"
        content = "Evaluate applicant_id '$ApplicantId' by invoking the required tools in sequence and summarize in Vietnamese."
    })

    $headers = @{ "Authorization" = "Bearer $ApiKey" }
    $finalReasoning = ""
    for ($turn = 1; $turn -le 10; $turn++) {
        $payload = [ordered]@{
            model = $ModelName
            messages = @($messages)
            tools = $tools
            tool_choice = "auto"
            temperature = 0.1
        }
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 15))
        [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "LLM_REQUEST" `
            -SkillName "llm_orchestrator" -ToolName "openai_api" -ApplicantId $ApplicantId `
            -ToolArgs ([ordered]@{ model = $ModelName; turn = $turn }) -ToolResultSummary "Sending request to OpenAI-compatible API")

        $resp = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bodyBytes -TimeoutSec 45
        $msgObj = $resp.choices[0].message
        [void]$messages.Add($msgObj)

        $rawToolCalls = Get-PropValue -Obj $msgObj -Name "tool_calls" -Default $null
        $toolCalls = if ($null -eq $rawToolCalls) { @() } else { @($rawToolCalls | Where-Object { $null -ne $_ }) }
        if (@($toolCalls).Count -eq 0) {
            $finalReasoning = ([string](Get-PropValue -Obj $msgObj -Name "content" -Default "")).Trim()
            break
        }
        foreach ($tc in $toolCalls) {
            $toolName = [string]$tc.function.name
            $parsedArgs = $tc.function.arguments | ConvertFrom-Json
            $argId = [string](Get-PropValue -Obj $parsedArgs -Name "applicant_id" -Default $ApplicantId)
            if ([string]::IsNullOrWhiteSpace($argId)) { $argId = $ApplicantId }

            $toolOut = Invoke-NamedAgentTool -Context $Context -ToolName $toolName -ApplicantId $argId
            [void]$messages.Add([ordered]@{
                role = "tool"
                tool_call_id = [string]$tc.id
                content = ($toolOut | ConvertTo-Json -Depth 10 -Compress)
            })
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($finalReasoning) -and $Context.WorkState.Contains($ApplicantId)) {
        $Context.WorkState[$ApplicantId]["ai_reasoning"] = $finalReasoning
    }
    return $finalReasoning
}
