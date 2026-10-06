# Bật máy từ xa (Wake-on-LAN)

Bấm nút nguồn trên HeDeck là máy tính bật lên, kể cả sau khi đã **tắt hẳn**
(Shut down). Bấm lại khi máy đang chạy thì có Khoá · Ngủ · Khởi động lại · Tắt máy.

## Cách nó chạy

```
 Điện thoại                    Router / switch              PC (đang tắt)
┌───────────┐  UDP broadcast  ┌──────────────┐  dây LAN  ┌──────────────────┐
│  HeDeck   │ ──────────────▶ │ phát cho mọi │ ────────▶ │ card mạng vẫn có │
│ nút nguồn │  magic packet   │ máy trong LAN│           │ điện chờ, thấy   │
└───────────┘   cổng 9 và 7   └──────────────┘           │ đúng MAC → bật   │
                                                          └──────────────────┘
```

Lúc máy tắt thì agent cũng tắt, nên **điện thoại tự gửi gói tin**. Agent chỉ
làm một việc: mỗi lần kết nối, nó gửi cho điện thoại địa chỉ MAC của card mạng
có dây, điện thoại lưu lại để dùng lúc máy tắt.

## Ba điều kiện bắt buộc

1. **PC cắm dây LAN.** Máy đã tắt hẳn chỉ nghe được gói tin qua dây. Wi-Fi
   trên main không giữ kết nối khi máy tắt. Điện thoại thì dùng Wi-Fi bình
   thường, miễn là cùng router.
2. **BIOS cho phép card mạng đánh thức máy** — làm tay một lần.
3. **Windows cho phép card mạng đánh thức máy** — chạy
   `agent\CAI_BAT_MAY_TU_XA.bat` một lần.

## Bước 1 — BIOS (MSI B760 Gaming Plus WiFi DDR4)

Bật máy, bấm liên tục phím **Delete** để vào Click BIOS. Bấm **F7** để chuyển
sang chế độ Advanced nếu đang ở EZ Mode.

| Mục | Đường dẫn | Đặt thành |
|---|---|---|
| ErP Ready | Settings → Advanced → Power Management Setup | **Disabled** |
| Resume By PCI-E Device | Settings → Advanced → Wake Up Event Setup | **Enabled** |

Bấm **F10** để lưu và khởi động lại.

Vì sao: **ErP Ready** là chế độ tiết kiệm điện chuẩn châu Âu, cắt hết điện
chờ dưới 1 W khi tắt máy — card mạng mất điện thì không nghe được gì. Card mạng
có dây trên main này là **Realtek RTL8125BG 2.5G**, nằm trên đường PCI-E, nên
cần bật **Resume By PCI-E Device**. Một số bản BIOS ghi là *Resume By
PCI-E/Networking Device*.

Kiểm tra nhanh: tắt máy, nhìn cổng LAN sau case. **Đèn cổng LAN vẫn sáng hoặc
nháy** là card đang được cấp điện chờ. Đèn tắt hẳn thì ErP Ready vẫn đang bật
(hoặc dây LAN chưa cắm).

## Bước 2 — Windows

Nháy đúp `agent\CAI_BAT_MAY_TU_XA.bat`, bấm **Yes** khi Windows hỏi quyền. Nó
tự làm những việc mà bình thường phải mở Device Manager bấm từng ô:

| Cài đặt của driver Realtek | Đặt thành |
|---|---|
| Wake on Magic Packet | Enabled |
| Shutdown Wake-On-Lan | Enabled |
| Energy-Efficient Ethernet, Green Ethernet, Power Saving Mode | Disabled |
| Power Management → Allow this device to wake the computer | Bật |
| **Fast Startup** của Windows | Tắt |

Card mạng có thể chớp mất kết nối vài giây khi đổi cài đặt — bình thường.

Vì sao phải tắt **Fast Startup**: với nó, nút Shut down trong Start Menu thực
ra là ngủ đông một nửa. Trong trạng thái đó driver Realtek thường không "giao
nhiệm vụ" chờ magic packet cho card mạng, nên máy không dậy. Lệnh Tắt máy
trong HeDeck luôn tắt hẳn, không đi qua Fast Startup, nhưng tắt luôn cho chắc
thì tắt bằng cách nào cũng bật lại được.

## Bước 3 — Cho agent tự chạy khi máy lên

Bật máy được mà agent không chạy thì app vẫn không điều khiển được gì. Nháy
đúp `agent\TU_CHAY_CUNG_WINDOWS.bat` một lần: đăng nhập Windows là agent tự mở,
thu nhỏ ở thanh tác vụ. Chạy lại lần nữa để gỡ.

### Tự đăng nhập

Nếu Windows có mật khẩu, máy bật lên sẽ dừng ở màn hình khoá, agent chưa chạy.
Hai cách:

- **Đơn giản:** bật tự đăng nhập. Nhấn `Win+R`, gõ `netplwiz`, bỏ chọn
  *Users must enter a user name and password…*. Nếu không thấy ô đó: Settings
  → Accounts → Sign-in options → tắt *For improved security, only allow
  Windows Hello sign-in…*, rồi mở lại `netplwiz`.
- **An toàn hơn:** giữ mật khẩu, chấp nhận ngồi vào máy đăng nhập. Máy vẫn
  bật lên được từ xa, chỉ là agent chưa chạy cho tới lúc đó.

Tự đăng nhập nghĩa là ai bấm nút nguồn cũng vào được máy. Ở nhà thì thường
chấp nhận được; máy có dữ liệu nhạy cảm thì đừng bật.

## Bước 4 — Thử

1. Mở HeDeck khi PC đang chạy, để app kết nối một lần — app lưu MAC lúc này.
   Bấm nút nguồn ⏻ trên thanh trên cùng: không có dòng cảnh báo vàng nào là ổn.
2. Bấm **Tắt máy**. Chờ khoảng 15 giây cho máy tắt hẳn.
3. Nút ⏻ chuyển sang **xanh lá**. Bấm nó → **Bật máy**.
4. Máy lên sau vài giây, Windows và agent sẵn sàng sau khoảng 20–60 giây. App
   tự kết nối lại, không cần bấm gì thêm.

Cửa sổ agent cũng có dòng `Bật từ xa : D8:43:… · sẵn sàng`, kèm cảnh báo
`[!]` nếu thiếu bước nào.

## Không bật được thì xem gì

| Dấu hiệu | Nguyên nhân hay gặp |
|---|---|
| Đèn cổng LAN tắt khi máy tắt | ErP Ready vẫn Enabled, hoặc chưa cắm dây |
| Đèn sáng nhưng gửi không dậy | Chưa chạy `CAI_BAT_MAY_TU_XA.bat`, hoặc Resume By PCI-E Device chưa bật |
| Tắt từ Start Menu thì không dậy, tắt từ HeDeck thì dậy | Fast Startup vẫn bật |
| Ngủ (Sleep) dậy được, tắt hẳn thì không | *Shutdown Wake-On-Lan* trong driver đang Disabled |
| Rút điện / mất điện xong thì không dậy | Bình thường — xem đề xuất *Restore after AC Power Loss* bên dưới |
| Lâu lâu mới hỏng một lần | Router chặn broadcast từ Wi-Fi sang LAN, xem bên dưới |
| Agent báo không đọc được card mạng | Nhập MAC tay: nút ⏻ → *Địa chỉ MAC để bật máy*. Xem MAC bằng lệnh `getmac /v` |

**Router chặn broadcast**: một số router (hay gặp ở mesh Wi-Fi) không chuyển
gói broadcast từ Wi-Fi sang cổng LAN. Kiểm tra bằng cách cắm thử PC và router
chính trực tiếp, hoặc tìm trong cài đặt router mục *Wi-Fi isolation / AP
isolation / Client isolation* và tắt đi. Điện thoại phải ở mạng Wi-Fi chính,
không phải mạng khách.

**Driver**: nếu vẫn hỏng, cài driver LAN mới nhất từ trang hỗ trợ của MSI cho
B760 Gaming Plus WiFi DDR4 (hoặc trực tiếp từ Realtek). Driver mặc định của
Windows Update đôi khi thiếu mục *Shutdown Wake-On-Lan*.

## Đề xuất thêm

- **Restore after AC Power Loss** (Settings → Advanced → Power Management
  Setup): đặt **Power On** hoặc **Last State**. Mất điện xong có điện lại thì
  máy tự bật — hữu ích vì sau khi mất điện, card mạng thường *không* nhận
  Wake-on-LAN cho tới khi máy được bật lần đầu.
- **Ngủ thay vì tắt** khi chỉ rời máy vài tiếng: máy dậy trong 2–3 giây, giữ
  nguyên mọi cửa sổ, agent không phải khởi động lại. Card Realtek dậy từ Ngủ
  ổn định hơn từ Tắt hẳn. Tốn điện chờ chỉ vài watt.
- **Bật từ ngoài nhà** (4G, mạng khác): Wake-on-LAN chỉ đi trong mạng nội bộ.
  Cách gọn nhất là một thiết bị luôn bật trong nhà làm trạm trung chuyển —
  router có tính năng WoL (ASUS, OpenWrt, MikroTik…), hoặc Raspberry Pi /
  điện thoại cũ chạy Tailscale. Đừng mở cổng router ra Internet cho agent: agent
  cố ý từ chối mọi kết nối ngoài mạng nội bộ.
- **Đặt IP tĩnh cho PC** trong router (DHCP reservation). App vẫn tự dò lại
  khi IP đổi, nhưng IP cố định giúp kết nối lại sau khi bật máy nhanh hơn.
