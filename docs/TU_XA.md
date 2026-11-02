# Dùng HeDeck từ xa qua Internet

Ở ngoài quán, ở công ty, đi 4G — vẫn điều khiển được máy tính ở nhà, xem màn
hình của nó ngay trong touchpad, và bật máy khi nó đang tắt.

```
 Điện thoại của bạn (ở ngoài)                         Ở nhà
 ┌───────────────────┐        Tailscale        ┌──────────────────┐
 │ HeDeck            │ ═══════ mã hoá ════════▶│ PC + HeDeck Agent│
 │ deck · touchpad · │                         └──────────────────┘
 │ xem màn hình      │                                  ▲ tín hiệu bật máy
 └───────────────────┘                                  │ (trong mạng nhà)
           ║ lệnh bật máy, có chữ ký           ┌──────────────────┐
           ╚══════════════════════════════════▶│ Điện thoại deck  │
                                               │ = trạm bật máy   │
                                               └──────────────────┘
```

## Bạn dùng thế nào? (PC + iPhone + điện thoại deck Android)

| Tình huống | Cần gì | Làm thế nào |
|---|---|---|
| **Trên đường về, bật PC bằng iPhone** | Điện thoại deck **ở nhà**, bật *Trạm bật máy*; Tailscale trên iPhone và deck | Chạm biểu tượng **Bật PC** trên iPhone (mục *Bật máy từ iPhone*) |
| **Mang deck ra ngoài, điều khiển PC ở nhà** | PC **đang bật**; Tailscale trên PC và deck | Mở HeDeck trên deck như ở nhà: app tự đi đường Tailscale, touchpad có màn hình PC |
| **iPhone ở bất cứ đâu dùng như deck** | PC đang bật; Tailscale trên iPhone | Quét mã QR **Mọi nơi** trên cửa sổ HeDeck ở PC, thêm vào Màn hình chính (mục *iPhone dùng như deck ở mọi nơi*) |

> **Bật PC đang tắt luôn cần một thiết bị ở nhà phát tín hiệu.** Mang điện thoại
> deck theo người thì ở nhà không còn trạm: iPhone không bật được PC (HeDeck sẽ
> báo *trạm không ở nhà*). Khi đó hoặc để PC bật (hoặc ngủ) trước khi đi, hoặc
> thêm một thiết bị luôn ở nhà: router có chức năng Wake-on-LAN qua app, hay
> ổ cắm thông minh + BIOS *Restore on AC Power Loss = Power On*.

HeDeck **không mở cổng nào trên router** và không đưa máy tính ra Internet.
Đường đi từ xa là [Tailscale](https://tailscale.com): một mạng riêng ảo có mã
hoá, miễn phí cho cá nhân, nối các máy cùng một tài khoản dù chúng ở đâu.

---

## 1. Điều khiển từ xa (Tailscale)

1. **Trên máy tính:** tải Tailscale tại https://tailscale.com/download, cài,
   đăng nhập (Google, Microsoft hay GitHub đều được).
2. **Trên điện thoại của bạn:** cài app **Tailscale** từ CH Play / App Store,
   đăng nhập **cùng tài khoản**, bật lên.
   Trong Tailscale trên máy tính, bật **Run unattended** để nó chạy cả khi
   chưa đăng nhập Windows.
   Nếu cửa sổ HeDeck hiện dải vàng *Tường lửa Windows đang chặn kết nối qua
   Tailscale*, bấm **Cho phép qua Tailscale** rồi bấm **Có** khi Windows hỏi.
3. Mở lại HeDeck Agent. Cửa sổ agent hiện dòng
   **Từ xa: Tailscale 100.x.y.z** — nghĩa là đã sẵn sàng.
4. Mở HeDeck trên điện thoại **một lần khi đang ở nhà**, để app nhớ địa chỉ
   Tailscale của máy tính.

Xong. Ra ngoài (hay thử tắt Wi-Fi, dùng 4G), mở HeDeck: app không thấy máy trong
mạng nhà thì tự đi đường Tailscale. Nhãn cạnh tên máy đổi từ **Wi-Fi · 6 ms**
sang **Từ xa · 80 ms**. Mọi ô, macro, media, touchpad, đo hiệu năng, khoá/ngủ/
tắt máy đều dùng như ở nhà.

### iPhone dùng như deck ở mọi nơi

Bản web trên iPhone gắn với địa chỉ đã mở nó. Mở bằng địa chỉ **Tailscale** thì
một biểu tượng dùng được cả ở nhà lẫn ở ngoài (miễn iPhone bật Tailscale):

1. Trên cửa sổ HeDeck ở PC, dưới mã QR bấm **Chuyển sang mã Mọi nơi** (chỉ hiện
   khi PC đã có Tailscale). Chú thích đổi thành *mọi nơi (cần Tailscale)*.
2. Bật Tailscale trên iPhone, mở Camera quét mã → HeDeck mở trong Safari và tự
   ghép cặp.
3. **Chia sẻ → Thêm vào Màn hình chính**. Từ giờ dùng biểu tượng này ở mọi nơi:
   deck, touchpad có màn hình PC, phóng to, đo hiệu năng. Nhãn trạng thái ghi
   **Tailscale · … ms**.

Biểu tượng tạo từ mã *Trong nhà* chỉ dùng được khi iPhone ở nhà; hai biểu tượng
là hai lần ghép cặp riêng, giữ cả hai cũng được.

**Lâu không mở mà biểu tượng đòi ghép cặp lại?** Biểu tượng ngoài Màn hình chính
có bộ nhớ riêng, và iOS xoá dữ liệu của trang lâu ngày không mở. Từ bản này,
sau khi ghép cặp HeDeck ghi một "vé" vào đường link (`…/#hd=…`); biểu tượng
thêm **sau khi đã ghép cặp xong** lưu vé đó, nên dù iOS xoá dữ liệu, mở lên vẫn
tự vào lại, khỏi nhập mã. Biểu tượng tạo từ bản cũ không có vé: mở trong
Safari, ghép cặp, rồi xoá biểu tượng cũ và **Thêm vào Màn hình chính** lại.

- Vé chứa khoá của iPhone này: **đừng gửi đường link của biểu tượng cho người
  khác**. Muốn thu hồi: cửa sổ agent → xoá điện thoại đã ghép.
- Bố cục (trang, ô, thiết lập) được sao lưu lên máy tính. Ghép cặp lại trên máy
  cùng tên thì bố cục tự trở về, khỏi dựng lại từ đầu.

## 2. Bật máy từ xa (trạm bật máy)

Tín hiệu bật máy (Wake-on-LAN) chỉ đi được trong mạng nhà, và lúc máy tắt thì
Tailscale trên máy cũng tắt. Nên cần một thiết bị **luôn bật ở nhà** phát tín
hiệu giúp: chính chiếc **điện thoại cũ làm deck**.

Trước hết bật máy từ xa phải chạy được **trong mạng nhà** — xem
[BAT_MAY_TU_XA.md](BAT_MAY_TU_XA.md) (BIOS, card mạng, cắm dây LAN).

1. Trên **điện thoại deck**: cài Tailscale, đăng nhập cùng tài khoản, bật lên.
   Trong cài đặt Android → VPN → Tailscale, bật **VPN luôn bật** (*Always-on
   VPN*). Tắt **tối ưu pin** cho Tailscale và HeDeck.
2. Mở HeDeck trên điện thoại deck → bánh răng ⚙ → bật **Trạm bật máy (điện
   thoại này để ở nhà)**. Cho phép **thông báo** và chọn **Cho phép** khi được
   hỏi bỏ tối ưu pin. Dòng dưới hiện **Đang chạy ngầm · Tailscale 100.y.y.y**.
3. Cửa sổ agent hiện **Trạm bật máy: <tên điện thoại deck>**.
4. Mở HeDeck trên **điện thoại của bạn** một lần lúc máy tính đang chạy, để app
   nhận địa chỉ trạm.

Từ giờ: máy tính tắt, bạn ở ngoài, bấm nút nguồn trên HeDeck → **Bật máy**. App
nhờ trạm ở nhà phát tín hiệu; khoảng 20–60 giây sau Windows lên, agent tự chạy
(nếu đã bật `TU_CHAY_CUNG_WINDOWS.bat`) và app tự kết nối lại.

Trạm **chạy ngầm**: tắt màn hình, chuyển app khác hay vuốt đóng HeDeck thì trạm
vẫn chạy, thanh thông báo có dòng *HeDeck · Trạm bật máy đang chạy*. Khởi động
lại điện thoại thì trạm tự chạy lại. Để chắc ăn: cắm sạc, giữ Wi-Fi, và trong
cài đặt Android → Ứng dụng → HeDeck → Pin chọn **Không hạn chế** (một số máy
Xiaomi, Oppo, Samsung còn có mục *Tự khởi chạy* / *Ứng dụng không bao giờ ngủ*
— thêm HeDeck và Tailscale vào). Muốn tắt trạm: bỏ công tắc trong ⚙.

**An toàn:** trạm chỉ nhận lệnh từ mạng nhà hoặc mạng Tailscale của bạn, và mỗi
lệnh phải ký bằng khoá do agent cấp cho các điện thoại đã ghép cặp, hết hạn sau
2 phút, không dùng lại được. Người khác dù vào được Wi-Fi nhà cũng không bật máy
hộ được.

### Bật máy từ iPhone

iPhone dùng bản web, mà bản web do máy tính phục vụ — máy tắt thì không mở
được. Nên trạm bật máy (điện thoại deck) tự phục vụ một trang **"Bật PC"** riêng:

1. Làm xong bước 1–3 ở trên (điện thoại deck đã bật **Trạm bật máy**).
2. Cài **Tailscale** trên iPhone, đăng nhập cùng tài khoản.
3. Lúc máy tính đang bật, mở HeDeck trên iPhone (bản web) → ⚙ → **Nút bật máy
   cho iPhone** → **Mở trang Bật PC**. Safari mở trang có nút tròn lớn.
4. Trong Safari: **Chia sẻ → Thêm vào Màn hình chính → Thêm**. Màn hình chính
   có biểu tượng **Bật PC**.

Khi ở ngoài và máy tính đang tắt: bật Tailscale trên iPhone → chạm **Bật PC** →
bấm **Bật máy tính**. Trang do điện thoại deck ở nhà phục vụ nên mở được cả khi
máy tính tắt.

Đường link của trang chứa khoá bật máy (phần sau dấu `#`, không bao giờ gửi lên
mạng) — đừng gửi link đó cho người khác. Nếu trang báo *Khoá không khớp*, làm
lại bước 3–4.

## 3. Xem màn hình trong touchpad

Mở **Touchpad** (biểu tượng chuột trên deck). Phía sau vùng touchpad là hình màn
hình máy tính, với **con trỏ giống hệt trên Windows** — mũi tên, chữ I khi trỏ vào
ô chữ, bàn tay khi trỏ vào đường link, vòng chờ khi máy bận. Kéo một ngón để di
chuột như thường — con trỏ đi theo ngón tay ngay.

**Phóng to để nhìn rõ:**

- **Mở rộng / chụm hai ngón** trên vùng touchpad để phóng to / thu nhỏ (tới 4×).
  Hai ngón cùng kéo mà không đổi khoảng cách thì vẫn là cuộn như cũ.
- Hoặc bấm nút **1×** trên thanh trên cùng: 1× → 1,5× → 2× → 3× → 1×.
- Vùng phóng to bám theo con trỏ (như kính lúp của Windows): đứng yên khi con
  trỏ ở giữa, trượt theo khi con trỏ tới gần mép. Máy tính gửi đúng vùng đó ở
  độ phân giải gốc nên phóng to vẫn nét, không vỡ hình.

- Biểu tượng **màn hình** trên thanh trên cùng: bật/tắt hình (tắt khi không
  cần, cho máy tính và dữ liệu nhẹ hơn).
- **HQ**: chất lượng hình — *Tự động* (vừa ở nhà, tiết kiệm khi ở xa), *Tiết
  kiệm*, *Vừa*, *Nét*, *Rất nét* (độ phân giải gốc, tốn dữ liệu nhất).
- Hình chỉ gửi khi màn hình thay đổi. Đứng yên thì gần như không tốn dữ liệu;
  xem video qua 4G thì tốn khoảng 5–15 MB mỗi phút ở mức *Tiết kiệm*.
- Mỗi khi có điện thoại xem màn hình, cửa sổ agent ghi lại một dòng. Không muốn
  cho xem: mở `agent/agent.py`, đặt `ALLOW_SCREEN_VIEW = False`.

Hình chụp màn hình chính, khoảng 10 khung mỗi giây tối đa — đủ để thao tác,
không dành để xem phim hay chơi game từ xa.

---

## Sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Cửa sổ agent ghi *Từ xa: chưa có* | Tailscale trên máy tính chưa bật hoặc chưa đăng nhập. Mở Tailscale, đăng nhập, rồi mở lại agent. |
| iPhone báo *Safari không thể mở trang vì máy chủ đã dừng phản hồi* (mã Mọi nơi), app cứ *Đang kết nối* qua Tailscale | **Tường lửa Windows chặn Tailscale** (card mạng Tailscale bị xếp vào loại Public). Bấm **Cho phép qua Tailscale** trên cửa sổ HeDeck ở PC, hoặc chạy `MO_TAILSCALE.bat`. Chỉ mở cổng 8787 cho mạng Tailscale của bạn. |
| Ở ngoài, app cứ *Đang kết nối* | Tailscale trên điện thoại chưa bật, hoặc chưa mở HeDeck ở nhà lần nào kể từ khi cài Tailscale trên máy tính. |
| *Không liên lạc được trạm bật máy* | Thanh thông báo của điện thoại deck không còn dòng *Trạm bật máy đang chạy* (mở HeDeck, bật lại công tắc trạm), điện thoại mất Wi-Fi, hoặc Tailscale trên nó bị Android tắt (bật *VPN luôn bật*, đặt pin *Không hạn chế* cho cả HeDeck và Tailscale). |
| Biểu tượng HeDeck trên iPhone đòi mã ghép cặp | Biểu tượng tạo từ bản cũ, chưa có vé khôi phục. Mở trong Safari, ghép cặp, rồi Thêm vào Màn hình chính lại (xem *iPhone dùng như deck ở mọi nơi*). |
| Trạm báo đã gửi nhưng máy không lên | Bật máy trong mạng nhà chưa chạy được — xem [BAT_MAY_TU_XA.md](BAT_MAY_TU_XA.md). |
| Touchpad ghi *Cập nhật agent…* | Agent trên máy tính là bản cũ: cập nhật agent (cửa sổ agent → *Xem và cập nhật*). |
