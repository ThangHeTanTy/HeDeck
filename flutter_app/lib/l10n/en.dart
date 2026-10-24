// Bản dịch tiếng Anh, tra theo đúng câu tiếng Việt trong code.
// Sinh bằng script lúc thêm tiếng Anh; thêm câu mới thì thêm tay vào đây.
// Câu nào thiếu thì t() tự hiện nguyên tiếng Việt, không bao giờ hiện trống.

const en = <String, String>{
  'Giao diện':
      'Appearance',
  'Tối · mặt trăng':
      'Dark · moon',
  'Sáng · mặt trời':
      'Light · sun',
  'Trang {0}':
      'Page {0}',
  'HeDeck gặp lỗi khi dựng giao diện':
      'HeDeck hit an error while building the screen',
  '"{0}" không xong sau {1} giây':
      '"{0}" did not finish after {1} seconds',
  'Đọc cấu hình đã lưu':
      'Reading saved settings',
  'Nạp khoá điện thoại':
      'Loading phone key',
  'Tính vân tay khoá':
      'Computing key fingerprint',
  'Xoá ghép cặp cũ':
      'Clearing old pairing',
  'Không khởi động được ở bước: {0}':
      'Could not start at step: {0}',
  'Thử lại':
      'Try again',
  'Lặp lại nhiều lần thì chụp màn hình này gửi Hề IT.':
      'If this keeps happening, send a screenshot of this screen to Hề IT.',
  'Làm việc':
      'Work',
  'Giải trí':
      'Play',
  'Phát / Tạm dừng':
      'Play / Pause',
  'Bài kế':
      'Next track',
  'Bài trước':
      'Previous track',
  'Dừng':
      'Stop',
  'Tăng âm lượng':
      'Volume up',
  'Giảm âm lượng':
      'Volume down',
  'Tắt tiếng':
      'Mute',
  'Tăng âm lượng app':
      'App volume up',
  'Giảm âm lượng app':
      'App volume down',
  'Tắt tiếng app':
      'Mute app',
  'Chưa kết nối tới thiết bị':
      'Not connected to the device',
  'Đang chạy chế độ…':
      'Running mode…',
  'Đang chạy "{0}"…':
      'Running "{0}"…',
  'Ứng dụng':
      'App',
  'Đã tắt {0}':
      'Closed {0}',
  '{0} · {1} cửa sổ':
      '{0} · {1} windows',
  'Chỉ còn một cửa sổ — chạm vào ô để mở nó.':
      'Only one window left — tap the tile to open it.',
  'Ứng dụng đã đóng hết.':
      'The app has closed all its windows.',
  '(không có tiêu đề)':
      '(no title)',
  'Đang ở trước':
      'In front',
  'Đóng cửa sổ này':
      'Close this window',
  'Nguồn · {0}':
      'Power · {0}',
  'Bật máy':
      'Turn on',
  'Wake-on-LAN tới {0}':
      'Wake-on-LAN to {0}',
  'Chưa biết địa chỉ MAC. Kết nối một lần lúc máy đang bật, hoặc nhập tay bên dưới.':
      'MAC address unknown. Connect once while the PC is on, or enter it below.',
  'Khoá máy':
      'Lock',
  'Ngủ':
      'Sleep',
  'Khởi động lại':
      'Restart',
  'Tắt máy':
      'Shut down',
  'Địa chỉ MAC để bật máy':
      'MAC address for waking',
  'Đã khoá máy':
      'Locked',
  'Máy đang đi ngủ…':
      'Going to sleep…',
  'Đang khởi động lại…':
      'Restarting…',
  'Đang tắt máy…':
      'Shutting down…',
  'Chưa có địa chỉ MAC của máy tính':
      'The computer\'s MAC address is not set',
  'Không gửi được — điện thoại có đang nối Wi-Fi nhà không?':
      'Could not send — is the phone on the home Wi-Fi?',
  'Gửi tín hiệu bật máy lỗi: {0}':
      'Wake signal failed: {0}',
  'Đã gửi tín hiệu bật máy. Windows cần khoảng 20–60 giây để lên.':
      'Wake signal sent. Windows needs about 20–60 seconds to start.',
  'Khởi động lại máy?':
      'Restart the computer?',
  'Tắt máy?':
      'Shut down the computer?',
  'Máy sẽ khởi động lại ngay.':
      'The computer will restart right away.',
  'Máy sẽ tắt hẳn. Bật lại bằng nút nguồn trên HeDeck nếu đã cài Wake-on-LAN.':
      'The computer will power off completely. Turn it back on with the power button in HeDeck if Wake-on-LAN is set up.',
  'Buộc đóng app chưa lưu':
      'Force-close unsaved apps',
  'Không chọn thì Windows có thể dừng lại hỏi lưu file.':
      'If unchecked, Windows may stop and ask to save files.',
  'Huỷ':
      'Cancel',
  'Địa chỉ MAC':
      'MAC address',
  'Agent tự gửi MAC mỗi lần kết nối. Chỉ cần nhập tay nếu cửa sổ agent báo không đọc được. Xem bằng lệnh: getmac /v':
      'The agent sends the MAC on every connection. Only enter it by hand if the agent window says it could not read it. See it with: getmac /v',
  'Lưu':
      'Save',
  'MAC không hợp lệ — cần 12 chữ số hex':
      'Invalid MAC — needs 12 hex digits',
  'Đã lưu MAC {0}':
      'Saved MAC {0}',
  'Tự mở trang này khi…':
      'Open this page automatically when…',
  'Quét lại ứng dụng trên thiết bị':
      'Rescan apps on the device',
  'Thêm trang':
      'Add page',
  'Đổi tên trang này':
      'Rename this page',
  'Xoá trang này':
      'Delete this page',
  'Quên thiết bị này':
      'Forget this device',
  'Đang quét lại Start Menu…':
      'Rescanning the Start Menu…',
  'Tự đổi trang theo app đang dùng':
      'Switch pages to match the app in use',
  'Như Stream Deck: vào game là sang trang Game':
      'Like Stream Deck: open a game, jump to the Game page',
  'Tự mở trang "{0}" khi…':
      'Open page "{0}" automatically when…',
  'Deck chỉ đổi trang lúc bạn chuyển sang app khác trên thiết bị. Tự vuốt sang trang khác thì nó để yên.':
      'The deck only switches pages when you switch to another app on the device. Swipe to another page yourself and it stays put.',
  '…đang ở màn hình desktop':
      '…on the desktop',
  'Thu nhỏ hết cửa sổ hoặc Win+D. Chỉ một trang được chọn mục này.':
      'All windows minimized, or Win+D. Only one page can use this.',
  '…đang dùng một trong các app:':
      '…using one of these apps:',
  'Chưa chọn app nào':
      'No apps chosen',
  'App không còn trên thiết bị':
      'App no longer on the device',
  'Thêm app':
      'Add app',
  'Đang mở':
      'Open now',
  'Trang này không tự mở nữa':
      'This page no longer opens automatically',
  'Đã lưu — deck sẽ tự mở trang này':
      'Saved — the deck will open this page automatically',
  '{0} ô mỗi trang':
      '{0} tiles per page',
  'Bố cục lưới':
      'Grid layout',
  '5 × 2':
      '5 × 2',
  '5 × 3':
      '5 × 3',
  'Hề IT':
      'Hề IT',
  'Agent v{0} — cần v{1}, hãy chạy lại agent':
      'Agent v{0} — needs v{1}, please restart the agent',
  'Vân tay {0}':
      'Fingerprint {0}',
  'Tên trang':
      'Page name',
  'Agent trên thiết bị là bản cũ — tắt cửa sổ agent rồi chạy lại run_agent.bat':
      'The agent on the device is outdated — close the agent window and run run_agent.bat again',
  'Thiết bị chưa quét xong — xem cửa sổ agent':
      'The device has not finished scanning — check the agent window',
  'Đang lấy danh sách ứng dụng…':
      'Getting the app list…',
  'Đang tìm thiết bị…':
      'Looking for the device…',
  'Chưa thấy thiết bị · thử lại sau {0}s':
      'Device not found · retrying in {0}s',
  'Đang thử lại…':
      'Retrying…',
  'Cần ghép cặp lại':
      'Needs pairing again',
  'Ngoại tuyến':
      'Offline',
  'Ghép cặp lại':
      'Pair again',
  'Thử kết nối lại ngay':
      'Reconnect now',
  'Hiệu năng: FPS, nhiệt độ':
      'Performance: FPS, temperatures',
  'Touchpad và bàn phím':
      'Touchpad & keyboard',
  'Nguồn máy tính':
      'Computer power',
  'Bật máy tính':
      'Turn on the computer',
  'Sửa bố cục':
      'Edit layout',
  'Tuỳ chọn':
      'Options',
  'Tuỳ chọn HeDeck':
      'HeDeck options',
  'Nhập địa chỉ IP hiện trên cửa sổ agent':
      'Enter the IP address shown in the agent window',
  'Mã ghép cặp gồm 6 chữ số':
      'The pairing code has 6 digits',
  'Điện thoại Android':
      'Android phone',
  'Không ghép cặp được. Kiểm tra IP và mã.':
      'Pairing failed. Check the IP and code.',
  'Kết nối tới thiết bị':
      'Connect to the device',
  'Chạy agent trên máy Windows, rồi nhập địa chỉ và mã 6 số hiện trên cửa sổ đó.':
      'Run the agent on the Windows computer, then enter the address and 6-digit code shown in its window.',
  'Dùng máy ảo Android? Chạy adb reverse tcp:8787 tcp:8787 rồi nhập 127.0.0.1.':
      'Using an Android emulator? Run adb reverse tcp:8787 tcp:8787 then enter 127.0.0.1.',
  'Địa chỉ IP':
      'IP address',
  'Cổng':
      'Port',
  'Mã ghép cặp':
      'Pairing code',
  'Máy này chưa tạo được khoá điện thoại':
      'This phone could not create its key',
  'Khoá điện thoại {0}':
      'Phone key {0}',
  'Ghép cặp':
      'Pair',
  'Máy tìm thấy trong mạng':
      'Computers found on the network',
  'Quét lại':
      'Scan again',
  'Chưa thấy máy nào. Nhập IP thủ công ở dưới cũng được.':
      'No computers found yet. You can enter the IP manually below.',
  'Hiệu năng':
      'Performance',
  'Đang đo…':
      'Measuring…',
  'FPS 60 giây':
      'FPS, last 60 s',
  'Tải':
      'Load',
  'Công suất':
      'Power',
  'Tải CPU':
      'CPU load',
  'Nhiệt độ 60 giây':
      'Temperature, last 60 s',
  'Quạt':
      'Fan',
  'Tải GPU':
      'GPU load',
  'Đang dùng':
      'In use',
  'Mạng':
      'Network',
  'Tải xuống':
      'Download',
  'Tải lên':
      'Upload',
  'FPS cần RivaTuner Statistics Server (RTSS) — cài kèm MSI Afterburner. Mở RTSS trước khi vào game, FPS hiện sau vài giây.':
      'FPS needs RivaTuner Statistics Server (RTSS) — installed with MSI Afterburner. Start RTSS before launching the game; FPS shows up after a few seconds.',
  'Nhiệt độ, xung và công suất CPU cần LibreHardwareMonitor: chạy bằng quyền Administrator, vào Options → Remote Web Server → Run (cổng 8085).':
      'CPU temperature, clock and power need LibreHardwareMonitor: run it as Administrator, then Options → Remote Web Server → Run (port 8085).',
  'Không đọc được GPU. Card NVIDIA cần driver mới; card khác cần LibreHardwareMonitor như trên.':
      'Could not read the GPU. NVIDIA cards need a recent driver; other cards need LibreHardwareMonitor as above.',
  'Nóng':
      'Hot',
  'Ấm':
      'Warm',
  'Mát':
      'Cool',
  'thấp {0} · cao {1}':
      'low {0} · high {1}',
  'Tải {0} luồng':
      'Load on {0} threads',
  'hoạt ảnh xong':
      'animation done',
  'hết thời gian chờ':
      'timed out',
  'Chuyển cửa sổ':
      'Switch window',
  'Hiện desktop':
      'Show desktop',
  'Chụp màn hình':
      'Screenshot',
  'Bảng lệnh VS Code':
      'VS Code command palette',
  'Đóng cửa sổ':
      'Close window',
  'Hoàn tác':
      'Undo',
  'Chọn một ứng dụng trước đã':
      'Pick an app first',
  'Nhập ít nhất một tổ hợp phím cho mặt chính':
      'Enter at least one key combo for the front face',
  'Thêm ít nhất một ứng dụng cho chế độ này':
      'Add at least one app to this mode',
  'Ô hai trạng thái cần tổ hợp phím cho cả mặt phụ':
      'A two-state tile needs a key combo for the back face too',
  'Sửa ô':
      'Edit tile',
  'Xoá ô':
      'Delete tile',
  'Tên hiển thị · {0}':
      'Label · {0}',
  'Tên hiển thị':
      'Label',
  'Để trống thì chỉ hiện icon':
      'Leave empty to show only the icon',
  'Âm lượng':
      'Volume',
  'Chế độ':
      'Mode',
  'Ô hai trạng thái':
      'Two-state tile',
  'Bấm để bật, bấm lại để tắt. Mỗi mặt có icon và màu riêng.':
      'Tap to turn on, tap again to turn off. Each face has its own icon and color.',
  'Mặt chính':
      'Front face',
  'Mặt phụ':
      'Back face',
  'Tìm ứng dụng trên thiết bị':
      'Search apps on the device',
  'Quét lại Start Menu':
      'Rescan Start Menu',
  'Chọn từ cửa sổ đang mở trên PC':
      'Pick from windows open on the PC',
  'Chưa kết nối tới thiết bị nên không lấy được danh sách.':
      'Not connected to the device, so the list is unavailable.',
  'Đang lấy danh sách từ thiết bị…':
      'Getting the list from the device…',
  'Thiết bị chưa gửi được danh sách ứng dụng. Bấm nút làm mới bên phải, hoặc xem cửa sổ agent có báo lỗi không.':
      'The device has not sent the app list yet. Tap the refresh button on the right, or check the agent window for errors.',
  'Không có ứng dụng nào khớp.':
      'No matching apps.',
  'Ô này làm gì với âm lượng của app đó':
      'What this tile does to that app\'s volume',
  'Tăng 5%':
      'Up 5%',
  'Giảm 5%':
      'Down 5%',
  'Tổ hợp phím · {0}':
      'Key combo · {0}',
  'Tổ hợp phím':
      'Key combo',
  'Nhiều bước thì ngăn bằng dấu phẩy':
      'For several steps, separate them with commas',
  'Bấm ô là chạy lần lượt từ trên xuống. "Mở" bỏ qua app đã chạy sẵn, "Đóng" tắt hẳn app.':
      'Tapping the tile runs the steps top to bottom. "Open" skips apps already running, "Close" quits the app.',
  'Thêm ứng dụng':
      'Add app',
  'Từ cửa sổ đang mở':
      'From open windows',
  'Đóng':
      'Close',
  'Mở':
      'Open',
  'Bỏ bước này':
      'Remove this step',
  'Dùng icon mặc định':
      'Use default icon',
  'Chọn từ {0} icon':
      'Choose from {0} icons',
  'Màu nhấn':
      'Accent color',
  'Đang mở trên PC':
      'Open on the PC',
  'Mở app trên PC trước rồi chọn ở đây. App chưa có trong danh sách sẽ được thêm và giữ lại cả khi quét lại.':
      'Open the app on the PC first, then pick it here. Apps not in the list are added and kept after rescans.',
  'Không lấy được danh sách: {0}':
      'Could not get the list: {0}',
  'Không thấy cửa sổ nào đang mở':
      'No open windows found',
  '{0} cửa sổ · {1}':
      '{0} windows · {1}',
  'Đã có':
      'Added',
  'Không có ứng dụng nào':
      'No apps',
  'Tìm icon: micro, ghi hình, khoá…':
      'Search icons: mic, record, lock…',
  'Không tìm thấy icon nào':
      'No icons found',
  'Tốc độ con trỏ':
      'Pointer speed',
  'Ẩn bàn phím':
      'Hide keyboard',
  'Bàn phím':
      'Keyboard',
  'Đang giữ chuột trái — kéo rồi thả tay':
      'Holding left button — drag, then lift your finger',
  'Một ngón: di chuột · chạm để nhấp\nHai ngón: cuộn · chạm để nhấp phải\nGiữ yên một ngón rồi kéo: kéo thả':
      'One finger: move · tap to click\nTwo fingers: scroll · tap to right-click\nHold one finger still, then drag: drag and drop',
  'Trái':
      'Left',
  'Giữa':
      'Middle',
  'Phải':
      'Right',
  'Gõ ở đây, chữ hiện thẳng trên thiết bị':
      'Type here, the text appears directly on the device',
  'Màn hình thiết bị càng lớn thì nên để càng nhanh.':
      'The bigger the device\'s screen, the faster this should be.',
  'Đã thay bằng yêu cầu mới':
      'Replaced by a newer request',
  'Thiết bị không trả lời':
      'The device did not answer',
  'Lỗi không rõ':
      'Unknown error',
  'Thiết bị từ chối kết nối — agent chưa chạy?':
      'The device refused the connection — is the agent running?',
  'Agent chỉ nhận kết nối từ mạng nội bộ':
      'The agent only accepts connections from the local network',
  'Hết thời gian chờ — kiểm tra Wi-Fi và tường lửa':
      'Timed out — check Wi-Fi and the firewall',
  'Không tới được máy — hai thiết bị có cùng Wi-Fi không?':
      'Cannot reach the computer — are both devices on the same Wi-Fi?',
  'Không kết nối được':
      'Could not connect',
  'Không tạo được khoá điện thoại':
      'Could not create the phone key',
  'Không tạo được khoá điện thoại: {0}':
      'Could not create the phone key: {0}',
  'không đọc được bộ nhớ máy ({0})':
      'could not read phone storage ({0})',
  'sinh khoá thất bại ({0})':
      'key generation failed ({0})',
  'không lưu được khoá xuống máy':
      'could not save the key to the phone',
  'không lưu được khoá ({0})':
      'could not save the key ({0})',
  'Chưa có khoá điện thoại':
      'No phone key yet',
  'Thêm ô':
      'Add tile',
  '{0} bước':
      '{0} steps',
  'Tắt sau {0}s':
      'Closing in {0}s',
  'Phát hoặc tạm dừng':
      'Play or pause',
  'máy tính':
      'computer',
  'mặt chính':
      'front face',
  'mặt phụ':
      'back face',
  'Tiếng Việt':
      'Tiếng Việt',
  'Ngôn ngữ':
      'Language',
  'Livestream':
      'Livestream',
  'Âm thanh':
      'Audio',
  'Cửa sổ':
      'Windows',
  'Hệ thống':
      'System',
  'Công việc':
      'Work',
  'Điều hướng':
      'Navigation',
  'Ký hiệu':
      'Symbols',
  'Chữ số':
      'Numbers',
  'Micro':
      'Mic',
  'Tắt micro':
      'Mic off',
  'Máy quay':
      'Camera',
  'Tắt máy quay':
      'Camera off',
  'Ghi hình':
      'Record',
  'Dừng ghi':
      'Stop recording',
  'Phát trực tiếp':
      'Go live',
  'Đổi cảnh':
      'Switch scene',
  'Camera trước':
      'Front camera',
  'Chia sẻ màn hình':
      'Share screen',
  'Tai nghe':
      'Headset',
  'Trò chuyện':
      'Chat',
  'Khách mời':
      'Guests',
  'Nổi bật':
      'Highlight',
  'Đánh dấu':
      'Mark',
  'Hẹn giờ':
      'Timer',
  'Tăng tiếng':
      'Volume up',
  'Giảm tiếng':
      'Volume down',
  'Phát':
      'Play',
  'Tạm dừng':
      'Pause',
  'Nhạc':
      'Music',
  'Cân bằng':
      'Equalizer',
  'Loa':
      'Speaker',
  'Đài':
      'Radio',
  'Danh sách phát':
      'Playlist',
  'Màn hình nền':
      'Desktop',
  'Thu nhỏ':
      'Minimize',
  'Phóng to':
      'Maximize',
  'Nhiều thẻ':
      'Tabs',
  'Chia đôi':
      'Split view',
  'Toàn màn hình':
      'Full screen',
  'Chuyển đổi':
      'Switch',
  'Nhiều lớp':
      'Layers',
  'Nguồn':
      'Power',
  'Cài đặt':
      'Settings',
  'Dòng lệnh':
      'Terminal',
  'Thư mục':
      'Folder',
  'Tìm kiếm':
      'Search',
  'Đồng bộ':
      'Sync',
  'Đám mây':
      'Cloud',
  'Wi-Fi':
      'Wi-Fi',
  'Bluetooth':
      'Bluetooth',
  'Pin':
      'Battery',
  'Độ sáng':
      'Brightness',
  'Lập trình':
      'Code',
  'Lỗi':
      'Bug',
  'Biên dịch':
      'Build',
  'Sao chép':
      'Copy',
  'Dán':
      'Paste',
  'Cắt':
      'Cut',
  'Làm lại':
      'Redo',
  'Thư':
      'Mail',
  'Lịch':
      'Calendar',
  'Ghi chú':
      'Notes',
  'Việc cần làm':
      'To-do',
  'Biểu đồ':
      'Chart',
  'In':
      'Print',
  'Vẽ':
      'Draw',
  'Hình ảnh':
      'Image',
  'Cắt clip':
      'Clip',
  'Lên':
      'Up',
  'Xuống':
      'Down',
  'Trang chủ':
      'Home',
  'Quay lại':
      'Back',
  'Tiến tới':
      'Forward',
  'Làm mới':
      'Refresh',
  'Mở mới':
      'Open new',
  'Liên kết':
      'Link',
  'Đánh dấu trang':
      'Bookmark',
  'Lịch sử':
      'History',
  'Tia chớp':
      'Lightning',
  'Lửa':
      'Fire',
  'Trái tim':
      'Heart',
  'Bóng đèn':
      'Light bulb',
  'Tên lửa':
      'Rocket',
  'Khiên':
      'Shield',
  'Chìa khoá':
      'Key',
  'Chuông':
      'Bell',
  'Tắt chuông':
      'Bell off',
  'Dấu tích':
      'Check',
  'Dấu nhân':
      'Cross',
  'Dấu cộng':
      'Plus',
  'Dấu trừ':
      'Minus',
  'Hình tròn':
      'Circle',
  'Hình vuông':
      'Square',
  'Tay cầm':
      'Gamepad',
  'Cà phê':
      'Coffee',
  'Mặt trăng':
      'Moon',
  'Mặt trời':
      'Sun',
  'Ghim':
      'Pin',
  'Số 1':
      'Number 1',
  'Số 2':
      'Number 2',
  'Số 3':
      'Number 3',
  'Số 4':
      'Number 4',
  'Số 5':
      'Number 5',
  'Số 6':
      'Number 6',
  'Số 7':
      'Number 7',
  'Số 8':
      'Number 8',
  'Số 9':
      'Number 9',
};
