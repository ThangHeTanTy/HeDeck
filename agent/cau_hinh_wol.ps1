# Cau hinh Windows de may bat duoc tu xa bang Wake-on-LAN.
# Chay qua CAI_BAT_MAY_TU_XA.bat (tu xin quyen Administrator).
#
# Script chi lo phan Windows. Phan BIOS phai tu vao bang tay - xem cuoi file
# hoac docs\BAT_MAY_TU_XA.md.

$ErrorActionPreference = "Continue"

function Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Info($msg) { Write-Host "       $msg" }

Write-Host ""
Write-Host "== HeDeck: cau hinh bat may tu xa (Wake-on-LAN) ==" -ForegroundColor Cyan
Write-Host ""

$wired = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
           Where-Object { "$($_.PhysicalMediaType)" -match "802\.3" })

if ($wired.Count -eq 0) {
    Warn "Khong thay card mang co day nao. Wake-on-LAN khi may tat han"
    Warn "chi chay qua day LAN, khong chay qua Wi-Fi."
    exit 1
}

# Thuoc tinh nang cao cua driver, dat theo RegistryKeyword (khong phu thuoc
# ngon ngu Windows). Card nao khong co keyword thi bo qua.
#   *WakeOnMagicPacket          nghe magic packet
#   S5WakeOnLan                 Realtek: nghe ca khi may tat han (S5)
#   *ModernStandbyWoLMagicPacket nghe trong Modern Standby
#   EnablePME                   Intel: cho phep danh thuc
#   *EEE / EEELinkAdvertisement Energy Efficient Ethernet - hay lam rot link
#   EnableGreenEthernet         Realtek: tiet kiem dien, hay lam rot link
#   PowerSavingMode             Realtek: tiet kiem dien
$wanted = [ordered]@{
    "*WakeOnMagicPacket"           = "1"
    "S5WakeOnLan"                  = "1"
    "*ModernStandbyWoLMagicPacket" = "1"
    "EnablePME"                    = "1"
    "*EEE"                         = "0"
    "EEELinkAdvertisement"         = "0"
    "EnableGreenEthernet"          = "0"
    "PowerSavingMode"              = "0"
}

foreach ($a in $wired) {
    Write-Host "Card: $($a.Name) - $($a.InterfaceDescription)" -ForegroundColor Cyan
    Info "MAC: $($a.MacAddress)   Trang thai: $($a.Status)"

    $props = @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue)
    foreach ($key in $wanted.Keys) {
        $p = $props | Where-Object { $_.RegistryKeyword -eq $key } | Select-Object -First 1
        if (-not $p) { continue }
        if ("$($p.RegistryValue)" -eq $wanted[$key]) {
            Ok "$($p.DisplayName) da dung ($($p.DisplayValue))"
            continue
        }
        try {
            Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $key `
                -RegistryValue $wanted[$key] -NoRestart -ErrorAction Stop
            Ok "$($p.DisplayName) -> da sua"
        } catch {
            Warn "Khong sua duoc $($p.DisplayName): $($_.Exception.Message)"
        }
    }

    # Tab Power Management trong Device Manager.
    try {
        Set-NetAdapterPowerManagement -Name $a.Name -WakeOnMagicPacket Enabled `
            -NoRestart -ErrorAction Stop
        Ok "Cho phep magic packet danh thuc may"
    } catch {
        Warn "Khong bat duoc WakeOnMagicPacket: $($_.Exception.Message)"
    }
    & powercfg /deviceenablewake "$($a.InterfaceDescription)" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "Cho phep thiet bi danh thuc may (powercfg)" }
    else { Info "powercfg /deviceenablewake bo qua (co the da bat san)" }
    Write-Host ""
}

# Fast Startup: tat may tu Start Menu se thanh ngu dong mot nua, card mang
# Realtek thuong khong duoc giao nhiem vu cho magic packet.
$powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
try {
    $cur = (Get-ItemProperty -Path $powerKey -Name HiberbootEnabled -ErrorAction Stop).HiberbootEnabled
    if ($cur -ne 0) {
        Set-ItemProperty -Path $powerKey -Name HiberbootEnabled -Value 0 -Type DWord
        Ok "Da tat Fast Startup"
    } else {
        Ok "Fast Startup da tat san"
    }
} catch {
    Ok "May khong co Fast Startup"
}

Write-Host ""
Write-Host "== Phan Windows xong. Card mang co the chop mat ket noi vai giay. ==" -ForegroundColor Cyan
Write-Host ""
Write-Host "Con mot buoc BAT BUOC trong BIOS (MSI Click BIOS, nhan Delete khi bat may):" -ForegroundColor Yellow
Info "1. Settings > Advanced > Power Management Setup > ErP Ready  = Disabled"
Info "2. Settings > Advanced > Wake Up Event Setup"
Info "     > Resume By PCI-E Device (hoac PCI-E/Networking Device) = Enabled"
Info "3. F10 de luu va khoi dong lai."
Write-Host ""
Info "Thu: tat may, cho 10 giay, roi bam nut nguon trong app HeDeck."
Info "Den LAN o mat sau case van sang khi may tat la dau hieu card dang cho."
Write-Host ""
