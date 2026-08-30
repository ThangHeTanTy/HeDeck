import 'dart:convert';
import 'dart:typed_data';

/// Một ô có thể là: trống, mở ứng dụng, gõ macro, điều khiển media, hoặc
/// chỉnh âm lượng riêng của một ứng dụng.
enum TileKind { empty, app, macro, media, appVolume }

/// Một mặt của ô. Ô thường chỉ có mặt chính; ô hai trạng thái có thêm mặt phụ,
/// bấm một lần là lật qua lại giữa hai mặt.
class TileFace {
  final String label;

  /// Tên icon trong thư viện vector. Rỗng thì dùng icon của ứng dụng.
  final String icon;

  final int accent;
  final List<String> keys;
  final String? mediaAction;

  const TileFace({
    this.label = '',
    this.icon = '',
    this.accent = 0,
    this.keys = const [],
    this.mediaAction,
  });

  TileFace copyWith({
    String? label,
    String? icon,
    int? accent,
    List<String>? keys,
    String? mediaAction,
  }) =>
      TileFace(
        label: label ?? this.label,
        icon: icon ?? this.icon,
        accent: accent ?? this.accent,
        keys: keys ?? this.keys,
        mediaAction: mediaAction ?? this.mediaAction,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'icon': icon,
        'accent': accent,
        'keys': keys,
        'mediaAction': mediaAction,
      };

  factory TileFace.fromJson(Map<String, dynamic> j) => TileFace(
        label: j['label'] as String? ?? '',
        icon: j['icon'] as String? ?? '',
        accent: j['accent'] as int? ?? 0,
        keys: (j['keys'] as List?)?.cast<String>() ?? const [],
        mediaAction: j['mediaAction'] as String?,
      );
}

class DeckTile {
  final TileKind kind;

  /// Ứng dụng gắn với ô: mở app, hoặc chỉnh âm lượng của chính app đó.
  final String? appId;

  /// Hành động âm lượng: up | down | mute.
  final String? volumeAction;

  /// Mặt chính và mặt phụ. Mặt phụ chỉ dùng khi [isToggle] bật.
  final TileFace front;
  final TileFace back;
  final bool isToggle;

  const DeckTile({
    this.kind = TileKind.empty,
    this.appId,
    this.volumeAction,
    this.front = const TileFace(),
    this.back = const TileFace(),
    this.isToggle = false,
  });

  static const empty = DeckTile();

  bool get isEmpty => kind == TileKind.empty;

  /// Mặt đang hiển thị, tuỳ trạng thái lật.
  TileFace face(bool flipped) => (isToggle && flipped) ? back : front;

  DeckTile copyWith({
    TileKind? kind,
    String? appId,
    String? volumeAction,
    TileFace? front,
    TileFace? back,
    bool? isToggle,
  }) =>
      DeckTile(
        kind: kind ?? this.kind,
        appId: appId ?? this.appId,
        volumeAction: volumeAction ?? this.volumeAction,
        front: front ?? this.front,
        back: back ?? this.back,
        isToggle: isToggle ?? this.isToggle,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'appId': appId,
        'volumeAction': volumeAction,
        'front': front.toJson(),
        'back': back.toJson(),
        'isToggle': isToggle,
      };

  factory DeckTile.fromJson(Map<String, dynamic> j) {
    // Bản cũ lưu label/keys/mediaAction/accent ngay ở cấp ngoài. Đọc lại cho
    // người đang dùng không mất bố cục đã dựng.
    final front = j['front'] != null
        ? TileFace.fromJson(j['front'] as Map<String, dynamic>)
        : TileFace(
            label: j['label'] as String? ?? '',
            accent: j['accent'] as int? ?? 0,
            keys: (j['keys'] as List?)?.cast<String>() ?? const [],
            mediaAction: j['mediaAction'] as String?,
          );

    return DeckTile(
      kind: TileKind.values.firstWhere(
        (k) => k.name == j['kind'],
        orElse: () => TileKind.empty,
      ),
      appId: j['appId'] as String?,
      volumeAction: j['volumeAction'] as String?,
      front: front,
      back: j['back'] != null
          ? TileFace.fromJson(j['back'] as Map<String, dynamic>)
          : const TileFace(),
      isToggle: j['isToggle'] as bool? ?? false,
    );
  }
}

/// Một trang chứa tối đa 15 ô. Bố cục 5x2 hiển thị 10 ô đầu, 5x3 hiển thị cả
/// 15. Ô ngoài phạm vi vẫn được giữ nguyên khi đổi bố cục.
class DeckPage {
  static const maxSlots = 15;

  final String name;
  final List<DeckTile> tiles;

  DeckPage({required this.name, List<DeckTile>? tiles})
      : tiles = List<DeckTile>.generate(
          maxSlots,
          (i) => (tiles != null && i < tiles.length) ? tiles[i] : DeckTile.empty,
        );

  DeckPage rename(String newName) => DeckPage(name: newName, tiles: tiles);

  DeckPage withTile(int index, DeckTile tile) {
    final next = List<DeckTile>.from(tiles);
    next[index] = tile;
    return DeckPage(name: name, tiles: next);
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'tiles': tiles.map((t) => t.toJson()).toList()};

  factory DeckPage.fromJson(Map<String, dynamic> j) => DeckPage(
        name: j['name'] as String? ?? 'Trang',
        tiles: (j['tiles'] as List? ?? [])
            .map((e) => DeckTile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static List<DeckPage> starter() => [
        DeckPage(name: 'Làm việc'),
        DeckPage(name: 'Giải trí'),
      ];

  /// Chỗ trống đầu tiên trong phạm vi bố cục đang dùng, -1 nếu đã đầy.
  int firstEmptySlot(int capacity) {
    for (var i = 0; i < capacity && i < maxSlots; i++) {
      if (tiles[i].isEmpty) return i;
    }
    return -1;
  }
}

/// Ứng dụng có trên laptop, do agent gửi về.
class RemoteApp {
  final String id;
  final String name;
  final String exe;
  final Uint8List? icon;

  /// Kích thước gốc thật của icon trên laptop, tính bằng pixel.
  final int iconNative;

  RemoteApp({
    required this.id,
    required this.name,
    required this.exe,
    this.icon,
    this.iconNative = 0,
  });

  factory RemoteApp.fromJson(Map<String, dynamic> j) {
    final raw = j['icon'] as String?;
    return RemoteApp(
      id: j['id'] as String,
      name: j['name'] as String,
      exe: j['exe'] as String? ?? '',
      icon: (raw == null || raw.isEmpty) ? null : base64Decode(raw),
      iconNative: j['icon_native'] as int? ?? 0,
    );
  }
}

class AppStatus {
  final bool running;
  final int windows;

  /// Âm lượng riêng của app, 0..1. Âm nghĩa là chưa biết.
  final double volume;
  final bool muted;

  const AppStatus({
    this.running = false,
    this.windows = 0,
    this.volume = -1,
    this.muted = false,
  });
}

/// Nhãn tiếng Việt cho các hành động media.
const mediaLabels = <String, String>{
  'playpause': 'Phát / Tạm dừng',
  'next': 'Bài kế',
  'prev': 'Bài trước',
  'stop': 'Dừng',
  'volup': 'Tăng âm lượng',
  'voldown': 'Giảm âm lượng',
  'mute': 'Tắt tiếng',
};

/// Nhãn cho hành động âm lượng riêng từng app.
const appVolumeLabels = <String, String>{
  'up': 'Tăng âm lượng app',
  'down': 'Giảm âm lượng app',
  'mute': 'Tắt tiếng app',
};
