# Cau hinh Gradle cho HeDeck.
#
# Ghi vao HAI noi:
#   1. Cap may:     %USERPROFILE%\.gradle\gradle.properties
#   2. Cap project: <project>\android\gradle.properties
#
# Vi sao can ca hai: thu muc android/ duoc sinh lai moi lan chay flutter create,
# nen cau hinh o do co the bien mat. Cau hinh cap may ton tai doc lap voi
# project va ap dung cho moi lan build tren may nay, ke ca khi ban chay
# `flutter run` thang chu khong qua script nao.
#
# Cac thiet lap:
#   kotlin.incremental=false
#       Kotlin luu cache bien dich bang duong dan tuong doi. Project va Pub
#       cache khac o dia thi Windows khong co duong dan tuong doi giua hai o,
#       va build sap voi loi "this and base files have different roots".
#
#   kotlin.compiler.execution.strategy=in-process
#       Bien dich ngay trong tien trinh Gradle, khong sinh daemon rieng. Daemon
#       giu trang thai giua cac lan build; mot lan hong la nhung lan sau bao
#       "Storage is already registered" cho toi khi giet no di.
#
#   org.gradle.jvmargs
#       Bu lai bo nho cho tien trinh Gradle, vi gio no bien dich luon phan
#       Kotlin thay vi day sang daemon.

param([string]$ProjectAndroidDir = "")

$settings = [ordered]@{
    "kotlin.incremental"                     = "false"
    "kotlin.incremental.useClasspathSnapshot" = "false"
    "kotlin.compiler.execution.strategy"     = "in-process"
    "org.gradle.jvmargs"                     = "-Xmx4G -XX:MaxMetaspaceSize=1G"
}

function Set-GradleProperties {
    param([string]$Path, [string]$Label)

    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $lines = @()
    if (Test-Path $Path) {
        $lines = @(Get-Content $Path)
    }

    $changed = $false
    foreach ($key in $settings.Keys) {
        $value = $settings[$key]
        $pattern = "^\s*" + [regex]::Escape($key) + "\s*="
        $existing = $lines | Where-Object { $_ -match $pattern }

        if ($existing) {
            # Da co dong nay: chi sua neu gia tri khac
            if ($existing[0] -notmatch ([regex]::Escape("$key=$value"))) {
                $lines = $lines | ForEach-Object {
                    if ($_ -match $pattern) { "$key=$value" } else { $_ }
                }
                $changed = $true
            }
        } else {
            $lines += "$key=$value"
            $changed = $true
        }
    }

    if ($changed) {
        $header = "# HeDeck: cau hinh de build khong sap khi project va Pub cache khac o dia"
        if (-not ($lines | Where-Object { $_ -like "*HeDeck: cau hinh*" })) {
            $lines = @("", $header) + $lines
        }
        [System.IO.File]::WriteAllLines($Path, $lines,
            (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  + $Label : da cap nhat" -ForegroundColor Green
    } else {
        Write-Host "  = $Label : da dung san" -ForegroundColor DarkGray
    }
    Write-Host "      $Path" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Cau hinh Gradle cho HeDeck"
Write-Host ("-" * 58)

# 1. Cap may - quan trong nhat, ton tai qua moi lan sinh lai project
Set-GradleProperties -Path (Join-Path $env:USERPROFILE ".gradle\gradle.properties") `
                     -Label "Cap may   "

# 2. Cap project - de nguoi khac clone ve cung co
if ($ProjectAndroidDir -and (Test-Path $ProjectAndroidDir)) {
    Set-GradleProperties -Path (Join-Path $ProjectAndroidDir "gradle.properties") `
                         -Label "Cap project"
} elseif ($ProjectAndroidDir) {
    Write-Host "  ! Chua co thu muc android, bo qua cau hinh cap project" -ForegroundColor Yellow
}

Write-Host ("-" * 58)
Write-Host ""
