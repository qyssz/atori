[CmdletBinding()]
param([string]$SdkRoot = 'D:\atori-sdk', [string]$JavaHome, [switch]$AcceptLicenses)
$ErrorActionPreference = 'Stop'
$sdkDirectory = [System.IO.Path]::GetFullPath($SdkRoot)
if ($sdkDirectory -eq [System.IO.Path]::GetPathRoot($sdkDirectory) -or $sdkDirectory -match '[^\x00-\x7F]|\s') {
    throw 'Use a dedicated writable ASCII SDK path, not a drive root.'
}
New-Item -ItemType Directory -Path $sdkDirectory -Force | Out-Null

function Get-VerifiedArchive {
    param([string]$Url, [string]$Path, [string]$Checksum, [string]$Algorithm = 'SHA256')
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output "Downloading $Url"
        & curl.exe --fail --location --retry 3 --connect-timeout 30 --max-time 900 --silent --show-error --output $Path $Url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    }
    if ((Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant() -ne $Checksum.ToLowerInvariant()) {
        throw "Checksum mismatch: $Path"
    }
}

$jdkDirectory = Get-ChildItem -LiteralPath $sdkDirectory -Directory -Filter 'jdk-17*' | Select-Object -First 1
if (-not $JavaHome -and -not $jdkDirectory) {
    $javaMetadata = Invoke-RestMethod -Uri 'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'
    $package = $javaMetadata[0].binary.package
    $javaArchive = Join-Path $sdkDirectory $package.name
    Get-VerifiedArchive -Url $package.link -Path $javaArchive -Checksum $package.checksum
    & tar.exe -xf $javaArchive -C $sdkDirectory
    if ($LASTEXITCODE -ne 0) { throw 'JDK extraction failed.' }
    $jdkDirectory = Get-ChildItem -LiteralPath $sdkDirectory -Directory -Filter 'jdk-17*' | Select-Object -First 1
}
if ($JavaHome) {
    $effectiveJavaHome = [System.IO.Path]::GetFullPath($JavaHome)
} elseif ($jdkDirectory) {
    $effectiveJavaHome = $jdkDirectory.FullName
} else {
    throw 'No JDK was found.'
}
if (-not (Test-Path -LiteralPath (Join-Path $effectiveJavaHome 'bin/java.exe'))) {
    throw 'JDK 17 is incomplete.'
}
$env:JAVA_HOME = $effectiveJavaHome
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$androidDirectory = Join-Path $sdkDirectory 'android'
$manager = Join-Path $androidDirectory 'cmdline-tools/latest/bin/sdkmanager.bat'
if (-not (Test-Path -LiteralPath $manager)) {
    [xml]$repository = (Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/repository2-3.xml').Content
    $archiveNode = $repository.SelectNodes("//*[local-name()='remotePackage' and @path='cmdline-tools;latest']/*[local-name()='archives']/*[local-name()='archive']") |
        Where-Object { $_.'host-os' -eq 'windows' } | Select-Object -First 1
    $complete = $archiveNode.SelectSingleNode("./*[local-name()='complete']")
    $checksumNode = $complete.SelectSingleNode("./*[local-name()='checksum']")
    $urlNode = $complete.SelectSingleNode("./*[local-name()='url']")
    $algorithm = $checksumNode.GetAttribute('type').ToUpperInvariant().Replace('-', '')
    if ($algorithm -notin @('SHA1', 'SHA256')) { throw 'Unsupported official archive checksum type.' }
    $toolsArchive = Join-Path $sdkDirectory $urlNode.InnerText
    Get-VerifiedArchive -Url "https://dl.google.com/android/repository/$($urlNode.InnerText)" `
        -Path $toolsArchive -Checksum $checksumNode.InnerText -Algorithm $algorithm
    $toolsStage = Join-Path $sdkDirectory 'android-tools-stage'
    New-Item -ItemType Directory -Path $toolsStage -Force | Out-Null
    & tar.exe -xf $toolsArchive -C $toolsStage
    if ($LASTEXITCODE -ne 0) { throw 'Android tools extraction failed.' }
    $sourceDirectory = [System.IO.Path]::GetFullPath((Join-Path $toolsStage 'cmdline-tools'))
    $targetDirectory = [System.IO.Path]::GetFullPath((Join-Path $androidDirectory 'cmdline-tools/latest'))
    $allowedPrefix = $sdkDirectory.TrimEnd('\') + '\'
    if (-not $sourceDirectory.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not $targetDirectory.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'SDK staging paths escaped the intended SDK directory.'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetDirectory) -Force | Out-Null
    if (Test-Path -LiteralPath $targetDirectory) { throw 'Partial SDK exists. Inspect it before retrying.' }
    Move-Item -LiteralPath $sourceDirectory -Destination $targetDirectory
}
if (-not $AcceptLicenses) {
    Write-Output "Read and accept Android licenses: & '$manager' --sdk_root='$androidDirectory' --licenses"
    exit 1
}
$androidCli = Join-Path $androidDirectory 'cmdline-tools/latest/bin/android.exe'
if (Test-Path -LiteralPath $androidCli) {
    foreach ($component in @('platform-tools', 'platforms/android-36', 'platforms/android-35', 'build-tools/36.0.0', 'ndk/28.2.13676358', 'cmake/3.22.1')) {
        & $androidCli --no-metrics --sdk $androidDirectory sdk install $component
        if ($LASTEXITCODE -ne 0) { throw "Android component installation failed: $component" }
    }
} else {
    1..100 | ForEach-Object { 'y' } | & $manager "--sdk_root=$androidDirectory" --licenses
    if ($LASTEXITCODE -ne 0) { throw 'Android license acceptance failed.' }
    & $manager "--sdk_root=$androidDirectory" 'platform-tools' 'platforms;android-36' 'platforms;android-35' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
    if ($LASTEXITCODE -ne 0) { throw 'Android SDK component installation failed.' }
}
foreach ($required in @('platform-tools/adb.exe', 'platforms/android-36/android.jar', 'platforms/android-35/android.jar', 'build-tools/36.0.0/apksigner.bat', 'ndk/28.2.13676358/source.properties', 'cmake/3.22.1/bin/cmake.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $androidDirectory $required))) { throw "Incomplete Android SDK: $required" }
}
Write-Output "Android SDK ready: $androidDirectory"
Write-Output "JDK ready: $env:JAVA_HOME"
