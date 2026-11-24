import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../services/updater.dart';
import '../theme.dart';

/// Hộp thoại "Kiểm tra cập nhật": hỏi GitHub, hiện ghi chú thay đổi, rồi mở
/// link tải HeDeck.apk trong trình duyệt. Chỉ chạy khi người dùng bấm.
Future<void> showUpdateDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UpdateDialog(),
    );

enum _Step { checking, latest, available, opened, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Step _step = _Step.checking;
  Release? _rel;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _step = _Step.checking);
    try {
      final rel = await Updater.check();
      if (!mounted) return;
      setState(() {
        _rel = rel;
        _step = rel == null ? _Step.latest : _Step.available;
      });
    } catch (_) {
      _fail(t('Không hỏi được GitHub. Kiểm tra mạng Internet rồi thử lại.'));
    }
  }

  Future<void> _open() async {
    try {
      await Updater.openDownload(_rel!);
      if (mounted) setState(() => _step = _Step.opened);
    } on MissingPluginException {
      _fail(t('Bản build này chưa có bộ cập nhật. Chạy lại setup_app.bat '
          'rồi build lại, hoặc tải APK trên trang GitHub.'));
    } on PlatformException catch (e) {
      _fail(t('Không mở được trình duyệt: {0}', [e.message ?? e.code]));
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _step = _Step.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: DeckColors.muted, fontSize: 13, height: 1.4);
    final current = Updater.selfBuilt
        ? t('Bản tự build trên máy')
        : t('Đang dùng bản {0}', [Updater.version]);

    Widget body;
    final actions = <Widget>[];
    void close([String label = 'Đóng']) => actions.add(TextButton(
        onPressed: () => Navigator.pop(context), child: Text(t(label))));

    switch (_step) {
      case _Step.checking:
        body = Row(children: [
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 14),
          Text(t('Đang hỏi GitHub…'), style: muted),
        ]);
        close('Huỷ');
      case _Step.latest:
        body = Row(children: [
          Icon(Icons.verified_rounded, color: DeckColors.accent),
          const SizedBox(width: 12),
          Expanded(
              child: Text(t('Bạn đang dùng bản mới nhất.'),
                  style: TextStyle(color: DeckColors.text, fontSize: 14))),
        ]);
        close();
      case _Step.available:
        final rel = _rel!;
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Có bản mới {0}', [rel.version]),
                style: TextStyle(
                    color: DeckColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (rel.notes.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child:
                    SingleChildScrollView(child: Text(rel.notes, style: muted)),
              ),
            if (Updater.selfBuilt) ...[
              const SizedBox(height: 10),
              _warning(t('Bản đang dùng do bạn tự build, ký bằng khoá khác bản '
                  'trên GitHub. Nếu Android báo "Chưa cài đặt ứng dụng", hãy '
                  'gỡ HeDeck rồi cài lại — sẽ phải ghép cặp lại một lần.')),
            ],
            const SizedBox(height: 10),
            Text(
                t('Trình duyệt sẽ tải HeDeck.apk. Tải xong, bấm vào file để '
                    'cài đè bản cũ — giữ nguyên ghép cặp và bố cục.'),
                style: muted),
          ],
        );
        close('Để sau');
        actions.add(FilledButton.icon(
          onPressed: _open,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(t('Tải bản mới')),
        ));
      case _Step.opened:
        body = Text(
            t('Đã mở trình duyệt. Tải xong, bấm vào HeDeck.apk (trên thanh '
                'thông báo hoặc trong mục Tải xuống) rồi chọn "Cài đặt". Nếu '
                'Google Play Protect hỏi, chọn "Vẫn cài đặt".'),
            style: muted);
        close();
        actions.add(
            FilledButton(onPressed: _open, child: Text(t('Mở lại link tải'))));
      case _Step.failed:
        body = _warning(_error);
        close();
        actions.add(FilledButton(
          onPressed: _rel == null ? _check : _open,
          child: Text(t('Thử lại')),
        ));
    }

    return AlertDialog(
      backgroundColor: DeckColors.surface,
      title: Row(children: [
        Icon(Icons.system_update_rounded, color: DeckColors.accent),
        const SizedBox(width: 10),
        Text(t('Cập nhật HeDeck'),
            style: TextStyle(color: DeckColors.text, fontSize: 17)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(current,
              style: TextStyle(color: DeckColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          body,
        ],
      ),
      actions: actions,
    );
  }

  Widget _warning(String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFFE0A030)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: DeckColors.text, fontSize: 13, height: 1.4))),
        ],
      );
}
