import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/deck_connection.dart';
import '../theme.dart';

/// Điều khiển nhạc và âm lượng — luôn có sẵn, không tốn ô nào trên deck.
///
/// Thu gọn được thành một nút ở góc phải dưới; bấm nút đó để mở lại.
class MediaBar extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;

  const MediaBar({super.key, required this.collapsed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<DeckConnection>();

    void tap(String action) {
      if (!conn.isOnline) return;
      HapticFeedback.selectionClick();
      conn.media(action);
    }

    Widget btn(IconData icon, String action, {String? tip}) => Semantics(
          button: true,
          label: tip,
          child: InkWell(
            onTap: () => tap(action),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Icon(icon,
                  size: 20,
                  color: conn.isOnline ? DeckColors.text : DeckColors.muted),
            ),
          ),
        );

    void toggle() {
      HapticFeedback.selectionClick();
      onToggle();
    }

    final box = BoxDecoration(
      color: DeckColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: DeckColors.line, width: 0.8),
    );

    if (collapsed) {
      return Tooltip(
        message: t('Hiện nút nhạc và âm lượng'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: box,
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.music_note_rounded,
                  size: 20,
                  color: conn.isOnline ? DeckColors.text : DeckColors.muted),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: box,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.skip_previous_rounded, 'prev', tip: t('Bài trước')),
          btn(Icons.play_arrow_rounded, 'playpause',
              tip: t('Phát hoặc tạm dừng')),
          btn(Icons.skip_next_rounded, 'next', tip: t('Bài kế')),
          Container(width: 0.8, height: 20, color: DeckColors.line),
          btn(Icons.volume_down_rounded, 'voldown', tip: t('Giảm âm lượng')),
          btn(Icons.volume_off_rounded, 'mute', tip: t('Tắt tiếng')),
          btn(Icons.volume_up_rounded, 'volup', tip: t('Tăng âm lượng')),
          Container(width: 0.8, height: 20, color: DeckColors.line),
          Tooltip(
            message: t('Thu gọn vào góc'),
            child: InkWell(
              onTap: toggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(Icons.keyboard_double_arrow_right_rounded,
                    size: 18, color: DeckColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
