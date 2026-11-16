import 'package:flutter/material.dart';

import '../models/device.dart';
import '../routers/guided_connector.dart';
import '../routers/router_connector.dart';
import '../services/device_store.dart';
import '../services/network_scanner.dart';

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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _store.load();
    final cfg = await _store.loadRouterConfig();
    _brandId = cfg['brand'] ?? 'autre';
    await _scan();
  }

  RouterBrandInfo get _brand =>
      knownBrands.firstWhere((b) => b.id == _brandId, orElse: () => knownBrands.last);

  RouterConnector get _connector =>
      GuidedConnector(_brand, gatewayIp: _net?.gatewayIp);

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

    final newOnes = await _store.recordScan(results);
    if (!mounted) return;
    setState(() {
      _devices = results;
      _scanning = false;
    });

    final intruders = results
        .where((d) => _store.get(d.id)?.status == DeviceStatus.bloque)
        .toList();

    if (newOnes.isNotEmpty) {
      _showAlert(
        '${newOnes.length} nouvel(s) appareil(s)',
        newOnes.map((d) => '• ${d.displayName} (${d.ip})').join('\n'),
      );
    } else if (intruders.isNotEmpty) {
      _showAlert(
        'Appareil bloqué toujours présent',
        'Vérifie que la MAC a bien été enregistrée dans la liste noire du routeur :\n'
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
            tooltip: 'Mon routeur',
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
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _devices.length,
              itemBuilder: (_, i) => _deviceTile(_devices[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme) {
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

  Widget _deviceTile(Device d) {
    final known = _store.get(d.id);
    final status = known?.status;
    final name = (known != null && known.label.isNotEmpty) ? known.label : d.displayName;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor(status).withValues(alpha: 0.15),
        child: Icon(_iconFor(d), color: _statusColor(status)),
      ),
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
            if (known != null) _info('Vu pour la 1re fois', _fmt(known.firstSeen)),
            const SizedBox(height: 8),
            TextField(
              controller: macCtrl,
              decoration: InputDecoration(
                labelText: 'Adresse MAC',
                helperText: d.mac == null
                    ? 'Sur téléphone, la MAC n\'est pas lisible : copie-la depuis la liste « appareils connectés » de ton routeur.'
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
    if (!_validMac(mac)) {
      _showAlert('Adresse MAC manquante',
          'Pour bloquer définitivement, il faut l\'adresse MAC (ex. A4:83:E7:12:34:56).\n\n'
              'Ouvre la page de ton routeur, menu « Appareils connectés », repère l\'IP ${d.ip} et copie sa MAC.');
      return;
    }
    if (name.isNotEmpty) await _store.rename(d.id, name);
    final res = await _connector.block(mac.replaceAll('-', ':'), name: name);
    if (!mounted) return;

    if (res.done) {
      await _store.setStatus(d.id, DeviceStatus.bloque);
      setState(() {});
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Termine le blocage dans ton routeur'),
        content: Text(res.message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('C\'est fait')),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.setStatus(d.id, DeviceStatus.bloque);
      setState(() {});
    }
  }

  Future<void> _unblock(Device d, String mac) async {
    final res = await _connector.unblock(mac);
    if (!mounted) return;
    if (!res.done) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Débloquer dans ton routeur'),
          content: Text(res.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('C\'est fait')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _store.setStatus(d.id, DeviceStatus.connu);
    setState(() {});
  }

  void _openRouterSettings() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Mon routeur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adresse : ${_net?.gatewayIp ?? 'inconnue'}'),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: _brandId,
                items: knownBrands
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: (v) => setLocal(() => _brandId = v ?? 'autre'),
              ),
              const SizedBox(height: 8),
              Text(
                'Mode actuel : guidé. Le blocage automatique par marque arrive en version 2.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await _store.saveRouterConfig({'brand': _brandId});
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
