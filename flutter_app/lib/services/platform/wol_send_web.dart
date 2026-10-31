/// Trình duyệt không gửi được gói UDP broadcast, nên bản web không bật được
/// máy đang tắt. Các lệnh khi máy còn chạy (khoá, ngủ, tắt) vẫn đi qua agent.
const canSendWakeOnLan = false;

Future<int> sendWakeOnLan(List<String> macs, {String broadcast = ''}) async =>
    0;
