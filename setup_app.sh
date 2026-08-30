#!/usr/bin/env bash
# Dùng cho macOS / Linux. Trên Windows chạy setup_app.bat.
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
    <!-- Cần cho mDNS: nhận gói multicast khi dò tìm laptop -->
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
"""
    m = re.sub(r"(<manifest[^>]*>)", r"\1" + perms, m, count=1)

m = re.sub(r'android:label="[^"]*"', 'android:label="HeDeck"', m, count=1)

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

for d in drawable drawable-v21; do
  mkdir -p "android/app/src/main/res/$d"
  cp ../android_patch/launch_background.xml "android/app/src/main/res/$d/"
done

MAIN_ACTIVITY=$(find android/app/src/main -name MainActivity.kt | head -1)
if [ -n "$MAIN_ACTIVITY" ] && ! grep -q FLAG_KEEP_SCREEN_ON "$MAIN_ACTIVITY"; then
  PKG=$(grep '^package ' "$MAIN_ACTIVITY")
  cat > "$MAIN_ACTIVITY" <<EOF
$PKG

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Màn hình không tắt khi đang dùng deck.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
EOF
  echo "  bật giữ màn hình sáng"
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
