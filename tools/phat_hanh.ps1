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
    $out = & git.exe @args 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { Fail "git $($args -join ' ') that bai:`n$($out -join "`n")" }
    return $out
}

if (-not (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    Fail "Khong tim thay git. Cai Git for Windows roi chay lai."
}

Write-Host ""
Write-Host "Phat hanh HeDeck"
Write-Host ("-" * 58)

$branch = (Invoke-Git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "master") {
    Fail "Dang o nhanh '$branch'. Chuyen sang master: git checkout master"
}
if (Invoke-Git status --porcelain) {
    Fail "Con thay doi chua commit. Commit hoac bo di truoc khi phat hanh."
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
# Moi dong mot y. Dong bat dau bang dau # se bi bo qua.
# Viet xong thi luu (Ctrl+S) va dong Notepad.

"@
[System.IO.File]::WriteAllText($msgFile, $template,
    (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "Notepad dang mo de ban viet ghi chu thay doi."
Start-Process notepad $msgFile
# Khong dung -Wait: Notepad moi cua Windows 11 tra ve ngay luc vua mo.
Read-Host "Luu (Ctrl+S) va dong Notepad xong thi nhan Enter o day"
$lines = @(Get-Content $msgFile -Encoding UTF8 |
    Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith("#") } |
    ForEach-Object {
        $t = $_.Trim()
        if ($t -match '^[-*] ') { $t } else { "- $t" }
    })
Remove-Item $msgFile
if (-not $lines) { Fail "Can it nhat mot dong ghi chu." }

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
