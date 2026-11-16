# Wifensor — version 1

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
- **Blocage (mode guidé)** : l'appli copie la MAC et ouvre la page de ton
  routeur, avec l'indication du menu selon la marque. Tu colles la MAC dans la
  liste noire.
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
  routers/router_connector.dart interface commune des routeurs + marques
  routers/guided_connector.dart mode guidé (toutes les box)
  screens/home_screen.dart     écran principal
```

## Version 2 : ajouter un blocage automatique

Crée `lib/routers/tplink_connector.dart` (par exemple) qui implémente
`RouterConnector` en appelant l'API du routeur (login, liste des clients,
ajout à la liste noire). Choisis-le ensuite dans `_connector` de
`home_screen.dart` selon la marque.
