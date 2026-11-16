import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../models/device.dart';
import 'oui_vendors.dart';

/// Infos sur le réseau auquel on est connecté.
class NetworkContext {
  final String selfIp;
  final String? gatewayIp;
  final String? wifiName;
  final String prefix; // ex. "192.168.1."

  NetworkContext({
    required this.selfIp,
    required this.gatewayIp,
    required this.wifiName,
    required this.prefix,
  });
}

class NetworkScanner {
  /// Ports testés pour savoir si un appareil est présent.
  /// Une connexion acceptée OU refusée prouve que l'appareil existe.
  static const List<int> probePorts = [
    80, 443, 53, 22, 445, 139, 62078, 8080, 554, 8008, 9100, 631, 5000, 7000,
  ];

  static const Duration probeTimeout = Duration(milliseconds: 600);
  static const int parallelHosts = 32;

  final NetworkInfo _info = NetworkInfo();

  /// Trouve notre IP, la passerelle et le préfixe du réseau.
  Future<NetworkContext?> detectNetwork() async {
    String? ip;
    String? gateway;
    String? ssid;
    try {
      ip = await _info.getWifiIP();
      gateway = await _info.getWifiGatewayIP();
      ssid = await _info.getWifiName();
    } catch (_) {
      // Certaines plateformes (Linux, Windows filaire) ne répondent pas.
    }

    ip ??= await _firstPrivateIPv4();
    if (ip == null) return null;

    final parts = ip.split('.');
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    gateway ??= '${prefix}1';

    return NetworkContext(
      selfIp: ip,
      gatewayIp: gateway,
      wifiName: ssid?.replaceAll('"', ''),
      prefix: prefix,
    );
  }

  Future<String?> _firstPrivateIPv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final a = addr.address;
        if (a.startsWith('192.168.') ||
            a.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(a)) {
          return a;
        }
      }
    }
    return null;
  }

  /// Scanne tout le sous-réseau /24.
  /// [onProgress] reçoit une valeur entre 0 et 1.
  /// [onFound] est appelé dès qu'un appareil répond.
  Future<List<Device>> scan(
    NetworkContext net, {
    void Function(double progress)? onProgress,
    void Function(Device device)? onFound,
  }) async {
    final found = <String, Device>{};
    final hosts = List.generate(254, (i) => '${net.prefix}${i + 1}');
    var done = 0;

    for (var i = 0; i < hosts.length; i += parallelHosts) {
      final batch = hosts.skip(i).take(parallelHosts);
      await Future.wait(batch.map((host) async {
        final ports = await _probeHost(host);
        final isSelf = host == net.selfIp;
        if (ports != null || isSelf) {
          final d = Device(
            ip: host,
            openPorts: ports ?? [],
            isGateway: host == net.gatewayIp,
            isSelf: isSelf,
          );
          found[host] = d;
          onFound?.call(d);
        }
        done++;
        onProgress?.call(done / hosts.length);
      }));
    }

    // Une fois les appareils « réveillés », la table ARP de l'OS est remplie :
    // on y lit les adresses MAC (possible sur PC seulement).
    final arp = await readArpTable();
    for (final entry in arp.entries) {
      if (!entry.key.startsWith(net.prefix)) continue;
      final d = found.putIfAbsent(
        entry.key,
        () => Device(ip: entry.key, isGateway: entry.key == net.gatewayIp),
      );
      d.mac = entry.value;
      d.vendor = lookupVendor(entry.value);
    }

    // Noms d'hôte (DNS inverse) en parallèle, avec délai court.
    await Future.wait(found.values.map((d) async {
      d.hostname = await _reverseLookup(d.ip);
    }));

    final list = found.values.toList()
      ..sort((a, b) => _lastOctet(a.ip).compareTo(_lastOctet(b.ip)));
    return list;
  }

  int _lastOctet(String ip) => int.tryParse(ip.split('.').last) ?? 0;

  /// Renvoie la liste des ports ouverts si l'hôte existe, sinon null.
  Future<List<int>?> _probeHost(String host) async {
    var alive = false;
    final open = <int>[];

    await Future.wait(probePorts.map((port) async {
      try {
        final s = await Socket.connect(host, port, timeout: probeTimeout);
        s.destroy();
        alive = true;
        open.add(port);
      } on SocketException catch (e) {
        if (_isConnectionRefused(e)) alive = true;
      } catch (_) {}
    }));

    return alive ? (open..sort()) : null;
  }

  /// « Connexion refusée » = l'appareil existe mais le port est fermé.
  bool _isConnectionRefused(SocketException e) {
    final code = e.osError?.errorCode;
    // 111 = Linux/Android, 61 = macOS/iOS, 10061 = Windows
    return code == 111 || code == 61 || code == 10061;
  }

  Future<String?> _reverseLookup(String ip) async {
    try {
      final addr = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(seconds: 2));
      return addr.host == ip ? null : addr.host;
    } catch (_) {
      return null;
    }
  }

  /// Lit la table ARP du système : IP -> MAC.
  /// Fonctionne sur Windows, macOS et Linux.
  /// Android 10+ et iOS l'interdisent : on renvoie alors une table vide.
  Future<Map<String, String>> readArpTable() async {
    final table = <String, String>{};
    try {
      if (Platform.isLinux) {
        final lines = await File('/proc/net/arp').readAsLines();
        for (final line in lines.skip(1)) {
          final cols = line.split(RegExp(r'\s+'));
          if (cols.length >= 4 && cols[3] != '00:00:00:00:00:00') {
            table[cols[0]] = _normalizeMac(cols[3]);
          }
        }
      } else if (Platform.isWindows || Platform.isMacOS) {
        final res = await Process.run('arp', ['-a']);
        final out = res.stdout.toString();
        final re = RegExp(
          r'(\d{1,3}(?:\.\d{1,3}){3})\)?\s+(?:at\s+)?([0-9a-fA-F]{1,2}(?:[:-][0-9a-fA-F]{1,2}){5})',
        );
        for (final m in re.allMatches(out)) {
          table[m.group(1)!] = _normalizeMac(m.group(2)!);
        }
      }
    } catch (_) {
      // Pas d'accès : on continue sans MAC.
    }
    table.removeWhere((_, mac) => mac == 'FF:FF:FF:FF:FF:FF');
    return table;
  }

  String _normalizeMac(String raw) => raw
      .replaceAll('-', ':')
      .split(':')
      .map((p) => p.padLeft(2, '0').toUpperCase())
      .join(':');
}
