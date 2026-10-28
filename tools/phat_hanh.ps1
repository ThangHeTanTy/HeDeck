# Gan the phien ban moi va day len GitHub. GitHub Actions thay the moi se tu
# build APK + agent .exe va dang thanh Release (.github/workflows/release.yml).
#
# Chi phat hanh tu master da day len GitHub: the gan vao dung commit ma moi
# nguoi nhin thay, khong gan vao thay doi chi nam tren may nay.

$ErrorActionPreference = "Stop"
$repo = "ThangHeTanTy/HeDeck"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Fail($msg) {
    Write-Host "[X] $msg" -ForegroundColor Red
    exit 1
}

# Khong dat ten ham la "Git": PowerShell khong phan biet hoa thuong va uu
# tien ham hon chuong trinh, nen "git" ben trong ham se goi lai chinh ham do
# mai khong dung (StackOverflowException). Goi thang git.exe cho chac.
function Invoke-Git {
    # git ghi tien trinh ra stderr; de "Stop" thi PowerShell 5 coi do la loi.
    $ErrorActionPreference = "Continue"
    # Dong stderr bi PowerShell boc thanh ErrorRecord; lay lai chu goc, neu
    # khong se in ra "System.Management.Automation.RemoteException".
    $out = & git.exe @args 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { "$($_.TargetObject)" }
        else { "$_" }
    }
    if ($LASTEXITCODE -ne 0) { Fail "git $($args -join ' ') that bai:`n$($out -join "`n")" }
    return $out
}

if (-not (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    Fail "Khong tim thay git. Cai Git for Windows roi chay lai."
}

# The phien ban ghi ten nguoi tao, giong chu ky. Git chua biet ban la ai thi
# hoi ngay tu dau, dung de toi buoc cuoi moi bao loi.
function Get-GitConfig($key) {
    $ErrorActionPreference = "Continue"
    $v = & git.exe config --get $key 2>$null
    if ($LASTEXITCODE -ne 0) { return "" }
    return "$v".Trim()
}
if (-not (Get-GitConfig "user.name") -or -not (Get-GitConfig "user.email")) {
    Write-Host ""
    Write-Host "Git tren may nay chua co ten va email nguoi dung (can de ky ten" -ForegroundColor Yellow
    Write-Host "vao the phien ban). Chi hoi mot lan, luu cho rieng kho HeDeck."   -ForegroundColor Yellow
    Write-Host "Email se hien cong khai tren GitHub - nen dung email an danh cua"
    Write-Host "GitHub (Settings -> Emails), dang <so>+<ten>@users.noreply.github.com"
    Write-Host ""
    $defName  = "ThangHeTanTy"
    $defEmail = "64769041+ThangHeTanTy@users.noreply.github.com"
    $name = Read-Host "Ten (Enter = $defName)"
    if (-not $name) { $name = $defName }
    $email = Read-Host "Email (Enter = $defEmail)"
    if (-not $email) { $email = $defEmail }
    Invoke-Git config user.name $name.Trim() | Out-Null
    Invoke-Git config user.email $email.Trim() | Out-Null
    Write-Host "  + Da luu: $name <$email>" -ForegroundColor Green
}

Write-Host ""
Write-Host "Phat hanh HeDeck"
Write-Host ("-" * 58)

$branch = (Invoke-Git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "master") {
    Fail "Dang o nhanh '$branch'. Chuyen sang master: git checkout master"
}
# Chi xet file Git dang theo doi. File moi chua add (??) khong anh huong
# toi the phien ban nen khong chan.
$changed = @(Invoke-Git status --porcelain --untracked-files=no |
    Where-Object { $_ } | ForEach-Object { $_.Substring(3).Trim('"') })
if ($changed) {
    # Flutter tu ghi lai hai file nay moi lan chay setup_app.bat, BUILD_APK.bat
    # hay CHAY_APP.bat, du ban khong sua gi. Ban phat hanh build tren GitHub
    # dung dung ban da commit, nen tra chung ve nhu cu la an toan.
    $auto = @("flutter_app/.metadata", "flutter_app/pubspec.lock")
    $others = @($changed | Where-Object { $_ -notin $auto })
    Write-Host ""
    Write-Host "  File da thay doi ma chua commit:" -ForegroundColor Yellow
    $changed | ForEach-Object { Write-Host "    $_" }
    if ($others) {
        Write-Host ""
        Write-Host "  Neu la thay doi ban muon giu: commit va push len GitHub truoc."
        Write-Host "  Neu khong can giu: git checkout -- <ten file>"
        Write-Host "  Xem chi tiet: git diff <ten file>"
        Fail "Con thay doi chua commit, chua phat hanh."
    }
    Write-Host ""
    Write-Host "  Day la file Flutter tu ghi lai khi build, khong phai ban sua." -ForegroundColor Cyan
    $ok = Read-Host "Tra ve nhu tren GitHub roi phat hanh tiep? (c/k)"
    if ($ok -notin @("c", "C", "y", "Y")) { Write-Host "Da huy."; exit 0 }
    Invoke-Git checkout -- @changed | Out-Null
    Write-Host "  + Da tra ve: $($changed -join ', ')" -ForegroundColor Green
}
Write-Host "  Lay ban moi nhat tu GitHub..."
Invoke-Git fetch origin master --tags | Out-Null
$local  = (Invoke-Git rev-parse HEAD).Trim()
$remote = (Invoke-Git rev-parse origin/master).Trim()
if ($local -ne $remote) {
    Fail "master tren may khac master tren GitHub. Chay git pull (va git push neu can) truoc."
}

# Goi y so phien ban ke tiep tu the moi nhat
$tags = @(Invoke-Git tag -l "v*") | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' } |
    Sort-Object { [version]($_.Substring(1)) }
$last = $tags | Select-Object -Last 1
if ($last) {
    $v = [version]$last.Substring(1)
    $suggest = "$($v.Major).$($v.Minor + 1).0"
    Write-Host "  Ban gan nhat: $last"
} else {
    $suggest = "1.0.0"
    Write-Host "  Chua co ban phat hanh nao."
}
Write-Host ""
Write-Host "  Cach danh so: sua loi nho -> tang so cuoi (1.2.0 -> 1.2.1),"
Write-Host "  them tinh nang -> tang so giua (1.2.1 -> 1.3.0)."
Write-Host ""

$ver = Read-Host "So phien ban moi (Enter = $suggest)"
if (-not $ver) { $ver = $suggest }
$ver = $ver.Trim().TrimStart("v")
if ($ver -notmatch '^\d+\.\d+\.\d+$') { Fail "Phien ban phai co dang 1.2.3" }
if ($last -and [version]$ver -le [version]$last.Substring(1)) {
    Fail "v$ver khong moi hon $last - app va agent se khong coi la ban moi."
}
$tag = "v$ver"

# Ghi chu viet trong Notepad: go tieng Viet co dau va nhieu dong de hon
# trong cua so lenh.
$msgFile = Join-Path $env:TEMP "hedeck-$tag.txt"
$template = @"
# Ghi chu thay doi cua $tag. Nguoi dung doc phan nay trong app va cua so agent.
# Viet tu do: tieu de, gach dau dong "- ", dong trong deu duoc giu nguyen.
# Dong bat dau bang dau # se bi bo qua.
# Viet xong thi luu (Ctrl+S) va dong Notepad.

"@
[System.IO.File]::WriteAllText($msgFile, $template,
    (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "Notepad dang mo de ban viet ghi chu thay doi."
Start-Process notepad $msgFile
# Khong dung -Wait: Notepad moi cua Windows 11 tra ve ngay luc vua mo.
Read-Host "Luu (Ctrl+S) va dong Notepad xong thi nhan Enter o day"
# Giu nguyen cach ban viet (tieu de, gach dau dong, dong trong ngan cach),
# chi bo cac dong # huong dan va dong trong thua o dau, cuoi.
$lines = @(Get-Content $msgFile -Encoding UTF8 |
    Where-Object { -not $_.TrimStart().StartsWith("#") } |
    ForEach-Object { $_.TrimEnd() })
Remove-Item $msgFile
while ($lines.Count -and -not $lines[0]) { $lines = @($lines | Select-Object -Skip 1) }
while ($lines.Count -and -not $lines[-1]) { $lines = @($lines | Select-Object -SkipLast 1) }
if (-not ($lines | Where-Object { $_ })) { Fail "Can it nhat mot dong ghi chu." }

Write-Host ""
Write-Host ("-" * 58)
Write-Host "  The   : $tag"
Write-Host "  Commit: $($local.Substring(0, 7))  $((Invoke-Git log -1 --format=%s).Trim())"
$lines | ForEach-Object { Write-Host "  $_" }
Write-Host ("-" * 58)
$ok = Read-Host "Phat hanh? (c/k)"
if ($ok -notin @("c", "C", "y", "Y")) { Write-Host "Da huy."; exit 0 }

# Ghi ra file UTF-8 de giu nguyen dau tieng Viet
[System.IO.File]::WriteAllText($msgFile, ($lines -join "`n") + "`n",
    (New-Object System.Text.UTF8Encoding($false)))
Invoke-Git tag -a $tag -F $msgFile | Out-Null
Remove-Item $msgFile
$ErrorActionPreference = "Continue"
& git.exe push origin $tag
if ($LASTEXITCODE -ne 0) {
    & git.exe tag -d $tag | Out-Null
    Fail "Day the len GitHub that bai, da xoa the tren may. Kiem tra mang roi chay lai."
}

Write-Host ""
Write-Host "[OK] Da day $tag. GitHub dang build, khoang 10-15 phut." -ForegroundColor Green
Write-Host "     Theo doi: https://github.com/$repo/actions"
Write-Host "     Xong se co tai: https://github.com/$repo/releases"
Start-Process "https://github.com/$repo/actions"
