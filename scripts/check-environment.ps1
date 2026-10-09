<#
Read-only file and tool discovery for the future Flutter Android project.
Does not invoke Flutter, download packages, or modify the environment.
Exit codes: 0 = preflight passed, 1 = missing prerequisites, 2 = inspection error.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$FlutterRoot,
    [string]$AndroidSdkRoot,
    [string]$JavaHome,
    [ValidateRange(23, 1000)]
    [int]$MinimumAndroidApi = 35,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ToolPath {
    param([string]$Name, [string]$Root, [string]$RelativePath)
    if ($Root) {
        $candidate = Join-Path $Root $RelativePath
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
        return $null
    }
    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return $command.Source }
    return $null
}

function New-Check {
    param([string]$Id, [string]$Category, [bool]$Present, [string]$Path, [string]$Action)
    [PSCustomObject]@{
        id = $Id
        category = $Category
        present = $Present
        path = $Path
        action = $(if ($Present) { '' } else { $Action })
    }
}

try {
    if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw 'ProjectRoot must be an existing directory.'
    }
    $resolvedProject = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $checks = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($relativePath in @('PROJECT_SPEC.md', 'pubspec.yaml', 'lib/main.dart', 'android/app/src/main/AndroidManifest.xml')) {
        $filePath = Join-Path $resolvedProject $relativePath
        $checks.Add((New-Check -Id $relativePath -Category 'project' `
            -Present (Test-Path -LiteralPath $filePath -PathType Leaf) -Path $filePath `
            -Action 'Create or locate the application project; preserve existing documentation.'))
    }
    foreach ($relativePath in @('test', 'assets/mock')) {
        $directoryPath = Join-Path $resolvedProject $relativePath
        $checks.Add((New-Check -Id $relativePath -Category 'project' `
            -Present (Test-Path -LiteralPath $directoryPath -PathType Container) -Path $directoryPath `
            -Action 'Add the required tests or mock assets during development.'))
    }

    $effectiveFlutterRoot = $FlutterRoot
    if (-not $effectiveFlutterRoot) { $effectiveFlutterRoot = $env:FLUTTER_ROOT }
    $flutterPath = Get-ToolPath -Name 'flutter' -Root $effectiveFlutterRoot -RelativePath 'bin/flutter.bat'
    $checks.Add((New-Check -Id 'flutter' -Category 'tool' -Present ([bool]$flutterPath) `
        -Path $flutterPath -Action 'Locate/install Flutter and add its bin directory to PATH, or pass -FlutterRoot.'))
    if ($effectiveFlutterRoot) {
        $dartPath = Get-ToolPath -Name 'dart' -Root $effectiveFlutterRoot -RelativePath 'bin/dart.bat'
    } elseif ($flutterPath) {
        $dartCandidate = Join-Path (Split-Path -Parent $flutterPath) 'dart.bat'
        if (Test-Path -LiteralPath $dartCandidate -PathType Leaf) {
            $dartPath = $dartCandidate
        } else {
            $dartPath = Get-ToolPath -Name 'dart'
        }
    } else {
        $dartPath = Get-ToolPath -Name 'dart'
    }
    $checks.Add((New-Check -Id 'dart' -Category 'tool' -Present ([bool]$dartPath) `
        -Path $dartPath -Action 'Use the Dart command bundled with Flutter.'))

    $effectiveJavaHome = $JavaHome
    if (-not $effectiveJavaHome) { $effectiveJavaHome = $env:JAVA_HOME }
    foreach ($javaTool in @('java', 'javac')) {
        $javaPath = Get-ToolPath -Name $javaTool -Root $effectiveJavaHome -RelativePath "bin/$javaTool.exe"
        $checks.Add((New-Check -Id $javaTool -Category 'tool' -Present ([bool]$javaPath) `
            -Path $javaPath -Action 'Locate a compatible JDK, then verify Flutter/Gradle compatibility.'))
    }
    $gitPath = Get-ToolPath -Name 'git'
    $checks.Add((New-Check -Id 'git' -Category 'tool' -Present ([bool]$gitPath) `
        -Path $gitPath -Action 'Install Git for Windows and make it discoverable.'))

    $effectiveAndroidRoot = $AndroidSdkRoot
    if (-not $effectiveAndroidRoot) { $effectiveAndroidRoot = $env:ANDROID_HOME }
    if (-not $effectiveAndroidRoot) { $effectiveAndroidRoot = $env:ANDROID_SDK_ROOT }
    if (-not $effectiveAndroidRoot -and $env:LOCALAPPDATA) {
        $effectiveAndroidRoot = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
    }
    $androidPresent = [bool]($effectiveAndroidRoot -and (Test-Path -LiteralPath $effectiveAndroidRoot -PathType Container))
    $checks.Add((New-Check -Id 'android-sdk' -Category 'tool' -Present $androidPresent `
        -Path $effectiveAndroidRoot -Action 'Locate/install Android SDK or pass -AndroidSdkRoot.'))

    $adbPath = $null
    $platformPath = $null
    $buildToolsPath = $null
    $sdkManagerPath = $null
    if ($androidPresent) {
        $adbPath = Get-ToolPath -Name 'adb' -Root $effectiveAndroidRoot -RelativePath 'platform-tools/adb.exe'
        $platformsRoot = Join-Path $effectiveAndroidRoot 'platforms'
        if (Test-Path -LiteralPath $platformsRoot -PathType Container) {
            $platformPath = Get-ChildItem -LiteralPath $platformsRoot -Directory |
                Where-Object {
                    $_.Name -match '^android-(\d+)$' -and [int]$Matches[1] -ge $MinimumAndroidApi -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName 'android.jar') -PathType Leaf)
                } | Sort-Object { [int]($_.Name -replace '^android-', '') } -Descending |
                Select-Object -First 1 -ExpandProperty FullName
        }
        $buildToolsRoot = Join-Path $effectiveAndroidRoot 'build-tools'
        if (Test-Path -LiteralPath $buildToolsRoot -PathType Container) {
            $buildToolsPath = Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
                Where-Object {
                    (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt2.exe') -PathType Leaf) -and
                    (Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') -PathType Leaf)
                } | Select-Object -First 1 -ExpandProperty FullName
        }
        $commandToolsRoot = Join-Path $effectiveAndroidRoot 'cmdline-tools'
        if (Test-Path -LiteralPath $commandToolsRoot -PathType Container) {
            $sdkManagerPath = Get-ChildItem -LiteralPath $commandToolsRoot -Directory |
                ForEach-Object { Join-Path $_.FullName 'bin/sdkmanager.bat' } |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        }
    }
    $checks.Add((New-Check -Id 'adb' -Category 'tool' -Present ([bool]$adbPath) `
        -Path $adbPath -Action 'Install Android SDK Platform-Tools in the selected SDK.'))
    $checks.Add((New-Check -Id 'android-platform' -Category 'tool' -Present ([bool]$platformPath) `
        -Path $platformPath -Action "Install an Android platform with android.jar and API >= $MinimumAndroidApi."))
    $checks.Add((New-Check -Id 'android-build-tools' -Category 'tool' -Present ([bool]$buildToolsPath) `
        -Path $buildToolsPath -Action 'Install Android SDK Build-Tools (aapt2 and apksigner).'))
    $checks.Add((New-Check -Id 'sdkmanager' -Category 'tool' -Present ([bool]$sdkManagerPath) `
        -Path $sdkManagerPath -Action 'Install Android SDK Command-line Tools.'))

    if (-not (Test-Path -LiteralPath (Join-Path $resolvedProject '.git'))) {
        $warnings.Add('No local .git metadata; check parent/worktree context before initializing Git.')
    }
    $warnings.Add('File discovery does not verify versions, licenses, devices, runtime behavior, or build compatibility. Run flutter doctor -v afterwards.')
    $missing = @($checks | Where-Object { -not $_.present } | Select-Object -ExpandProperty id)
    $report = [PSCustomObject]@{
        schemaVersion = 1
        projectRoot = $resolvedProject
        minimumAndroidApi = $MinimumAndroidApi
        preflightPassed = ($missing.Count -eq 0)
        checks = @($checks.ToArray())
        missing = $missing
        warnings = @($warnings.ToArray())
    }
    if ($Json) {
        $report | ConvertTo-Json -Depth 6
    } else {
        Write-Output "Project: $resolvedProject"
        foreach ($check in $checks) {
            $label = if ($check.present) { 'PRESENT' } else { 'MISSING' }
            Write-Output "[$label] $($check.id)"
            if ($check.path) { Write-Output "  $($check.path)" }
            if ($check.action) { Write-Output "  $($check.action)" }
        }
        foreach ($warning in $warnings) { Write-Output "WARNING: $warning" }
        Write-Output "Preflight passed: $($report.preflightPassed)"
    }
    if ($report.preflightPassed) { exit 0 }
    exit 1
} catch {
    if ($Json) {
        [PSCustomObject]@{schemaVersion=1; preflightPassed=$false; error=$_.Exception.Message} |
            ConvertTo-Json -Depth 3
    } else {
        Write-Output "Inspection failed: $($_.Exception.Message)"
    }
    exit 2
}
