import 'dart:async';
import 'dart:convert';

import 'deck_connection.dart';
import 'store.dart';

/// Giữ bản sao bố cục (trang, ô, thiết lập) trên máy tính.
///
/// Sửa gì thì vài giây sau gửi bản mới lên agent. Vào được agent mà máy này
/// chưa có bố cục riêng (cài lại app, biểu tượng iPhone mới, iOS xoá dữ liệu
/// trang lâu không mở) thì lấy lại từ bản sao — khỏi dựng lại từ đầu.
void attachBackupSync(Store store, DeckConnection conn) {
  Timer? timer;
  var lastSent = '';

  void push() {
    if (!conn.isOnline || !store.hasOwnLayout) return;
    final data = store.backupData();
    final text = jsonEncode(data);
    if (text == lastSent) return;
    lastSent = text;
    conn.sendBackup(data);
  }

  store.addListener(() {
    timer?.cancel();
    timer = Timer(const Duration(seconds: 3), push);
  });

  conn.onAuthed = (backup) async {
    if (backup != null && !store.hasOwnLayout) {
      await store.restoreBackup(backup);
      lastSent = jsonEncode(store.backupData());
    } else {
      // Sửa lúc mất kết nối thì giờ mới gửi được.
      push();
    }
  };
}
