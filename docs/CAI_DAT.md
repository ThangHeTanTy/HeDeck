# Cài HeDeck từ bản phát hành

Không cần Python, Flutter hay cáp USB — chỉ tải hai file từ trang
[**Releases**](https://github.com/ThangHeTanTy/HeDeck/releases/latest).

Điện thoại và máy tính phải dùng **cùng một mạng Wi-Fi / mạng nhà**.

<img src="images/qr-tai-hedeck.png" width="180" alt="Mã QR mở trang tải HeDeck">

Quét mã trên bằng điện thoại để mở thẳng trang tải bản mới nhất.

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
3. Cửa sổ agent hiện **địa chỉ IP** và **mã ghép cặp 6 số**.

**Agent chạy ngầm, không chiếm chỗ làm việc.** Bấm **X** trên cửa sổ agent
chỉ ẩn cửa sổ đi — agent vẫn chạy, icon HeDeck nằm ở khay hệ thống (bấm mũi
tên **^** góc phải thanh tác vụ, *Show hidden icons*):

- **Bấm** icon: mở lại cửa sổ agent.
- **Chuột phải** icon → **Mã ghép cặp mới**, hoặc **Thoát HeDeck Agent** để
  tắt hẳn. Chỉ cách này mới tắt agent.
- Lỡ nháy đúp `HeDeckAgent.exe` thêm lần nữa thì cửa sổ cũ hiện lên, không
  chạy agent thứ hai.

Tuỳ chọn, trong cùng thư mục:

| File | Làm gì |
|---|---|
| `TU_CHAY_CUNG_WINDOWS.bat` | Agent tự chạy ngầm ở khay mỗi khi đăng nhập Windows, không mở cửa sổ nào. Chạy lại để gỡ. |
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
**Ghép cặp**. Mã hết hạn thì bấm **Mã mới** trong cửa sổ agent.

---

## Cập nhật

Không có gì tự cài sau lưng bạn — cả hai đều hỏi trước.

**App:** bánh răng ⚙ → **Kiểm tra cập nhật**. Có bản mới thì app hiện ghi
chú thay đổi; bấm **Cập nhật**, app tải về và mở trình cài đặt của Android,
bấm **Cài đặt** để xong. Lần đầu Android hỏi cho phép HeDeck cài ứng dụng —
bật lên rồi quay lại.

Cập nhật **giữ nguyên mọi thứ**: các trang, ô và app đã chọn, ngôn ngữ, giao
diện sáng/tối, tốc độ chuột, tự đổi trang, MAC bật máy và ghép cặp. Android
chỉ xoá dữ liệu khi **gỡ** app, không xoá khi cài bản mới đè lên.

**Agent:** khi mở và cứ 12 giờ, agent hỏi GitHub. Có bản mới thì icon ở
khay báo một thông báo nhỏ, và cửa sổ agent hiện dải **"Có bản mới …"**. Bấm
**Xem và cập nhật** để đọc ghi chú thay đổi, đồng ý thì agent tải bản mới,
kiểm tra mã SHA-256, thay file và tự mở lại. Tải hỏng thì giữ nguyên bản cũ.
Điện thoại đã ghép và danh mục app (`%USERPROFILE%\.hedeck`) giữ nguyên.

> App và agent nên cùng phiên bản. App báo *"Agent là bản cũ"* thì cập nhật
> agent trước.

---

## Gỡ cài đặt

- **App:** gỡ như mọi app Android.
- **Agent:** chuột phải icon ở khay → **Thoát HeDeck Agent**, chạy lại
  `TU_CHAY_CUNG_WINDOWS.bat` nếu đã bật tự chạy, rồi xoá thư mục agent. Dữ liệu (điện thoại đã ghép, danh mục app) nằm ở
  `%USERPROFILE%\.hedeck`, xoá luôn nếu muốn sạch hẳn.
