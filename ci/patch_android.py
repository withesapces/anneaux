"""Adapte le dossier android/ généré par `flutter create` aux besoins de l'app.

Échoue bruyamment si un motif attendu est introuvable (template Flutter modifié).
"""
import pathlib
import re
import shutil
import sys

root = pathlib.Path("android/app")


def patch(path, old, new, count=1, regex=False):
    p = pathlib.Path(path)
    s = p.read_text()
    if regex:
        s2, n = re.subn(old, new, s, count=count)
    else:
        n = s.count(old)
        s2 = s.replace(old, new, count)
    if n == 0:
        sys.exit(f"Motif introuvable dans {path}: {old!r}")
    p.write_text(s2)


# 1. R8 : on garde les classes appelées via JNI et on désactive la minification.
shutil.copy("ci/proguard-rules.pro", root / "proguard-rules.pro")
gradle = root / "build.gradle.kts"
patch(gradle, 'signingConfig = signingConfigs.getByName("debug")',
      'signingConfig = signingConfigs.getByName("debug")\n'
      '            isMinifyEnabled = false\n'
      '            isShrinkResources = false')
# Health Connect exige Android 8 (API 26) minimum.
patch(gradle, r"minSdk = [^\n]+", "minSdk = 26", regex=True)

# 2. Health Connect : l'activité doit être une FlutterFragmentActivity.
main = next(root.glob("src/main/kotlin/**/MainActivity.kt"))
s = main.read_text().replace("FlutterActivity", "FlutterFragmentActivity")
main.write_text(s)

# 3. Manifest : nom, permissions, filtres d'intent Health Connect.
manifest = root / "src/main/AndroidManifest.xml"
patch(manifest, 'android:label="anneaux"', 'android:label="Anneaux"')
patch(manifest, "<application",
      '<uses-permission android:name="android.permission.health.WRITE_EXERCISE"/>\n'
      '    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>\n'
      "    <application")
patch(manifest, r'(<category android:name="android.intent.category.LAUNCHER"\s*/>\s*</intent-filter>)',
      r'\1\n            <intent-filter>\n'
      r'                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
      r'            </intent-filter>', regex=True)
patch(manifest, "</application>",
      '    <activity-alias\n'
      '            android:name="ViewPermissionUsageActivity"\n'
      '            android:exported="true"\n'
      '            android:targetActivity=".MainActivity"\n'
      '            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
      '            <intent-filter>\n'
      '                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />\n'
      '                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />\n'
      '            </intent-filter>\n'
      '        </activity-alias>\n'
      '    </application>')
q = manifest.read_text()
health_queries = ('<package android:name="com.google.android.apps.healthdata" />\n'
                  '        <intent>\n'
                  '            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />\n'
                  '        </intent>\n')
if "<queries>" in q:
    patch(manifest, "<queries>", "<queries>\n        " + health_queries)
else:
    patch(manifest, "</manifest>", "    <queries>\n        " + health_queries + "    </queries>\n</manifest>")

print(manifest.read_text())
print(gradle.read_text())
print(main.read_text())
