# Vá AndroidManifest do Flutter vừa sinh ra, thay vì ship sẵn một file cứng.
# Cách này giữ nguyên phần v2 embedding mà Flutter tạo, nên không bao giờ
# gặp lỗi "deleted Android v1 embedding".
#
# Chạy từ thư mục flutter_app.

$ErrorActionPreference = "Stop"
$path = "android\app\src\main\AndroidManifest.xml"

if (-not (Test-Path $path)) {
    Write-Host "[X] Khong tim thay $path. Chay 'flutter create' truoc." -ForegroundColor Red
    exit 1
}

$m = Get-Content $path -Raw
$nl = "`r`n"

# 1. Quyen mang
if ($m -notmatch "android.permission.INTERNET") {
    $perms = @"
$nl
    <!-- Noi chuyen voi agent qua LAN -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <!-- Can cho mDNS: nhan goi multicast khi do tim thiet bi -->
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
"@
    $m = [regex]::Replace($m, "(<manifest[^>]*>)", "`$1$perms", 1)
    Write-Host "  + Da them quyen mang"
}

# 1b. Quyen mo trinh cai dat, de app tu cap nhat tu GitHub. Tach rieng khoi
# buoc 1 de may da chay setup ban cu cung duoc them.
if ($m -notmatch "REQUEST_INSTALL_PACKAGES") {
    $m = [regex]::Replace(
        $m,
        "(<manifest[^>]*>)",
        "`$1$nl    <!-- Mo trinh cai dat khi cap nhat app tu GitHub -->$nl    <uses-permission android:name=`"android.permission.REQUEST_INSTALL_PACKAGES`" />",
        1)
    Write-Host "  + Da them quyen cai ban cap nhat"
}

# 2. Ten hien thi
$m = [regex]::Replace($m, 'android:label="[^"]*"', 'android:label="HeDeck"', 1)

# 3. Cho phep ket noi ws:// trong mang noi bo
if ($m -notmatch "networkSecurityConfig") {
    $m = [regex]::Replace(
        $m,
        'android:icon="@mipmap/ic_launcher"',
        "android:icon=`"@mipmap/ic_launcher`"$nl        android:networkSecurityConfig=`"@xml/network_security_config`"",
        1)
    Write-Host "  + Da bat network security config"
}

# 4. Uu tien man hinh ngang
if ($m -notmatch "screenOrientation") {
    $m = [regex]::Replace(
        $m,
        'android:windowSoftInputMode="adjustResize"',
        "android:screenOrientation=`"sensorLandscape`"$nl            android:windowSoftInputMode=`"adjustResize`"",
        1)
    Write-Host "  + Da dat huong man hinh ngang"
}

# 4b. Chia se APK tai ve cho trinh cai dat (Android 7+ cam dung file://)
if ($m -notmatch "update_paths") {
    $provider = @"
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="`${applicationId}.updates"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/update_paths" />
        </provider>
"@
    $i = $m.LastIndexOf("</application>")
    if ($i -lt 0) {
        Write-Host "[X] Khong thay </application> trong manifest" -ForegroundColor Red
        exit 1
    }
    $m = $m.Insert($i, "    " + $provider.Trim() + $nl + "    ")
    Write-Host "  + Da them FileProvider cho ban cap nhat"
}

# Ghi lai khong kem BOM, aapt khong thich BOM
[System.IO.File]::WriteAllText(
    (Resolve-Path $path),
    $m,
    (New-Object System.Text.UTF8Encoding($false)))

# 5. Chep file cau hinh mang
$xmlDir = "android\app\src\main\res\xml"
if (-not (Test-Path $xmlDir)) { New-Item -ItemType Directory -Path $xmlDir -Force | Out-Null }
Copy-Item "..\android_patch\network_security_config.xml" $xmlDir -Force
Copy-Item "..\android_patch\update_paths.xml" $xmlDir -Force

# 6. Nen khoi dong trang, khop voi man hinh mo dau cua app
foreach ($dir in @("android\app\src\main\res\drawable",
                   "android\app\src\main\res\drawable-v21")) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item "..\android_patch\launch_background.xml" $dir -Force
}
Write-Host "  + Da dat nen khoi dong mau trang"

# 6a. Go bo phan tat Impeller neu ban cu da them.
# Truoc day script nay tat Impeller vi tuong no gay man hinh den. Chan doan sai:
# nguyen nhan that la man hinh mo dau khong go duoc lop phu, cong voi
# MaskFilter.blur trong logo - ca hai da sua. Flutter sap go han co tat Impeller
# nen giu lai chi tao canh bao thua va se hong o ban sau.
if ($m -match "EnableImpeller") {
    $m = [regex]::Replace(
        $m,
        '\s*<meta-data\s+android:name="io\.flutter\.embedding\.android\.EnableImpeller"[^>]*/>',
        "", 1)
    [System.IO.File]::WriteAllText(
        (Resolve-Path $path),
        $m,
        (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  + Da go phan tat Impeller (khong con can nua)"
}

# 6b. Tat sao luu tu dong. Android khoi phuc du lieu cu sau khi cai lai app,
# nhung khoa giai ma thi khong con -> kho khoa hong. Tat di cho chac.
if ($m -notmatch "allowBackup") {
    $m = [regex]::Replace(
        $m,
        'android:label="HeDeck"',
        "android:label=`"HeDeck`"$nl        android:allowBackup=`"false`"$nl        android:fullBackupContent=`"false`"",
        1)
    [System.IO.File]::WriteAllText(
        (Resolve-Path $path),
        $m,
        (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  + Da tat sao luu tu dong"
}

# 6c. Tat bien dich tang dan cua Kotlin.
# Ly do: neu project nam khac o dia voi Pub cache (vi du project o D:, cache o
# C:), Kotlin khong tinh duoc duong dan tuong doi giua hai o va build sap voi
# loi "this and base files have different roots". Tat di thi build lau hon vai
# giay nhung khong bao gio dinh loi nay.
$gp = "android\gradle.properties"
if (Test-Path $gp) {
    $props = Get-Content $gp -Raw
} else {
    $props = ""
}
$added = $false
foreach ($line in @(
    "kotlin.incremental=false",
    "kotlin.incremental.useClasspathSnapshot=false",
    "kotlin.compiler.execution.strategy=in-process"
)) {
    $key = $line.Split("=")[0]
    if ($props -notmatch [regex]::Escape($key)) {
        if ($props -and -not $props.EndsWith("`n")) { $props += $nl }
        $props += $line + $nl
        $added = $true
    }
}
if ($added) {
    $full = Join-Path (Resolve-Path "android").Path "gradle.properties"
    [System.IO.File]::WriteAllText($full, $props,
        (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  + Da tat bien dich tang dan cua Kotlin (tranh loi khac o dia)"
}

# 6d. Chep quy tac giu lop cho R8, phong khi Gradle bat rut gon ma nguon.
$pgDir = "android\app"
if (Test-Path $pgDir) {
    Copy-Item "..\android_patch\proguard-rules.pro" $pgDir -Force
    Write-Host "  + Da chep quy tac ProGuard"
}

# 7. MainActivity: giu man hinh sang (thay plugin wakelock) va kenh
# hedeck/update de mo trinh cai dat. Lay tu android_patch\MainActivity.kt,
# chi giu lai ten package Flutter da sinh.
$mainActivity = Get-ChildItem -Recurse "android\app\src\main" -Filter "MainActivity.kt" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mainActivity) {
    $code = Get-Content $mainActivity.FullName -Raw
    $tpl = Get-Content "..\android_patch\MainActivity.kt" -Raw
    $pkg = ($code -split "`n" | Select-String "^package ").ToString().Trim()
    $newCode = $tpl.Replace("package __PACKAGE__", $pkg)
    if ($code -ne $newCode) {
        [System.IO.File]::WriteAllText(
            $mainActivity.FullName,
            $newCode,
            (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  + Da cap nhat MainActivity (giu man hinh sang, cap nhat app)"
    }
} else {
    Write-Host "  ! Khong thay MainActivity.kt, bo qua buoc giu man hinh sang"
}

Write-Host "[OK] Da va AndroidManifest cho HeDeck" -ForegroundColor Green
