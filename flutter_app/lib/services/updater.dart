import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

/// Cập nhật app từ GitHub Releases.
///
/// Android không cho app ngoài Play Store tự cài im lặng: app chỉ tải APK về
/// rồi mở trình cài đặt của hệ thống, người dùng bấm "Cài đặt" để xác nhận.
/// Phần mở trình cài đặt nằm trong MainActivity.kt (kênh `hedeck/update`), do
/// setup_app.bat sinh ra.
class Updater {
  static const repo = 'ThangHeTanTy/HeDeck';
  static const releasesPage = 'https://github.com/$repo/releases';

  /// Số phiên bản, do GitHub Actions truyền vào lúc build từ thẻ v1.2.3.
  /// Rỗng nghĩa là bản tự build trên máy.
  static const version = String.fromEnvironment('HEDECK_VERSION');

  /// Bản tự build ký bằng khoá riêng của máy build, khác khoá của bản trên
  /// GitHub — Android không cho cài đè, phải gỡ app trước.
  static bool get selfBuilt => version.isEmpty;

  static const _channel = MethodChannel('hedeck/update');

  static List<int>? parseVersion(String text) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
    if (m == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  static bool _newer(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  /// Bản mới nhất trên GitHub nếu mới hơn bản đang chạy, null nếu không có.
  /// Bản tự build không biết số phiên bản nên luôn nhận bản mới nhất.
  static Future<Release?> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'HeDeck-App')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 404) return null; // chưa có bản phát hành nào
      if (resp.statusCode != 200) {
        throw HttpException('GitHub ${resp.statusCode}');
      }
      final rel = Release.fromJson(jsonDecode(body) as Map<String, dynamic>);
      if (rel == null) return null;
      final current = parseVersion(version);
      if (current != null && !_newer(rel.parts, current)) return null;
      return rel;
    } finally {
      client.close(force: true);
    }
  }

  /// Tải APK về bộ nhớ đệm của app, kiểm SHA-256 nếu GitHub có ghi.
  /// [onProgress] nhận 0..1, hoặc -1 khi không biết dung lượng.
  static Future<File> download(Release rel,
      {void Function(double)? onProgress}) async {
    final dir = await _channel.invokeMethod<String>('apkDir');
    final file = File('$dir/HeDeck-${rel.version}.apk');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(rel.apkUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'HeDeck-App');
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('GitHub ${resp.statusCode}');
      }
      final total = resp.contentLength > 0 ? resp.contentLength : rel.apkSize;
      final hash = Sha256().newHashSink();
      final out = file.openWrite();
      var done = 0;
      try {
        await for (final chunk in resp.timeout(const Duration(seconds: 30))) {
          out.add(chunk);
          hash.add(chunk);
          done += chunk.length;
          onProgress?.call(total > 0 ? done / total : -1);
        }
      } finally {
        await out.close();
      }
      hash.close();
      if (rel.apkSha256.isNotEmpty) {
        final got = (await hash.hash())
            .bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (got != rel.apkSha256) {
          await file.delete();
          throw const FormatException('sha256');
        }
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Mở trình cài đặt của Android. Lần đầu Android sẽ hỏi cho phép HeDeck
  /// cài ứng dụng — bật lên rồi quay lại là cài tiếp.
  static Future<void> install(File apk) =>
      _channel.invokeMethod('install', {'path': apk.path});
}

class Release {
  final String version;
  final List<int> parts;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final String apkSha256;

  const Release({
    required this.version,
    required this.parts,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.apkSha256,
  });

  /// Null nếu thẻ không đúng dạng v1.2.3 hoặc bản phát hành không có APK.
  static Release? fromJson(Map<String, dynamic> j) {
    final parts = Updater.parseVersion('${j['tag_name'] ?? ''}');
    if (parts == null) return null;
    final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final apk = assets
        .where((a) => '${a['name']}'.toLowerCase().endsWith('.apk'))
        .firstOrNull;
    if (apk == null) return null;
    final digest = '${apk['digest'] ?? ''}';
    return Release(
      version: parts.join('.'),
      parts: parts,
      // Phần dưới dòng --- là hướng dẫn cài lần đầu, không phải thay đổi.
      notes: '${j['body'] ?? ''}'
          .split(RegExp(r'^---\s*$', multiLine: true))[0]
          .trim(),
      apkUrl: '${apk['browser_download_url']}',
      apkSize: (apk['size'] as num?)?.toInt() ?? 0,
      // GitHub tự tính SHA-256 cho mọi file đính kèm, dạng "sha256:…".
      apkSha256: digest.startsWith('sha256:') ? digest.substring(7) : '',
    );
  }
}
