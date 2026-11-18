/// Guides pas à pas pour chaque box.
///
/// Wifensor ne bloque pas les appareils lui-même : c'est la box qui le fait,
/// grâce à sa liste de blocage (filtrage MAC). L'appli ouvre la page de la box
/// et affiche les étapes une par une. Ça marche avec toutes les box : les
/// marques connues ont un guide précis, les autres un guide général.
///
/// Dans les textes, {ip} est remplacé par l'adresse IP de l'appareil et
/// {mac} par son adresse MAC.
class BoxGuide {
  final String id;
  final String name;

  /// Adresse habituelle de la page de la box (utilisée si l'appli ne trouve
  /// pas l'adresse du routeur toute seule).
  final String defaultIp;

  /// Comment trouver l'adresse MAC d'un appareil dans la box.
  final List<String> findMacSteps;

  /// Comment ajouter une adresse MAC à la liste de blocage.
  final List<String> blockSteps;

  /// Comment retirer une adresse MAC de la liste de blocage.
  final List<String> unblockSteps;

  const BoxGuide({
    required this.id,
    required this.name,
    required this.defaultIp,
    required this.findMacSteps,
    required this.blockSteps,
    required this.unblockSteps,
  });
}

const _loginGeneric =
    'Connecte-toi avec le mot de passe d\'administration de la box (souvent écrit sous la box). Ce n\'est pas forcément ton mot de passe Wi-Fi.';

const List<BoxGuide> boxGuides = [
  BoxGuide(
    id: 'airtel_zlt',
    name: 'Box Airtel (ZLT X17U / W154R)',
    defaultIp: '192.168.1.1',
    findMacSteps: [
      'Connecte-toi : nom d\'utilisateur « admin ». Le mot de passe d\'usine est souvent « admin » aussi.',
      'Sur l\'accueil, descends jusqu\'au tableau « Appareils connectés ».',
      'Repère la ligne de l\'appareil {ip}, puis fais glisser le tableau vers la droite pour voir sa colonne MAC.',
      'Wifensor repère l\'adresse MAC tout seul et l\'écrit en bas. Sinon, touche-la dans le tableau. Puis « Valider ».',
    ],
    blockSteps: [
      'Connecte-toi : nom d\'utilisateur « admin ».',
      'Touche le menu ☰ en haut à gauche, puis « Pare-feu », puis « Règles de filtrage ».',
      'Onglet « Filtres MAC » : vérifie que « Liste de blocage » est choisi.',
      'Touche « Ajouter » et touche le champ de l\'adresse MAC : Wifensor écrit {mac} tout seul.',
      'Coche « Activer » si la case existe, valide, puis touche « Sauvegarder les paramètres ».',
    ],
    unblockSteps: [
      'Connecte-toi : nom d\'utilisateur « admin ».',
      'Menu ☰ › « Pare-feu » › « Règles de filtrage » › onglet « Filtres MAC ».',
      'Trouve la ligne {mac} et supprime-la, puis touche « Sauvegarder les paramètres ».',
    ],
  ),
  BoxGuide(
    id: 'canalbox',
    name: 'Canalbox (GVA)',
    defaultIp: '192.168.1.1',
    findMacSteps: [
      _loginGeneric,
      'Cherche une page « Appareils connectés », « Clients », « Réseau local » ou « LAN ».',
      'Repère l\'appareil {ip} et touche son adresse MAC : Wifensor l\'écrit en bas. Puis « Valider ».',
    ],
    blockSteps: [
      _loginGeneric,
      'Cherche « Wi-Fi » ou « WLAN », puis « Filtrage MAC » ou « Contrôle d\'accès ».',
      'Choisis le mode « Liste noire » (ou « Bloquer »).',
      'Ajoute l\'adresse MAC {mac} (Wifensor la remplit quand tu touches le champ), puis enregistre.',
    ],
    unblockSteps: [
      _loginGeneric,
      'Retourne dans « Filtrage MAC » ou « Contrôle d\'accès ».',
      'Supprime la ligne {mac}, puis enregistre.',
    ],
  ),
  BoxGuide(
    id: 'tplink',
    name: 'TP-Link',
    defaultIp: '192.168.0.1',
    findMacSteps: [
      _loginGeneric,
      'Ouvre « Clients » ou « Appareils connectés » (souvent sur l\'accueil, ou dans « Avancé › Réseau »).',
      'Repère l\'appareil {ip} et touche son adresse MAC : Wifensor l\'écrit en bas. Puis « Valider ».',
    ],
    blockSteps: [
      _loginGeneric,
      'Va dans « Avancé › Sécurité › Contrôle d\'accès » (ou « Wireless › Filtrage MAC »).',
      'Active la fonction et choisis « Liste noire ».',
      'Ajoute l\'adresse MAC {mac}, puis enregistre.',
    ],
    unblockSteps: [
      _loginGeneric,
      'Retourne dans « Contrôle d\'accès » ou « Filtrage MAC ».',
      'Supprime la ligne {mac}, puis enregistre.',
    ],
  ),
  BoxGuide(
    id: 'huawei',
    name: 'Huawei',
    defaultIp: '192.168.3.1',
    findMacSteps: [
      _loginGeneric,
      'Ouvre « Appareils » ou « Terminaux connectés ».',
      'Touche l\'appareil {ip}, puis son adresse MAC : Wifensor l\'écrit en bas. Puis « Valider ».',
    ],
    blockSteps: [
      _loginGeneric,
      'Va dans « Plus de fonctions › Sécurité › Filtrage MAC » (ou « Wi-Fi › Contrôle d\'accès »).',
      'Choisis le mode « Liste noire ».',
      'Ajoute l\'adresse MAC {mac}, puis enregistre.',
    ],
    unblockSteps: [
      _loginGeneric,
      'Retourne dans « Filtrage MAC ».',
      'Supprime la ligne {mac}, puis enregistre.',
    ],
  ),
  BoxGuide(
    id: 'zte',
    name: 'ZTE',
    defaultIp: '192.168.1.1',
    findMacSteps: [
      _loginGeneric,
      'Ouvre « État › Réseau local » ou « Appareils connectés ».',
      'Repère l\'appareil {ip} et touche son adresse MAC : Wifensor l\'écrit en bas. Puis « Valider ».',
    ],
    blockSteps: [
      _loginGeneric,
      'Va dans « Réseau local › WLAN › Filtrage MAC » (ou « Contrôle d\'accès »).',
      'Choisis le mode « Liste noire ».',
      'Ajoute l\'adresse MAC {mac}, puis touche « Appliquer ».',
    ],
    unblockSteps: [
      _loginGeneric,
      'Retourne dans « Filtrage MAC ».',
      'Supprime la ligne {mac}, puis touche « Appliquer ».',
    ],
  ),
  BoxGuide(
    id: 'tenda',
    name: 'Tenda',
    defaultIp: '192.168.0.1',
    findMacSteps: [
      _loginGeneric,
      'Ouvre « Appareils connectés » ou « Gestion des clients ».',
      'Repère l\'appareil {ip} et touche son adresse MAC : Wifensor l\'écrit en bas. Puis « Valider ».',
    ],
    blockSteps: [
      _loginGeneric,
      'Va dans « Paramètres Wi-Fi › Filtrage MAC ».',
      'Choisis « Liste noire ».',
      'Ajoute l\'adresse MAC {mac}, puis enregistre.',
    ],
    unblockSteps: [
      _loginGeneric,
      'Retourne dans « Filtrage MAC ».',
      'Supprime la ligne {mac}, puis enregistre.',
    ],
  ),
  BoxGuide(
    id: 'autre',
    name: 'Autre box / je ne sais pas',
    defaultIp: '192.168.1.1',
    findMacSteps: [
      _loginGeneric,
      'Cherche une page « Appareils connectés », « Clients », « DHCP » ou « LAN ».',
      'Repère l\'appareil {ip} et touche son adresse MAC (6 paires comme A4:83:E7:12:34:56) : Wifensor l\'écrit en bas. Puis « Valider ».',
    ],
    blockSteps: [
      _loginGeneric,
      'Cherche « Filtrage MAC », « Contrôle d\'accès », « Liste noire » ou « Pare-feu ».',
      'Choisis le mode qui bloque (« Liste noire », « Refuser », « Bloquer »).',
      'Ajoute l\'adresse MAC {mac}, puis enregistre.',
    ],
    unblockSteps: [
      _loginGeneric,
      'Retourne dans la liste de blocage (« Filtrage MAC » ou « Contrôle d\'accès »).',
      'Supprime la ligne {mac}, puis enregistre.',
    ],
  ),
];

BoxGuide guideById(String? id) =>
    boxGuides.firstWhere((g) => g.id == id, orElse: () => boxGuides.last);
