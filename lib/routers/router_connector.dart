/// Interface commune à tous les routeurs.
///
/// Pour ajouter une marque (TP-Link, Huawei, ZTE…), on crée une classe qui
/// implémente cette interface en parlant à l'API de ce routeur, puis on
/// l'ajoute dans [RouterRegistry].
abstract class RouterConnector {
  String get brand;

  /// true si ce connecteur bloque tout seul (sans action de l'utilisateur).
  bool get isAutomatic;

  /// Se connecter à l'administration du routeur.
  Future<bool> login(String gatewayIp, String username, String password);

  /// Liste des appareils connus du routeur (IP -> MAC).
  /// Utile sur téléphone, où l'appli ne peut pas lire les MAC elle-même.
  Future<Map<String, String>> listClients();

  /// Bloque définitivement une adresse MAC (liste noire du routeur).
  Future<BlockResult> block(String mac, {String? name});

  /// Retire une adresse MAC de la liste noire.
  Future<BlockResult> unblock(String mac);
}

class BlockResult {
  final bool done;
  final String message;
  const BlockResult(this.done, this.message);
}

/// Informations d'aide par marque pour le mode guidé.
class RouterBrandInfo {
  final String id;
  final String name;
  final String defaultUrl;
  final String menuHint;

  const RouterBrandInfo(this.id, this.name, this.defaultUrl, this.menuHint);
}

const List<RouterBrandInfo> knownBrands = [
  RouterBrandInfo('airtel_zlt', 'Box Airtel (ZLT X17U / W154R)', 'http://192.168.1.1',
      'Connecte-toi (admin), puis menu ☰ > « Pare-feu » > « Règles de filtrage » > onglet « Filtres MAC ». Choisis « Liste de blocage », touche « Ajouter », colle la MAC, puis « Sauvegarder ».'),
  RouterBrandInfo('tplink', 'TP-Link', 'http://192.168.0.1',
      'Menu « Sécurité » ou « Wireless » > « Filtrage MAC » / « Contrôle d\'accès » > Liste noire.'),
  RouterBrandInfo('huawei', 'Huawei', 'http://192.168.3.1',
      'Menu « Plus de fonctions » > « Sécurité » > « Filtrage MAC » (ou « Wi-Fi » > « Contrôle d\'accès »).'),
  RouterBrandInfo('zte', 'ZTE', 'http://192.168.1.1',
      'Menu « Réseau local » / « WLAN » > « Filtrage MAC » > mode Liste noire.'),
  RouterBrandInfo('tenda', 'Tenda', 'http://192.168.0.1',
      'Menu « Paramètres Wi-Fi » > « Filtrage MAC » > Liste noire.'),
  RouterBrandInfo('autre', 'Autre / je ne sais pas', 'http://192.168.1.1',
      'Cherche un menu « Filtrage MAC », « Contrôle d\'accès », « Liste noire » ou « Appareils connectés ».'),
];
