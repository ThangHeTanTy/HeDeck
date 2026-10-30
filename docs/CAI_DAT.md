# Cài HeDeck từ bản phát hành

Không cần Python, Flutter hay cáp USB — chỉ tải hai file từ
[**trang tải HeDeck**](https://thanghetanty.github.io/HeDeck/) hoặc trang
[**Releases**](https://github.com/ThangHeTanTy/HeDeck/releases/latest).

Điện thoại và máy tính phải dùng **cùng một mạng Wi-Fi / mạng nhà**.

<img src="images/qr-tai-hedeck.png" width="180" alt="Mã QR mở trang tải HeDeck">

Quét mã trên bằng điện thoại để mở thẳng trang tải bản mới nhất.

---

## 1. Máy tính Windows — agent

1. Tải **[`HeDeckAgent.zip`](https://github.com/ThangHeTanTy/HeDeck/releases/latest/download/HeDeckAgent.zip)**, giải nén ra một thư mục cố định, ví dụ
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

1. Trên điện thoại, tải **[`HeDeck.apk`](https://github.com/ThangHeTanTy/HeDeck/releases/latest/download/HeDeck.apk)** (hoặc quét mã QR ở trên).
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

## iPhone, iPad — bản web

iPhone không cài được file như APK, nên HeDeck chạy trên Safari: **agent tự
phục vụ bản web**, không cần cài gì, không cần tài khoản Apple.

1. Chạy agent trên máy tính như bước 1. iPhone/iPad dùng cùng Wi-Fi.
2. Mở **Camera** trên iPhone, quét **mã QR** ở góc phải cửa sổ agent (cạnh mã
   ghép cặp), bấm vào đường link hiện ra. HeDeck mở trong Safari và **tự ghép
   cặp** — không phải gõ mã.
   - Không quét được: mở Safari, gõ địa chỉ dòng **Bản web** trong cửa sổ
     agent, ví dụ `http://192.168.1.12:8787/`, rồi nhập mã 6 số.
3. Để dùng như app, toàn màn hình: bấm nút **Chia sẻ** (ô vuông có mũi tên
   lên) → **Thêm vào Màn hình chính** → **Thêm**. Từ giờ mở HeDeck từ biểu
   tượng trên màn hình chính. Xoay ngang điện thoại cho rộng.

Bản web làm được gần như mọi thứ của app Android: các ô, macro, media, âm
lượng từng app, touchpad, bàn phím, đo hiệu năng, khoá/ngủ/tắt máy. Khác biệt:

- **Không bật được máy đang tắt** (Wake-on-LAN): trình duyệt không gửi được
  tín hiệu bật máy. Các lệnh khi máy đang chạy vẫn dùng được.
- **Tự cập nhật theo agent:** cập nhật agent là bản web mới theo, tải lại trang.
- Màn hình được giữ sáng sau lần chạm đầu tiên. Không rung khi chạm (Safari
  không hỗ trợ).
- Biểu tượng trên màn hình chính gắn với **địa chỉ IP** của máy tính. Nếu router
  đổi IP máy tính, biểu tượng cũ không mở được: quét lại mã QR và ghép cặp lại.
  Để tránh, đặt **IP cố định** (DHCP reservation) cho máy tính trong trang quản
  lý router.

Cũng dùng được trên máy tính bảng Android hay bất kỳ trình duyệt nào trong mạng
nhà, theo đúng cách trên.

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
