import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/deck_connection.dart';
import '../services/discovery.dart';
import '../services/store.dart';
import '../theme.dart';

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8787');
  final _code = TextEditingController();

  List<FoundHost> _found = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;
  String _fingerprint = '';

  @override
  void initState() {
    super.initState();
    _scan();
    _loadFingerprint();
  }

  /// Vân tay khoá của chính máy này. Hiện lên để biết khoá có tồn tại không —
  /// nếu trống thì lỗi nằm ở khâu tạo khoá chứ không phải ở kết nối.
  Future<void> _loadFingerprint() async {
    final identity = context.read<DeckConnection>().identity;
    try {
      await identity.ensureReady();
    } catch (_) {
      // Lỗi sẽ hiện ra khi bấm Ghép cặp, ở đây chỉ cần biết có hay không.
    }
    final fp = await identity.fingerprint();
    if (mounted) setState(() => _fingerprint = fp);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    final hosts = await discoverHosts();
    if (!mounted) return;
    setState(() {
      _found = hosts;
      _scanning = false;
      if (hosts.length == 1 && _host.text.isEmpty) {
        _host.text = hosts.first.ip;
        _port.text = '${hosts.first.port}';
      }
    });
  }

  Future<void> _connect() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 8787;
    final code = _code.text.trim();

    if (host.isEmpty) {
      setState(() => _error = 'Nhập địa chỉ IP hiện trên cửa sổ agent');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'Mã ghép cặp gồm 6 chữ số');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    final store = context.read<Store>();
    final conn = context.read<DeckConnection>();
    try {
      final result = await conn.pair(
        host: host,
        port: port,
        code: code,
        deviceId: store.deviceId,
        deviceName: 'Điện thoại Android',
      );
      await store.savePairing(
        host: host,
        port: port,
        deviceId: result.deviceId,
        hostName: result.hostName,
        fingerprint: result.fingerprint,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Không tự đẩy màn hình: gốc app theo dõi trạng thái ghép cặp và tự
      // chuyển sang deck. Một nơi quyết định thì không bao giờ lệch nhau.
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = conn.lastError ?? 'Không ghép cặp được. Kiểm tra IP và mã.';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kết nối tới laptop',
                    style: TextStyle(
                        color: DeckColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chạy agent trên máy Windows, rồi nhập địa chỉ và mã 6 số hiện trên cửa sổ đó.',
                    style: TextStyle(color: DeckColors.muted, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Dùng máy ảo Android? Chạy adb reverse tcp:8787 tcp:8787 '
                    'rồi nhập 127.0.0.1.',
                    style: TextStyle(
                        color: DeckColors.muted, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _discoveryBlock(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _host,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(color: DeckColors.text),
                          decoration: const InputDecoration(
                            labelText: 'Địa chỉ IP',
                            hintText: '192.168.1.12',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: DeckColors.text),
                          decoration: const InputDecoration(labelText: 'Cổng'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                        color: DeckColors.text, fontSize: 20, letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'Mã ghép cặp',
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: DeckColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: DeckColors.danger, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        _fingerprint.isEmpty
                            ? Icons.error_outline_rounded
                            : Icons.verified_user_rounded,
                        size: 13,
                        color: _fingerprint.isEmpty
                            ? DeckColors.danger
                            : DeckColors.live,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _fingerprint.isEmpty
                              ? 'Máy này chưa tạo được khoá thiết bị'
                              : 'Khoá thiết bị $_fingerprint',
                          style: TextStyle(
                            color: _fingerprint.isEmpty
                                ? DeckColors.danger
                                : DeckColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _connecting ? null : _connect,
                    child: _connecting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Ghép cặp'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _discoveryBlock() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeckColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DeckColors.line, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_tethering_rounded,
                  size: 16, color: DeckColors.muted),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Máy tìm thấy trong mạng',
                    style: TextStyle(color: DeckColors.muted, fontSize: 12)),
              ),
              InkWell(
                onTap: _scanning ? null : _scan,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: _scanning
                      ? const SizedBox(
                          height: 13,
                          width: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: DeckColors.muted),
                        )
                      : const Text('Quét lại',
                          style:
                              TextStyle(color: DeckColors.accent, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_found.isEmpty)
            const Text(
              'Chưa thấy máy nào. Nhập IP thủ công ở dưới cũng được.',
              style: TextStyle(color: DeckColors.muted, fontSize: 12),
            )
          else
            ..._found.map(
              (h) => InkWell(
                onTap: () => setState(() {
                  _host.text = h.ip;
                  _port.text = '${h.port}';
                }),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.laptop_windows_rounded,
                          size: 16, color: DeckColors.live),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(h.name,
                            style: const TextStyle(
                                color: DeckColors.text, fontSize: 13)),
                      ),
                      Text('${h.ip}:${h.port}',
                          style: const TextStyle(
                              color: DeckColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
