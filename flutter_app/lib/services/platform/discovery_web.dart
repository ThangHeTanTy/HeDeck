import '../discovery.dart';

/// Bản web do agent phục vụ, nên máy cần kết nối là máy đã trả trang này về:
/// cùng địa chỉ, cùng cổng. Không phải dò.
Future<List<FoundHost>> discoverHosts({
  Duration timeout = const Duration(seconds: 4),
}) async {
  final page = Uri.base;
  if (!page.scheme.startsWith('http') || page.host.isEmpty) return [];
  return [FoundHost(page.host, page.host, page.hasPort ? page.port : 80)];
}
