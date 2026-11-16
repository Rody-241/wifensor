import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';

/// Mémorise les appareils déjà vus, fiables ou bloqués.
class DeviceStore {
  static const _key = 'known_devices_v1';
  static const _routerKey = 'router_config_v1';

  final Map<String, KnownDevice> _devices = {};

  Map<String, KnownDevice> get all => Map.unmodifiable(_devices);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    _devices.clear();
    for (final item in list) {
      final k = KnownDevice.fromJson(item as Map<String, dynamic>);
      _devices[k.id] = k;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_devices.values.map((d) => d.toJson()).toList()),
    );
  }

  /// Le premier scan enregistre tout comme « connu » (pas d'alerte inutile).
  bool get isFirstRun => _devices.isEmpty;

  /// Met à jour la mémoire après un scan et renvoie les nouveaux appareils.
  Future<List<Device>> recordScan(List<Device> scanned) async {
    final firstRun = isFirstRun;
    final now = DateTime.now();
    final newOnes = <Device>[];

    for (final d in scanned) {
      final existing = _devices[d.id];
      if (existing == null) {
        _devices[d.id] = KnownDevice(
          id: d.id,
          label: d.displayName,
          status: (firstRun || d.isSelf || d.isGateway)
              ? DeviceStatus.connu
              : DeviceStatus.nouveau,
          lastIp: d.ip,
          mac: d.mac,
          firstSeen: now,
          lastSeen: now,
        );
        if (!firstRun && !d.isSelf && !d.isGateway) newOnes.add(d);
      } else {
        existing.lastSeen = now;
        existing.lastIp = d.ip;
        existing.mac ??= d.mac;
      }
    }
    await _save();
    return newOnes;
  }

  KnownDevice? get(String id) => _devices[id];

  Future<void> setStatus(String id, DeviceStatus status) async {
    final d = _devices[id];
    if (d == null) return;
    d.status = status;
    await _save();
  }

  Future<void> rename(String id, String label) async {
    final d = _devices[id];
    if (d == null) return;
    d.label = label;
    await _save();
  }

  Future<void> forget(String id) async {
    _devices.remove(id);
    await _save();
  }

  // --- Configuration du routeur ---

  Future<Map<String, String>> loadRouterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_routerKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveRouterConfig(Map<String, String> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routerKey, jsonEncode(config));
  }
}
