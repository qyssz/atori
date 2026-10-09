[CmdletBinding()]
param([string]$SdkRoot='D:\atori-sdk',[string]$JavaHome='D:\编程\jdk')
$ErrorActionPreference='Stop'
$sdkDirectory=[System.IO.Path]::GetFullPath($SdkRoot)
if($sdkDirectory -eq [System.IO.Path]::GetPathRoot($sdkDirectory)) { throw 'Use a dedicated SDK directory.' }
$android=Join-Path $sdkDirectory 'android'
$cli=Join-Path $android 'cmdline-tools/latest/bin/android.exe'
$env:JAVA_HOME=$JavaHome
$env:ANDROID_HOME=$android
$env:ANDROID_USER_HOME=Join-Path $sdkDirectory 'android-user'
$env:ANDROID_AVD_HOME=Join-Path $sdkDirectory 'avd'
$logs=Join-Path $sdkDirectory 'logs'
New-Item -ItemType Directory -Path $env:ANDROID_USER_HOME,$env:ANDROID_AVD_HOME,$logs -Force | Out-Null
foreach($component in @('emulator','system-images/android-36/google_apis/x86_64')) {
    Write-Output "Installing emulator component: $component"
    $log=Join-Path $logs (($component.Replace('/','-'))+'.log')
    & $cli --no-metrics --sdk $android sdk --ignore-outdated-xmls install $component *> $log
    if($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $log -Tail 20;throw 'Emulator component installation failed.' }
}
$avdPath=Join-Path $env:ANDROID_AVD_HOME 'atori_mvp.avd'
if(-not (Test-Path -LiteralPath $avdPath)) {
    'no' | & (Join-Path $android 'cmdline-tools/latest/bin/avdmanager.bat') create avd --name atori_mvp `
        --package 'system-images;android-36;google_apis;x86_64' --path $avdPath --device pixel_6
    if($LASTEXITCODE -ne 0) { throw 'AVD creation failed.' }
}
$emulator=Join-Path $android 'emulator/emulator.exe'
& $emulator -accel-check *> (Join-Path $logs 'acceleration.log')
$accelerationAvailable=$LASTEXITCODE -eq 0
$arguments=@('-avd','atori_mvp','-port','5556','-no-window','-no-audio','-no-boot-anim','-no-snapshot','-gpu','swiftshader','-memory','2048')
if(-not $accelerationAvailable) { $arguments+=@('-accel','off') }
$process=Start-Process -FilePath $emulator -ArgumentList $arguments -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $logs 'emulator-stdout.log') -RedirectStandardError (Join-Path $logs 'emulator-stderr.log')
Write-Output "Headless emulator started. PID=$($process.Id), adb target=emulator-5556"
Write-Output "Logs: $logs"
