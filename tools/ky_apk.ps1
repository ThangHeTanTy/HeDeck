# Ky lai APK tu build bang khoa phat hanh, neu may nay co khoa (tao bang
# TAO_KHOA_KY.bat). Nho vay ban build tren may cai de len duoc ban tai tu
# GitHub va nguoc lai, khong phai go app (go app la mat ghep cap).
# Khong co khoa thi im lang bo qua, APK giu chu ky debug nhu truoc.

param([Parameter(Mandatory = $true)][string]$Apk)

$dir = Join-Path $env:USERPROFILE "HeDeck-khoa-ky"
$jks = Join-Path $dir "hedeck-release.jks"
$passFile = Join-Path $dir "MAT_KHAU.txt"
if (-not (Test-Path $jks) -or -not (Test-Path $passFile)) { exit 0 }

function Version-Of($name) {
    try { return [version]$name } catch { return [version]"0.0" }
}

$sdks = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT,
          (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
    Where-Object { $_ -and (Test-Path (Join-Path $_ "build-tools")) }
$bt = $sdks |
    ForEach-Object { Get-ChildItem (Join-Path $_ "build-tools") -Directory } |
    Sort-Object { Version-Of $_.Name } | Select-Object -Last 1
$signer = if ($bt) { Join-Path $bt.FullName "apksigner.bat" } else { "" }
if (-not $signer -or -not (Test-Path $signer)) {
    Write-Host "  ! Khong tim thay apksigner trong Android SDK, APK giu chu ky debug" -ForegroundColor Yellow
    exit 0
}

# apksigner can Java; PATH chua co thi dung JDK di kem Android Studio
if (-not $env:JAVA_HOME -and -not (Get-Command java -ErrorAction SilentlyContinue)) {
    foreach ($j in @("$env:ProgramFiles\Android\Android Studio\jbr",
                     "$env:LOCALAPPDATA\Programs\Android Studio\jbr")) {
        if (Test-Path "$j\bin\java.exe") {
            $env:JAVA_HOME = $j
            $env:Path = "$j\bin;$env:Path"
            break
        }
    }
}

$env:HEDECK_KS_PASS = (Get-Content $passFile -Raw).Trim()
& $signer sign --ks $jks --ks-key-alias hedeck `
    --ks-pass env:HEDECK_KS_PASS --key-pass env:HEDECK_KS_PASS $Apk
$code = $LASTEXITCODE
Remove-Item Env:\HEDECK_KS_PASS
if ($code -ne 0) {
    Write-Host "  ! Ky bang khoa phat hanh that bai, APK giu chu ky debug" -ForegroundColor Yellow
    exit 0
}
Write-Host "  + Da ky bang khoa phat hanh: cai de len ban tu GitHub duoc" -ForegroundColor Green
