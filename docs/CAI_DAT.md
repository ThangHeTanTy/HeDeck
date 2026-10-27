# Cài HeDeck từ bản phát hành

Không cần Python, Flutter hay cáp USB — chỉ tải hai file từ trang
[**Releases**](https://github.com/ThangHeTanTy/HeDeck/releases/latest).

Điện thoại và máy tính phải dùng **cùng một mạng Wi-Fi / mạng nhà**.

---

## 1. Máy tính Windows — agent

1. Tải **`HeDeckAgent-x.y.z.zip`**, giải nén ra một thư mục cố định, ví dụ
   `C:\HeDeck`. Đừng chạy thẳng trong file zip, cũng đừng để trong
   Downloads rồi lỡ xoá.
2. Nháy đúp **`HeDeckAgent.exe`**.
   - Windows SmartScreen báo *"Windows protected your PC"*: bấm
     **More info → Run anyway**. Cảnh báo này hiện vì file chưa được ký bằng
     chứng chỉ trả phí, không phải vì có virus.
   - Windows Firewall hỏi: chọn **Private networks** (mạng riêng) rồi
     **Allow access**.
3. Cửa sổ agent hiện **địa chỉ IP** và **mã ghép cặp 6 số**. Giữ cửa sổ này
   mở (thu nhỏ được) trong lúc dùng.

Tuỳ chọn, trong cùng thư mục:

| File | Làm gì |
|---|---|
| `TU_CHAY_CUNG_WINDOWS.bat` | Agent tự mở mỗi khi đăng nhập Windows. Chạy lại để gỡ. |
| `CAI_BAT_MAY_TU_XA.bat` | Cấu hình để bật máy từ điện thoại. Xem [BAT_MAY_TU_XA.md](BAT_MAY_TU_XA.md). |

## 2. Điện thoại Android — app

1. Trên điện thoại, mở trang Releases và tải **`HeDeck-x.y.z.apk`**.
2. Mở file vừa tải. Android hỏi *"Cho phép cài ứng dụng từ nguồn này?"* —
   bật cho trình duyệt (Chrome…), quay lại, bấm **Cài đặt**.
3. Play Protect cảnh báo ứng dụng lạ: bấm **Vẫn cài đặt** (*Install anyway*).

> **Đang dùng bản tự build** (cài qua `CHAY_APP.bat` hay `BUILD_APK.bat`)?
> Gỡ app cũ trước. Bản trên GitHub ký bằng khoá khác, Android không cho cài
> đè và báo *"Chưa cài đặt ứng dụng"*. Gỡ xong phải ghép cặp lại một lần.

## 3. Ghép cặp

Mở app, chọn máy tính trong danh sách (hoặc nhập IP), nhập mã 6 số, bấm
**Ghép cặp**. Mã hết hạn thì nhấn **Enter** trong cửa sổ agent để lấy mã mới.

---

## Cập nhật

Không có gì tự cài sau lưng bạn — cả hai đều hỏi trước.

**App:** bánh răng ⚙ → **Kiểm tra cập nhật**. Có bản mới thì app hiện ghi
chú thay đổi; bấm **Cập nhật**, app tải về và mở trình cài đặt của Android,
bấm **Cài đặt** để xong. Lần đầu Android hỏi cho phép HeDeck cài ứng dụng —
bật lên rồi quay lại. Dữ liệu và ghép cặp giữ nguyên.

**Agent:** khi mở và cứ 12 giờ, agent hỏi GitHub. Có bản mới thì cửa sổ
agent báo kèm ghi chú thay đổi:

```
  [↑] Có bản mới 1.3.0 trên GitHub:
        - Thêm ô hẹn giờ tắt máy
      Gõ C rồi Enter để cập nhật, agent tự mở lại sau đó.
```

Gõ `C` rồi Enter: agent tải bản mới, kiểm tra mã SHA-256, thay file và tự
mở lại trong cửa sổ mới. Tải hỏng thì giữ nguyên bản cũ.

> App và agent nên cùng phiên bản. App báo *"Agent là bản cũ"* thì cập nhật
> agent trước.

---

## Gỡ cài đặt

- **App:** gỡ như mọi app Android.
- **Agent:** chạy lại `TU_CHAY_CUNG_WINDOWS.bat` nếu đã bật tự chạy, rồi xoá
  thư mục agent. Dữ liệu (điện thoại đã ghép, danh mục app) nằm ở
  `%USERPROFILE%\.hedeck`, xoá luôn nếu muốn sạch hẳn.
