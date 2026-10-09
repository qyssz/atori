[CmdletBinding()]
param([string]$SdkRoot = 'D:\atori-sdk')
$ErrorActionPreference = 'Stop'
$sdkDirectory = [System.IO.Path]::GetFullPath($SdkRoot)
if ($sdkDirectory -eq [System.IO.Path]::GetPathRoot($sdkDirectory)) { throw 'Use a dedicated SDK directory.' }
$archive = Join-Path $sdkDirectory 'gradle-9.3.1-bin.zip'
$expected = (Invoke-RestMethod -Uri 'https://downloads.gradle.org/distributions/gradle-9.3.1-bin.zip.sha256').Trim()
if (-not (Test-Path -LiteralPath $archive)) {
    & curl.exe --fail --location --retry 2 --connect-timeout 30 --max-time 600 --silent --show-error `
        --output $archive 'https://repo.huaweicloud.com/gradle/gradle-9.3.1-bin.zip'
    if ($LASTEXITCODE -ne 0) { throw 'Gradle archive download failed.' }
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Gradle archive does not match the official SHA-256.'
}
Write-Output "Verified official Gradle 9.3.1 archive: $archive"
