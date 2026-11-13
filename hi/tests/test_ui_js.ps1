$ErrorActionPreference = "Stop"
$js = Get-Content (Join-Path $PSScriptRoot "..\web\app.js") -Raw -Encoding UTF8
$html = Get-Content (Join-Path $PSScriptRoot "..\web\index.html") -Raw -Encoding UTF8
$css = Get-Content (Join-Path $PSScriptRoot "..\web\styles.css") -Raw -Encoding UTF8

$checks = @(
    @{ Name = "app.js has pendingAttachments"; Ok = $js.Contains("pendingAttachments") },
    @{ Name = "app.js has DOSSIER_JSON_KEY_MAP"; Ok = $js.Contains("DOSSIER_JSON_KEY_MAP") },
    @{ Name = "app.js has extractFieldsFromText"; Ok = $js.Contains("extractFieldsFromText") },
    @{ Name = "app.js has extractFieldsFromCsv"; Ok = $js.Contains("extractFieldsFromCsv") },
    @{ Name = "app.js has processDossierFile"; Ok = $js.Contains("processDossierFile") },
    @{ Name = "app.js has processAttachmentFiles"; Ok = $js.Contains("processAttachmentFiles") },
    @{ Name = "app.js has renderAttachmentsList"; Ok = $js.Contains("renderAttachmentsList") },
    @{ Name = "app.js has removePendingAttachment"; Ok = $js.Contains("removePendingAttachment") },
    @{ Name = "app.js has dropzone listeners"; Ok = $js.Contains("createDossierDropzone") },
    @{ Name = "app.js has cfDossierFileInput listener"; Ok = $js.Contains("cfDossierFileInput") },
    @{ Name = "app.js has cfAttachmentsInput listener"; Ok = $js.Contains("cfAttachmentsInput") },
    @{ Name = "app.js has attachment links in loadTargetDatasetDossiers"; Ok = $js.Contains("/api/attachments/") },
    @{ Name = "index.html has createDossierDropzone"; Ok = $html.Contains('id="createDossierDropzone"') },
    @{ Name = "index.html has cfDossierFileInput"; Ok = $html.Contains('id="cfDossierFileInput"') },
    @{ Name = "index.html has cfAttachmentsInput"; Ok = $html.Contains('id="cfAttachmentsInput"') },
    @{ Name = "index.html has cfLoadedFileBadge"; Ok = $html.Contains('id="cfLoadedFileBadge"') },
    @{ Name = "index.html has cfAttachmentsList"; Ok = $html.Contains('id="cfAttachmentsList"') },
    @{ Name = "styles.css has upload-dropzone"; Ok = $css.Contains(".upload-dropzone") },
    @{ Name = "styles.css has dragover"; Ok = $css.Contains(".upload-dropzone.dragover") },
    @{ Name = "styles.css has attachment-chip"; Ok = $css.Contains(".attachment-chip") },
    @{ Name = "styles.css has attachment-chip-remove"; Ok = $css.Contains(".attachment-chip-remove") },
    @{ Name = "styles.css has loaded-file-badge"; Ok = $css.Contains(".loaded-file-badge") }
)

$passed = 0
foreach ($c in $checks) {
    if ($c.Ok) {
        Write-Output ("[PASS] " + $c.Name)
        $passed++
    } else {
        Write-Error ("[FAIL] " + $c.Name)
    }
}

Write-Output ("ALL_UI_CHECKS_PASSED: $passed/" + $checks.Count)

