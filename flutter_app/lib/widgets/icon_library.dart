import 'package:flutter/material.dart';

/// Thư viện icon vector cho các ô.
///
/// Icon lấy từ file `.exe` bị vỡ khi phóng lớn, vì Windows chỉ có tới 256px
/// trong khi một ô 135 điểm trên màn hình mật độ cao cần gần 400 pixel. Icon
/// vector nét ở mọi kích thước, và quan trọng hơn là nhìn đồng bộ với nhau
/// thay vì mỗi thương hiệu một phong cách.
class IconLibrary {
  /// Tên nhóm -> danh sách (mã icon, tên hiển thị).
  static const groups = <String, List<(String, String)>>{
    'Livestream': [
      ('mic', 'Micro'),
      ('mic_off', 'Tắt micro'),
      ('videocam', 'Máy quay'),
      ('videocam_off', 'Tắt máy quay'),
      ('record', 'Ghi hình'),
      ('stop_circle', 'Dừng ghi'),
      ('live', 'Phát trực tiếp'),
      ('scene', 'Đổi cảnh'),
      ('camera_front', 'Camera trước'),
      ('screen_share', 'Chia sẻ màn hình'),
      ('headset', 'Tai nghe'),
      ('chat', 'Trò chuyện'),
      ('people', 'Khách mời'),
      ('star', 'Nổi bật'),
      ('flag', 'Đánh dấu'),
      ('timer', 'Hẹn giờ'),
    ],
    'Âm thanh': [
      ('volume_up', 'Tăng tiếng'),
      ('volume_down', 'Giảm tiếng'),
      ('volume_off', 'Tắt tiếng'),
      ('play', 'Phát'),
      ('pause', 'Tạm dừng'),
      ('next', 'Bài kế'),
      ('prev', 'Bài trước'),
      ('music', 'Nhạc'),
      ('equalizer', 'Cân bằng'),
      ('speaker', 'Loa'),
      ('radio', 'Đài'),
      ('playlist', 'Danh sách phát'),
    ],
    'Cửa sổ': [
      ('desktop', 'Màn hình nền'),
      ('window', 'Cửa sổ'),
      ('minimize', 'Thu nhỏ'),
      ('maximize', 'Phóng to'),
      ('close', 'Đóng'),
      ('tabs', 'Nhiều thẻ'),
      ('split', 'Chia đôi'),
      ('fullscreen', 'Toàn màn hình'),
      ('swap', 'Chuyển đổi'),
      ('layers', 'Nhiều lớp'),
    ],
    'Hệ thống': [
      ('power', 'Nguồn'),
      ('lock', 'Khoá máy'),
      ('restart', 'Khởi động lại'),
      ('sleep', 'Ngủ'),
      ('settings', 'Cài đặt'),
      ('terminal', 'Dòng lệnh'),
      ('folder', 'Thư mục'),
      ('search', 'Tìm kiếm'),
      ('download', 'Tải xuống'),
      ('upload', 'Tải lên'),
      ('sync', 'Đồng bộ'),
      ('cloud', 'Đám mây'),
      ('wifi', 'Wi-Fi'),
      ('bluetooth', 'Bluetooth'),
      ('battery', 'Pin'),
      ('brightness', 'Độ sáng'),
    ],
    'Công việc': [
      ('code', 'Lập trình'),
      ('bug', 'Lỗi'),
      ('build', 'Biên dịch'),
      ('save', 'Lưu'),
      ('copy', 'Sao chép'),
      ('paste', 'Dán'),
      ('cut', 'Cắt'),
      ('undo', 'Hoàn tác'),
      ('redo', 'Làm lại'),
      ('mail', 'Thư'),
      ('calendar', 'Lịch'),
      ('note', 'Ghi chú'),
      ('task', 'Việc cần làm'),
      ('chart', 'Biểu đồ'),
      ('print', 'In'),
      ('brush', 'Vẽ'),
      ('image', 'Hình ảnh'),
      ('scissors', 'Cắt clip'),
    ],
    'Điều hướng': [
      ('arrow_up', 'Lên'),
      ('arrow_down', 'Xuống'),
      ('arrow_left', 'Trái'),
      ('arrow_right', 'Phải'),
      ('home', 'Trang chủ'),
      ('back', 'Quay lại'),
      ('forward', 'Tiến tới'),
      ('refresh', 'Làm mới'),
      ('open_new', 'Mở mới'),
      ('link', 'Liên kết'),
      ('bookmark', 'Đánh dấu trang'),
      ('history', 'Lịch sử'),
    ],
    'Ký hiệu': [
      ('bolt', 'Tia chớp'),
      ('fire', 'Lửa'),
      ('heart', 'Trái tim'),
      ('bulb', 'Bóng đèn'),
      ('rocket', 'Tên lửa'),
      ('shield', 'Khiên'),
      ('key', 'Chìa khoá'),
      ('bell', 'Chuông'),
      ('bell_off', 'Tắt chuông'),
      ('check', 'Dấu tích'),
      ('cross', 'Dấu nhân'),
      ('plus', 'Dấu cộng'),
      ('minus', 'Dấu trừ'),
      ('circle', 'Hình tròn'),
      ('square', 'Hình vuông'),
      ('gamepad', 'Tay cầm'),
      ('coffee', 'Cà phê'),
      ('moon', 'Mặt trăng'),
      ('sun', 'Mặt trời'),
      ('pin', 'Ghim'),
    ],
    'Chữ số': [
      ('num_1', 'Số 1'),
      ('num_2', 'Số 2'),
      ('num_3', 'Số 3'),
      ('num_4', 'Số 4'),
      ('num_5', 'Số 5'),
      ('num_6', 'Số 6'),
      ('num_7', 'Số 7'),
      ('num_8', 'Số 8'),
      ('num_9', 'Số 9'),
    ],
  };

  static const _icons = <String, IconData>{
    // Livestream
    'mic': Icons.mic_rounded,
    'mic_off': Icons.mic_off_rounded,
    'videocam': Icons.videocam_rounded,
    'videocam_off': Icons.videocam_off_rounded,
    'record': Icons.fiber_manual_record_rounded,
    'stop_circle': Icons.stop_circle_rounded,
    'live': Icons.sensors_rounded,
    'scene': Icons.movie_filter_rounded,
    'camera_front': Icons.camera_front_rounded,
    'screen_share': Icons.screen_share_rounded,
    'headset': Icons.headset_mic_rounded,
    'chat': Icons.forum_rounded,
    'people': Icons.people_alt_rounded,
    'star': Icons.star_rounded,
    'flag': Icons.flag_rounded,
    'timer': Icons.timer_rounded,

    // Âm thanh
    'volume_up': Icons.volume_up_rounded,
    'volume_down': Icons.volume_down_rounded,
    'volume_off': Icons.volume_off_rounded,
    'play': Icons.play_arrow_rounded,
    'pause': Icons.pause_rounded,
    'next': Icons.skip_next_rounded,
    'prev': Icons.skip_previous_rounded,
    'music': Icons.music_note_rounded,
    'equalizer': Icons.equalizer_rounded,
    'speaker': Icons.speaker_rounded,
    'radio': Icons.radio_rounded,
    'playlist': Icons.queue_music_rounded,

    // Cửa sổ
    'desktop': Icons.desktop_windows_rounded,
    'window': Icons.web_asset_rounded,
    'minimize': Icons.minimize_rounded,
    'maximize': Icons.crop_square_rounded,
    'close': Icons.close_rounded,
    'tabs': Icons.tab_rounded,
    'split': Icons.vertical_split_rounded,
    'fullscreen': Icons.fullscreen_rounded,
    'swap': Icons.swap_horiz_rounded,
    'layers': Icons.layers_rounded,

    // Hệ thống
    'power': Icons.power_settings_new_rounded,
    'lock': Icons.lock_rounded,
    'restart': Icons.restart_alt_rounded,
    'sleep': Icons.bedtime_rounded,
    'settings': Icons.settings_rounded,
    'terminal': Icons.terminal_rounded,
    'folder': Icons.folder_rounded,
    'search': Icons.search_rounded,
    'download': Icons.download_rounded,
    'upload': Icons.upload_rounded,
    'sync': Icons.sync_rounded,
    'cloud': Icons.cloud_rounded,
    'wifi': Icons.wifi_rounded,
    'bluetooth': Icons.bluetooth_rounded,
    'battery': Icons.battery_full_rounded,
    'brightness': Icons.brightness_6_rounded,

    // Công việc
    'code': Icons.code_rounded,
    'bug': Icons.bug_report_rounded,
    'build': Icons.build_rounded,
    'save': Icons.save_rounded,
    'copy': Icons.content_copy_rounded,
    'paste': Icons.content_paste_rounded,
    'cut': Icons.content_cut_rounded,
    'undo': Icons.undo_rounded,
    'redo': Icons.redo_rounded,
    'mail': Icons.mail_rounded,
    'calendar': Icons.calendar_month_rounded,
    'note': Icons.sticky_note_2_rounded,
    'task': Icons.checklist_rounded,
    'chart': Icons.bar_chart_rounded,
    'print': Icons.print_rounded,
    'brush': Icons.brush_rounded,
    'image': Icons.image_rounded,
    'scissors': Icons.content_cut_rounded,

    // Điều hướng
    'arrow_up': Icons.arrow_upward_rounded,
    'arrow_down': Icons.arrow_downward_rounded,
    'arrow_left': Icons.arrow_back_rounded,
    'arrow_right': Icons.arrow_forward_rounded,
    'home': Icons.home_rounded,
    'back': Icons.undo_rounded,
    'forward': Icons.redo_rounded,
    'refresh': Icons.refresh_rounded,
    'open_new': Icons.open_in_new_rounded,
    'link': Icons.link_rounded,
    'bookmark': Icons.bookmark_rounded,
    'history': Icons.history_rounded,

    // Ký hiệu
    'bolt': Icons.bolt_rounded,
    'fire': Icons.local_fire_department_rounded,
    'heart': Icons.favorite_rounded,
    'bulb': Icons.lightbulb_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'shield': Icons.shield_rounded,
    'key': Icons.vpn_key_rounded,
    'bell': Icons.notifications_rounded,
    'bell_off': Icons.notifications_off_rounded,
    'check': Icons.check_circle_rounded,
    'cross': Icons.cancel_rounded,
    'plus': Icons.add_circle_rounded,
    'minus': Icons.remove_circle_rounded,
    'circle': Icons.circle_rounded,
    'square': Icons.square_rounded,
    'gamepad': Icons.sports_esports_rounded,
    'coffee': Icons.coffee_rounded,
    'moon': Icons.dark_mode_rounded,
    'sun': Icons.light_mode_rounded,
    'pin': Icons.push_pin_rounded,

    // Chữ số
    'num_1': Icons.looks_one_rounded,
    'num_2': Icons.looks_two_rounded,
    'num_3': Icons.looks_3_rounded,
    'num_4': Icons.looks_4_rounded,
    'num_5': Icons.looks_5_rounded,
    'num_6': Icons.looks_6_rounded,
    'num_7': Icons.filter_7_rounded,
    'num_8': Icons.filter_8_rounded,
    'num_9': Icons.filter_9_rounded,
  };

  /// Tổng số icon có sẵn.
  static int get count => _icons.length;

  /// Tra icon theo mã. Mã không có thì trả về null để nơi gọi tự xử lý.
  static IconData? lookup(String? name) {
    if (name == null || name.isEmpty) return null;
    return _icons[name];
  }

  /// Tìm theo từ khoá tiếng Việt hoặc mã.
  static List<(String, String)> search(String query) {
    final q = query.trim().toLowerCase();
    final all = <(String, String)>[];
    for (final entries in groups.values) {
      all.addAll(entries);
    }
    if (q.isEmpty) return all;
    return all
        .where((e) =>
            e.$1.toLowerCase().contains(q) || e.$2.toLowerCase().contains(q))
        .toList();
  }
}
