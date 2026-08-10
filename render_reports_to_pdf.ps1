[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactsRoot,

    [Parameter(Mandatory = $false)]
    [string]$RunFolder,

    [Parameter(Mandatory = $false)]
    [string]$BrandingConfig = "config/report-branding.json",

    [Parameter(Mandatory = $false)]
    [string]$PandocPath,

    [Parameter(Mandatory = $false)]
    [string]$WkhtmltopdfPath
)

$ErrorActionPreference = "Stop"

function Resolve-ToolPath {
    param(
        [string]$ToolName,
        [string]$ExplicitPath,
        [string[]]$FallbackPaths
    )

    if ($ExplicitPath) {
        if (Test-Path $ExplicitPath) {
            return (Resolve-Path $ExplicitPath).Path
        }
        throw "Explicit path for '$ToolName' was provided but does not exist: $ExplicitPath"
    }

    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $cmd -and $cmd.Source) { return $cmd.Source }

    foreach ($candidate in $FallbackPaths) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Get-LatestRunFolder {
    param([string]$RootPath)

    $dirs = Get-ChildItem -Path $RootPath -Directory -ErrorAction Stop |
        Where-Object { $_.Name -match "^\d{8}_\d{6}$" } |
        Sort-Object LastWriteTimeUtc -Descending

    if (-not $dirs) {
        throw "No timestamped run folder found in '$RootPath'. Expected artifacts/<yyyyMMdd_HHmmss>/."
    }

    return $dirs[0].FullName
}

function To-HexWithoutHash {
    param([string]$ColorValue)

    $trimmed = $ColorValue.Trim()
    if ($trimmed.StartsWith("#")) { return $trimmed.Substring(1) }
    return $trimmed
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsRootPath = if ([System.IO.Path]::IsPathRooted($ArtifactsRoot)) { $ArtifactsRoot } else { Join-Path $repoRoot $ArtifactsRoot }
$brandingPath = if ([System.IO.Path]::IsPathRooted($BrandingConfig)) { $BrandingConfig } else { Join-Path $repoRoot $BrandingConfig }

if (-not (Test-Path $artifactsRootPath)) {
    throw "Artifacts root not found: $artifactsRootPath"
}
if (-not (Test-Path $brandingPath)) {
    throw "Branding config not found: $brandingPath"
}

$branding = Get-Content -Path $brandingPath -Raw -Encoding UTF8 | ConvertFrom-Json

$resolvedRunFolder = if ($RunFolder) {
    if ([System.IO.Path]::IsPathRooted($RunFolder)) { $RunFolder } else { Join-Path $artifactsRootPath $RunFolder }
} else {
    Get-LatestRunFolder -RootPath $artifactsRootPath
}

if (-not (Test-Path $resolvedRunFolder)) {
    throw "Run folder not found: $resolvedRunFolder"
}

$pandocExe = Resolve-ToolPath -ToolName "pandoc" -ExplicitPath $PandocPath -FallbackPaths @(
    (Join-Path $env:ProgramFiles "Pandoc\pandoc.exe"),
    (Join-Path $env:LocalAppData "Pandoc\pandoc.exe")
)
if (-not $pandocExe) {
    throw "pandoc is not installed or not on PATH. Install command: choco install pandoc -y"
}

$wkhtmlExe = Resolve-ToolPath -ToolName "wkhtmltopdf" -ExplicitPath $WkhtmltopdfPath -FallbackPaths @(
    (Join-Path $env:ProgramFiles "wkhtmltopdf\bin\wkhtmltopdf.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "wkhtmltopdf\bin\wkhtmltopdf.exe")
)
$xelatexExe = Resolve-ToolPath -ToolName "xelatex" -ExplicitPath $null -FallbackPaths @()

if (-not $wkhtmlExe -and -not $xelatexExe) {
    throw "Neither wkhtmltopdf nor xelatex was found. Install one of: 'choco install wkhtmltopdf -y' or 'choco install miktex -y'."
}

$engine = if ($wkhtmlExe) { "wkhtmltopdf" } else { "xelatex" }

$templateHtml = Join-Path $repoRoot "tools/reporting/templates/report-template.html"
$templateCss = Join-Path $repoRoot "tools/reporting/templates/report-style.css"
$templateTex = Join-Path $repoRoot "tools/reporting/templates/latex-template.tex"

if (-not (Test-Path $templateHtml)) { throw "Template missing: $templateHtml" }
if (-not (Test-Path $templateCss)) { throw "Template missing: $templateCss" }
if ($engine -eq "xelatex" -and -not (Test-Path $templateTex)) { throw "Template missing: $templateTex" }

$pdfRoot = Join-Path $resolvedRunFolder "pdf"
New-Item -ItemType Directory -Path $pdfRoot -Force | Out-Null

$tempDir = Join-Path $env:TEMP ("report-render-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $logoPath = if ([System.IO.Path]::IsPathRooted($branding.logoPath)) { $branding.logoPath } else { Join-Path $repoRoot $branding.logoPath }
    if (-not (Test-Path $logoPath)) {
        Write-Warning "Logo file not found at '$logoPath'. Header will show a broken image until logo is provided."
    }

    $logoUri = ([System.Uri]$logoPath).AbsoluteUri
    $cssOut = Join-Path $tempDir "report-style.rendered.css"
    $htmlTemplateOut = Join-Path $tempDir "report-template.rendered.html"

    $cssContent = Get-Content -Path $templateCss -Raw -Encoding UTF8
    $cssContent = $cssContent.Replace("__PRIMARY_COLOR__", [string]$branding.primaryColor)
    $cssContent = $cssContent.Replace("__SECONDARY_COLOR__", [string]$branding.secondaryColor)
    $cssContent = $cssContent.Replace("__FONT_FAMILY__", [string]$branding.fontFamily)
    Set-Content -Path $cssOut -Value $cssContent -Encoding UTF8

    $htmlTemplateContent = Get-Content -Path $templateHtml -Raw -Encoding UTF8
    $htmlTemplateContent = $htmlTemplateContent.Replace("__LOGO_URL__", $logoUri)
    Set-Content -Path $htmlTemplateOut -Value $htmlTemplateContent -Encoding UTF8

    $runTimestamp = Split-Path -Leaf $resolvedRunFolder
    $mdFiles = Get-ChildItem -Path $resolvedRunFolder -Recurse -File -Filter *.md |
        Where-Object { $_.FullName -notlike "*\pdf\*" }

    $total = @($mdFiles).Count
    $converted = 0
    $failed = 0
    $failedFiles = New-Object System.Collections.Generic.List[string]

    Write-Host "Artifacts root : $artifactsRootPath"
    Write-Host "Run folder     : $resolvedRunFolder"
    Write-Host "PDF output root: $pdfRoot"
    Write-Host "Markdown files : $total"
    Write-Host "PDF engine     : $engine"
    Write-Host "pandoc exe     : $pandocExe"
    if ($wkhtmlExe) { Write-Host "wkhtmltopdf exe: $wkhtmlExe" } else { Write-Host "xelatex exe    : $xelatexExe" }

    foreach ($md in $mdFiles) {
        $relative = $md.FullName.Substring($resolvedRunFolder.Length).TrimStart('\')
        $relativePdf = [System.IO.Path]::ChangeExtension($relative, ".pdf")
        $targetPdf = Join-Path $pdfRoot $relativePdf
        $targetDir = Split-Path -Parent $targetPdf
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $reportTitle = [System.IO.Path]::GetFileNameWithoutExtension($md.Name)

        try {
            if ($engine -eq "wkhtmltopdf") {
                $args = @(
                    "--from", "gfm",
                    "--to", "html5",
                    "--standalone",
                    "--template", $htmlTemplateOut,
                    "--css", $cssOut,
                    "--metadata", "title=$reportTitle",
                    "--metadata", "run_timestamp=$runTimestamp",
                    "--pdf-engine=$wkhtmlExe",
                    "--pdf-engine-opt=--enable-local-file-access",
                    "--pdf-engine-opt=--encoding",
                    "--pdf-engine-opt=UTF-8",
                    "--pdf-engine-opt=--page-size",
                    "--pdf-engine-opt=A4",
                    "--pdf-engine-opt=--margin-top",
                    "--pdf-engine-opt=20mm",
                    "--pdf-engine-opt=--margin-right",
                    "--pdf-engine-opt=15mm",
                    "--pdf-engine-opt=--margin-bottom",
                    "--pdf-engine-opt=20mm",
                    "--pdf-engine-opt=--margin-left",
                    "--pdf-engine-opt=15mm",
                    "--pdf-engine-opt=--footer-left",
                    "--pdf-engine-opt=$reportTitle | $runTimestamp",
                    "--pdf-engine-opt=--footer-center",
                    "--pdf-engine-opt=$($branding.footerText)",
                    "--pdf-engine-opt=--footer-right",
                    "--pdf-engine-opt=Page [page] of [topage]",
                    "--pdf-engine-opt=--footer-font-size",
                    "--pdf-engine-opt=8",
                    "--pdf-engine-opt=--footer-spacing",
                    "--pdf-engine-opt=5",
                    "--output", $targetPdf,
                    $md.FullName
                )
            } else {
                $args = @(
                    "--from", "gfm",
                    "--standalone",
                    "--template", $templateTex,
                    "--metadata", "title=$reportTitle",
                    "--metadata", "run_timestamp=$runTimestamp",
                    "--metadata", "footer_text=$($branding.footerText)",
                    "--metadata", "logo_path=$logoPath",
                    "--metadata", "mainfont=$($branding.fontFamily)",
                    "--metadata", "primarycolorhex=$(To-HexWithoutHash -ColorValue ([string]$branding.primaryColor))",
                    "--metadata", "secondarycolorhex=$(To-HexWithoutHash -ColorValue ([string]$branding.secondaryColor))",
                    "--pdf-engine=$xelatexExe",
                    "--output", $targetPdf,
                    $md.FullName
                )
            }

            & $pandocExe @args
            if ($LASTEXITCODE -ne 0) {
                throw "pandoc exited with code $LASTEXITCODE"
            }

            $converted++
            Write-Host "[OK] $relative -> $targetPdf"
        }
        catch {
            $failed++
            $failedFiles.Add("$relative :: $($_.Exception.Message)") | Out-Null
            Write-Host "[FAIL] $relative :: $($_.Exception.Message)"
        }
    }

    Write-Host ""
    Write-Host "========== PDF Rendering Summary =========="
    Write-Host "Total markdown files : $total"
    Write-Host "Converted            : $converted"
    Write-Host "Failed               : $failed"
    Write-Host "Output folder        : $pdfRoot"
    Write-Host "==========================================="

    if ($failed -gt 0) {
        Write-Host "Failed files:"
        $failedFiles | ForEach-Object { Write-Host " - $_" }
        exit 1
    }

    exit 0
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}
