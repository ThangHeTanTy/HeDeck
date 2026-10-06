# HeDeck — tài liệu kỹ thuật

> Hướng dẫn sử dụng cho người dùng nằm ở [README](../README.md).
> Hướng dẫn cài đặt từng bước nằm ở [BAT_DAU.md](BAT_DAU.md).

Điện thoại Android trở thành một Steam Deck nhỏ: 8 ô lớn, chạm một cái là
ứng dụng trên laptop mở lên và được đưa ra trước. Kèm điều khiển nhạc, âm
lượng, và các ô macro gõ tổ hợp phím.

```
Android (Flutter)  ──  WebSocket ws://<ip>:8787  ──  Agent Python (Windows)
   8 ô, media, macro         cùng mạng Wi-Fi          mở app, focus cửa sổ
```

## Phần 1 — Chạy agent trên laptop

Cần Python 3.10 trở lên trên Windows 10/11.

```bat
cd agent
run_agent.bat
```

Lần đầu, script tự tạo môi trường ảo và cài phụ thuộc. Những lần sau nó vẫn
kiểm tra thư viện có đủ không rồi mới chạy, nên môi trường hỏng giữa chừng sẽ
được dựng lại tự động. Cửa sổ sẽ hiện ngay:

```
  ┌───────────────────────────────────────────┐
  │  HeDeck Agent · DESKTOP-A1B2C3            │
  │  Địa chỉ  : ws://192.168.1.12:8787         │
  │  Mã ghép  : 481902                         │
  │  Ứng dụng : 63                             │
  └───────────────────────────────────────────┘
```

Giữ cửa sổ này chạy. Lần đầu Windows Firewall sẽ hỏi — chọn **Cho phép ở
mạng riêng (Private networks)**.

Mã ghép cặp sống 5 phút. Hết hạn thì **nhấn Enter ngay trong cửa sổ agent**,
bảng thông tin in lại kèm mã mới. Không cần khởi động lại.

Danh mục được dựng theo **hai chặng**, để bạn không phải chờ:

1. Quét tên và đường dẫn app — khoảng một giây. Gửi ngay sang điện thoại, các ô
   dùng được luôn.
2. Trích icon từng app — vài chục giây tới vài phút. Xong thì gửi bổ sung, icon
   tự hiện lên mà không cần làm gì.

Cổng lắng nghe mở trước cả hai chặng, nên ghép cặp được ngay từ giây đầu tiên.

Quét lại danh sách app sau khi cài phần mềm mới: `python agent.py --rescan`,
hoặc bấm nút quét lại ngay trong app điện thoại.

## Phần 2 — Chạy app trên điện thoại

```bat
setup_app.bat          :: Windows
./setup_app.sh         :: macOS / Linux
```

Script chạy `flutter create` để Flutter tự sinh phần khung Android, rồi **vá**
những gì HeDeck cần bằng `android_patch/patch_manifest.ps1`: quyền mạng, tên
hiển thị, network security config, khoá hướng ngang, nền khởi động trắng, và cờ
giữ màn hình sáng trong `MainActivity.kt`.

Giữ màn hình sáng dùng cờ `FLAG_KEEP_SCREEN_ON` của Android chứ không dùng
plugin. Các plugin wakelock hay hỏng mỗi lần Flutter đổi phiên bản Kotlin, mà
việc này chỉ cần đúng một dòng mã.

Gói này **cố tình không chứa sẵn `AndroidManifest.xml`**. Ship sẵn manifest sẽ
khiến `flutter create` bỏ qua bước sinh file, dẫn tới lỗi
`Build failed due to use of deleted Android v1 embedding`. Vá sau khi sinh là
cách duy nhất luôn khớp với phiên bản Flutter bạn đang dùng.

Sau đó nháy đúp **`CHAY_APP.bat`** ở thư mục gốc, hoặc:

```bat
cd flutter_app
flutter run                    :: chạy thử
flutter build apk --release    :: xuất APK
```

### Vì sao nên dùng `CHAY_APP.bat`

Nó cấu hình Gradle, dừng daemon cũ, kiểm tra thiết bị, rồi mới gọi `flutter run`.
Ba bước đó xử lý sẵn nhóm lỗi Kotlin trên Windows mà `flutter run` trực tiếp sẽ
vấp phải trên máy mới.

### Cấu hình Gradle được ghi ở đâu

`android_patch/cau_hinh_gradle.ps1` ghi vào **hai nơi**:

1. **Cấp máy** — `%USERPROFILE%\.gradle\gradle.properties`. Đây mới là chỗ
   quan trọng: nó tồn tại độc lập với project, nên vẫn có hiệu lực kể cả khi
   bạn xoá thư mục `android/`, chạy lại `flutter create`, hay gọi thẳng
   `flutter run` mà không qua script nào.
2. **Cấp project** — `flutter_app/android/gradle.properties`, để người khác
   lấy source về cũng có.

Ban đầu mình chỉ ghi cấp project. Nhưng `android/` được sinh lại mỗi lần chạy
`flutter create`, nên cấu hình biến mất và lỗi quay lại — đúng như đã xảy ra.

Script chỉ sửa những dòng nó quản, giữ nguyên phần còn lại, và chạy lại nhiều
lần không nhân đôi dòng nào.

Code đã dọn sạch các API bị xoá ở Flutter mới (`withOpacity`, `RadioListTile`
kiểu cũ), kiểm trên Flutter 3.44 / Dart 3.12.

Mở app → chọn máy trong danh sách dò tìm (hoặc gõ IP) → nhập mã 6 số → **Ghép cặp**.
Mã chỉ dùng được một lần và hết hạn sau 5 phút; sau khi ghép, điện thoại giữ
token dài hạn nên các lần sau tự kết nối.

## Dùng hàng ngày

| Thao tác | Kết quả |
|---|---|
| Chạm ô ứng dụng chưa chạy | Mở app rồi đưa ra trước |
| Chạm ô đang chạy | Thu nhỏ cửa sổ xuống |
| Chạm ô app có nhiều cửa sổ | Xoay vòng qua từng cửa sổ |
| Giữ 3 giây trên ô đang chạy | Tắt hẳn app, viền đỏ chạy dần làm đồng hồ đếm |
| Giữ ô chưa chạy / macro / media | Mở màn hình sửa ô |
| Nút bút chì | Bật chế độ sửa — lúc này chạm ô nào cũng là sửa ô đó |
| Nút cộng ở thanh dưới | Thêm ô vào chỗ trống gần nhất; hết chỗ thì tự tạo trang mới và trượt sang |
| Vuốt ngang | Đổi trang |

### Viền ô nói gì

| Viền | Nghĩa |
|---|---|
| Không viền | App chưa chạy |
| Tím | Vừa bấm mở, đang chờ cửa sổ hiện ra. Quá 15 giây không thấy thì tự bỏ |
| Xanh lục | App đang chạy |
| Đỏ chạy dần | Đang giữ để tắt app, đủ vòng (3 giây) là tắt. Lúc này dòng trạng thái đổi thành đồng hồ đếm ngược |

Ô chỉ hiện icon. Dòng chữ bên dưới **chỉ xuất hiện khi bạn tự đặt tên** — không
đặt thì icon phình to lấp đầy ô. Trạng thái không còn hiện bằng chữ nữa, màu
viền lo hết. Riêng ô macro không đặt tên sẽ tự hiện tổ hợp phím, vì icon bàn
phím của mọi macro đều giống nhau. Đang giữ để tắt thì dòng chữ tạm thành đồng
hồ đếm ngược.

Góc trái trên có logo chú hề nghiêng 13°, vẽ bằng `CustomPainter` nên nét ở mọi
kích thước. Chạm vào nó là mở menu tuỳ chọn.

### Icon lấy từ đâu

Agent thử ba nguồn theo thứ tự, dừng ở nguồn cho ảnh lớn nhất:

1. **Tài nguyên icon trong file `.exe`** (`icon_source.py`) — đọc thẳng bảng
   `RT_GROUP_ICON` và `RT_ICON`. Đây là nguồn duy nhất cho biết **độ phân giải
   thật**. Các API tiện dụng của Windows như `PrivateExtractIcons` hay
   `ExtractIconEx` **tự phóng to** khi file không có khung đúng cỡ và không hề
   báo — xin 256px từ file chỉ có 32px thì nhận về ảnh mờ mà cứ tưởng là nét.
2. **Ảnh logo đi kèm trong thư mục cài đặt** — nhiều ứng dụng Electron và Store
   để sẵn PNG lớn ở `Assets/`, `resources/`… thường nét hơn icon nhúng. Nguồn
   này bị siết chặt vì nhận nhầm một ảnh bất kỳ làm icon còn tệ hơn icon mờ:
   bỏ qua toàn bộ thư mục hệ thống (`System32`, `SysWOW64`, `WinSxS`), chỉ nhận
   file trùng tên chương trình hoặc tên quy ước (`icon.png`, `logo.png`…), bắt
   buộc ảnh phải vuông, và cạnh phải nằm trong khoảng 128–1024 px. Ảnh rời chỉ
   thắng khi lớn hơn icon trong `.exe` ít nhất 1,5 lần.
3. **Danh sách ảnh hệ thống** rồi `PrivateExtractIcons`, làm phương án dự phòng.

Sau đó ảnh được cắt sạch phần thừa và căn giữa trong khung vuông. Việc cắt ưu
tiên kênh alpha; icon nào không mang thông tin trong suốt thì so với màu ở góc
để tìm vùng có nội dung. Nhờ vậy icon lấp đầy ô thay vì trôi về một góc.

Muốn biết từng app có icon bao nhiêu pixel, chạy `agent/kiem_tra_quet.py` —
bước 8 in bảng độ phân giải kèm các cỡ có trong file. App nào dưới 128px sẽ có
dấu `!`; với những app đó, cách duy nhất để nét hơn là **chọn icon vector từ
thư viện** trong màn hình sửa ô.

Phía app còn một lớp bảo hiểm nữa: `widgets/app_icon.dart` quét kênh alpha của
mỗi icon một lần để tìm vùng thật sự có nội dung, rồi chỉ vẽ đúng vùng đó cho
lấp đầy ô. Nhờ vậy icon luôn nằm giữa, kể cả khi ảnh nhận được có nội dung kẹt
ở một góc. Kết quả giải mã được nhớ lại nên chỉ tốn công một lần.

Kích thước vẽ ra là một sự cân bằng: icon **luôn chiếm ít nhất 82% ô**, và
được phép lấp đầy 100% khi độ phân giải gốc đủ cao. App có icon 256px thật thì
luôn đầy ô; app cũ chỉ có icon 32px thì dừng ở 82% cho đỡ vỡ. Icon nhỏ còn được
làm nét bằng UnsharpMask sau khi phóng to.

`catalog.json` có số phiên bản. Đổi cách trích icon thì tăng `CATALOG_VERSION`
trong `catalog.py`, agent thấy số cũ hơn sẽ tự quét lại lúc khởi động.

### Khi mất kết nối

App tự thử lại mãi, thời gian chờ tăng dần rồi dừng ở 20 giây một lần — agent
tắt cả ngày thì bật lên là app nối lại trong vòng 20 giây. Thanh trên đếm ngược
tới lần thử kế tiếp để bạn biết nó đang chạy chứ không phải treo.

Cứ ba lần hụt liên tiếp, app **dò lại bằng mDNS**: router cấp IP khác cho laptop
thì app tự cập nhật địa chỉ và lưu lại, không cần ghép cặp lại. Ngoại lệ quan
trọng — nếu địa chỉ đang lưu là `127.0.0.1` (máy ảo hoặc cáp USB qua
`adb reverse`), app **không** dò lại, vì địa chỉ LAN tìm được sẽ không tới nơi.

Mở app từ nền cũng thử kết nối ngay thay vì chờ hết chu kỳ.

Thanh trên hiện nút **↻** để thử lại ngay. Nếu agent không còn nhận ra thiết bị
(nhấn **D** xoá danh sách, `agent.json` bị xoá, hoặc khoá đã đổi), trạng thái
chuyển thành *Cần ghép cặp lại* kèm nút mở thẳng màn hình ghép cặp — thử lại tự
động trong trường hợp này là vô ích nên app không phí thời gian.

Trạng thái này **không bị ghi đè** khi socket đóng. Agent gửi lỗi rồi ngắt kết
nối ngay, nên nếu xử lý ngắt kết nối coi đây là mất mạng bình thường thì app sẽ
quay lại vòng thử vô hạn và người dùng không bao giờ thấy nút ghép cặp lại.
Cả `start()` lẫn nút ↻ đều dừng khi ở trạng thái này; chỉ ghép cặp mới thoát ra
được.

### Bố cục

Vào nút bánh răng để đổi giữa **5 × 2** (10 ô) và **5 × 3** (15 ô). Ô luôn
vuông và cả lưới được căn giữa. Đổi qua lại không mất dữ liệu: mỗi trang luôn
giữ đủ 15 chỗ, bố cục chỉ quyết định hiển thị bao nhiêu. Xoay dọc màn hình thì
lưới tự lật lại thành 2 × 5 hoặc 3 × 5.

Vì ô vuông, **số hàng quyết định cạnh ô**, không phải số cột. Trên điện thoại
ngang cỡ Pixel 7: 5 × 2 cho ô 136 điểm, 5 × 3 cho ô 88 điểm. Bố cục 3 hàng để
lại khoảng trống hai bên — nếu bạn muốn lấp kín, 7 hoặc 8 cột sẽ vừa hơn, đổi
hằng số `Store.cols` là được.

### Icon cho từng ô

Mỗi ô chọn được icon từ **thư viện 113 icon vector**, chia theo nhóm
Livestream, Âm thanh, Cửa sổ, Hệ thống, Công việc, Điều hướng, Ký hiệu, Chữ số.
Có ô tìm theo tiếng Việt. Icon vector nét ở mọi kích thước, khác với icon lấy
từ `.exe` vốn chỉ có tối đa 256 pixel và sẽ vỡ khi ô lớn.

Ô ứng dụng mặc định dùng icon của app, nhưng chọn icon thư viện thì icon đó
được ưu tiên — tiện khi muốn cả deck nhìn đồng bộ.

### Ô hai trạng thái

Bật trong màn hình sửa ô, dùng được với macro và media. Ô có **hai mặt**, mỗi
mặt có icon, màu, nhãn và hành động riêng. Bấm một lần chạy mặt chính rồi lật
sang mặt phụ; bấm lần nữa chạy mặt phụ rồi lật về. Khi đang ở mặt phụ, ô đổi
nền và viền theo màu mặt đó nên nhìn từ xa là biết.

Ví dụ điển hình cho livestream: mặt chính `ctrl+shift+m` với icon micro màu
xanh, mặt phụ cũng `ctrl+shift+m` nhưng icon micro gạch chéo màu đỏ.

Trạng thái lật được lưu lại sau khi đóng app — micro vẫn đang tắt dù bạn có mở
app hay không.

### Âm lượng riêng từng ứng dụng

Loại ô **Âm lượng** chỉnh tiếng của đúng một app, độc lập với âm lượng chung:
hạ nhạc nền mà không hạ giọng nói. Mỗi lần bấm đổi 5%, hoặc bật tắt tiếng.

Agent dùng `pycaw` để nói chuyện với phiên âm thanh của Windows. App chỉ đo
mức âm lượng của những app thật sự có ô âm lượng trên deck, không đo tất cả.

Ô macro nhận một hoặc nhiều tổ hợp, ngăn bằng dấu phẩy:
`ctrl+shift+p` hoặc `win+d, alt+tab`. Tên phím hỗ trợ: các chữ cái, `f1`–`f24`,
`enter`, `esc`, `tab`, `space`, `up`/`down`/`left`/`right`, `home`, `end`,
`pageup`, `pagedown`, `delete`, `printscreen`, cùng modifier `ctrl` `alt`
`shift` `win`.

## Giao thức

JSON trên một WebSocket duy nhất.

Ghép cặp:

```json
→ {"t":"pair","code":"481902","device_id":"a1b2…","device_name":"Pixel 8"}
← {"t":"paired","token":"<64 hex>","device_id":"a1b2…","host_name":"DESKTOP-A1B2C3"}
```

Các lần sau, ký bằng token đó:

```json
→ {"t":"auth","device_id":"a1b2…","ts":1754640000,"nonce":"9f…",
   "sig":"HMAC-SHA256(token, 'device_id|ts|nonce')"}
← {"t":"auth_ok","host_name":"DESKTOP-A1B2C3"}
```

Lệnh: `catalog`, `rescan`, `launch` (`app_id`, `toggle`), `close` (`app_id`),
`macro` (`keys`), `media` (`action`), `ping`. Lệnh `close` gửi `WM_CLOSE` trước,
chờ 3 giây, còn sống thì `terminate` rồi `kill`. Agent đẩy `status` mỗi 1,5 giây với danh sách app
đang chạy và số cửa sổ của từng app.

Nguồn: `power` (`action` là `lock` | `sleep` | `restart` | `shutdown`, `force`
để đóng luôn app chưa lưu). Agent trả `{"t":"power"}` trước rồi 0,8 giây sau
mới thực hiện, vì tắt máy xong thì không còn kết nối để trả lời. Tắt máy dùng
`shutdown /s /t 0` không kèm cờ hybrid, tức tắt hẳn (S5), không đi qua Fast
Startup. Đặt `ALLOW_POWER = False` trong `agent.py` để chặn nhóm lệnh này.

`paired` và `auth_ok` mang thêm khối `wol`:

```json
"wol": {"macs":["D8:43:AE:12:34:56"],"broadcast":"192.168.1.255",
        "wired":true,"warnings":[]}
```

Điện thoại lưu `macs` và `broadcast`. Lúc máy tắt, app tự dựng magic packet
(6 byte `FF` + MAC lặp 16 lần) và gửi UDP broadcast tới `255.255.255.255` và
địa chỉ broadcast của mạng, cổng 9 và 7, ba lượt. Không gửi thẳng IP của máy:
máy tắt không trả lời ARP nên gói gửi thẳng sẽ lạc. Agent lấy MAC bằng
`Get-NetAdapter` và chỉ gửi card **có dây** — card Wi-Fi không nhận
Wake-on-LAN khi máy tắt hẳn. Chi tiết cài đặt: `docs/BAT_MAY_TU_XA.md`.

## Bảo mật

Ba tầng độc lập nhau. Một tầng thủng thì hai tầng còn lại vẫn giữ.

### Tầng 1 — Chặn theo mạng

Agent chỉ nhận kết nối từ dải IP nội bộ (`192.168.x`, `10.x`, `172.16–31.x`,
loopback, link-local). Máy ngoài Internet không bao giờ chạm được tới lớp xác
thực, kể cả khi có ai đó mở cổng 8787 ra ngoài router.

### Tầng 2 — Phát hiện và chặn IP lạ

`security.py` theo dõi từng IP:

| Hành vi | Hậu quả |
|---|---|
| Sai mã ghép cặp 5 lần trong 5 phút | Khoá tạm 15 phút |
| Gửi lệnh khi chưa xác thực | Tính là một lần thất bại |
| Trên 30 kết nối mỗi phút | Khoá tạm ngay |
| Bị khoá tạm 3 lần | Chặn vĩnh viễn, ghi vào `blocked.json` |
| IP ngoài mạng nội bộ | Từ chối ngay, ghi log |

Mọi cảnh báo hiện thẳng trên cửa sổ agent kèm địa chỉ IP. Bảng khởi động đếm
số IP đang bị chặn. Nhấn **U** rồi Enter để gỡ toàn bộ danh sách chặn.

### Tầng 3 — Chữ ký một chiều

Điện thoại sinh một cặp khoá **Ed25519** trong lần chạy đầu. Khoá bí mật nằm
trong vùng dữ liệu riêng của app và **không bao giờ rời khỏi máy**. Lúc ghép
cặp, chỉ khoá công khai được gửi sang laptop.

Bản trước dùng `flutter_secure_storage`. Thư viện đó dựa trên
`EncryptedSharedPreferences` của Jetpack Security — đã bị Google ngừng phát
triển và ghi/đọc hỏng lặng lẽ trên Android mới (thấy rõ trên Android 17). Khoá
bị sinh lại mà app không hay biết, laptop không còn nhận ra thiết bị, và lỗi
hiện ra dưới dạng *Chữ ký không hợp lệ* — rất khó lần. Vùng dữ liệu riêng của
app không đọc được từ app khác trên máy chưa root, đủ an toàn cho mục đích ở
đây và quan trọng hơn là hoạt động ổn định. Khi nạp, app còn dựng lại khoá công
khai từ hạt giống và đối chiếu, lệch thì sinh lại ngay thay vì ký bằng khoá
hỏng.

Mỗi lần kết nối, điện thoại ký `device_id|timestamp|nonce` bằng khoá bí mật.
Agent xác minh bằng khoá công khai đang giữ. Điều này có nghĩa:

- **Đọc trộm `agent.json` trên laptop không giả mạo được thiết bị.** File đó
  chỉ chứa khoá công khai. Đây là khác biệt căn bản so với HMAC khoá chung,
  nơi hai bên giữ cùng một bí mật và lộ một bên là lộ cả hai.
- **Không phát lại được.** Mỗi nonce chỉ dùng một lần, agent nhớ 4096 nonce gần
  nhất. Lệch giờ quá 2 phút cũng bị từ chối.

Điện thoại gửi kèm khoá công khai đang dùng trong mỗi lần xác thực. Agent đối
chiếu với khoá đã lưu: lệch nhau thì nó trả về mã `key_changed` và app đưa
thẳng về màn hình ghép cặp. Trường hợp này **không** bị tính vào bộ đếm chặn IP,
vì cài lại app là chuyện bình thường chứ không phải tấn công.

App cũng tự kiểm tra ngay lúc khởi động: vân tay khoá hiện tại phải trùng vân
tay đã lưu lúc ghép cặp. Lệch là dọn ghép cặp cũ luôn, không phí thời gian thử
kết nối.

Vân tay khoá hiện ở hai nơi để đối chiếu: dòng log lúc ghép cặp trên laptop, và
khối thông tin trong menu tuỳ chọn trên điện thoại. Hai chỗ khác nhau nghĩa là
có thiết bị khác đã ghép cặp.

### Giới hạn còn lại

Kênh vẫn là `ws://` chưa mã hoá — nội dung lệnh có thể bị đọc trong mạng nội bộ,
dù không thể bị giả mạo. Người ở cùng mạng thấy được bạn mở app nào, nhưng không
tự mở app được. Ở mạng nhà thì chấp nhận được; ở Wi-Fi công cộng thì không nên.

Điện thoại cũng chỉ gửi `app_id`, không bao giờ gửi đường dẫn hay lệnh shell.
Kể cả khi ai đó vượt được cả ba tầng, họ chỉ mở được đúng những app đã có trong
danh mục trên laptop.

## Build bản phát hành

```bat
BUILD_APK.bat
```

Script chạy `flutter build apk --release` kèm:

- `--obfuscate` — đổi tên lớp, hàm, biến trong mã Dart thành ký tự vô nghĩa.
  Dịch ngược APK sẽ không đọc được logic.
- `--split-debug-info=..\debug_symbols` — tách bảng đối chiếu ra ngoài, không
  kèm trong APK. Giữ thư mục này lại nếu muốn đọc stack trace từ bản đã phát
  hành; mất nó thì báo lỗi từ người dùng sẽ vô nghĩa.

**Không dùng `--shrink`.** R8 cắt bỏ lớp Java/Kotlin mà nó cho là không ai gọi,
nhưng các plugin dùng Pigeon (`shared_preferences` chẳng hạn) gọi qua cầu nối
nên R8 không thấy đường gọi và cắt mất. Hậu quả là bản release lỗi trong khi
bản gỡ lỗi vẫn chạy — rất khó lần vì hai bản chạy cùng một mã Dart. Vài trăm KB
tiết kiệm được không đáng để đổi lấy rủi ro đó.

Phòng khi Gradle vẫn bật R8, `android_patch/proguard-rules.pro` giữ lại các lớp
Flutter, lớp plugin và lớp Pigeon sinh ra. Script vá chép file này vào
`android/app/` tự động.

Xong, script in **SHA-256** của file APK và ghi ra `app-release.apk.sha256`.
Gửi kèm mã này khi chia sẻ APK để người nhận đối chiếu, biết file không bị sửa
giữa đường.

## Xử lý sự cố

**Agent báo `ModuleNotFoundError: No module named 'websockets'`** hoặc
`The system cannot find the path specified` — môi trường ảo hỏng hoặc dở dang.
Bản mới của `run_agent.bat` tự phát hiện và dựng lại; nếu vẫn lỗi, chạy
`agent\SUA_LOI_AGENT.bat` để xoá sạch `.venv` rồi làm lại từ đầu.

**Không dò thấy máy nào** — nhiều router chặn multicast, nhất là mạng công ty
và mạng khách. Nhập IP thủ công, địa chỉ đã hiện sẵn trên cửa sổ agent. Log của
app sẽ in `HeDeck: dò tìm mDNS không thành (...)` kèm lý do.

Trên máy ảo Android, dò tìm gần như chắc chắn không ra gì vì máy ảo nằm sau lớp
mạng ảo riêng — dùng `adb reverse tcp:8787 tcp:8787` rồi nhập `127.0.0.1`.

**Ghép cặp báo hết thời gian chờ** — hai thiết bị phải cùng một mạng
(cẩn thận mạng khách và băng tần 5 GHz tách SSID), và Windows Firewall phải
cho phép Python ở mạng riêng.

**App mở nhưng không nổi lên trước** — Windows khoá foreground khá chặt.
`force_foreground()` đã dùng mẹo AttachThreadInput kèm nhấp ALT, xử lý được
hầu hết trường hợp. Vài app chạy quyền admin thì agent thường cũng phải chạy
admin mới focus được.

**Một số app không thấy trong danh sách** — agent chỉ quét shortcut trong
Start Menu. Thêm tay vào `%USERPROFILE%\.hedeck\catalog.json` theo mẫu có sẵn
(`id` tự đặt, `path` là đường dẫn `.exe` hoặc `.lnk`, `exe` là tên file chạy
để khớp cửa sổ), rồi khởi động lại agent.

**`flutter doctor` báo đỏ mục Visual Studio** — bỏ qua. Mục đó chỉ cần khi build
app Windows desktop, không liên quan tới APK Android.

**`Build failed due to use of deleted Android v1 embedding`** — thư mục
`android/` bị lệch. Chạy `SUA_LOI_ANDROID.bat`: nó xoá sạch `android/`, `build/`,
`.dart_tool/` rồi dựng lại từ đầu và vá manifest. Code trong `lib/` không bị đụng.

**`Storage ... is already registered`** — Kotlin daemon cũ còn chạy và vẫn giữ
các file cache đã đăng ký từ lần build hỏng trước. Xoá thư mục `build` thôi
không đủ, phải giết daemon. Chạy `.\SUA_LOI_KHAC_O_DIA.bat` — nó dùng
PowerShell + CIM để tìm và dừng tiến trình (`wmic` đã bị gỡ khỏi Windows 11 bản
mới nên không dùng được nữa), sau đó ghi
`kotlin.compiler.execution.strategy=in-process` để Kotlin biên dịch ngay trong
tiến trình Gradle, không sinh daemon riêng và không còn giữ trạng thái giữa các
lần build.

**`this and base files have different roots` hoặc `Could not close incremental
caches`** — project nằm khác ổ đĩa với Pub cache (ví dụ project ở `D:`, cache ở
`C:\Users\...\AppData\Local\Pub\Cache`). Kotlin không tính được đường dẫn
tương đối giữa hai ổ nên build sập. Chạy `SUA_LOI_KHAC_O_DIA.bat`: nó dừng
Gradle daemon, xoá cache hỏng, và ghi `kotlin.incremental=false` vào
`android/gradle.properties`.

Script tự đo xem project và Pub cache có cùng ổ đĩa không, rồi cho chọn:

1. **Tắt biên dịch tăng dần** — nhanh, sửa được ngay, đổi lại mỗi lần build đều
   biên dịch lại từ đầu.
2. **Chuyển Pub cache về cùng ổ với project** (`setx PUB_CACHE D:\pub-cache`) —
   dứt điểm, giữ được biên dịch tăng dần nên build lại nhanh hơn nhiều. Lần
   chạy đầu phải tải lại toàn bộ package.
3. Cả hai.

Với cách 2, nhớ **mở lại cửa sổ PowerShell** sau khi chạy, vì biến môi trường
chỉ có hiệu lực ở tiến trình mở sau đó.

`setup_app.bat` cũng cảnh báo ngay từ đầu nếu phát hiện hai thứ khác ổ đĩa.

**`Unresolved reference` hoặc `compileDebugKotlin failed` ở một plugin** — plugin
đó chưa hợp với bản Flutter hiện tại. Chạy `SUA_LOI_PLUGIN.bat` ở thư mục gốc:
nó dọn cache build, xoá bản plugin hỏng trong Pub cache, tải lại rồi vá lại
MainActivity.

**Ô hiện icon màn hình chung chung** — chặng lấy icon chưa xong hoặc đã lỗi.
Xem cửa sổ agent: `Đang lấy icon cho N ứng dụng...` là vẫn đang chạy. Nếu có
dòng `LỖI khi lấy icon` thì chép ra để lần nguyên nhân; danh sách app vẫn dùng
bình thường vì hai chặng độc lập nhau.

**Kẹt mãi ở "Đang lấy danh sách ứng dụng…"** — xem cửa sổ agent. Nếu có dòng
`LỖI khi quét danh mục`, chép nguyên đoạn đó ra để lần nguyên nhân. Agent luôn
mở khoá trạng thái kể cả khi quét hỏng, nên nếu app vẫn kẹt thì nhiều khả năng
kết nối đã đứt chứ không phải quét treo — bấm nút ↻ ở thanh trên.

**Ghép cặp được nhưng danh sách app trống** — agent còn đang quét. Thanh trên
sẽ hiện *Đang quét ứng dụng trên laptop…*, danh mục tự đến khi xong.

**Ghép cặp báo "Thiếu khoá công khai"** — điện thoại chưa tạo được cặp khoá.
Màn hình ghép cặp có dòng *Khoá thiết bị XXXX:XXXX:XXXX* ở gần nút bấm: hiện
vân tay là khoá đã có; hiện *Máy này chưa tạo được khoá thiết bị* màu đỏ nghĩa
là khâu tạo khoá hỏng, và thông báo lúc bấm Ghép cặp sẽ nói rõ lý do.

Nguyên nhân hay gặp nhất là bản release bị R8 cắt mất lớp của
`shared_preferences`; xem mục Build bản phát hành ở trên. Từ bản này khoá được
giữ trong bộ nhớ trước rồi mới lưu xuống đĩa, nên máy không ghi được vẫn ghép
cặp và dùng bình thường trong phiên đó.

**Agent báo "Chữ ký không hợp lệ" hoặc "Khoá thiết bị đã thay đổi"** — điện
thoại đã sinh khoá mới, thường sau khi cài lại app. Nhấn **D** rồi Enter trong
cửa sổ agent để xoá thiết bị cũ, sau đó ghép cặp lại. Dòng log kèm theo cho biết
vân tay đã lưu và vân tay máy gửi, đối chiếu được ngay.

**Agent báo "CHẶN: kết nối từ ngoài mạng nội bộ"** — thiết bị đang ở mạng khác.
Kiểm tra hai máy có cùng Wi-Fi không. Trên máy ảo Android, dùng
`adb reverse tcp:8787 tcp:8787` rồi nhập IP `127.0.0.1`.

**Bị khoá do nhập sai mã nhiều lần** — nhấn **U** rồi Enter trong cửa sổ agent
để gỡ, hoặc xoá `%USERPROFILE%\.hedeck\blocked.json`.

**App UWP từ Microsoft Store** — thường không có `.exe` thật để khớp cửa sổ.
Vẫn mở được, nhưng phần focus và trạng thái "đang chạy" có thể không chính xác.

## Màn hình mở đầu

Mở app: chú hề hiện lên giữa nền trắng, dừng một nhịp, rồi một vòng tròn màu
nền deck lan từ tâm ra nuốt hết nền trắng, cuối cùng cả lớp mờ dần để lộ màn
hình chính.

**Màn hình chính được dựng sẵn ngay từ đầu**, nằm dưới lớp phủ. Không có bước
chuyển màn hình nào cả.

Bản đầu tiên làm khác: hoạt ảnh chạy xong thì gọi `Navigator.pushReplacement`
từ `whenComplete`. Cả việc chuyển màn hình treo vào đúng một sự kiện — nó không
chạy là app kẹt vĩnh viễn ở nền tối, **không lỗi, không log, không cách nào
thoát**. Người dùng chỉ thấy màn hình đen sau khi logo chạy xong, và mọi dấu
hiệu đều chỉ sai hướng sang trình vẽ Impeller.

Cách hiện tại không có điểm chết đó. Kèm theo một lưới an toàn: quá thời lượng
hoạt ảnh cộng 2 giây thì lớp phủ tự biến mất dù có chuyện gì xảy ra.

Việc chọn hiện deck hay màn hình ghép cặp cũng do **một nơi duy nhất** quyết
định — `store.isPaired` ở gốc app. Ghép cặp xong hay quên laptop đều chỉ cần
đổi trạng thái đó, không màn hình nào tự đẩy màn hình khác nữa.

Nền khởi động của Android cũng được đặt trắng (`android_patch/launch_background.xml`)
để không bị nháy tối rồi sáng trong vài trăm mili giây trước khi Flutter kịp vẽ.

## Logo

Icon launcher là đầu chú hề — chữ **He** trong HeDeck chính là **hề** — kèm chữ
`Deck` dựng khối 3D. File nguồn nằm ở `tools/make_icon.py`, vẽ hoàn toàn bằng
Pillow nên sửa màu hay bố cục là chạy lại script, không cần phần mềm đồ hoạ:

```bash
cd tools
pip install Pillow
python make_icon.py          # xuất icon.png, icon_foreground.png, preview.png
```

Chép hai file PNG vào `flutter_app/assets/icon/` rồi chạy
`dart run flutter_launcher_icons` trong `flutter_app` để sinh lại toàn bộ mipmap
và adaptive icon. Bước này `setup_app.bat` đã làm sẵn.

## Tự kiểm tra

```bash
cd agent
python kiem_tra_agent.py
```

Bộ kiểm tra đọc mã nguồn bằng AST và soi những thứ mắt người dễ bỏ sót: một
tác vụ nền khai báo rồi nhưng chưa được khởi động trong `main()`, một phương
thức không ai gọi, một lệnh thiếu nhánh xử lý. `run_agent.bat` chạy nó tự động
trước khi khởi động agent và chỉ in ra khi có vấn đề.

Nó ra đời sau một lỗi thật: lời gọi `load_catalog()` biến mất khỏi `main()` sau
một lần sửa code, khiến `catalog_ready` mãi là `False` và app chờ danh mục vô
hạn. Nhìn mã thì mọi thứ vẫn đủ — hàm còn nguyên, chỉ là không ai gọi.

Chạy được trên mọi hệ điều hành vì chỉ phân tích mã nguồn, không cần Windows.

## Cấu trúc

```
tools/make_icon.py  script vẽ logo
agent/
  agent.py          server WebSocket, ghép cặp, xác thực, đẩy trạng thái
  security.py       chặn IP lạ, khoá tạm, chữ ký Ed25519
  kiem_tra_agent.py tự kiểm tra mã nguồn
  kiem_tra_quet.py  chẩn đoán riêng phần quét danh mục
  win_control.py    mở app, focus/toggle cửa sổ, phím media, macro, trích icon
  catalog.py        quét Start Menu, danh mục app
  power.py          tắt/ngủ/khoá máy, đọc MAC cho Wake-on-LAN
flutter_app/
  lib/main.dart
  lib/theme.dart
  lib/models/deck.dart
  lib/services/     store.dart · deck_connection.dart · discovery.dart ·
                    wake_on_lan.dart
  lib/screens/      pair_screen.dart · deck_screen.dart · tile_edit_screen.dart
  lib/widgets/      deck_tile_view.dart · media_bar.dart
```

## Hướng phát triển tiếp

Tầng transport đã tách riêng qua `DeckConnection`, nên thêm kênh khác không
phải viết lại giao diện:

1. **Bluetooth SPP** — thay phần mở socket, giữ nguyên JSON và HMAC.
2. **USB qua `adb reverse tcp:8787 tcp:8787`** — chỉ cần đổi host thành
   `127.0.0.1`, không sửa dòng code nào khác.
3. **Touchpad ảo** — thêm lệnh `mouse` với delta toạ độ, dùng `SendInput`.
4. **wss:// + ghim chứng chỉ** — đóng nốt lỗ hổng nghe lén.
5. **Đóng gói agent thành `.exe` + icon khay hệ thống + tự chạy cùng Windows**
   (`pyinstaller --noconsole --onefile agent.py` kèm `pystray`).
