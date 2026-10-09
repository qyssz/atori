[CmdletBinding()]
param(
    [ValidateSet('prepare','check','test','build-apk','build-web','doctor','pub-get')]
    [string]$Action = 'check',
    [string]$SdkRoot = 'D:\atori-sdk',
    [string]$JavaHome = 'D:\编程\jdk',
    [switch]$Clean
)
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkDirectory = [System.IO.Path]::GetFullPath($SdkRoot)
if ($sdkDirectory -match '[^\x00-\x7F]|\s' -or $sdkDirectory -eq [System.IO.Path]::GetPathRoot($sdkDirectory)) {
    throw 'Use a dedicated ASCII SDK directory.'
}
$buildDirectory = Join-Path $sdkDirectory 'atori-workspace'
$flutter = Join-Path $sdkDirectory 'flutter/bin/flutter.bat'
$dart = Join-Path $sdkDirectory 'flutter/bin/dart.bat'
$env:CI = 'true'
$env:PUB_CACHE = Join-Path $sdkDirectory 'pub-cache'
$env:TEMP = Join-Path $sdkDirectory 'temp'
$env:TMP = $env:TEMP
$env:GRADLE_USER_HOME = Join-Path $sdkDirectory 'gradle-cache'
$env:ANDROID_HOME = Join-Path $sdkDirectory 'android'
$env:JAVA_HOME = $JavaHome
$env:PATH = "$(Join-Path $sdkDirectory 'flutter/bin');$JavaHome\bin;$env:PATH"
New-Item -ItemType Directory -Path $buildDirectory,$env:TEMP -Force | Out-Null
if ($Action -eq 'doctor') {
    & $flutter doctor -v
    exit $LASTEXITCODE
}
Write-Output "Syncing source to ASCII build directory: $buildDirectory"
if ($Action -eq 'check') {
    & $dart format (Join-Path $projectDirectory 'lib') (Join-Path $projectDirectory 'test')
    if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
}
& robocopy.exe $projectDirectory $buildDirectory /E /XJ /XD .git .dart_tool build .bootstrap .gradle .cxx artifacts /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -gt 7) { throw 'Build workspace synchronization failed.' }
$gradleArchive = Join-Path $sdkDirectory 'gradle-9.3.1-bin.zip'
if ($Action -eq 'build-apk' -and (Test-Path -LiteralPath $gradleArchive)) {
    $wrapperPath = Join-Path $buildDirectory 'android/gradle/wrapper/gradle-wrapper.properties'
    $wrapperText = [System.IO.File]::ReadAllText($wrapperPath)
    $expected = [regex]::Match($wrapperText, '(?m)^distributionSha256Sum=(\w+)').Groups[1].Value
    if (-not $expected -or (Get-FileHash -LiteralPath $gradleArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
        throw 'Local Gradle archive checksum mismatch.'
    }
    $localUrl = ([Uri]$gradleArchive).AbsoluteUri
    $wrapperText = [regex]::Replace($wrapperText, '(?m)^distributionUrl=.*$', "distributionUrl=$localUrl")
    [System.IO.File]::WriteAllText($wrapperPath, $wrapperText, [System.Text.UTF8Encoding]::new($false))
}
Push-Location $buildDirectory
try {
    if ($Clean) {
        & $flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed.' }
    }
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    if ($Action -eq 'prepare' -or $Action -eq 'pub-get') { exit 0 }
    if ($Action -eq 'check') {
        & $dart format lib test
        if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
        & $flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
        & $flutter test
    } elseif ($Action -eq 'test') {
        & $flutter test
    } elseif ($Action -eq 'build-apk') {
        & $flutter build apk --release
        if ($LASTEXITCODE -eq 0) {
            $outputDirectory = Join-Path $projectDirectory 'build/app/outputs/flutter-apk'
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $buildDirectory 'build/app/outputs/flutter-apk/app-release.apk') -Destination $outputDirectory
        }
    } elseif ($Action -eq 'build-web') {
        & $flutter build web --release --no-web-resources-cdn
        if ($LASTEXITCODE -eq 0) {
            $outputParent = Join-Path $projectDirectory 'build'
            New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $buildDirectory 'build/web') -Destination $outputParent -Recurse -Force
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Flutter $Action failed." }
} finally {
    Pop-Location
}
