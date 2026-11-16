/// Un appareil trouvé sur le réseau.
class Device {
  final String ip;
  String? mac;
  String? hostname;
  String? vendor;
  final List<int> openPorts;
  bool isGateway;
  bool isSelf;

  Device({
    required this.ip,
    this.mac,
    this.hostname,
    this.vendor,
    List<int>? openPorts,
    this.isGateway = false,
    this.isSelf = false,
  }) : openPorts = openPorts ?? [];

  /// Identifiant stable : la MAC si on la connaît, sinon l'IP.
  String get id => (mac != null && mac!.isNotEmpty) ? mac! : 'ip:$ip';

  /// Vrai si l'adresse MAC est « privée » (aléatoire), comme sur les
  /// iPhone et Android récents. Le fabricant est alors inconnu.
  bool get hasRandomMac {
    if (mac == null || mac!.length < 2) return false;
    final firstByte = int.tryParse(mac!.substring(0, 2), radix: 16);
    if (firstByte == null) return false;
    return (firstByte & 0x02) != 0;
  }

  String get displayName {
    if (isSelf) return 'Cet appareil';
    if (isGateway) return 'Routeur / Box';
    if (hostname != null && hostname!.isNotEmpty && hostname != ip) {
      return hostname!;
    }
    if (vendor != null) return 'Appareil $vendor';
    return 'Appareil inconnu';
  }

  String get typeGuess {
    if (isGateway) return 'Routeur';
    if (openPorts.contains(62078)) return 'iPhone / iPad';
    if (openPorts.contains(9100) || openPorts.contains(631)) return 'Imprimante';
    if (openPorts.contains(554)) return 'Caméra';
    if (openPorts.contains(8008) || openPorts.contains(8009)) return 'TV / Chromecast';
    if (openPorts.contains(445) || openPorts.contains(139)) return 'Ordinateur';
    if (openPorts.contains(22)) return 'Ordinateur / Serveur';
    return 'Inconnu';
  }
}

/// Statut qu'on attribue à un appareil.
enum DeviceStatus { nouveau, connu, fiable, bloque }

/// Ce qu'on retient d'un appareil entre deux scans.
class KnownDevice {
  final String id;
  String label;
  DeviceStatus status;
  String? lastIp;
  String? mac;
  DateTime firstSeen;
  DateTime lastSeen;

  KnownDevice({
    required this.id,
    required this.label,
    required this.status,
    this.lastIp,
    this.mac,
    required this.firstSeen,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'status': status.name,
        'lastIp': lastIp,
        'mac': mac,
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory KnownDevice.fromJson(Map<String, dynamic> j) => KnownDevice(
        id: j['id'] as String,
        label: j['label'] as String? ?? '',
        status: DeviceStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => DeviceStatus.connu,
        ),
        lastIp: j['lastIp'] as String?,
        mac: j['mac'] as String?,
        firstSeen: DateTime.parse(j['firstSeen'] as String),
        lastSeen: DateTime.parse(j['lastSeen'] as String),
      );
}
