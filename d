#!/usr/bin/env bash
set -euo pipefail

echo "=== Dodawanie brakującego MainActivity.kt (v2 embedding) i poprawki manifestu ==="

# 1) Wykrycie paczki aplikacji
PKG=$(grep -RhoP '(?<=^package\s)[\w\.]+' android/app/src/main/java android/app/src/main/kotlin 2>/dev/null | head -n1 || true)
if [ -z "$PKG" ]; then
  PKG=$(grep -oP 'package=\"\K[^\"]+' android/app/src/main/AndroidManifest.xml || true)
fi
if [ -z "$PKG" ]; then
  echo "Podaj nazwę paczki (package), np. com.example.clock1000:"
  read -r PKG
fi
echo "Używam package: $PKG"

# 2) Tworzenie katalogu i MainActivity.kt
OUT_DIR="android/app/src/main/java/${PKG//./\/}"
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/MainActivity.kt" <<EOF
package $PKG

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
EOF
echo "Utworzono MainActivity.kt w $OUT_DIR"

# 3) Poprawka AndroidManifest.xml — dodanie activity jeśli brak
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "Nie znaleziono AndroidManifest. Tworzę nowy minimalny."
  cat > "$MANIFEST" <<EOM
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PKG">
  <application>
    <activity android:name=".MainActivity"
              android:exported="true"
              android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
              android:launchMode="singleTop">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOM
  echo "Utworzono minimalny AndroidManifest.xml"
else
  echo "Aktualizuję manifest: $MANIFEST"
  # usunięcie (jeśli istnieje) starej deklaracji MainActivity
  sed -i '/GeneratedPluginRegistrant/d' "$MANIFEST"
  
  # Dodaj deklarację activity
  if ! grep -q "android:name=\".MainActivity\"" "$MANIFEST"; then
    sed -i '/<application>/a \
    <activity android:name=".MainActivity" android:exported="true" android:launchMode="singleTop">\
      <intent-filter>\
        <action android:name="android.intent.action.MAIN"/>\n        <category android:name="android.intent.category.LAUNCHER"/>\
      </intent-filter>\
    </activity>' "$MANIFEST"
    echo "Dodano MainActivity w manifest."
  else
    echo "MainActivity już zadeklarowany w manifest."
  fi
fi

# 4) Uruchomienie czyszczenia i rebuild
echo "Uruchamiam flutter clean, pub get i rebuild."
flutter clean
flutter pub get
flutter build apk --debug

echo "✅ Gotowe! MainActivity dodany, projekt zaktualizowany pod embedding v2."