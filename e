#!/usr/bin/env bash
set -euo pipefail

echo "=== Migracja do Android v2 embedding (Flutter) ==="

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Brak pubspec.yaml — uruchom w katalogu głównym projektu."
  exit 1
fi

# 1) Znajdź package
PKG=$(grep -RhoP '(?<=^package\s)[\w\.]+' android/app/src/main/java android/app/src/main/kotlin 2>/dev/null | head -n1 || true)
if [ -z "$PKG" ]; then
  PKG=$(grep -oP 'package=\"\K[^\"]+' android/app/src/main/AndroidManifest.xml || true)
fi
if [ -z "$PKG" ]; then
  echo "Podaj nazwę paczki (np. com.example.clock1000):"
  read -r PKG
fi
echo "Package: $PKG"

# 2) Utwórz MainActivity.kt w embedding v2
OUT_DIR="android/app/src/main/java/${PKG//./\/}"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/MainActivity.kt" <<EOF
package $PKG

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
EOF
echo "Dodano: $OUT_DIR/MainActivity.kt"

# 3) Aktualizuj lub stwórz AndroidManifest.xml
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "Tworzę minimalny manifest."
  mkdir -p "$(dirname "$MANIFEST")"
  cat > "$MANIFEST" <<EOM
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PKG">
  <application>
    <activity android:name=".MainActivity"
              android:exported="true"
              android:launchMode="singleTop">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOM
  echo "Stworzono: $MANIFEST"
else
  echo "Aktualizuję: $MANIFEST"
  sed -i '/GeneratedPluginRegistrant/d' "$MANIFEST"
  if ! grep -q 'android:name=".MainActivity"' "$MANIFEST"; then
    sed -i '/<application>/a \
    <activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop">\
      <intent-filter>\
        <action android:name="android.intent.action.MAIN"/>\n        <category android:name="android.intent.category.LAUNCHER"/>\
      </intent-filter>\
    </activity>' "$MANIFEST"
    echo "MainActivity dodany do manifestu."
  else
    echo "MainActivity już w manifest."
  fi
fi

# 4) Usuń stare pliki GeneratedPluginRegistrant
find android -name GeneratedPluginRegistrant.java -exec rm -f {} \; && echo "Stare GeneratedPluginRegistrant usunięte."

# 5) Flutter clean i rebuild
echo "Czyszczenie i rebuild..."
flutter clean
flutter pub get
flutter build apk --debug

echo "✅ Migrowano do Android v2 embedding."