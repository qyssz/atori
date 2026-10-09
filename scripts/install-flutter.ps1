[CmdletBinding()]
param([string]$SdkRoot = 'D:\atori-sdk')
$ErrorActionPreference = 'Stop'
$sdkDirectory = [System.IO.Path]::GetFullPath($SdkRoot)
if ($sdkDirectory -eq [System.IO.Path]::GetPathRoot($sdkDirectory)) { throw 'SDK root cannot be a drive root.' }
if ($sdkDirectory -match '[^\x00-\x7F]|\s') { throw 'Use a writable ASCII SDK path without spaces.' }
New-Item -ItemType Directory -Path $sdkDirectory -Force | Out-Null
$flutterCommand = Join-Path $sdkDirectory 'flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutterCommand)) {
    $metadata = Invoke-RestMethod -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    $release = $metadata.releases | Where-Object { $_.hash -eq $metadata.current_release.stable } | Select-Object -First 1
    if (-not $release.sha256) { throw 'Official archive checksum is missing.' }
    $archive = Join-Path $sdkDirectory (Split-Path -Leaf $release.archive)
    Write-Output "Downloading official Flutter stable $($release.version) to $archive"
    if (-not (Test-Path -LiteralPath $archive)) {
        & curl.exe --fail --location --retry 3 --silent --show-error --output $archive "https://storage.googleapis.com/flutter_infra_release/releases/$($release.archive)"
        if ($LASTEXITCODE -ne 0) { throw 'Flutter SDK download failed.' }
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $release.sha256) {
        throw 'Flutter archive checksum mismatch. Do not use this archive.'
    }
    Write-Output 'Checksum verified. Extracting Flutter SDK.'
    & tar.exe -xf $archive -C $sdkDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Flutter extraction failed.' }
}
$env:CI = 'true'
$env:PUB_CACHE = Join-Path $sdkDirectory 'pub-cache'
$env:TEMP = Join-Path $sdkDirectory 'temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Path $env:PUB_CACHE,$env:TEMP -Force | Out-Null
& $flutterCommand --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter version check failed.' }
Write-Output "Flutter ready at $flutterCommand. System PATH was not changed."
