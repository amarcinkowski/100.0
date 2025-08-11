#!/usr/bin/env bash
set -euo pipefail

echo "=== Dodawanie natywnego Android widgeta do projektu Flutter ==="

# 1) znajdź package name (z java/kt plików, manifestu lub build.gradle)
PKG=""
PKG=$(grep -RhoP '(?<=^package\s)[\w\.]+' android/app/src/main/java android/app/src/main/kotlin 2>/dev/null | head -n1 || true)

if [ -z "$PKG" ] && [ -f android/app/src/main/AndroidManifest.xml ]; then
  PKG=$(grep -oP 'package=\"\K[^\"]+' android/app/src/main/AndroidManifest.xml | head -n1 || true)
fi

if [ -z "$PKG" ] && [ -f android/app/build.gradle ]; then
  PKG=$(grep -oP 'applicationId\s+["'\'']\K[^"'\'']+' android/app/build.gradle | head -n1 || true)
fi

if [ -z "$PKG" ]; then
  echo "Nie znalazłem nazwy paczki (package). Podaj ją ręcznie (np. com.example.clock1000):"
  read -r PKG
fi

echo "Używam package: $PKG"

# 2) scieżki
PKG_PATH=${PKG//./\/}
JAVA_OUT_DIR="android/app/src/main/java/$PKG_PATH"
LAYOUT_DIR="android/app/src/main/res/layout"
XML_DIR="android/app/src/main/res/xml"
MANIFEST_CANDIDATES=$(find android -type f -name AndroidManifest.xml || true)
MANIFEST_PATH=""

# preferowany manifest (app src main)
if [ -f android/app/src/main/AndroidManifest.xml ]; then
  MANIFEST_PATH="android/app/src/main/AndroidManifest.xml"
else
  MANIFEST_PATH=$(echo "$MANIFEST_CANDIDATES" | head -n1 || true)
fi

# 3) stwórz pliki i katalogi
mkdir -p "$JAVA_OUT_DIR"
mkdir -p "$LAYOUT_DIR"
mkdir -p "$XML_DIR"

# 4) ClockWidget.kt
cat > "$JAVA_OUT_DIR/ClockWidget.kt" <<EOF
package $PKG

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.util.*

class ClockWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val now = Calendar.getInstance()

            val startToday = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 6)
                set(Calendar.MINUTE, 15)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (now.before(startToday)) {
                startToday.add(Calendar.DATE, -1)
            }

            val diffMillis = now.timeInMillis - startToday.timeInMillis
            val minutesElapsed = (diffMillis / 60000).toInt()

            val maxMinutes = 1000
            val displayMinutes = if (minutesElapsed in 0..maxMinutes) {
                minutesElapsed
            } else {
                startToday.add(Calendar.DATE, 1)
                val diffNext = startToday.timeInMillis - now.timeInMillis
                val remaining = (diffNext / 60000).toInt()
                if (remaining < 0) 0 else remaining
            }

            views.setTextViewText(R.id.textViewMinutes, String.format("%03d", displayMinutes))
            val progress = if (displayMinutes > maxMinutes) maxMinutes else displayMinutes
            views.setProgressBar(R.id.progressBar, maxMinutes, progress, false)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
EOF

echo "Utworzono: $JAVA_OUT_DIR/ClockWidget.kt"

# 5) layout widget_layout.xml
cat > "$LAYOUT_DIR/widget_layout.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:padding="12dp"
    android:background="#FFFFFF">

    <TextView
        android:id="@+id/textViewMinutes"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="000"
        android:textSize="36sp"
        android:textStyle="bold"
        android:textColor="#000000"/>

    <ProgressBar
        android:id="@+id/progressBar"
        style="@android:style/Widget.ProgressBar.Horizontal"
        android:layout_width="match_parent"
        android:layout_height="12dp"
        android:layout_below="@id/textViewMinutes"
        android:layout_marginTop="8dp"
        android:max="1000"
        android:progress="0"
        android:progressTint="#2196F3"/>
</RelativeLayout>
XML

echo "Utworzono: $LAYOUT_DIR/widget_layout.xml"

# 6) clock_widget_info.xml
cat > "$XML_DIR/clock_widget_info.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="72dp"
    android:updatePeriodMillis="60000"
    android:initialLayout="@layout/widget_layout"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen">
</appwidget-provider>
XML

echo "Utworzono: $XML_DIR/clock_widget_info.xml"

# 7) Zaktualizuj/utwórz AndroidManifest.xml
if [ -z "$MANIFEST_PATH" ]; then
  echo "Nie znaleziono AndroidManifest.xml. Tworzę minimalny manifest w android/app/src/main/AndroidManifest.xml"
  MANIFEST_PATH="android/app/src/main/AndroidManifest.xml"
  cat > "$MANIFEST_PATH" <<MAN
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PKG">

    <application
        android:label="@string/app_name"
        android:icon="@mipmap/ic_launcher">
    </application>

</manifest>
MAN
  echo "Utworzono: $MANIFEST_PATH"
fi

echo "Aktualizuję manifest: $MANIFEST_PATH"

# użyj Pythona do bezpiecznego wstawienia receivera (obsługa namespace android)
python3 - <<PY
import xml.etree.ElementTree as ET
import sys

mf = "$MANIFEST_PATH"
pkg = "$PKG"
ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')

try:
    tree = ET.parse(mf)
    root = tree.getroot()
except Exception as e:
    print("Błąd parsowania manifestu:", e)
    sys.exit(1)

ns = {'android': 'http://schemas.android.com/apk/res/android'}

app = root.find('application')
if app is None:
    app = ET.SubElement(root, 'application')

# sprawdź czy receiver już istnieje
exists = False
for r in app.findall('receiver'):
    name = r.get('{http://schemas.android.com/apk/res/android}name')
    if name and name.endswith('.ClockWidget'):
        exists = True
        break

if not exists:
    recv = ET.SubElement(app, 'receiver')
    recv.set('{http://schemas.android.com/apk/res/android}name', f"{pkg}.ClockWidget")
    recv.set('{http://schemas.android.com/apk/res/android}exported', 'true')

    intent = ET.SubElement(recv, 'intent-filter')
    action = ET.SubElement(intent, 'action')
    action.set('{http://schemas.android.com/apk/res/android}name', 'android.appwidget.action.APPWIDGET_UPDATE')

    meta = ET.SubElement(recv, 'meta-data')
    meta.set('{http://schemas.android.com/apk/res/android}name', 'android.appwidget.provider')
    meta.set('{http://schemas.android.com/apk/res/android}resource', '@xml/clock_widget_info')

    tree.write(mf, encoding='utf-8', xml_declaration=True)
    print("Dodano receiver do manifestu.")
else:
    print("Receiver już istnieje w manifeście.")
PY

# 8) git: utwórz branch, commit, opcjonalnie push
read -r -p "Chcesz utworzyć branch 'feature/android-widget' i zacommitować zmiany? (y/n) " ans
if [ "${ans,,}" = "y" ] || [ "${ans,,}" = "tak" ] || [ "${ans,,}" = "t" ]; then
  git checkout -b feature/android-widget
  git add "$JAVA_OUT_DIR/ClockWidget.kt" "$LAYOUT_DIR/widget_layout.xml" "$XML_DIR/clock_widget_info.xml" "$MANIFEST_PATH"
  git commit -m "Add native Android home-screen widget (ClockWidget)"
  echo "Commit wykonany na branchu feature/android-widget."
  read -r -p "Wypchnąć branch do origin teraz? (y/n) " pus
  if [ "${pus,,}" = "y" ] || [ "${pus,,}" = "tak" ] || [ "${pus,,}" = "t" ]; then
    git push --set-upstream origin feature/android-widget
    # wyświetl link do PR (próba wyciągnięcia repo owner/name)
    remote=$(git remote get-url origin || true)
    repo=$(echo "$remote" | sed -n 's#.*github.com[:/]\(.*\)\.git#\1#p')
    if [ -n "$repo" ]; then
      echo "Możesz otworzyć PR: https://github.com/$repo/compare/feature/android-widget?expand=1"
    else
      echo "Branch został wypchnięty — stwórz PR z przeglądarki."
    fi
  else
    echo "Branch został utworzony lokalnie (feature/android-widget). Nie wypchnięto go."
  fi
else
  echo "Pominięto tworzenie commita/brancha. Pliki zostały wgrane lokalnie."
fi

echo "Gotowe ✅"