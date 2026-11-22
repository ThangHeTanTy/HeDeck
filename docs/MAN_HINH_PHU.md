# Màn hình phụ

Điện thoại hiện một **cửa sổ** hoặc một **màn hình** của máy tính, chạm thẳng
lên hình để điều khiển như màn hình cảm ứng. Mở bằng nút **📡 Màn hình phụ**
trên thanh trên của deck (bấm ☰ nếu đang thu gọn).

Cần HeDeck trên máy tính từ bản có màn hình phụ trở lên. Bản cũ thì app báo
*Cập nhật HeDeck trên máy tính*.

## Hai cách dùng

| | Cửa sổ | Màn hình |
|---|---|---|
| Hiện gì | Đúng một cửa sổ: Discord, OBS, Spotify, Task Manager, khung chat… | Cả một màn hình của Windows |
| Cần cài gì | Không | Màn hình thứ hai, hoặc **màn hình ảo** (bên dưới) |
| Hợp với | Đặt điện thoại cạnh màn hình, luôn thấy chat/nhạc/OBS | Điện thoại thành màn hình mở rộng: kéo cửa sổ sang |

Chọn cửa sổ thì vẫn thấy cửa sổ đó khi nó bị cửa sổ khác che trên máy tính.
Chạm vào thì cửa sổ được đưa ra trước rồi mới nhấp.

App nhớ lựa chọn: lần sau mở lại là vào thẳng màn hình/cửa sổ đó (cửa sổ được
nhớ theo chương trình, ví dụ Discord).

## Thao tác

| Làm gì | Được gì |
|---|---|
| Chạm | Nhấp chuột trái. Chạm nhanh hai lần: nhấp đúp |
| Kéo một ngón | Cuộn, như vuốt trên điện thoại |
| Giữ yên rồi thả | Chuột phải |
| Giữ yên rồi kéo | Kéo thả (kéo file, kéo thanh trượt, chọn chữ) |
| Chụm / mở hai ngón | Phóng to vùng quanh con trỏ, nét như ảnh gốc |
| Nút 📡 góc trái trên | Đổi màn hình/cửa sổ, bỏ phóng to, về deck |

Gõ chữ: dùng bàn phím trong **touchpad** (nút chuột), chữ gõ vào cửa sổ đang
được chọn.

## Biến điện thoại thành màn hình mở rộng thật

Windows chỉ "thấy" thêm màn hình khi có màn hình thật hoặc một **màn hình ảo**.
HeDeck dùng [Virtual Display Driver](https://github.com/VirtualDrivers/Virtual-Display-Driver)
— mã nguồn mở (giấy phép MIT), đã ký số, chạy trên Windows 10/11.

1. Trong thư mục HeDeck trên máy tính, chạy **`CAI_MAN_HINH_AO.bat`** → chọn
   **1**. Windows hỏi quyền Administrator thì bấm **Yes**; hiện cửa sổ *Virtual
   Driver Control* thì bấm **Install**.
2. Cài đặt màn hình của Windows tự mở ra:
   - chọn màn hình mới, đặt **Extend these displays** (*Mở rộng các màn hình
     này*);
   - chọn **độ phân giải** gần với điện thoại. Khi chọn nguồn trong Màn hình
     phụ, app ghi sẵn độ phân giải của điện thoại (ví dụ 2400×1080). Màn hình
     điện thoại dài hơn 16:9 thì hai bên có viền đen, vẫn dùng bình thường;
   - kéo khung màn hình mới tới cạnh màn hình chính, đúng phía bạn đặt điện
     thoại, để con chuột đi sang tự nhiên.
3. Trên điện thoại: **Màn hình phụ** → chọn **màn hình ảo**. Kéo cửa sổ sang
   màn hình đó trên máy tính là nó hiện trên điện thoại.

Mẹo:
- **Tỉ lệ phóng (Scale)** của màn hình ảo đặt 150–200% để chữ đủ to trên điện
  thoại.
- Muốn đúng tỉ lệ điện thoại: thêm độ phân giải riêng trong
  `C:\VirtualDisplayDriver\vdd_settings.xml` (mục `<resolutions>`, ví dụ
  `<width>2400</width><height>1080</height><refresh_rate>60</refresh_rate>`),
  rồi mở **Virtual Driver Control** → *Reload Driver*.
- Không dùng nữa: chạy lại `CAI_MAN_HINH_AO.bat` → **2** để gỡ. Gỡ rồi các cửa
  sổ đang nằm trên màn hình ảo tự về màn hình chính.

## Độ mượt

Hình gửi dạng ảnh nén, chỉ gửi khi có thay đổi. Qua Wi-Fi nhà (nên dùng
5 GHz) khoảng **15–25 khung/giây**: thoải mái cho chat, nhạc, OBS, theo dõi máy,
đọc tài liệu. **Video và game** trên màn hình phụ sẽ giật — chưa phải mục đích
của chế độ này.

Độ nét chỉnh trong touchpad (nút chất lượng), dùng chung cho màn hình phụ. Mặc
định: *Nét* ở nhà, *Vừa* khi ở xa qua Tailscale.

## Sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Danh sách chỉ có *màn hình chính* | Chưa có màn hình thứ hai: cài màn hình ảo như trên, hoặc chọn một cửa sổ. |
| Chọn cửa sổ mà hình đen | Một số app (game, video có DRM) không cho chụp. Chọn màn hình thay vì cửa sổ. |
| Báo *Cửa sổ này đã đóng* | App đã tắt; chọn lại trong danh sách. |
| Chạm lệch chỗ | Cập nhật HeDeck trên máy tính lên bản mới nhất (bản cũ tính sai khi các màn hình có tỉ lệ phóng khác nhau). |
| `CAI_MAN_HINH_AO.bat` báo chưa có winget | Cài *App Installer* từ Microsoft Store, hoặc tải bản cài ở trang Releases của Virtual Display Driver. |
