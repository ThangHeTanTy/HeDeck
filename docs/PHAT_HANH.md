# Phát hành bản mới

Dành cho người giữ kho mã. Người dùng cài theo [CAI_DAT.md](CAI_DAT.md).

```
PHAT_HANH.bat ──► thẻ v1.3.0 ──► GitHub Actions ──► Release v1.3.0
                                  • build APK, ký      ├─ HeDeck.apk
                                  • đóng gói agent     ├─ HeDeckAgent.exe
                                                       ├─ HeDeckAgent.zip
                                                       └─ SHA256SUMS.txt
                                                              │
         App: ⚙ → Kiểm tra cập nhật ◄─────────────────────────┤
         Agent: tự báo, bấm Cập nhật ◄────────────────────────┘
```

Chỉ **gắn thẻ phiên bản** mới phát hành. Merge vào `master` không phát hành
gì cả — chỉ chạy build thử trên pull request để chắc `master` luôn build được.

---

## Việc làm một lần: khoá ký APK

Android chỉ cho cài bản mới đè lên bản cũ khi cả hai **ký bằng cùng một
khoá**. Khoá này phải giữ mãi: **mất khoá là mọi người dùng phải gỡ app cài
lại**.

1. Cần Android Studio (hoặc JDK 17) trên máy — chính cái đang dùng để build.
2. Nháy đúp **`TAO_KHOA_KY.bat`**. Script:
   - hỏi có **dùng lại khoá debug của máy này** không (xem dưới). Không thì
     tạo khoá mới kèm mật khẩu ngẫu nhiên. Khoá cất ở
     `%USERPROFILE%\HeDeck-khoa-ky\`, ngoài kho mã, không bao giờ lên Git;
   - mở trang tạo secret của GitHub và chép sẵn từng giá trị vào clipboard.
     Bạn chỉ cần dán (Ctrl+V) và bấm **Add secret** ba lần:

     | Name | Secret |
     |---|---|
     | `ANDROID_KEYSTORE_BASE64` | (script đã chép sẵn) |
     | `ANDROID_KEYSTORE_PASSWORD` | (script đã chép sẵn) |
     | `ANDROID_KEY_ALIAS` | (script đã chép sẵn) |

3. **Sao lưu thư mục `HeDeck-khoa-ky`** sang USB, Google Drive… Không gửi cho
   ai, không đưa vào kho mã.

### Dùng lại khoá debug — để lần đầu không phải gỡ app

App đang cài trên điện thoại bằng `CHAY_APP.bat`, `BUILD_APK.bat` hay
Android Studio đều ký bằng **khoá debug của máy build**
(`%USERPROFILE%\.android\debug.keystore`). Chọn dùng lại khoá đó làm khoá
phát hành thì bản tải từ GitHub cài đè lên được ngay: **không gỡ app, giữ
nguyên ô, trang, cài đặt và ghép cặp.**

- Chỉ có tác dụng với điện thoại cài app build từ **chính máy chạy script**.
  Điện thoại khác (build ở máy khác) vẫn phải gỡ một lần.
- Mật khẩu khoá debug là `android`, ai cũng biết — nhưng thiếu file khoá thì
  vô dụng. Giữ file như giữ một khoá mới.
- Script chép khoá vào `HeDeck-khoa-ky`, nên lỡ cài lại Android Studio mất
  `debug.keystore` thì vẫn còn bản sao.

Chạy lại `TAO_KHOA_KY.bat` không tạo khoá mới — chỉ chép lại secret (dùng
khi cần dán lại, hoặc sang máy khác sau khi chép thư mục khoá qua).

Có khoá trên máy thì `BUILD_APK.bat` cũng tự ký bằng khoá này, nên APK tự
build cài đè lên được bản tải từ GitHub và ngược lại, không mất ghép cặp.

---

## Việc làm một lần: bật trang tải

Trang https://thanghetanty.github.io/HeDeck/ dựng từ thư mục `site/` bằng
workflow `.github/workflows/pages.yml`. GitHub chỉ cho bật bằng tay:

1. Repo trên GitHub → **Settings** → **Pages** (cột trái).
2. Mục **Build and deployment** → **Source**: chọn **GitHub Actions**.
3. Tab **Actions** → **Trang tải** → **Run workflow** → **Run workflow**.
   Khoảng một phút sau trang chạy ở địa chỉ trên.

Trang tự hỏi GitHub bản phát hành mới nhất (số phiên bản, dung lượng, ghi chú,
link tải), nên phát hành bản mới **không** cần đăng lại trang. Workflow chỉ tự
chạy lại khi sửa `site/` hoặc ảnh trong `docs/images/`.

Nút tải trong README trỏ tới link cố định
`releases/latest/download/HeDeck.apk` và `.../HeDeckAgent.zip`. Từ bản `1.0.1`
file mới mang tên cố định này; bản `1.0.0` còn tên kèm số phiên bản nên hai nút
đó chỉ chạy được khi đã có bản `1.0.1` trở lên. Trang tải thì chạy được với
mọi bản, vì nó tìm file theo đuôi `.apk` / `.zip`.

---

## Mỗi lần phát hành

1. Merge mọi thay đổi vào `master`, rồi trên máy:
   `git checkout master` và `git pull`.
2. Nháy đúp **`PHAT_HANH.bat`**:
   - kiểm tra đang ở `master`, không còn thay đổi chưa commit, khớp GitHub;
   - gợi ý số phiên bản kế tiếp;
   - mở Notepad để viết **ghi chú thay đổi** — người dùng đọc phần này trong
     app và cửa sổ agent, nên viết cho người dùng chứ không cho lập trình viên;
   - gắn thẻ và đẩy lên GitHub.
3. Theo dõi ở tab **Actions** (khoảng 10–15 phút). Xong thì bản mới nằm ở
   tab **Releases** và người dùng thấy ngay khi kiểm tra cập nhật.

Đánh số `chính.phụ.sửa`: sửa lỗi nhỏ tăng số cuối (`1.2.0 → 1.2.1`), thêm
tính năng tăng số giữa (`1.2.1 → 1.3.0`). Số phải luôn tăng — app và agent
chỉ coi là bản mới khi số lớn hơn bản đang chạy.

Không dùng được `PHAT_HANH.bat` thì gắn thẻ bằng tay, kết quả như nhau:

```
git tag -a v1.3.0 -m "- Thêm ô hẹn giờ tắt máy"
git push origin v1.3.0
```

### Lỡ phát hành bản lỗi

Đừng xoá rồi đăng lại cùng số — máy đã tải bản lỗi sẽ không nhận ra bản sửa.
Sửa lỗi rồi phát hành số mới (`1.3.1`).

---

## Build hỏng trên GitHub

Mở lượt chạy đỏ trong tab **Actions**, bấm vào bước đỏ để xem log.

| Báo lỗi | Cách sửa |
|---|---|
| `Chưa có secret ANDROID_KEYSTORE_BASE64…` | Chạy `TAO_KHOA_KY.bat`, dán đủ 3 secret. |
| `apksigner … password` / `Failed to load signer` | Secret mật khẩu hoặc alias sai — chạy lại `TAO_KHOA_KY.bat`, dán lại secret 2 và 3. |
| `Thẻ phải có dạng v1.2.3` | Xoá thẻ sai (`git push --delete origin <thẻ>`), gắn lại cho đúng. |

Build lại cùng thẻ sau khi sửa secret: tab **Actions** → lượt chạy đỏ →
**Re-run all jobs**.

---

## Bên trong

- Workflow: [`.github/workflows/release.yml`](../.github/workflows/release.yml).
  APK build trên Linux bằng `setup_app.sh` (giữ đồng bộ với
  `android_patch/patch_manifest.ps1`), agent đóng gói bằng PyInstaller trên
  Windows.
- Flutter ký APK bằng khoá debug như mọi khi; workflow dùng `apksigner` ký
  lại bằng khoá phát hành. Không phải sửa file Gradle do `flutter create` sinh.
- Số phiên bản lấy từ thẻ: `--build-name`, `versionCode = chính×1 000 000 +
  phụ×1 000 + sửa`, và `--dart-define=HEDECK_VERSION` để app biết mình là bản
  nào. Bản tự build không có số này và tự coi là *"bản tự build"*.
- App hỏi `api.github.com/repos/ThangHeTanTy/HeDeck/releases/latest`, tải
  APK, so SHA-256 GitHub ghi cho file, rồi mở trình cài đặt qua
  `FileProvider` (kênh `hedeck/update` trong `android_patch/MainActivity.kt`).
  Android luôn bắt người dùng bấm **Cài đặt** — app ngoài Play Store không
  cài im lặng được.
- Cập nhật app không đụng tới dữ liệu: Android giữ nguyên vùng dữ liệu
  riêng của app (thiết lập, trang, ô, khoá ghép cặp — tất cả nằm trong
  SharedPreferences) khi cài đè bản cùng khoá ký. Chỉ **gỡ app** mới xoá.
  Nếu một bản sau đổi cách lưu ô mà đọc không được trang cũ, app bỏ qua
  riêng trang đó và cất nguyên bản gốc ở khoá `deck.pages.backup`, không
  ghi đè mất.
- Agent (`agent/updater.py`) chỉ tự thay được bản `.exe`: tải về cạnh file
  đang chạy, đổi tên file cũ thành `.old` (Windows cho đổi tên file đang
  chạy), đặt file mới vào chỗ cũ, mở lại. Chạy từ mã nguồn thì chỉ nhắc
  `git pull`.
- Ghi chú phát hành = lời ghi chú của thẻ, nối thêm
  [`.github/release_body.md`](../.github/release_body.md) (hướng dẫn cài lần
  đầu) sau dòng `---`. App và agent chỉ hiện phần trên dòng đó.
- Bảng đối chiếu stack trace (`debug_symbols`) nằm ở mục Artifacts của lượt
  chạy, giữ 90 ngày; không đính vào Release vì công khai nó thì làm rối mã
  như không.
