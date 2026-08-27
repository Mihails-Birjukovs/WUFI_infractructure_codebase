@echo off
setlocal

rem ---------------------------------------------------------------------------
rem Extract the main XML file from every WUFI .w6p project in this folder.
rem Each extracted file is renamed to match its source project:
rem
rem     Example_model.w6p  ->  Example_model.xml
rem
rem Existing same-named XML files are replaced only after successful extraction
rem and XML validation.
rem ---------------------------------------------------------------------------

set "WUFI_BATCH_SELF=%~f0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=$env:WUFI_BATCH_SELF; $lines=[IO.File]::ReadAllLines($p); $marker=[Array]::IndexOf($lines,'# POWERSHELL'); if($marker -lt 0){throw 'Embedded PowerShell section not found.'}; & ([ScriptBlock]::Create(($lines[($marker+1)..($lines.Length-1)] -join [Environment]::NewLine)))"

set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo Finished successfully.
) else (
    echo Finished with one or more errors. Exit code: %RC%
)

echo.
pause
exit /b %RC%

# POWERSHELL

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$folder = [IO.Path]::GetDirectoryName($env:WUFI_BATCH_SELF)
$projects = @(Get-ChildItem -LiteralPath $folder -Filter '*.w6p' -File |
              Sort-Object Name)

if ($projects.Count -eq 0) {
    Write-Host "No .w6p files were found in:"
    Write-Host "  $folder"
    exit 0
}

$successCount = 0
$failureCount = 0

Write-Host "Folder:"
Write-Host "  $folder"
Write-Host ""
Write-Host "WUFI projects found: $($projects.Count)"
Write-Host ""

foreach ($project in $projects) {
    $archive = $null
    $temporaryPath = $null

    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($project.FullName)

        # Prefer WUFI's normal project XML name, regardless of archive subfolder.
        $preferredEntries = @(
            $archive.Entries |
            Where-Object { $_.Name -ieq 'wufi1d.xml' } |
            Sort-Object @{ Expression = { $_.FullName.Split('/').Count } },
                        FullName
        )

        if ($preferredEntries.Count -gt 0) {
            $xmlEntry = $preferredEntries[0]
        }
        else {
            # Fallback: accept a single XML file if wufi1d.xml is absent.
            $allXmlEntries = @(
                $archive.Entries |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.Name) -and
                    $_.Name -match '(?i)\.xml$'
                }
            )

            if ($allXmlEntries.Count -eq 0) {
                throw "No XML file was found inside the archive."
            }

            if ($allXmlEntries.Count -gt 1) {
                $names = ($allXmlEntries.FullName -join ', ')
                throw "Several XML files were found, but none was named wufi1d.xml: $names"
            }

            $xmlEntry = $allXmlEntries[0]
        }

        $outputPath = [IO.Path]::Combine(
            $folder,
            $project.BaseName + '.xml'
        )

        $temporaryPath = [IO.Path]::Combine(
            $folder,
            '.' + $project.BaseName + '.' +
            [guid]::NewGuid().ToString('N') + '.xml.tmp'
        )

        # Extract only the XML entry. The large WUFI result .tmp files are ignored.
        $inputStream = $xmlEntry.Open()
        try {
            $outputStream = [IO.File]::Open(
                $temporaryPath,
                [IO.FileMode]::CreateNew,
                [IO.FileAccess]::Write,
                [IO.FileShare]::None
            )

            try {
                $inputStream.CopyTo($outputStream)
            }
            finally {
                $outputStream.Dispose()
            }
        }
        finally {
            $inputStream.Dispose()
        }

        # Confirm that the extracted file is well-formed XML before replacing
        # any existing same-named output file.
        $readerSettings = New-Object System.Xml.XmlReaderSettings
        $readerSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $readerSettings.XmlResolver = $null

        $reader = [System.Xml.XmlReader]::Create(
            $temporaryPath,
            $readerSettings
        )

        try {
            while ($reader.Read()) {
                # Reading the full document performs the validation.
            }
        }
        finally {
            $reader.Dispose()
        }

        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force
        }

        Move-Item -LiteralPath $temporaryPath -Destination $outputPath
        $temporaryPath = $null

        Write-Host "[OK]    $($project.Name)"
        Write-Host "        -> $([IO.Path]::GetFileName($outputPath))"
        $successCount++
    }
    catch {
        if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath)) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host "[ERROR] $($project.Name)" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        $failureCount++
    }
    finally {
        if ($archive) {
            $archive.Dispose()
        }
    }
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Extracted successfully: $successCount"
Write-Host "  Failed:                 $failureCount"

if ($failureCount -gt 0) {
    exit 1
}

exit 0
