#!/usr/bin/env bash
# Dùng cho macOS / Linux và cho GitHub Actions. Trên Windows chạy setup_app.bat.
# Giữ đồng bộ với android_patch/patch_manifest.ps1: bản APK phát hành trên
# GitHub được build bằng chính script này.
set -e
cd "$(dirname "$0")/flutter_app"

command -v flutter >/dev/null || { echo "Không tìm thấy Flutter trong PATH."; exit 1; }

echo "[1/4] Sinh phần khung Android..."
flutter create . --platforms=android --project-name hedeck --org com.hedeck

echo "[2/4] Vá AndroidManifest cho HeDeck..."
MANIFEST="android/app/src/main/AndroidManifest.xml"

python3 - "$MANIFEST" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
m = p.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in m:
    perms = """
    <!-- Nói chuyện với agent qua LAN -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <!-- Cần cho mDNS: nhận gói multicast khi dò tìm thiết bị -->
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
"""
    m = re.sub(r"(<manifest[^>]*>)", r"\1" + perms, m, count=1)

if "FOREGROUND_SERVICE_SPECIAL_USE" not in m:
    m = re.sub(r"(<manifest[^>]*>)", r"\1" + """
    <!-- Trạm bật máy chạy ngầm (dịch vụ nền có thông báo) -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />""", m, count=1)

# Bản 1.2.3 còn tự mở lại khi khởi động máy và tự xin bỏ tối ưu pin. Bộ quyền
# đó cùng quyền tự cài bản cập nhật khiến Google Play Protect chặn app là "có
# hại". Gỡ khỏi khung đã sinh từ trước.
m = re.sub(r'\s*<uses-permission android:name="android\.permission\.(RECEIVE_BOOT_COMPLETED|REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)" />', "", m)
m = re.sub(r'\s*<receiver\s+android:name="\.BootReceiver".*?</receiver>', "", m, flags=re.S)

# Bản 1.3.0 vẫn bị chặn: app tự tải APK rồi tự mở trình cài đặt
# (REQUEST_INSTALL_PACKAGES + FileProvider) là hành vi Play Protect nghi là
# "ứng dụng phát tán". Giờ cập nhật bằng cách mở link tải trong trình duyệt.
m = re.sub(r'\s*<!-- M[^>]*trình cài đặt[^>]*-->', "", m)
m = re.sub(r'\s*<uses-permission android:name="android\.permission\.REQUEST_INSTALL_PACKAGES" />', "", m)
m = re.sub(r'\s*<provider\s+android:name="androidx\.core\.content\.FileProvider".*?</provider>', "", m, flags=re.S)

if "WakeRelayService" not in m:
    i = m.rindex("</application>")
    m = m[:i] + """    <service
            android:name=".WakeRelayService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="Tram bat may tinh (Wake-on-LAN) cho dien thoai khac" />
        </service>
    """ + m[i:]

m = re.sub(r'android:label="[^"]*"', 'android:label="HeDeck"', m, count=1)

# Android khôi phục dữ liệu cũ sau khi cài lại app, nhưng khoá giải mã thì
# không còn -> kho khoá hỏng. Tắt sao lưu tự động.
if "allowBackup" not in m:
    m = m.replace('android:label="HeDeck"',
                  'android:label="HeDeck"\n        android:allowBackup="false"'
                  '\n        android:fullBackupContent="false"', 1)

if "networkSecurityConfig" not in m:
    m = m.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@mipmap/ic_launcher"\n        '
        'android:networkSecurityConfig="@xml/network_security_config"', 1)

if "screenOrientation" not in m:
    m = m.replace(
        'android:windowSoftInputMode="adjustResize"',
        'android:screenOrientation="sensorLandscape"\n            '
        'android:windowSoftInputMode="adjustResize"', 1)

p.write_text(m, encoding="utf-8")
print("  vá manifest xong")
PYEOF

mkdir -p android/app/src/main/res/xml
cp ../android_patch/network_security_config.xml android/app/src/main/res/xml/
rm -f android/app/src/main/res/xml/update_paths.xml

for d in drawable drawable-v21; do
  mkdir -p "android/app/src/main/res/$d"
  cp ../android_patch/launch_background.xml "android/app/src/main/res/$d/"
done

# MainActivity: giữ màn hình sáng và kênh hedeck/update để mở trình cài đặt.
# Lấy từ android_patch/MainActivity.kt, chỉ giữ tên package Flutter đã sinh.
MAIN_ACTIVITY=$(find android/app/src/main -name MainActivity.kt | head -1)
if [ -n "$MAIN_ACTIVITY" ]; then
  PKG=$(grep '^package ' "$MAIN_ACTIVITY" | tr -d '\r')
  sed "s/^package __PACKAGE__$/$PKG/" ../android_patch/MainActivity.kt > "$MAIN_ACTIVITY"
  echo "  cập nhật MainActivity"
else
  echo "  ! không thấy MainActivity.kt"
  exit 1
fi

cp ../android_patch/proguard-rules.pro android/app/ 2>/dev/null || true

GP="android/gradle.properties"
touch "$GP"
for line in "kotlin.incremental=false" "kotlin.incremental.useClasspathSnapshot=false" "kotlin.compiler.execution.strategy=in-process"; do
  key="${line%%=*}"
  grep -q "$key" "$GP" || echo "$line" >> "$GP"
done

echo "[3/4] Tải package..."
flutter pub get

echo "[4/4] Sinh icon launcher HeDeck..."
dart run flutter_launcher_icons || echo "(bỏ qua, app vẫn chạy với icon mặc định)"

echo
echo "=== Xong. Chạy thử: flutter run   |   Xuất APK: flutter build apk --release ==="
