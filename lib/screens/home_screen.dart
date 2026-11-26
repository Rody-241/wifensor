import 'package:flutter/material.dart';

import '../models/device.dart';
import '../routers/box_guides.dart';
import '../services/box_detector.dart';
import '../services/device_store.dart';
import '../services/network_scanner.dart';
import 'box_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scanner = NetworkScanner();
  final _store = DeviceStore();

  NetworkContext? _net;
  List<Device> _devices = [];
  bool _scanning = false;
  double _progress = 0;
  String? _error;
  String _brandId = 'autre';
  bool _brandAuto = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _store.load();
    final cfg = await _store.loadRouterConfig();
    _brandId = cfg['brand'] ?? 'autre';
    _brandAuto = cfg['source'] == 'auto';
    final manual = cfg['source'] == 'manual';
    await _scan();
    if (!manual) await _detectBox();
  }

  /// Reconnaît la box tout seul (sauf si l'utilisateur l'a choisie à la main).
  Future<void> _detectBox() async {
    final ip = _net?.gatewayIp;
    if (ip == null) return;
    final found = await BoxDetector().detect(ip);
    if (found == null || !mounted) return;
    await _store.saveRouterConfig({'brand': found, 'source': 'auto'});
    setState(() {
      _brandId = found;
      _brandAuto = true;
    });
  }

  BoxGuide get _guide => guideById(_brandId);

  String get _gatewayIp => _net?.gatewayIp ?? _guide.defaultIp;

  /// Ouvre la page de la box dans l'appli, avec les étapes du guide.
  Future<T?> _openGuide<T>(GuideMode mode, Device d, String? mac) {
    final known = _store.get(d.id);
    final name = (known != null && known.label.isNotEmpty) ? known.label : d.displayName;
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => BoxGuideScreen(
          guide: _guide,
          gatewayIp: _gatewayIp,
          mode: mode,
          deviceIp: d.ip,
          deviceName: name,
          mac: mac,
        ),
      ),
    );
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _progress = 0;
      _error = null;
      _devices = [];
    });

    final net = await _scanner.detectNetwork();
    if (net == null) {
      setState(() {
        _scanning = false;
        _error = 'Aucun réseau Wi-Fi détecté. Connecte-toi au Wi-Fi puis réessaie.';
      });
      return;
    }
    _net = net;

    final results = await _scanner.scan(
      net,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      onFound: (d) {
        if (mounted) setState(() => _devices = [..._devices, d]);
      },
    );

    final firstScan = _store.isFirstRun;
    final newOnes = await _store.recordScan(results);
    if (!mounted) return;
    setState(() {
      _devices = results;
      _scanning = false;
    });

    // Un appareil « Bloqué » qui répond encore au scan n'est pas vraiment
    // bloqué par la box : on ne garde pas un faux statut, il redevient « Connu ».
    final intruders = results
        .where((d) => _store.get(d.id)?.status == DeviceStatus.bloque)
        .toList();
    for (final d in intruders) {
      await _store.setStatus(d.id, DeviceStatus.connu);
    }
    if (intruders.isNotEmpty && mounted) setState(() {});

    if (newOnes.isNotEmpty) {
      _showAlert(
        firstScan
            ? '${newOnes.length} appareil(s) à vérifier'
            : '${newOnes.length} nouvel(s) appareil(s)',
        '${firstScan ? 'Touche chacun : « Fiable » pour les tiens, « Bloquer » pour les intrus.\n\n' : ''}'
        '${newOnes.map((d) => '• ${d.displayName} (${d.ip})').join('\n')}',
      );
    } else if (intruders.isNotEmpty) {
      _showAlert(
        'Le blocage n\'a pas été appliqué par la box',
        'Ces appareils sont encore connectés, donc ils ne sont pas bloqués. '
            'Leur adresse MAC n\'est sans doute pas dans la liste de blocage de ta box. '
            'Touche-les et refais « Bloquer » jusqu\'à « Sauvegarder » :\n'
            '${intruders.map((d) => '• ${d.ip}').join('\n')}',
      );
    }
  }

  void _showAlert(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Color _statusColor(DeviceStatus? s) => switch (s) {
        DeviceStatus.nouveau => Colors.orange,
        DeviceStatus.fiable => Colors.green,
        DeviceStatus.bloque => Colors.red,
        _ => Colors.blueGrey,
      };

  String _statusLabel(DeviceStatus? s) => switch (s) {
        DeviceStatus.nouveau => 'Nouveau',
        DeviceStatus.fiable => 'Fiable',
        DeviceStatus.bloque => 'Bloqué',
        _ => 'Connu',
      };

  IconData _iconFor(Device d) {
    if (d.isGateway) return Icons.router;
    if (d.isSelf) return Icons.person_pin_circle;
    final t = d.typeGuess;
    if (t.contains('iPhone')) return Icons.phone_iphone;
    if (t.contains('Imprimante')) return Icons.print;
    if (t.contains('Caméra')) return Icons.videocam;
    if (t.contains('TV')) return Icons.tv;
    if (t.contains('Ordinateur')) return Icons.computer;
    return Icons.devices_other;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wifensor'),
        actions: [
          IconButton(
            tooltip: 'Ma box',
            icon: const Icon(Icons.settings_input_antenna),
            onPressed: _openRouterSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _scan,
        icon: _scanning
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.radar),
        label: Text(_scanning ? 'Scan ${(_progress * 100).round()} %' : 'Scanner'),
      ),
      body: Column(
        children: [
          if (_scanning) LinearProgressIndicator(value: _progress),
          _header(theme),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                ..._devices.map(_deviceTile),
                if (!_scanning) ..._recentDevices.map(_deviceTile),
                ..._blockedSection(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme) {
    // Les appareils grisés (vus récemment mais sans réponse) ne comptent pas.
    final count = _devices.length;
    final newCount = _devices
        .where((d) => _store.get(d.id)?.status == DeviceStatus.nouveau)
        .length;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text('$count', style: theme.textTheme.displaySmall),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('appareil(s) connecté(s)', style: theme.textTheme.titleMedium),
                  Text(
                    [
                      if (_net?.wifiName != null) 'Wi-Fi : ${_net!.wifiName}',
                      if (_net != null) 'Routeur : ${_net!.gatewayIp}',
                    ].join('  ·  '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (newCount > 0)
              Chip(
                label: Text('$newCount nouveau(x)'),
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
              ),
          ],
        ),
      ),
    );
  }

  /// Un téléphone en veille peut ne pas répondre à un scan. Un appareil vu
  /// il y a moins de 15 minutes reste donc affiché (en grisé) au lieu de
  /// disparaître, pour que la liste ne change pas à chaque scan.
  static const Duration _recentWindow = Duration(minutes: 15);

  List<Device> get _recentDevices {
    final ids = _devices.map((d) => d.id).toSet();
    final ips = _devices.map((d) => d.ip).toSet();
    final now = DateTime.now();
    final list = _store.all.values
        .where((k) =>
            k.status != DeviceStatus.bloque &&
            !ids.contains(k.id) &&
            k.lastIp != null &&
            !ips.contains(k.lastIp) &&
            now.difference(k.lastSeen) < _recentWindow)
        .toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return list
        .map((k) => Device(
              ip: k.lastIp!,
              mac: k.id.startsWith('ip:') ? null : k.mac,
              hostname: k.label,
            ))
        .toList();
  }

  bool _isPresent(Device d) => _devices.any((x) => x.id == d.id);

  /// Appareils bloqués qui ne sont plus connectés : ils n'apparaissent pas
  /// dans le scan, donc on les garde visibles ici pour pouvoir les débloquer.
  List<KnownDevice> get _blockedAway {
    final present = _devices.map((d) => d.id).toSet();
    return _store.all.values
        .where((k) => k.status == DeviceStatus.bloque && !present.contains(k.id))
        .toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  }

  List<Widget> _blockedSection(ThemeData theme) {
    final list = _blockedAway;
    if (list.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          'Appareils bloqués (${list.length})',
          style: theme.textTheme.titleSmall?.copyWith(color: Colors.red),
        ),
      ),
      ...list.map((k) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.15),
              child: const Icon(Icons.block, color: Colors.red),
            ),
            title: Text(k.label.isNotEmpty ? k.label : 'Appareil bloqué'),
            subtitle: Text([
              if (k.mac != null) k.mac!,
              'N\'a plus accès au Wi-Fi',
            ].join(' · ')),
            trailing: TextButton(
              onPressed: () => _unblockKnown(k),
              child: const Text('Débloquer'),
            ),
          )),
    ];
  }

  Future<void> _unblockKnown(KnownDevice k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Débloquer ${k.label.isNotEmpty ? k.label : 'cet appareil'} ?'),
        content: const Text(
            'Wifensor va ouvrir la page de ta box pour retirer cet appareil de la liste de blocage. '
            'Il pourra ensuite se reconnecter à ton Wi-Fi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final d = Device(ip: k.lastIp ?? '', mac: k.mac, hostname: k.label);
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BoxGuideScreen(
          guide: _guide,
          gatewayIp: _gatewayIp,
          mode: GuideMode.debloquer,
          deviceIp: d.ip,
          deviceName: k.label.isNotEmpty ? k.label : 'cet appareil',
          mac: k.mac,
        ),
      ),
    );
    if (done != true || !mounted) return;
    await _store.setStatus(k.id, DeviceStatus.connu);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Débloqué : il peut se reconnecter.')),
    );
  }

  Widget _deviceTile(Device d) {
    final known = _store.get(d.id);
    final status = known?.status;
    final name = (known != null && known.label.isNotEmpty) ? known.label : d.displayName;
    final present = _scanning || _isPresent(d);
    return ListTile(
      leading: Opacity(
        opacity: present ? 1 : 0.45,
        child: CircleAvatar(
        backgroundColor: _statusColor(status).withValues(alpha: 0.15),
        child: Icon(_iconFor(d), color: _statusColor(status)),
      )),
      title: Text(name),
      subtitle: Text([
        d.ip,
        if (d.mac != null) d.mac!,
        if (d.vendor != null) d.vendor!,
        if (d.vendor == null && d.hasRandomMac) 'MAC privée',
      ].join(' · ')),
      trailing: Text(
        _statusLabel(status),
        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w600),
      ),
      onTap: () => _openDetails(d),
    );
  }

  void _openDetails(Device d) {
    final known = _store.get(d.id);
    final macCtrl = TextEditingController(text: d.mac ?? known?.mac ?? '');
    final nameCtrl = TextEditingController(text: known?.label ?? d.displayName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom de l\'appareil'),
            ),
            const SizedBox(height: 12),
            _info('Adresse IP', d.ip),
            _info('Fabricant', d.vendor ?? (d.hasRandomMac ? 'Inconnu (MAC privée)' : 'Inconnu')),
            _info('Type probable', d.typeGuess),
            _info('Ports ouverts', d.openPorts.isEmpty ? 'Aucun' : d.openPorts.join(', ')),
            if (known != null) _info('Première connexion', _fmt(known.firstSeen)),
            const SizedBox(height: 8),
            TextField(
              controller: macCtrl,
              decoration: InputDecoration(
                labelText: 'Adresse MAC',
                helperText: d.mac == null
                    ? 'Pas besoin de la connaître : si elle manque, Wifensor t\'aidera à la trouver dans ta box.'
                    : null,
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            if (!d.isSelf && !d.isGateway) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.block),
                label: const Text('Bloquer cet appareil'),
                onPressed: () async {
                  final mac = macCtrl.text.trim().toUpperCase();
                  Navigator.pop(ctx);
                  await _block(d, mac, nameCtrl.text.trim());
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Fiable'),
                    onPressed: () async {
                      await _store.rename(d.id, nameCtrl.text.trim());
                      await _store.setStatus(d.id, DeviceStatus.fiable);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (known?.status == DeviceStatus.bloque)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Débloquer'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _unblock(d, macCtrl.text.trim().toUpperCase());
                      },
                    ),
                  ),
              ]),
            ] else
              FilledButton(
                onPressed: () async {
                  await _store.rename(d.id, nameCtrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('Enregistrer'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  String _fmt(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool _validMac(String mac) =>
      RegExp(r'^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$').hasMatch(mac);

  Future<void> _block(Device d, String mac, String name) async {
    if (name.isNotEmpty) await _store.rename(d.id, name);
    var cleanMac = mac.replaceAll('-', ':');

    // 1. Pas d'adresse MAC ? On ouvre la box pour aller la chercher.
    if (!_validMac(cleanMac)) {
      cleanMac = _store.get(d.id)?.mac ?? '';
    }
    if (!_validMac(cleanMac)) {
      final found = await _openGuide<String>(GuideMode.trouverMac, d, null);
      if (found == null || !mounted) return;
      cleanMac = found;
    }
    await _store.setMac(d.id, cleanMac);
    if (!mounted) return;

    // 2. On ouvre la box sur le guide de blocage.
    final done = await _openGuide<bool>(GuideMode.bloquer, d, cleanMac);
    if (done != true || !mounted) return;

    await _store.setStatus(d.id, DeviceStatus.bloque);
    setState(() {});
    _showAlert(
      'Appareil bloqué',
      'La box refuse maintenant l\'accès à cet appareil. '
          'Au prochain scan, Wifensor vérifiera qu\'il a bien disparu.',
    );
  }

  Future<void> _unblock(Device d, String mac) async {
    final known = _store.get(d.id);
    final cleanMac = _validMac(mac) ? mac.replaceAll('-', ':') : known?.mac;
    final done = await _openGuide<bool>(GuideMode.debloquer, d, cleanMac);
    if (done != true || !mounted) return;
    await _store.setStatus(d.id, DeviceStatus.connu);
    setState(() {});
  }

  void _openRouterSettings() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ma box'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adresse : ${_net?.gatewayIp ?? 'inconnue'}'),
              if (_brandAuto)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Reconnue automatiquement. Change-la si ce n\'est pas la bonne.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: _brandId,
                items: boxGuides
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: (v) => setLocal(() => _brandId = v ?? 'autre'),
              ),
              const SizedBox(height: 8),
              Text(
                'Wifensor ouvre la page de ta box et te guide pas à pas pour bloquer ou débloquer un appareil.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await _store.saveRouterConfig({'brand': _brandId, 'source': 'manual'});
                _brandAuto = false;
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
