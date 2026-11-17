"""Ajoute les permissions et le nom de l'appli dans le manifeste Android
généré par `flutter create`. Appelé par le workflow GitHub."""
import pathlib

path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
xml = path.read_text()

perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.ACCESS_FINE_LOCATION",
]
lines = "".join(
    f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in xml
)
if lines:
    xml = xml.replace("<application", lines + "    <application", 1)

xml = xml.replace('android:label="wifensor"', 'android:label="Wifensor"')
path.write_text(xml)
print(xml)

# Compatibilité avec les installateurs anciens (Tecno/HiOS, Android 13) :
# on cible Android 13 (API 33) au lieu de la toute dernière version.
import re
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    g = pathlib.Path(name)
    if g.exists():
        txt = g.read_text()
        txt = re.sub(r"targetSdk\s*=\s*flutter\.targetSdkVersion", "targetSdk = 33", txt)
        txt = re.sub(r"targetSdkVersion\s+flutter\.targetSdkVersion", "targetSdkVersion 33", txt)
        txt = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", txt)
        g.write_text(txt)
        print(name, "->", [l.strip() for l in txt.splitlines() if "Sdk" in l])
