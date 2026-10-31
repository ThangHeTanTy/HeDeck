import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

/// Bản web do agent phục vụ, nên luôn cùng phiên bản với agent: cập nhật
/// agent là bản web mới theo. Không có gì để tải ở phía trình duyệt.
Future<void> showUpdateDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DeckColors.surface,
        title: Row(children: [
          Icon(Icons.system_update_rounded, color: DeckColors.accent),
          const SizedBox(width: 10),
          Text(t('Cập nhật HeDeck'),
              style: TextStyle(color: DeckColors.text, fontSize: 17)),
        ]),
        content: Text(
          t('Bản web luôn cùng phiên bản với agent trên máy tính. Khi cửa sổ '
              'agent báo có bản mới, bấm "Xem và cập nhật" ở đó rồi tải lại '
              'trang này.'),
          style: TextStyle(color: DeckColors.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t('Đóng'))),
        ],
      ),
    );
