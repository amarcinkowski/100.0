#!/bin/bash
set -e

echo "=== Aktualizacja Flutter Android v1 embedding -> v2 ==="

# Sprawdź czy jesteś w katalogu projektu Flutter
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Nie znaleziono pubspec.yaml — uruchom w katalogu głównym projektu Flutter!"
  exit 1
fi

# Znajdź plik MainActivity w Kotlin lub Java
MAIN_ACTIVITY_KT=$(find android/app/src/main -name MainActivity.kt 2>/dev/null || true)
MAIN_ACTIVITY_JAVA=$(find android/app/src/main -name MainActivity.java 2>/dev/null || true)

if [ -n "$MAIN_ACTIVITY_KT" ]; then
    echo "✅ Znaleziono $MAIN_ACTIVITY_KT — aktualizacja..."
    cat > "$MAIN_ACTIVITY_KT" <<'EOF'
package com.example.clock1000

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
EOF
elif [ -n "$MAIN_ACTIVITY_JAVA" ]; then
    echo "✅ Znaleziono $MAIN_ACTIVITY_JAVA — aktualizacja..."
    cat > "$MAIN_ACTIVITY_JAVA" <<'EOF'
package com.example.clock1000;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
}
EOF
else
    echo "⚠️ Nie znaleziono MainActivity.kt ani MainActivity.java — pomiń"
fi

# Aktualizacja AndroidManifest.xml
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
    echo "✅ Aktualizacja $MANIFEST"
    sed -i 's/android:name="io.flutter.app.FlutterApplication"/android:name="${applicationName}"/g' "$MANIFEST"
else
    echo "⚠️ $MANIFEST nie istnieje"
fi

# Usuń stary GeneratedPluginRegistrant.java jeśli istnieje
OLD_REG=$(find android -name GeneratedPluginRegistrant.java 2>/dev/null || true)
if [ -n "$OLD_REG" ]; then
    echo "🗑️ Usuwanie $OLD_REG"
    rm -f "$OLD_REG"
fi

# Aktualizacja Gradle (minimalne SDK i wersja pluginu Fluttera)
GRADLE_FILE="android/app/build.gradle"
if [ -f "$GRADLE_FILE" ]; then
    echo "✅ Aktualizacja build.gradle"
    sed -i 's/minSdkVersion [0-9]\+/minSdkVersion 21/g' "$GRADLE_FILE"
fi

echo "=== Gotowe! ==="
echo "📦 Uruchom teraz: flutter clean && flutter pub get && flutter build apk"