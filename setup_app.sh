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

if "REQUEST_INSTALL_PACKAGES" not in m:
    m = re.sub(r"(<manifest[^>]*>)", r"\1" + """
    <!-- Mở trình cài đặt khi cập nhật app từ GitHub -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />""", m, count=1)

m = re.sub(r'android:label="[^"]*"', 'android:label="HeDeck"', m, count=1)

# Android khôi phục dữ liệu cũ sau khi cài lại app, nhưng khoá giải mã thì
# không còn -> kho khoá hỏng. Tắt sao lưu tự động.
if "allowBackup" not in m:
    m = m.replace('android:label="HeDeck"',
                  'android:label="HeDeck"\n        android:allowBackup="false"'
                  '\n        android:fullBackupContent="false"', 1)

# Chia sẻ APK tải về cho trình cài đặt (Android 7+ cấm dùng file://).
if "update_paths" not in m:
    provider = """    <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.updates"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/update_paths" />
        </provider>
    """
    i = m.rindex("</application>")
    m = m[:i] + provider + m[i:]

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
cp ../android_patch/network_security_config.xml ../android_patch/update_paths.xml \
   android/app/src/main/res/xml/

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
