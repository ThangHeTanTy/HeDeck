# Dung moi Kotlin va Gradle daemon dang chay.
#
# Daemon giu trang thai giua cac lan build. Mot lan build hong la nhung lan sau
# bao "Storage is already registered" cho toi khi giet no di. wmic khong dung
# duoc nua vi Windows 11 ban moi da go lenh do.

$found = 0
try {
    Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
        Where-Object { $_.CommandLine -match 'KotlinCompileDaemon|GradleDaemon' } |
        ForEach-Object {
            Write-Host ("   dung tien trinh " + $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            $script:found++
        }
} catch {
    Write-Host "   (khong liet ke duoc tien trinh: $_)"
}

if ($found -eq 0) {
    Write-Host "   khong co daemon nao dang chay"
} else {
    Start-Sleep -Seconds 2
}
