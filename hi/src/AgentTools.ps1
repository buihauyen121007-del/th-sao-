Set-StrictMode -Version Latest

function Get-AgentToolSchemas {
    return @(
        [ordered]@{
            name = "tool_load_and_extract_dossier"
            skill = "partner_identity_territory_screening"
            description = "Read applicant dossier text and structured fields, attach independent verification records, extract claimed metrics and evidence quotes, and identify missing fields."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    applicant_id = [ordered]@{ type = "string"; description = "Applicant ID such as HS001" }
                }
                required = @("applicant_id")
            }
        },
        [ordered]@{
            name = "tool_check_identity_and_territory"
            skill = "partner_identity_territory_screening"
            description = "Cross-check applicant identity (tax_id, phone, email, fuzzy name) against existing_partners and check POS location (GPS Haversine radius, province/district/ward) against existing_pos protection policy."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    applicant_id = [ordered]@{ type = "string" }
                }
                required = @("applicant_id")
            }
        },
        [ordered]@{
            name = "tool_check_mandatory_and_policy_gates"
            skill = "partner_identity_territory_screening"
            description = "Verify mandatory conditions, credit and commercial policy limits, and separate claimed commitments from independently verified evidence."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    applicant_id = [ordered]@{ type = "string" }
                }
                required = @("applicant_id")
            }
        },
        [ordered]@{
            name = "tool_evaluate_criteria_and_priority"
            skill = "partner_scoring_priority_and_escalation"
            description = "Score the applicant across weighted evaluation criteria, computing both claimed score and evidence-capped verified score."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    applicant_id = [ordered]@{ type = "string" }
                }
                required = @("applicant_id")
            }
        },
        [ordered]@{
            name = "tool_determine_escalation_and_recommendation"
            skill = "partner_scoring_priority_and_escalation"
            description = "Determine final recommendation (CONTINUE, SUPPLEMENT, NOT_CONTINUE), priority level, escalation targets, and required verification tasks per department."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    applicant_id = [ordered]@{ type = "string" }
                }
                required = @("applicant_id")
            }
        },
        [ordered]@{
            name = "tool_draft_partner_communication"
            skill = "partner_reporting_coordination_and_drafting"
            description = "Generate partner communication email/letter draft grounded in verified evidence, failed gates, and pending verification items."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    applicant_id = [ordered]@{ type = "string" }
                }
                required = @("applicant_id")
            }
        },
        [ordered]@{
            name = "tool_generate_regional_summary_and_plan"
            skill = "partner_reporting_coordination_and_drafting"
            description = "Build regional recommendation summary table across all 3 regions, escalation register, and cross-department verification coordination plan."
            parameters = [ordered]@{
                type = "object"
                properties = [ordered]@{
                    include_draft_previews = [ordered]@{ type = "boolean" }
                }
                required = @()
            }
        }
    )
}

function Resolve-NormalizedRegion {
    param(
        [string]$RawRegion,
        [string]$RawProvince,
        $Rules,
        $Messages
    )
    $regions = @($Rules.regions)
    foreach ($candidate in @($RawRegion, $RawProvince)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $norm = Normalize-MatchText -Text $candidate
        foreach ($r in $regions) {
            if ((Normalize-MatchText -Text ([string]$r)) -eq $norm) {
                return [string]$r
            }
        }
        $aliases = $Messages.regions_aliases
        if ($null -ne $aliases) {
            foreach ($prop in $aliases.PSObject.Properties) {
                if ($norm -eq $prop.Name -or $norm.Contains($prop.Name)) {
                    return [string]$prop.Value
                }
            }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($RawRegion)) { return $RawRegion.Trim() }
    return [string]$Messages.labels.unknown_region
}

function Extract-FromDossierText {
    param(
        [string]$RawText,
        $Messages
    )
    $extracted = [ordered]@{}
    $evidenceQuotes = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($RawText)) {
        return [ordered]@{ fields = $extracted; quotes = @() }
    }
    $patterns = $Messages.text_extraction_patterns
    $billionPattern = [string]$patterns.billion_unit_regex
    $numericFields = @(
        "showroom_area_m2",
        "warranty_technicians",
        "monthly_purchase_vnd_million",
        "requested_credit_days",
        "requested_credit_limit_vnd_million",
        "requested_marketing_support_pct"
    )
    foreach ($prop in $patterns.PSObject.Properties) {
        $fieldName = $prop.Name
        if ($fieldName -eq "billion_unit_regex") { continue }
        $pattern = [string]$prop.Value
        $m = [regex]::Match($RawText, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) {
            $rawVal = ""
            for ($gi = 1; $gi -lt $m.Groups.Count; $gi++) {
                if ($m.Groups[$gi].Success -and -not [string]::IsNullOrWhiteSpace($m.Groups[$gi].Value)) {
                    $rawVal = $m.Groups[$gi].Value.Trim()
                    break
                }
            }
            if ($numericFields -contains $fieldName) {
                $num = Try-ParseDoubleInvariant -Value $rawVal
                if (-not [double]::IsNaN($num)) {
                    if (($fieldName -eq "monthly_purchase_vnd_million" -or $fieldName -eq "requested_credit_limit_vnd_million") -and
                        (-not [string]::IsNullOrWhiteSpace($billionPattern)) -and
                        [regex]::IsMatch($m.Groups[0].Value, $billionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                        $num = $num * 1000.0
                    }
                    $extracted[$fieldName] = $num
                }
            } else {
                $extracted[$fieldName] = $rawVal
            }
            $quoteLine = $m.Groups[0].Value.Trim()
            if ($quoteLine.Length -gt 140) { $quoteLine = $quoteLine.Substring(0, 140) + "..." }
            [void]$evidenceQuotes.Add("${fieldName}: `"$quoteLine`"")
        }
    }
    return [ordered]@{
        fields = $extracted
        quotes = @($evidenceQuotes)
    }
}

function Invoke-ToolLoadAndExtractDossier {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $schema = $Context.SchemaMapping
    $rules = $Context.Rules
    $msg = $Context.Messages

    $rawRecord = $null
    foreach ($rec in $Context.RawApplicants) {
        $idVal = [string](Get-AliasedField -Obj $rec -Aliases @($schema.applicants_field_aliases.applicant_id) -Default "")
        if ($idVal -eq $ApplicantId) {
            $rawRecord = $rec
            break
        }
    }
    if ($null -eq $rawRecord) {
        throw "Applicant record not found: $ApplicantId"
    }

    $dossierFileRel = [string](Get-AliasedField -Obj $rawRecord -Aliases @($schema.applicants_field_aliases.dossier_file) -Default "")
    $rawText = [string](Get-AliasedField -Obj $rawRecord -Aliases @($schema.applicants_field_aliases.raw_text) -Default "")
    $sourceFiles = New-Object System.Collections.ArrayList
    [void]$sourceFiles.Add($Context.ApplicantsSourceName)

    if (-not [string]::IsNullOrWhiteSpace($dossierFileRel)) {
        $candidates = New-Object System.Collections.ArrayList
        if ([System.IO.Path]::IsPathRooted($dossierFileRel)) {
            [void]$candidates.Add($dossierFileRel)
        } else {
            [void]$candidates.Add((Join-Path $Context.DataDir $dossierFileRel))
            $leafName = [System.IO.Path]::GetFileName($dossierFileRel)
            [void]$candidates.Add((Join-Path $Context.DataDir $leafName))
            [void]$candidates.Add((Join-Path (Join-Path $Context.DataDir "dossiers") $leafName))
        }
        foreach ($cand in $candidates) {
            if (Test-Path -LiteralPath $cand) {
                $rawText = Read-Utf8Text -Path $cand
                [void]$sourceFiles.Add($dossierFileRel)
                break
            }
        }
    } elseif ([string]::IsNullOrWhiteSpace($rawText)) {
        $autoDossier = Join-Path (Join-Path $Context.DataDir "dossiers") "$ApplicantId.txt"
        if (Test-Path -LiteralPath $autoDossier) {
            $rawText = Read-Utf8Text -Path $autoDossier
            [void]$sourceFiles.Add("dossiers/$ApplicantId.txt")
        }
    }

    $textParse = Extract-FromDossierText -RawText $rawText -Messages $msg
    $textFields = $textParse.fields

    $merged = [ordered]@{
        applicant_id = $ApplicantId
        submitted_at = [string](Get-PropValue -Obj $rawRecord -Name "submitted_at" -Default "")
        source_files = @($sourceFiles)
        raw_text_length = if ($rawText) { $rawText.Length } else { 0 }
        raw_text_preview = if ($rawText) { if ($rawText.Length -gt 600) { $rawText.Substring(0, 600) + "..." } else { $rawText } } else { "" }
        evidence_quotes = @($textParse.quotes)
    }

    $stringFields = @("partner_name", "tax_id", "representative", "phone", "email", "region", "province", "district", "ward", "pos_address", "warranty_notes")
    foreach ($f in $stringFields) {
        $aliases = @($schema.applicants_field_aliases.$f)
        $val = Get-AliasedField -Obj $rawRecord -Aliases $aliases -Default $null
        if ($null -eq $val -and $textFields.Contains($f)) {
            $val = $textFields[$f]
        }
        $merged[$f] = if ($null -ne $val) { ([string]$val).Trim() } else { "" }
    }
    if ($merged.phone) {
        $merged["phone_normalized"] = Normalize-Phone -Phone $merged.phone
    } else {
        $merged["phone_normalized"] = ""
    }

    $merged["region"] = Resolve-NormalizedRegion -RawRegion $merged.region -RawProvince $merged.province -Rules $rules -Messages $msg

    $numFields = @("latitude", "longitude", "showroom_area_m2", "warranty_technicians", "monthly_purchase_vnd_million", "requested_credit_days", "requested_credit_limit_vnd_million", "requested_marketing_support_pct")
    foreach ($nf in $numFields) {
        $aliases = @($schema.applicants_field_aliases.$nf)
        $rawNum = Get-AliasedField -Obj $rawRecord -Aliases $aliases -Default $null
        $parsed = Try-ParseDoubleInvariant -Value $rawNum
        if ([double]::IsNaN($parsed) -and $textFields.Contains($nf)) {
            $parsed = [double]$textFields[$nf]
        }
        if ([double]::IsNaN($parsed)) {
            $merged[$nf] = $null
        } else {
            $merged[$nf] = $parsed
        }
    }

    # Track missing fields explicitly (never hallucinate values!)
    $missingFields = New-Object System.Collections.ArrayList
    $labels = $msg.labels
    if ([string]::IsNullOrWhiteSpace($merged.tax_id)) { [void]$missingFields.Add([string]$labels.missing_tax_id) }
    if ([string]::IsNullOrWhiteSpace($merged.pos_address)) { [void]$missingFields.Add([string]$labels.missing_pos_address) }
    if ($null -eq $merged.showroom_area_m2) { [void]$missingFields.Add([string]$labels.missing_showroom_area) }
    if ($null -eq $merged.warranty_technicians) { [void]$missingFields.Add([string]$labels.missing_warranty_tech) }
    if ($null -eq $merged.monthly_purchase_vnd_million) { [void]$missingFields.Add([string]$labels.missing_purchase_plan) }
    if ($null -eq $merged.requested_credit_days -or $null -eq $merged.requested_credit_limit_vnd_million) {
        [void]$missingFields.Add([string]$labels.missing_credit_request)
    }
    if ($merged.region -eq [string]$labels.unknown_region) { [void]$missingFields.Add([string]$labels.missing_region) }
    if ($null -eq $merged.latitude -or $null -eq $merged.longitude) {
        [void]$missingFields.Add([string]$labels.missing_coordinates)
    }
    $merged["missing_fields"] = @($missingFields)

    # Attach independent verification result row
    $verifRow = $null
    foreach ($vr in $Context.VerificationResults) {
        $vid = [string](Get-AliasedField -Obj $vr -Aliases @($schema.verification_results_field_aliases.applicant_id) -Default "")
        if ($vid -eq $ApplicantId) {
            $verifRow = $vr
            break
        }
    }
    if ($null -ne $verifRow) {
        $merged["verification"] = [ordered]@{
            record_found = $true
            identity_verified = ([string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.identity_verified) -Default "NOT_SUBMITTED")).Trim().ToUpperInvariant()
            pos_verified = ([string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.pos_verified) -Default "NOT_SUBMITTED")).Trim().ToUpperInvariant()
            warranty_verified = ([string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.warranty_verified) -Default "NOT_SUBMITTED")).Trim().ToUpperInvariant()
            financial_verified = ([string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.financial_verified) -Default "NOT_SUBMITTED")).Trim().ToUpperInvariant()
            verified_by = [string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.verified_by) -Default "")
            verification_date = [string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.verification_date) -Default "")
            verification_notes = [string](Get-AliasedField -Obj $verifRow -Aliases @($schema.verification_results_field_aliases.verification_notes) -Default "")
        }
    } else {
        $merged["verification"] = [ordered]@{
            record_found = $false
            identity_verified = "NOT_SUBMITTED"
            pos_verified = "NOT_SUBMITTED"
            warranty_verified = "NOT_SUBMITTED"
            financial_verified = "NOT_SUBMITTED"
            verified_by = ""
            verification_date = ""
            verification_notes = ""
        }
    }

    $Context.WorkState[$ApplicantId] = [ordered]@{ profile = $merged }
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_identity_territory_screening" -ToolName "tool_load_and_extract_dossier" -ApplicantId $ApplicantId `
        -ToolArgs ([ordered]@{ applicant_id = $ApplicantId }) `
        -EvidenceRefs @($sourceFiles) `
        -RuleIds @("SCHEMA_EXTRACTION", "VERIFICATION_JOIN") `
        -ToolResultSummary ([ordered]@{
            partner_name = $merged.partner_name
            region = $merged.region
            missing_fields_count = @($missingFields).Count
            verification_record_found = $merged.verification.record_found
        }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $merged
}

function Invoke-ToolCheckIdentityAndTerritory {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $state = $Context.WorkState[$ApplicantId]
    $p = $state.profile
    $schema = $Context.SchemaMapping
    $rules = $Context.Rules
    $msg = $Context.Messages.labels

    $identityMatches = New-Object System.Collections.ArrayList
    $simThreshold = [double]$rules.territory_policy.identity_name_similarity_threshold

    foreach ($ep in $Context.ExistingPartners) {
        $epId = [string](Get-AliasedField -Obj $ep -Aliases @($schema.existing_partners_field_aliases.partner_id) -Default "")
        $epName = [string](Get-AliasedField -Obj $ep -Aliases @($schema.existing_partners_field_aliases.partner_name) -Default "")
        $epTax = [string](Get-AliasedField -Obj $ep -Aliases @($schema.existing_partners_field_aliases.tax_id) -Default "")
        $epPhone = Normalize-Phone -Phone ([string](Get-AliasedField -Obj $ep -Aliases @($schema.existing_partners_field_aliases.phone) -Default ""))
        $epEmail = ([string](Get-AliasedField -Obj $ep -Aliases @($schema.existing_partners_field_aliases.email) -Default "")).Trim().ToLowerInvariant()
        $epStatus = ([string](Get-AliasedField -Obj $ep -Aliases @($schema.existing_partners_field_aliases.status) -Default "ACTIVE")).Trim().ToUpperInvariant()

        if (-not [string]::IsNullOrWhiteSpace($p.tax_id) -and -not [string]::IsNullOrWhiteSpace($epTax) -and ($p.tax_id.Trim() -eq $epTax.Trim())) {
            [void]$identityMatches.Add([ordered]@{
                match_type = "TAX_ID_EXACT"
                severity = "CONFIRMED_DUPLICATE"
                existing_partner_id = $epId
                existing_partner_name = $epName
                existing_status = $epStatus
                detail = ([string]$msg.identity_dup_tax -f $p.tax_id, $epId, $epName)
            })
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($p.phone_normalized) -and -not [string]::IsNullOrWhiteSpace($epPhone) -and ($p.phone_normalized -eq $epPhone)) {
            [void]$identityMatches.Add([ordered]@{
                match_type = "PHONE_EXACT"
                severity = "SUSPECTED_RELATED"
                existing_partner_id = $epId
                existing_partner_name = $epName
                existing_status = $epStatus
                detail = ([string]$msg.identity_dup_phone -f $p.phone, $epId, $epName)
            })
        }
        if (-not [string]::IsNullOrWhiteSpace($p.email) -and -not [string]::IsNullOrWhiteSpace($epEmail) -and ($p.email.Trim().ToLowerInvariant() -eq $epEmail)) {
            [void]$identityMatches.Add([ordered]@{
                match_type = "EMAIL_EXACT"
                severity = "SUSPECTED_RELATED"
                existing_partner_id = $epId
                existing_partner_name = $epName
                existing_status = $epStatus
                detail = ([string]$msg.identity_dup_email -f $p.email, $epId, $epName)
            })
        }
        $sim = Get-LevenshteinSimilarity -A $p.partner_name -B $epName
        $normA = Normalize-CompanyName -Text $p.partner_name
        $normB = Normalize-CompanyName -Text $epName
        $containsMatch = ($normA.Length -ge 8 -and $normB.Length -ge 8 -and ($normA.Contains($normB) -or $normB.Contains($normA)))
        if ($sim -ge $simThreshold -or $containsMatch) {
            $pct = [Math]::Round([Math]::Max($sim, 0.85) * 100, 1)
            [void]$identityMatches.Add([ordered]@{
                match_type = "NAME_SIMILARITY"
                severity = "SUSPECTED_RELATED"
                existing_partner_id = $epId
                existing_partner_name = $epName
                existing_status = $epStatus
                similarity = $sim
                detail = ([string]$msg.identity_sim_name -f $pct, $epId, $epName)
            })
        }
    }

    # Territory protection check
    $territoryConflicts = New-Object System.Collections.ArrayList
    $nearestPos = $null
    $nearestKm = [double]::PositiveInfinity

    $appProv = Normalize-AdminUnit -Text $p.province
    $appDist = Normalize-AdminUnit -Text $p.district
    $appWard = Normalize-AdminUnit -Text $p.ward

    $defaultRadius = [double]$rules.territory_policy.protection_radius_km
    $protectDistrict = [bool]$rules.territory_policy.protect_same_district
    $protectWard = [bool]$rules.territory_policy.protect_same_ward

    foreach ($pos in $Context.ExistingPos) {
        $posId = [string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.pos_id) -Default "")
        $posPartnerId = [string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.partner_id) -Default "")
        $posPartnerName = [string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.partner_name) -Default "")
        $posProvRaw = [string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.province) -Default "")
        $posDistRaw = [string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.district) -Default "")
        $posWardRaw = [string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.ward) -Default "")
        $posScope = ([string](Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.protection_scope) -Default "RADIUS_KM")).Trim().ToUpperInvariant()

        $posRadius = Try-ParseDoubleInvariant -Value (Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.protection_radius_km) -Default $null)
        if ([double]::IsNaN($posRadius)) { $posRadius = $defaultRadius }

        $posLat = Try-ParseDoubleInvariant -Value (Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.latitude) -Default $null)
        $posLon = Try-ParseDoubleInvariant -Value (Get-AliasedField -Obj $pos -Aliases @($schema.existing_pos_field_aliases.longitude) -Default $null)

        $distKm = $null
        if ($null -ne $p.latitude -and $null -ne $p.longitude -and -not [double]::IsNaN($posLat) -and -not [double]::IsNaN($posLon)) {
            $distKm = Get-HaversineDistanceKm -Lat1 ([double]$p.latitude) -Lon1 ([double]$p.longitude) -Lat2 $posLat -Lon2 $posLon
            if ($distKm -lt $nearestKm) {
                $nearestKm = $distKm
                $nearestPos = [ordered]@{ pos_id = $posId; partner_name = $posPartnerName; distance_km = $distKm; district = $posDistRaw; province = $posProvRaw }
            }
            if ($distKm -le $posRadius) {
                [void]$territoryConflicts.Add([ordered]@{
                    conflict_type = "RADIUS_BREACH"
                    pos_id = $posId
                    partner_id = $posPartnerId
                    partner_name = $posPartnerName
                    distance_km = $distKm
                    protection_radius_km = $posRadius
                    detail = ([string]$msg.territory_radius -f $posId, $posPartnerName, $posDistRaw, $distKm, $posRadius)
                })
            }
        }

        $posProv = Normalize-AdminUnit -Text $posProvRaw
        $posDist = Normalize-AdminUnit -Text $posDistRaw
        $posWard = Normalize-AdminUnit -Text $posWardRaw

        if ($protectDistrict -and $posScope.Contains("DISTRICT") -and
            -not [string]::IsNullOrEmpty($appProv) -and -not [string]::IsNullOrEmpty($appDist) -and
            $appProv -eq $posProv -and $appDist -eq $posDist) {
            [void]$territoryConflicts.Add([ordered]@{
                conflict_type = "SAME_PROTECTED_DISTRICT"
                pos_id = $posId
                partner_id = $posPartnerId
                partner_name = $posPartnerName
                detail = ([string]$msg.territory_district -f $p.district, $p.province, $posId, $posPartnerName)
            })
        } elseif ($protectWard -and $posScope.Contains("WARD") -and
            -not [string]::IsNullOrEmpty($appProv) -and -not [string]::IsNullOrEmpty($appDist) -and -not [string]::IsNullOrEmpty($appWard) -and
            $appProv -eq $posProv -and $appDist -eq $posDist -and $appWard -eq $posWard) {
            [void]$territoryConflicts.Add([ordered]@{
                conflict_type = "SAME_PROTECTED_WARD"
                pos_id = $posId
                partner_id = $posPartnerId
                partner_name = $posPartnerName
                detail = ([string]$msg.territory_ward -f $p.ward, $p.district, $p.province, $posId, $posPartnerName)
            })
        }
    }

    $result = [ordered]@{
        identity_status = if (@($identityMatches | Where-Object { $_.severity -eq "CONFIRMED_DUPLICATE" }).Count -gt 0) {
            "CONFIRMED_DUPLICATE"
        } elseif (@($identityMatches).Count -gt 0) {
            "SUSPECTED_RELATED"
        } else {
            "NEW_PARTNER"
        }
        identity_matches = @($identityMatches)
        territory_status = if (@($territoryConflicts).Count -gt 0) { "CONFLICT" } else { "CLEAR" }
        territory_conflicts = @($territoryConflicts)
        nearest_existing_pos = $nearestPos
        gps_check_performed = ($null -ne $p.latitude -and $null -ne $p.longitude)
    }
    $state["identity_territory"] = $result
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_identity_territory_screening" -ToolName "tool_check_identity_and_territory" -ApplicantId $ApplicantId `
        -ToolArgs ([ordered]@{ applicant_id = $ApplicantId }) `
        -EvidenceRefs @("existing_partners", "existing_pos") `
        -RuleIds @("IDENTITY_DEDUP_RULE", "TERRITORY_PROTECTION_RULE") `
        -ToolResultSummary ([ordered]@{
            identity_status = $result.identity_status
            identity_matches_count = @($identityMatches).Count
            territory_status = $result.territory_status
            territory_conflicts_count = @($territoryConflicts).Count
            nearest_km = if ($nearestPos) { $nearestPos.distance_km } else { $null }
        }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $result
}

function Invoke-ToolCheckMandatoryAndPolicyGates {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $state = $Context.WorkState[$ApplicantId]
    $p = $state.profile
    $v = $p.verification
    $rules = $Context.Rules
    $mc = $rules.mandatory_conditions
    $cp = $rules.credit_and_commercial_policy
    $msg = $Context.Messages.labels

    $failedConditions = New-Object System.Collections.ArrayList
    $policyViolations = New-Object System.Collections.ArrayList
    $unverifiedItems = New-Object System.Collections.ArrayList
    $rulesApplied = New-Object System.Collections.ArrayList

    # Mandatory conditions
    [void]$rulesApplied.Add("MANDATORY_GATES")
    if ([bool]$mc.require_tax_id -and [string]::IsNullOrWhiteSpace($p.tax_id)) {
        [void]$failedConditions.Add([string]$msg.fail_tax_id)
    }
    if ([bool]$mc.require_pos_address -and [string]::IsNullOrWhiteSpace($p.pos_address)) {
        [void]$failedConditions.Add([string]$msg.fail_pos_address)
    }
    if ($null -ne $p.showroom_area_m2 -and [double]$p.showroom_area_m2 -lt [double]$mc.min_showroom_area_m2) {
        [void]$failedConditions.Add(([string]$msg.fail_showroom_area -f $p.showroom_area_m2, $mc.min_showroom_area_m2))
    }
    if ([bool]$mc.require_warranty_capability -and $null -ne $p.warranty_technicians -and [double]$p.warranty_technicians -lt [double]$mc.min_warranty_technicians) {
        [void]$failedConditions.Add(([string]$msg.fail_warranty_tech -f $p.warranty_technicians, $mc.min_warranty_technicians))
    }
    if ($null -ne $p.monthly_purchase_vnd_million -and [double]$p.monthly_purchase_vnd_million -lt [double]$mc.min_monthly_purchase_vnd_million) {
        [void]$failedConditions.Add(([string]$msg.fail_min_purchase -f $p.monthly_purchase_vnd_million, $mc.min_monthly_purchase_vnd_million))
    }

    # Verification FAIL checks
    if ($v.pos_verified -eq "VERIFIED_FAIL") { [void]$failedConditions.Add([string]$msg.fail_pos_verified) }
    if ($v.warranty_verified -eq "VERIFIED_FAIL") { [void]$failedConditions.Add([string]$msg.fail_warranty_verified) }
    if ($v.financial_verified -eq "VERIFIED_FAIL") { [void]$failedConditions.Add([string]$msg.fail_financial_verified) }

    # Commercial & Credit Policy checks (strict boundary: > limit triggers violation; == limit passes)
    [void]$rulesApplied.Add("CREDIT_COMMERCIAL_POLICY")
    if ($null -ne $p.requested_credit_days -and [double]$p.requested_credit_days -gt [double]$cp.max_credit_days) {
        [void]$policyViolations.Add(([string]$msg.policy_credit_days -f $p.requested_credit_days, $cp.max_credit_days))
    }
    if ($null -ne $p.requested_credit_limit_vnd_million -and [double]$p.requested_credit_limit_vnd_million -gt [double]$cp.max_credit_limit_vnd_million) {
        [void]$policyViolations.Add(([string]$msg.policy_credit_limit -f $p.requested_credit_limit_vnd_million, $cp.max_credit_limit_vnd_million))
    }
    if ($null -ne $p.requested_marketing_support_pct -and [double]$p.requested_marketing_support_pct -gt [double]$cp.max_marketing_support_pct) {
        [void]$policyViolations.Add(([string]$msg.policy_marketing_support -f $p.requested_marketing_support_pct, $cp.max_marketing_support_pct))
    }
    if ($null -ne $p.requested_credit_limit_vnd_million -and
        [double]$p.requested_credit_limit_vnd_million -gt [double]$cp.require_financial_proof_above_vnd_million -and
        $v.financial_verified -ne "VERIFIED_PASS") {
        [void]$policyViolations.Add(([string]$msg.policy_fin_proof -f $p.requested_credit_limit_vnd_million, $cp.require_financial_proof_above_vnd_million))
    }

    # Independent Verification Gate (Never treat applicant's commitments as verified!)
    [void]$rulesApplied.Add("INDEPENDENT_EVIDENCE_GATE")
    $resolvedStatuses = @("VERIFIED_PASS", "VERIFIED_FAIL")
    if ($resolvedStatuses -notcontains $v.identity_verified) { [void]$unverifiedItems.Add("identity") }
    if ($resolvedStatuses -notcontains $v.pos_verified) { [void]$unverifiedItems.Add("pos") }
    if ($resolvedStatuses -notcontains $v.warranty_verified) { [void]$unverifiedItems.Add("warranty") }
    if ($resolvedStatuses -notcontains $v.financial_verified) { [void]$unverifiedItems.Add("financial") }

    $highCommitmentThreshold = [double]$rules.decision_thresholds.high_commitment_threshold_vnd_million
    $hasHighCommitment = ($null -ne $p.monthly_purchase_vnd_million -and [double]$p.monthly_purchase_vnd_million -ge $highCommitmentThreshold)
    $unverifiedHighCommitment = ($hasHighCommitment -and (@($unverifiedItems | Where-Object { $_ -in @("pos", "warranty", "financial") }).Count -gt 0))

    $gates = [ordered]@{
        mandatory_passed = (@($failedConditions).Count -eq 0 -and @($p.missing_fields | Where-Object { $_ -ne $msg.missing_coordinates }).Count -eq 0)
        failed_conditions = @($failedConditions)
        policy_compliant = (@($policyViolations).Count -eq 0)
        policy_violations = @($policyViolations)
        all_independent_verified = (@($unverifiedItems).Count -eq 0)
        unverified_dimensions = @($unverifiedItems)
        unverified_high_commitment_warning = $unverifiedHighCommitment
        commitment_note = if ($unverifiedHighCommitment) { [string]$msg.unverified_commitment_note } else { "" }
    }
    $state["gates"] = $gates
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_identity_territory_screening" -ToolName "tool_check_mandatory_and_policy_gates" -ApplicantId $ApplicantId `
        -ToolArgs ([ordered]@{ applicant_id = $ApplicantId }) `
        -EvidenceRefs @("rules_config", "verification_results") `
        -RuleIds @($rulesApplied) `
        -ToolResultSummary ([ordered]@{
            mandatory_passed = $gates.mandatory_passed
            policy_compliant = $gates.policy_compliant
            all_independent_verified = $gates.all_independent_verified
            unverified_high_commitment_warning = $gates.unverified_high_commitment_warning
        }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $gates
}

function Invoke-ToolEvaluateCriteriaAndPriority {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $state = $Context.WorkState[$ApplicantId]
    $p = $state.profile
    $v = $p.verification
    $rules = $Context.Rules
    $cp = $rules.credit_and_commercial_policy

    $capMap = @{}
    foreach ($c in $rules.evaluation_criteria) {
        $capMap[$c.id] = [double]$c.unverified_cap_ratio
    }

    # C1: POS & Market Coverage (Max 25)
    $c1Raw = 0.0
    if ($null -ne $p.showroom_area_m2) {
        $area = [double]$p.showroom_area_m2
        if ($area -ge 120) { $c1Raw = 25.0 }
        elseif ($area -ge 80) { $c1Raw = 22.0 }
        elseif ($area -ge 40) { $c1Raw = 18.0 }
        else { $c1Raw = 6.0 }
    }
    $c1Verified = if ($v.pos_verified -eq "VERIFIED_FAIL") { 0.0 }
                  elseif ($v.pos_verified -eq "VERIFIED_PASS") { $c1Raw }
                  else { [Math]::Round($c1Raw * $capMap["C1_POS_COVERAGE"], 2) }

    # C2: Warranty & Service Capability (Max 30)
    $c2Raw = 0.0
    if ($null -ne $p.warranty_technicians) {
        $tech = [double]$p.warranty_technicians
        if ($tech -ge 3) { $c2Raw = 30.0 }
        elseif ($tech -ge 2) { $c2Raw = 25.0 }
        elseif ($tech -ge 1) { $c2Raw = 20.0 }
        else { $c2Raw = 0.0 }
    }
    $c2Verified = if ($v.warranty_verified -eq "VERIFIED_FAIL") { 0.0 }
                  elseif ($v.warranty_verified -eq "VERIFIED_PASS") { $c2Raw }
                  else { [Math]::Round($c2Raw * $capMap["C2_WARRANTY_SERVICE"], 2) }

    # C3: Purchase Plan & Commercial Fit (Max 20)
    $c3Raw = 0.0
    if ($null -ne $p.monthly_purchase_vnd_million) {
        $pur = [double]$p.monthly_purchase_vnd_million
        if ($pur -ge 450) { $c3Raw = 20.0 }
        elseif ($pur -ge 300) { $c3Raw = 18.0 }
        elseif ($pur -ge 150) { $c3Raw = 15.0 }
        else { $c3Raw = 6.0 }
    }
    $opsVerified = ($v.pos_verified -eq "VERIFIED_PASS" -and $v.warranty_verified -eq "VERIFIED_PASS")
    $c3Verified = if ($opsVerified) { $c3Raw } else { [Math]::Round($c3Raw * $capMap["C3_PURCHASE_PLAN"], 2) }

    # C4: Financial & Credit Compliance (Max 25)
    $c4Raw = 25.0
    if ($null -eq $p.requested_credit_days -or $null -eq $p.requested_credit_limit_vnd_million) {
        $c4Raw = 10.0
    } else {
        if ([double]$p.requested_credit_days -gt [double]$cp.max_credit_days) { $c4Raw -= 8.0 }
        if ([double]$p.requested_credit_limit_vnd_million -gt [double]$cp.max_credit_limit_vnd_million) { $c4Raw -= 8.0 }
        if ($null -ne $p.requested_marketing_support_pct -and [double]$p.requested_marketing_support_pct -gt [double]$cp.max_marketing_support_pct) { $c4Raw -= 8.0 }
        if ($c4Raw -lt 0.0) { $c4Raw = 0.0 }
    }
    $c4Verified = if ($v.financial_verified -eq "VERIFIED_FAIL") { 0.0 }
                  elseif ($v.financial_verified -eq "VERIFIED_PASS") { $c4Raw }
                  else { [Math]::Round($c4Raw * $capMap["C4_FINANCIAL_COMPLIANCE"], 2) }

    $totalClaimed = [Math]::Round($c1Raw + $c2Raw + $c3Raw + $c4Raw, 2)
    $totalVerified = [Math]::Round($c1Verified + $c2Verified + $c3Verified + $c4Verified, 2)

    $scoring = [ordered]@{
        claimed_score = $totalClaimed
        verified_score = $totalVerified
        breakdown = @(
            [ordered]@{ id = "C1_POS_COVERAGE"; weight = 25; claimed = $c1Raw; verified = $c1Verified; evidence_status = $v.pos_verified },
            [ordered]@{ id = "C2_WARRANTY_SERVICE"; weight = 30; claimed = $c2Raw; verified = $c2Verified; evidence_status = $v.warranty_verified },
            [ordered]@{ id = "C3_PURCHASE_PLAN"; weight = 20; claimed = $c3Raw; verified = $c3Verified; evidence_status = if ($opsVerified) { "VERIFIED_PASS" } else { "UNVERIFIED_CAPPED" } },
            [ordered]@{ id = "C4_FINANCIAL_COMPLIANCE"; weight = 25; claimed = $c4Raw; verified = $c4Verified; evidence_status = $v.financial_verified }
        )
    }
    $state["scoring"] = $scoring
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_scoring_priority_and_escalation" -ToolName "tool_evaluate_criteria_and_priority" -ApplicantId $ApplicantId `
        -ToolArgs ([ordered]@{ applicant_id = $ApplicantId }) `
        -EvidenceRefs @("evaluation_criteria", "verification_results") `
        -RuleIds @("WEIGHTED_SCORING_V1", "UNVERIFIED_SCORE_CAP") `
        -ToolResultSummary ([ordered]@{
            claimed_score = $totalClaimed
            verified_score = $totalVerified
        }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $scoring
}

function Invoke-ToolDetermineEscalationAndRecommendation {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $state = $Context.WorkState[$ApplicantId]
    $p = $state.profile
    $v = $p.verification
    $idTerr = $state.identity_territory
    $gates = $state.gates
    $scoring = $state.scoring
    $rules = $Context.Rules
    $msg = $Context.Messages
    $labels = $msg.labels

    $escalations = New-Object System.Collections.ArrayList
    $escalationCodes = New-Object System.Collections.ArrayList
    $verifyTasks = New-Object System.Collections.ArrayList

    if ($idTerr.identity_status -eq "CONFIRMED_DUPLICATE" -or $idTerr.identity_status -eq "SUSPECTED_RELATED") {
        [void]$escalationCodes.Add("IDENTITY_DUPLICATE")
        $escCfg = $rules.escalation_mapping.IDENTITY_DUPLICATE
        $details = ($idTerr.identity_matches | ForEach-Object { $_.detail }) -join "; "
        [void]$escalations.Add([ordered]@{
            code = "IDENTITY_DUPLICATE"
            label = [string]$escCfg.label
            escalate_to = [string]$escCfg.escalate_to
            detail = $details
        })
        [void]$verifyTasks.Add([ordered]@{ department = [string]$msg.departments.SALES; task = [string]$labels.verify_identity })
    }

    if ($idTerr.territory_status -eq "CONFLICT") {
        [void]$escalationCodes.Add("TERRITORY_CONFLICT")
        $escCfg = $rules.escalation_mapping.TERRITORY_CONFLICT
        $details = ($idTerr.territory_conflicts | ForEach-Object { $_.detail }) -join "; "
        [void]$escalations.Add([ordered]@{
            code = "TERRITORY_CONFLICT"
            label = [string]$escCfg.label
            escalate_to = [string]$escCfg.escalate_to
            detail = $details
        })
        [void]$verifyTasks.Add([ordered]@{ department = [string]$msg.departments.SALES; task = [string]$labels.verify_territory })
    }

    if (-not $gates.policy_compliant) {
        [void]$escalationCodes.Add("POLICY_EXCEEDED")
        $escCfg = $rules.escalation_mapping.POLICY_EXCEEDED
        [void]$escalations.Add([ordered]@{
            code = "POLICY_EXCEEDED"
            label = [string]$escCfg.label
            escalate_to = [string]$escCfg.escalate_to
            detail = ($gates.policy_violations -join "; ")
        })
        [void]$verifyTasks.Add([ordered]@{ department = [string]$msg.departments.FINANCE; task = [string]$labels.verify_finance })
    }

    $nonGpsMissing = @($p.missing_fields | Where-Object { $_ -ne [string]$labels.missing_coordinates })
    if (-not $gates.all_independent_verified -or @($nonGpsMissing).Count -gt 0) {
        if ($gates.unverified_high_commitment_warning -or (@($gates.unverified_dimensions).Count -gt 0) -or (@($nonGpsMissing).Count -gt 0)) {
            [void]$escalationCodes.Add("MISSING_EVIDENCE")
            $escCfg = $rules.escalation_mapping.MISSING_EVIDENCE
            $detailParts = New-Object System.Collections.ArrayList
            if ($gates.unverified_high_commitment_warning) { [void]$detailParts.Add([string]$labels.unverified_commitment_note) }
            if (@($gates.unverified_dimensions).Count -gt 0) { [void]$detailParts.Add(([string]$labels.unverified_prefix) + ": " + ($gates.unverified_dimensions -join ", ")) }
            if (@($nonGpsMissing).Count -gt 0) { [void]$detailParts.Add(($nonGpsMissing -join "; ")) }
            [void]$escalations.Add([ordered]@{
                code = "MISSING_EVIDENCE"
                label = [string]$escCfg.label
                escalate_to = [string]$escCfg.escalate_to
                detail = ($detailParts -join " | ")
            })
        }
    }

    # Build verification checklist by department
    if ($v.pos_verified -ne "VERIFIED_PASS" -and $v.pos_verified -ne "VERIFIED_FAIL") {
        [void]$verifyTasks.Add([ordered]@{ department = [string]$msg.departments.OPS; task = [string]$labels.verify_pos })
    }
    if ($v.warranty_verified -ne "VERIFIED_PASS" -and $v.warranty_verified -ne "VERIFIED_FAIL") {
        [void]$verifyTasks.Add([ordered]@{ department = [string]$msg.departments.OPS; task = [string]$labels.verify_warranty })
    }
    if ($v.financial_verified -ne "VERIFIED_PASS" -and $v.financial_verified -ne "VERIFIED_FAIL") {
        $alreadyFin = @($verifyTasks | Where-Object { $_.department -eq [string]$msg.departments.FINANCE }).Count -gt 0
        if (-not $alreadyFin) {
            [void]$verifyTasks.Add([ordered]@{ department = [string]$msg.departments.FINANCE; task = [string]$labels.verify_finance })
        }
    }
    if (@($nonGpsMissing).Count -gt 0) {
        [void]$verifyTasks.Add([ordered]@{
            department = [string]$msg.departments.SALES
            task = ([string]$labels.verify_missing_data -f ($nonGpsMissing -join ", "))
        })
    }

    # Decision Logic
    $dt = $rules.decision_thresholds
    $vScore = [double]$scoring.verified_score
    $recCode = ""
    $prioCode = ""

    $hasHardFail = ($v.pos_verified -eq "VERIFIED_FAIL" -or $v.warranty_verified -eq "VERIFIED_FAIL" -or $v.financial_verified -eq "VERIFIED_FAIL")

    if ($idTerr.identity_status -eq "CONFIRMED_DUPLICATE") {
        $recCode = "NOT_CONTINUE"
        $prioCode = "REJECT"
    } elseif ($hasHardFail -or ($vScore -lt [double]$dt.supplement_min_score -and $gates.all_independent_verified -and @($nonGpsMissing).Count -eq 0)) {
        $recCode = "NOT_CONTINUE"
        $prioCode = "REJECT"
    } elseif ($idTerr.territory_status -eq "CONFLICT" -or $idTerr.identity_status -eq "SUSPECTED_RELATED" -or (-not $gates.policy_compliant)) {
        $recCode = "SUPPLEMENT"
        $prioCode = "HOLD"
    } elseif ((-not $gates.mandatory_passed) -or (-not $gates.all_independent_verified) -or ($vScore -lt [double]$dt.continue_min_score)) {
        $recCode = "SUPPLEMENT"
        $prioCode = "P3"
    } else {
        $recCode = "CONTINUE"
        if ($vScore -ge [double]$dt.priority_p1_min_score) { $prioCode = "P1" }
        else { $prioCode = "P2" }
    }

    $evidenceBasis = New-Object System.Collections.ArrayList
    foreach ($q in $p.evidence_quotes) { [void]$evidenceBasis.Add($q) }
    if ($v.record_found) {
        [void]$evidenceBasis.Add("Verification ($($v.verified_by) - $($v.verification_date)): $($v.verification_notes)")
    }
    if ($idTerr.nearest_existing_pos) {
        $np = $idTerr.nearest_existing_pos
        [void]$evidenceBasis.Add("Nearest POS: $($np.pos_id) ($($np.partner_name), $($np.district)) = $($np.distance_km) km")
    }

    $allFailed = New-Object System.Collections.ArrayList
    foreach ($fc in $gates.failed_conditions) { [void]$allFailed.Add($fc) }
    foreach ($pv in $gates.policy_violations) { [void]$allFailed.Add($pv) }
    foreach ($im in $idTerr.identity_matches) { [void]$allFailed.Add($im.detail) }
    foreach ($tc in $idTerr.territory_conflicts) { [void]$allFailed.Add($tc.detail) }

    $decision = [ordered]@{
        recommendation_code = $recCode
        recommendation_label = [string]$msg.recommendations.$recCode
        priority_code = $prioCode
        priority_label = [string]$msg.priorities.$prioCode
        requires_human_escalation = (@($escalations).Count -gt 0)
        escalation_codes = @($escalationCodes)
        escalations = @($escalations)
        verification_tasks = @($verifyTasks)
        failed_and_conflict_items = @($allFailed)
        unknown_or_missing_items = @($p.missing_fields)
        evidence_basis = @($evidenceBasis)
    }
    $state["decision"] = $decision
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_scoring_priority_and_escalation" -ToolName "tool_determine_escalation_and_recommendation" -ApplicantId $ApplicantId `
        -ToolArgs ([ordered]@{ applicant_id = $ApplicantId }) `
        -EvidenceRefs @("gates", "scoring", "identity_territory") `
        -RuleIds @("DECISION_MATRIX", "ESCALATION_ROUTING") `
        -ToolResultSummary ([ordered]@{
            recommendation = $decision.recommendation_label
            priority = $decision.priority_label
            requires_human_escalation = $decision.requires_human_escalation
            escalation_codes = @($escalationCodes)
        }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $decision
}

function Invoke-ToolDraftPartnerCommunication {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [Parameter(Mandatory=$true)][string]$ApplicantId
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $state = $Context.WorkState[$ApplicantId]
    $p = $state.profile
    $d = $state.decision
    $msg = $Context.Messages

    $tpl = $msg.draft_templates.($d.recommendation_code)
    $repDisplay = if ([string]::IsNullOrWhiteSpace($p.representative)) { "Quý đối tác" } else { $p.representative }
    $partnerDisplay = if ([string]::IsNullOrWhiteSpace($p.partner_name)) { $ApplicantId } else { $p.partner_name }

    $evBullets = if (@($d.evidence_basis).Count -gt 0) {
        ($d.evidence_basis | Select-Object -First 4 | ForEach-Object { "- $_" }) -join "`n"
    } else { "- Theo hồ sơ đăng ký đã tiếp nhận." }

    $failBullets = if (@($d.failed_and_conflict_items).Count -gt 0) {
        ($d.failed_and_conflict_items | ForEach-Object { "- $_" }) -join "`n"
    } else { [string]$msg.labels.no_failed_conditions }

    $verifyBullets = if (@($d.verification_tasks).Count -gt 0) {
        ($d.verification_tasks | ForEach-Object { "- [$($_.department)] $($_.task)" }) -join "`n"
    } else { [string]$msg.labels.no_verification_needed }

    $subject = ([string]$tpl.subject).
        Replace("{partner_name}", $partnerDisplay).
        Replace("{applicant_id}", $ApplicantId)

    $body = ([string]$tpl.body).
        Replace("{partner_name}", $partnerDisplay).
        Replace("{representative}", $repDisplay).
        Replace("{region}", $p.region).
        Replace("{applicant_id}", $ApplicantId).
        Replace("{priority}", $d.priority_label).
        Replace("{evidence_bullets}", $evBullets).
        Replace("{failed_bullets}", $failBullets).
        Replace("{verify_bullets}", $verifyBullets).
        Replace("{extra_note}", [string]$msg.labels.extra_note_continue)

    $draft = [ordered]@{
        applicant_id = $ApplicantId
        to_email = $p.email
        subject = $subject
        body = $body
        generated_by = "template_grounded_tool"
    }
    $state["draft"] = $draft
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_reporting_coordination_and_drafting" -ToolName "tool_draft_partner_communication" -ApplicantId $ApplicantId `
        -ToolArgs ([ordered]@{ applicant_id = $ApplicantId; recommendation_code = $d.recommendation_code }) `
        -EvidenceRefs @("decision", "messages_vi_templates") `
        -RuleIds @("PARTNER_DRAFT_TEMPLATE") `
        -ToolResultSummary ([ordered]@{ subject = $subject; to_email = $p.email }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $draft
}

function Invoke-ToolGenerateRegionalSummaryAndPlan {
    param(
        [Parameter(Mandatory=$true)]$Context,
        [bool]$IncludeDraftPreviews = $true
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $rules = $Context.Rules
    $msg = $Context.Messages

    $rankMap = @{ "CONTINUE" = 1; "SUPPLEMENT" = 2; "NOT_CONTINUE" = 3 }
    $orderedApplicants = @($Context.WorkState.Keys | ForEach-Object { $Context.WorkState[$_] } |
        Sort-Object { $rankMap[$_.decision.recommendation_code] }, { -1 * [double]$_.scoring.verified_score }, { $_.profile.applicant_id })

    $regionsList = New-Object System.Collections.ArrayList
    foreach ($r in $rules.regions) { [void]$regionsList.Add([string]$r) }
    $unknownLabel = [string]$msg.labels.unknown_region
    foreach ($item in $orderedApplicants) {
        if (-not ($regionsList -contains $item.profile.region)) {
            [void]$regionsList.Add($item.profile.region)
        }
    }

    $regionalGroups = New-Object System.Collections.ArrayList
    foreach ($reg in $regionsList) {
        $items = @($orderedApplicants | Where-Object { $_.profile.region -eq $reg })
        if ($reg -eq $unknownLabel -and @($items).Count -eq 0) { continue }
        $cntContinue = @($items | Where-Object { $_.decision.recommendation_code -eq "CONTINUE" }).Count
        $cntSupp = @($items | Where-Object { $_.decision.recommendation_code -eq "SUPPLEMENT" }).Count
        $cntNot = @($items | Where-Object { $_.decision.recommendation_code -eq "NOT_CONTINUE" }).Count
        $cntEsc = @($items | Where-Object { $_.decision.requires_human_escalation }).Count

        $rows = @($items | ForEach-Object {
            [ordered]@{
                applicant_id = $_.profile.applicant_id
                partner_name = $_.profile.partner_name
                province_district = "$($_.profile.district), $($_.profile.province)".Trim(', ')
                claimed_score = $_.scoring.claimed_score
                verified_score = $_.scoring.verified_score
                priority = $_.decision.priority_label
                recommendation = $_.decision.recommendation_label
                recommendation_code = $_.decision.recommendation_code
                requires_escalation = $_.decision.requires_human_escalation
                escalation_codes = $_.decision.escalation_codes
                unverified_high_commitment = $_.gates.unverified_high_commitment_warning
            }
        })
        [void]$regionalGroups.Add([ordered]@{
            region = $reg
            total = @($items).Count
            continue_count = $cntContinue
            supplement_count = $cntSupp
            not_continue_count = $cntNot
            escalation_count = $cntEsc
            partners = $rows
        })
    }

    # Escalation Register
    $escalationRegister = New-Object System.Collections.ArrayList
    foreach ($item in $orderedApplicants) {
        if ($item.decision.requires_human_escalation) {
            [void]$escalationRegister.Add([ordered]@{
                applicant_id = $item.profile.applicant_id
                partner_name = $item.profile.partner_name
                region = $item.profile.region
                recommendation = $item.decision.recommendation_label
                verified_score = $item.scoring.verified_score
                claimed_score = $item.scoring.claimed_score
                escalations = $item.decision.escalations
            })
        }
    }

    # Cross-Department Verification Coordination Plan
    $deptPlan = New-Object System.Collections.ArrayList
    foreach ($item in $orderedApplicants) {
        foreach ($vt in $item.decision.verification_tasks) {
            [void]$deptPlan.Add([ordered]@{
                department = $vt.department
                applicant_id = $item.profile.applicant_id
                partner_name = $item.profile.partner_name
                region = $item.profile.region
                current_status = $item.decision.recommendation_label
                task = $vt.task
                priority = $item.decision.priority_label
            })
        }
    }

    $summary = [ordered]@{
        generated_at = [DateTimeOffset]::UtcNow.ToString("o")
        total_applicants = @($orderedApplicants).Count
        continue_count = @($orderedApplicants | Where-Object { $_.decision.recommendation_code -eq "CONTINUE" }).Count
        supplement_count = @($orderedApplicants | Where-Object { $_.decision.recommendation_code -eq "SUPPLEMENT" }).Count
        not_continue_count = @($orderedApplicants | Where-Object { $_.decision.recommendation_code -eq "NOT_CONTINUE" }).Count
        escalation_count = @($escalationRegister).Count
        regional_summary = @($regionalGroups)
        escalation_register = @($escalationRegister)
        verification_plan = @($deptPlan)
    }
    $Context["Summary"] = $summary
    $sw.Stop()

    [void](Add-AuditEvent -LogList $Context.AuditLogs -RunId $Context.RunId -EventType "TOOL_RESULT" `
        -SkillName "partner_reporting_coordination_and_drafting" -ToolName "tool_generate_regional_summary_and_plan" -ApplicantId "ALL" `
        -ToolArgs ([ordered]@{ include_draft_previews = $IncludeDraftPreviews }) `
        -EvidenceRefs @("all_applicant_decisions") `
        -RuleIds @("REGIONAL_GROUPING", "DEPARTMENT_PLAN_ROUTING") `
        -ToolResultSummary ([ordered]@{
            total_applicants = $summary.total_applicants
            continue_count = $summary.continue_count
            supplement_count = $summary.supplement_count
            not_continue_count = $summary.not_continue_count
            escalation_count = $summary.escalation_count
            verification_tasks_count = @($deptPlan).Count
        }) -DurationMs ([int]$sw.ElapsedMilliseconds))

    return $summary
}
