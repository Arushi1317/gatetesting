# Reporting PDF Pipeline

This repository supports conversion of markdown reports under `artifacts/<yyyyMMdd_HHmmss>/` into branded PDF files.

## Prerequisites

- PowerShell 7+
- `pandoc`
- One PDF engine:
  - Preferred: `wkhtmltopdf`
  - Fallback: `xelatex` (from TeX distribution)

Windows install examples:

```powershell
choco install pandoc -y
choco install wkhtmltopdf -y
# Optional fallback engine:
choco install miktex -y
```

## Branding configuration

Branding values are read from:

`config/report-branding.json`

Configurable values:
- `logoPath`
- `primaryColor`
- `secondaryColor`
- `fontFamily`
- `footerText`

## Local run

```powershell
.\scripts\render_reports_to_pdf.ps1 -ArtifactsRoot artifacts
```

Optional explicit run folder:

```powershell
.\scripts\render_reports_to_pdf.ps1 -ArtifactsRoot artifacts -RunFolder 20260724_174058 -BrandingConfig config/report-branding.json
```

Optional explicit tool paths (recommended on Windows if PATH differs between shells):

```powershell
.\scripts\render_reports_to_pdf.ps1 `
  -ArtifactsRoot artifacts `
  -RunFolder 20260724_174058 `
  -BrandingConfig config/report-branding.json `
  -PandocPath "$env:ProgramFiles\Pandoc\pandoc.exe" `
  -WkhtmltopdfPath "$env:ProgramFiles\wkhtmltopdf\bin\wkhtmltopdf.exe"
```

## Output layout

For each markdown file:

- Input: `artifacts/<run>/.../*.md`
- Output: `artifacts/<run>/pdf/.../*.pdf`

Folder structure under `pdf/` mirrors source paths under the run folder.

## Troubleshooting

### pandoc not found

Install pandoc and retry:

```powershell
choco install pandoc -y
```

### neither wkhtmltopdf nor xelatex found

Install one engine:

```powershell
choco install wkhtmltopdf -y
# OR
choco install miktex -y
```

### logo not rendering

- Verify `config/report-branding.json -> logoPath`
- Ensure file exists in repository and is accessible
- For `wkhtmltopdf`, local file access is enabled by script

### Important invocation guidance

- Run the script directly in the current shell.
- Avoid nested `powershell -Command "...$env:Path=...; ..."` wrappers because they commonly break quoting and PATH propagation on Windows.
