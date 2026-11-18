# Wifensor — version 2

Détecte les appareils connectés à ton Wi-Fi, t'alerte quand un nouvel appareil
apparaît, et t'aide à bloquer les indésirables dans ton routeur.

Plateformes : Android, iPhone/iPad, Windows, macOS, Linux (Flutter).

## Installation

1. Installe Flutter 3.27 ou plus récent : https://docs.flutter.dev/get-started/install
2. Dans ce dossier, génère les dossiers des plateformes (ça ne touche pas à `lib/`) :
   ```
   flutter create --org com.wifensor --platforms=android,ios,windows,macos,linux .
   flutter pub get
   ```
3. Ajoute les permissions ci-dessous.
4. Lance : `flutter run` (téléphone branché) ou `flutter run -d windows`.

## Permissions à ajouter

### Android — `android/app/src/main/AndroidManifest.xml`
Dans `<manifest>`, avant `<application>` :
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```
Android demande la localisation pour lire le nom du Wi-Fi. Sans elle, le scan
marche quand même.

### iPhone — `ios/Runner/Info.plist`
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Wifensor scanne ton réseau local pour lister les appareils connectés.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Nécessaire pour afficher le nom de ton réseau Wi-Fi.</string>
```
Pour le nom du Wi-Fi, active aussi la capacité « Access WiFi Information » dans Xcode.

### macOS — `macos/Runner/DebugProfile.entitlements` et `Release.entitlements`
```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Comment ça marche

- **Scan** : l'appli teste les 254 adresses de ton réseau. Un appareil qui
  accepte ou refuse une connexion est présent.
- **Adresse MAC et fabricant** : lues dans la table ARP sur PC (Windows, macOS,
  Linux). Android 10+ et iOS interdisent cette lecture : sur téléphone, on copie
  la MAC depuis la page « appareils connectés » du routeur.
- **MAC privée** : les téléphones récents utilisent une MAC aléatoire par
  réseau. Elle reste stable sur ton Wi-Fi, donc le blocage marche quand même.
- **Blocage guidé dans l'appli (v2)** : Wifensor ouvre la page de la box DANS
  l'appli, avec un bandeau d'étapes en haut (« 1. Connecte-toi », « 2. Va dans
  Pare-feu »…). Guides précis pour Airtel ZLT, Canalbox, TP-Link, Huawei, ZTE,
  Tenda, et un guide général pour les autres box.
- **Aide pour l'adresse MAC** : si elle manque (cas des téléphones), l'appli
  ouvre la liste « Appareils connectés » de la box et propose un bouton Coller.
- **Vérification** : un appareil bloqué qui réapparaît au scan déclenche une alerte.
- **Mémoire** : le premier scan enregistre tout comme « connu ». Ensuite, chaque
  appareil inconnu déclenche une alerte. Si un appareil bloqué réapparaît,
  l'appli te prévient.

## Structure

```
lib/
  main.dart                    point d'entrée
  models/device.dart           appareil + statut (nouveau, connu, fiable, bloqué)
  services/network_scanner.dart scan du réseau, ARP, noms d'hôte
  services/oui_vendors.dart    fabricants d'après la MAC
  services/device_store.dart   mémoire locale
  routers/box_guides.dart      guides pas à pas, par box
  screens/home_screen.dart     écran principal
  screens/box_guide_screen.dart page de la box dans l'appli + bandeau d'étapes
```

## Fabrication automatique

À chaque envoi sur GitHub, le workflow « Fabriquer l'appli Android » génère
Wifensor.apk (universel, Android 7+) et le publie dans les Releases.
