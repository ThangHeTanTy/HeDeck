import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/deck_connection.dart';
import '../theme.dart';

/// Điều khiển nhạc và âm lượng — luôn có sẵn, không tốn ô nào trên deck.
class MediaBar extends StatelessWidget {
  const MediaBar({super.key});

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

    return Container(
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DeckColors.line, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.skip_previous_rounded, 'prev', tip: 'Bài trước'),
          btn(Icons.play_arrow_rounded, 'playpause', tip: 'Phát hoặc tạm dừng'),
          btn(Icons.skip_next_rounded, 'next', tip: 'Bài kế'),
          Container(width: 0.8, height: 20, color: DeckColors.line),
          btn(Icons.volume_down_rounded, 'voldown', tip: 'Giảm âm lượng'),
          btn(Icons.volume_off_rounded, 'mute', tip: 'Tắt tiếng'),
          btn(Icons.volume_up_rounded, 'volup', tip: 'Tăng âm lượng'),
        ],
      ),
    );
  }
}
