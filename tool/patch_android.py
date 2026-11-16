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
