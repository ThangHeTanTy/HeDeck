# Tao khoa ky APK cho ban phat hanh tren GitHub, roi huong dan dan vao
# GitHub Secrets.
#
# Android chi cho cai ban moi de len ban cu khi ca hai ky bang CUNG mot khoa.
# Mat khoa nay = moi nguoi dung phai go app cai lai. Vi vay:
#   - Khoa nam ngoai kho ma: %USERPROFILE%\HeDeck-khoa-ky
#   - Chay lai script nay KHONG tao khoa moi, chi chep lai secret.
#   - Sao luu ca thu muc do (USB, Google Drive...).

$ErrorActionPreference = "Stop"
$repo = "ThangHeTanTy/HeDeck"
$dir  = Join-Path $env:USERPROFILE "HeDeck-khoa-ky"
$jks  = Join-Path $dir "hedeck-release.jks"
$passFile = Join-Path $dir "MAT_KHAU.txt"
$aliasFile = Join-Path $dir "ALIAS.txt"
$debugKs = Join-Path $env:USERPROFILE ".android\debug.keystore"

function Find-Keytool {
    $list = @()
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { $list += $cmd.Source }
    if ($env:JAVA_HOME) { $list += Join-Path $env:JAVA_HOME "bin\keytool.exe" }
    $list += @(
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
    )
    return $list | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

Write-Host ""
Write-Host "Khoa ky APK cho HeDeck"
Write-Host ("-" * 58)

if (Test-Path $jks) {
    Write-Host "  = Da co khoa, KHONG tao lai:" -ForegroundColor DarkGray
    Write-Host "      $jks" -ForegroundColor DarkGray
    if (-not (Test-Path $passFile)) {
        Write-Host "[X] Thieu $passFile - khong biet mat khau cua khoa." -ForegroundColor Red
        exit 1
    }
    $pass = (Get-Content $passFile -Raw).Trim()
    $alias = if (Test-Path $aliasFile) { (Get-Content $aliasFile -Raw).Trim() } else { "hedeck" }
} else {
    $keytool = Find-Keytool
    if (-not $keytool) {
        Write-Host "[X] Khong tim thay keytool (di kem Java / Android Studio)." -ForegroundColor Red
        Write-Host "    Cai Android Studio hoac JDK 17 roi chay lai."
        exit 1
    }
    New-Item -ItemType Directory -Force $dir | Out-Null

    # Dien thoai dang cai ban build tu chinh may nay thi ky bang khoa debug
    # cua may. Dung lai khoa do lam khoa phat hanh: lan dau chuyen sang ban
    # GitHub cai de len duoc luon, khong phai go app, giu nguyen thiet lap va
    # ghep cap. Bao mat tuong duong khoa moi: mat khau "android" ai cung biet,
    # nhung khong co file khoa thi vo dung - giu file nhu giu khoa moi.
    $reuse = $false
    if (Test-Path $debugKs) {
        Write-Host ""
        Write-Host "May nay co khoa debug cua Android Studio:" -ForegroundColor Cyan
        Write-Host "    $debugKs"
        Write-Host "Dien thoai dang cai HeDeck build tu CHINH MAY NAY (CHAY_APP.bat,"
        Write-Host "BUILD_APK.bat, Android Studio)? Dung lai khoa nay thi lan dau cai"
        Write-Host "ban tu GitHub KHONG phai go app: giu nguyen o, trang, cai dat va"
        Write-Host "ghep cap. Neu app tren dien thoai build o may khac thi chon k."
        $ans = Read-Host "Dung lai khoa debug cua may nay? (c/k)"
        $reuse = $ans -in @("c", "C", "y", "Y")
    }

    if ($reuse) {
        # keytool ghi canh bao ra stderr; de "Stop" thi PowerShell 5 coi la loi.
        $ErrorActionPreference = "Continue"
        $info = & $keytool -list -v -keystore $debugKs -storepass android -alias androiddebugkey 2>&1
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[X] Khong doc duoc khoa debug (mat khau khac 'android'?)." -ForegroundColor Red
            Write-Host "    Chay lai va chon k de tao khoa moi."
            exit 1
        }
        $until = $info | Select-String "until:" | Select-Object -First 1
        if ($until) { Write-Host "  Hieu luc: $($until.ToString().Trim())" }
        Copy-Item $debugKs $jks
        $pass = "android"
        $alias = "androiddebugkey"
        [System.IO.File]::WriteAllText($passFile, $pass)
        [System.IO.File]::WriteAllText($aliasFile, $alias)
        Write-Host "  + Da chep khoa debug lam khoa phat hanh: $jks" -ForegroundColor Green
    } else {
        # Mat khau ngau nhien 24 ky tu, bo cac chu de nham (0/O, 1/l/I).
        $chars = [char[]]"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
        $bytes = New-Object byte[] 24
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $pass = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })

        & $keytool -genkeypair -keystore $jks -storetype PKCS12 -alias hedeck `
            -keyalg RSA -keysize 4096 -validity 36500 `
            -storepass $pass -keypass $pass -dname "CN=HeDeck, O=He IT, C=VN"
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $jks)) {
            Write-Host "[X] keytool that bai" -ForegroundColor Red
            exit 1
        }
        [System.IO.File]::WriteAllText($passFile, $pass)
        $alias = "hedeck"
        [System.IO.File]::WriteAllText($aliasFile, $alias)
        Write-Host "  + Da tao khoa moi: $jks" -ForegroundColor Green
    }
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))

Write-Host ""
Write-Host "SAO LUU NGAY thu muc nay (USB, Google Drive...):" -ForegroundColor Yellow
Write-Host "    $dir" -ForegroundColor Yellow
Write-Host "Mat khoa = moi nguoi dung phai go app cai lai." -ForegroundColor Yellow
Write-Host "Khong gui khoa hay mat khau cho ai, khong dua vao kho ma." -ForegroundColor Yellow
Write-Host ""
Write-Host "Dan 3 secret vao GitHub. Trinh duyet se mo trang tao secret."
Write-Host ("-" * 58)

$url = "https://github.com/$repo/settings/secrets/actions/new"

Set-Clipboard -Value $b64
Write-Host ""
Write-Host "Secret 1:  Name = ANDROID_KEYSTORE_BASE64" -ForegroundColor Cyan
Write-Host "           Secret = (da chep san, bam Ctrl+V)"
Start-Process $url
Read-Host "Bam 'Add secret' tren GitHub xong thi nhan Enter o day"

Set-Clipboard -Value $pass
Write-Host ""
Write-Host "Secret 2:  Name = ANDROID_KEYSTORE_PASSWORD" -ForegroundColor Cyan
Write-Host "           Secret = (da chep san, bam Ctrl+V)"
Start-Process $url
Read-Host "Bam 'Add secret' tren GitHub xong thi nhan Enter o day"

Set-Clipboard -Value $alias
Write-Host ""
Write-Host "Secret 3:  Name = ANDROID_KEY_ALIAS" -ForegroundColor Cyan
Write-Host "           Secret = $alias  (da chep san, bam Ctrl+V)"
Start-Process $url
Read-Host "Bam 'Add secret' tren GitHub xong thi nhan Enter o day"

Set-Clipboard -Value " "
Write-Host ""
Write-Host "[OK] Xong. Tu gio PHAT_HANH.bat se cho ra APK ky bang khoa nay." -ForegroundColor Green
Start-Process explorer $dir
