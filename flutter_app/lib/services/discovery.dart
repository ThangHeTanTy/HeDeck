// Android dò bằng mDNS (cần socket UDP). Bản web không có socket UDP, nhưng
// trang do chính agent phục vụ nên agent chính là máy đang mở trang này.
export 'platform/discovery_io.dart'
    if (dart.library.js_interop) 'platform/discovery_web.dart';

class FoundHost {
  final String name;
  final String ip;
  final int port;
  FoundHost(this.name, this.ip, this.port);
}
