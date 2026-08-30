# Bắt đầu trong 5 phút

Hai phần chạy song song: **agent** trên laptop Windows, **app** trên điện thoại.
Cả hai phải cùng một mạng Wi-Fi.

---

## Bước 1 — Laptop Windows

Cần Python 3.10+ ([tải tại python.org](https://www.python.org/downloads/), nhớ tick
"Add Python to PATH" lúc cài).

Nháy đúp:

```
agent\run_agent.bat
```

Lần đầu mất khoảng một phút để cài thư viện và quét Start Menu. Windows Firewall
sẽ hỏi — chọn **Cho phép ở mạng riêng (Private networks)**.

Cửa sổ hiện ra sẽ có **địa chỉ IP** và **mã ghép cặp 6 số**. Giữ cửa sổ này mở.

Mã sống 5 phút. Hết hạn thì **nhấn Enter** ngay trong cửa sổ đó để lấy mã mới.

> Muốn một file `.exe` chạy thẳng, không cần Python: nháy đúp `agent\build_exe.bat`,
> kết quả nằm ở `agent\dist\HeDeckAgent.exe`.

---

## Bước 2 — Điện thoại Android

Cần Flutter SDK ([hướng dẫn cài](https://docs.flutter.dev/get-started/install/windows)).
Giải nén vào `C:\flutter` — tránh thư mục có dấu cách như Program Files, Flutter
hay lỗi ở đó. Kiểm tra bằng `flutter doctor`, mục Android toolchain phải xanh.

Không cần tự thêm vào PATH: các script `.bat` tự tìm Flutter ở những vị trí
thường gặp (`C:\flutter`, `D:\flutter`, thư mục người dùng…) và quét ổ đĩa nếu
vẫn chưa thấy. Chỉ khi tìm không ra nó mới báo lỗi kèm hướng dẫn.

Nháy đúp `setup_app.bat`.

**Nếu project nằm khác ổ đĩa với thư mục người dùng** (ví dụ project ở `D:`,
Windows ở `C:`), script sẽ cảnh báo và tự xử lý. Đây là lỗi hay gặp của Kotlin
trên Windows, không liên quan tới HeDeck.

Script tự sinh phần khung Android, vá manifest, tải package, rồi sinh icon
launcher HeDeck. Code trong `lib/` không bị đụng.

Bật **USB debugging** trên điện thoại, cắm cáp, rồi nháy đúp `CHAY_APP.bat` ở
thư mục gốc.

Script này làm ba việc trước khi gọi `flutter run`: cấu hình Gradle cho máy,
dừng daemon cũ còn giữ cache, và liệt kê thiết bị đang nhận. Dùng nó thay cho
`flutter run` trực tiếp, nhất là trên máy mới hoặc khi project nằm ở ổ khác với
Windows — nó xử lý sẵn nhóm lỗi Kotlin hay gặp trên Windows.

Muốn chạy tay thì vẫn được, nhưng phải chạy `setup_app.bat` ít nhất một lần
trên máy đó:

```bat
cd flutter_app
flutter run
```

Xuất file APK để cài thẳng, không cần cáp về sau — chạy `BUILD_APK.bat` ở thư
mục gốc. Script build bản release có làm rối mã nguồn và in mã SHA-256 để đối
chiếu.

File nằm ở `flutter_app\build\app\outputs\flutter-apk\app-release.apk`.
Chép sang điện thoại và cài (cần bật "Cài từ nguồn không xác định").

---

## Bước 3 — Ghép cặp

Mở app → chọn máy trong danh sách, hoặc gõ IP thấy ở Bước 1 → nhập mã 6 số → **Ghép cặp**.

Xong. Chạm dấu cộng ở thanh dưới để gán ứng dụng cho ô đầu tiên.

Vài thao tác nên biết ngay:

- Chạm ô đang chạy → thu nhỏ app xuống. Giữ 3 giây → tắt hẳn app.
- Viền xanh lục là đang chạy, tím là đang mở, không viền là chưa mở.
- Nút bánh răng → đổi bố cục 4×2 hoặc 4×3.

---

## Nếu trục trặc

| Hiện tượng | Cách xử lý |
|---|---|
| App báo "Laptop từ chối kết nối" | Agent chưa chạy, hoặc Firewall chặn |
| Danh sách dò tìm trống | Router chặn multicast — gõ IP thủ công |
| "Hết thời gian chờ" | Hai máy khác mạng (mạng khách, hoặc 2.4 GHz vs 5 GHz tách SSID) |
| `flutter doctor` báo thiếu Android SDK | Cài Android Studio rồi chạy `flutter doctor --android-licenses` |
| `flutter is not recognized` | Chưa có Flutter trong PATH — chạy `setup_app.bat`, nó tự tìm giúp |
| `different roots` / `Could not close incremental caches` | Project khác ổ đĩa với Pub cache — chạy `.\SUA_LOI_KHAC_O_DIA.bat` |
| `deleted Android v1 embedding` | Chạy `SUA_LOI_ANDROID.bat` ở thư mục gốc |
| Agent báo "CHẶN: ngoài mạng nội bộ" | Hai máy khác mạng, hoặc dùng máy ảo mà chưa `adb reverse` |
| `No module named 'websockets'` | Môi trường ảo hỏng — chạy `agent\SUA_LOI_AGENT.bat` |
| Bị khoá do sai mã nhiều lần | Nhấn **U** rồi Enter trong cửa sổ agent |

Chi tiết đầy đủ về giao thức, bảo mật và cách thêm app thủ công nằm trong `README.md`.
