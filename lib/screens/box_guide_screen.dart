import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../routers/box_guides.dart';

/// Ce que l'utilisateur vient faire dans la page de sa box.
enum GuideMode { trouverMac, bloquer, debloquer }

/// Ouvre la page d'administration de la box DANS l'appli, avec en haut un
/// bandeau qui affiche les étapes une par une.
///
/// Résultat renvoyé par Navigator.pop :
/// - mode trouverMac : l'adresse MAC saisie (String), ou null si annulé ;
/// - modes bloquer / debloquer : true si l'utilisateur confirme « C'est fait ».
class BoxGuideScreen extends StatefulWidget {
  final BoxGuide guide;
  final String gatewayIp;
  final GuideMode mode;
  final String deviceIp;
  final String deviceName;
  final String? mac;

  const BoxGuideScreen({
    super.key,
    required this.guide,
    required this.gatewayIp,
    required this.mode,
    required this.deviceIp,
    required this.deviceName,
    this.mac,
  });

  @override
  State<BoxGuideScreen> createState() => _BoxGuideScreenState();
}

class _BoxGuideScreenState extends State<BoxGuideScreen> {
  WebViewController? _web;
  final _macCtrl = TextEditingController();
  int _step = 0;

  /// Où en est l'utilisateur dans la page de la box, d'après le script :
  /// login, home, filter (page de filtrage), adding (champ MAC visible),
  /// listed (l'adresse MAC apparaît dans la liste de filtrage).
  String _pageState = '';
  bool _macListed = false;
  int _progress = 0;
  String? _loadError;
  String? _macError;

  bool get _webSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  String get _url => 'http://${widget.gatewayIp}';

  List<String> get _steps => switch (widget.mode) {
        GuideMode.trouverMac => widget.guide.findMacSteps,
        GuideMode.bloquer => widget.guide.blockSteps,
        GuideMode.debloquer => widget.guide.unblockSteps,
      };

  String get _title => switch (widget.mode) {
        GuideMode.trouverMac => 'Trouver l\'adresse MAC',
        GuideMode.bloquer => 'Bloquer ${widget.deviceName}',
        GuideMode.debloquer => 'Débloquer ${widget.deviceName}',
      };

  @override
  void initState() {
    super.initState();
    _macCtrl.text = widget.mac ?? '';
    if (_webSupported) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('Wifensor', onMessageReceived: _onMessage)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => _injectHelper(),
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loadError = null);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) {
              if (mounted) setState(() => _loadError = e.description);
            }
          },
        ))
        ..loadRequest(Uri.parse(_url));
    }
  }

  /// Script injecté dans la page de la box :
  /// - mode « trouver » : repère la ligne qui contient l'IP de l'appareil et
  ///   renvoie l'adresse MAC trouvée sur cette ligne ; toucher une adresse
  ///   MAC dans la page la renvoie aussi ;
  /// - modes « bloquer / débloquer » : quand on touche un champ dont le nom
  ///   parle de MAC, il est rempli tout seul.
  String get _helperJs {
    // Dans la chaîne JS, « \\. » donne « \. » : un vrai point dans l'expression.
    final ip = widget.deviceIp.replaceAll('.', r'\\.');
    final mac = (widget.mac ?? '').replaceAll("'", '');
    final find = widget.mode == GuideMode.trouverMac;
    return '''
(function(){
  if (window.__wifensor) return; window.__wifensor = 1;
  var reMac = /([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/;
  var reIp = new RegExp('(^|[^0-9])$ip([^0-9]|\$)');
  function post(m){ try { Wifensor.postMessage(m); } catch(e){} }
  function send(m){ post('mac:' + m.toUpperCase().replace(/-/g, ':')); }
  function norm(t){ return (t || '').toUpperCase().replace(/-/g, ':'); }
  function visible(el){ return el && el.offsetParent !== null; }
  var wanted = '$mac'.toUpperCase();
  var reFilter = /filtr[a-z]* *(par )?(adresse )?mac|mac filter|liste de blocage|liste noire|blacklist|block ?list|contr[oô]le d.acc[eè]s|access control/i;
  var lastState = '';
  setInterval(function(){
    var body = document.body ? (document.body.innerText || '') : '';
    var pwd = Array.prototype.some.call(document.querySelectorAll('input[type=password]'), visible);
    var state = 'home';
    if (pwd && !reFilter.test(body)) state = 'login';
    else if (reFilter.test(body)) {
      state = 'filter';
      var macInput = Array.prototype.some.call(document.querySelectorAll('input'), function(f){
        if (!visible(f) || f.type === 'password') return false;
        var hint = [f.name, f.id, f.placeholder, f.getAttribute('aria-label')].join(' ');
        var lab = f.closest('label, tr, div');
        return /mac/i.test(hint) || (lab && /mac/i.test((lab.innerText || '').slice(0, 80)));
      });
      if (macInput) state = 'adding';
      if (wanted && norm(body).indexOf(wanted) >= 0) state = 'listed';
    }
    if (state !== lastState) { lastState = state; post('state:' + state); }
  }, 1200);
  if ($find) {
    var last = '';
    setInterval(function(){
      var rows = document.querySelectorAll('tr, li, [role=row], [class*=row], [class*=item]');
      for (var i = 0; i < rows.length; i++) {
        var t = rows[i].innerText || '';
        if (t.length < 400 && reIp.test(t)) {
          var m = t.match(reMac);
          if (m && m[0] !== last) { last = m[0]; send(m[0]); }
          return;
        }
      }
    }, 1500);
    document.addEventListener('click', function(e){
      var n = e.target;
      for (var k = 0; k < 4 && n; k++, n = n.parentElement) {
        var t = n.innerText || '';
        if (t.length < 200) { var m = t.match(reMac); if (m) { send(m[0]); return; } }
      }
    }, true);
  } else if ('$mac') {
    document.addEventListener('focusin', function(e){
      var f = e.target;
      if (!f || f.tagName !== 'INPUT' || f.value) return;
      var hint = [f.name, f.id, f.placeholder, f.getAttribute('aria-label')].join(' ');
      var lab = f.closest('label, tr, div');
      if (!/mac/i.test(hint) && !(lab && /mac/i.test((lab.innerText || '').slice(0, 80)))) return;
      f.value = '$mac';
      f.dispatchEvent(new Event('input', { bubbles: true }));
      f.dispatchEvent(new Event('change', { bubbles: true }));
    }, true);
  }
})();
''';
  }

  Future<void> _injectHelper() async {
    try {
      await _web?.runJavaScript(_helperJs);
    } catch (_) {
      // La page ne permet pas le script : l'utilisateur tape l'adresse lui-même.
    }
  }

  void _onMessage(JavaScriptMessage msg) {
    final m = msg.message.trim();
    if (m.startsWith('state:')) {
      _onPageState(m.substring(6));
    } else if (m.startsWith('mac:')) {
      _onMacFromPage(m.substring(4));
    }
  }

  /// Fait avancer le bandeau tout seul selon la page de la box.
  void _onPageState(String state) {
    if (!mounted) return;
    final last = _steps.length - 1;
    int? step;
    switch (widget.mode) {
      case GuideMode.trouverMac:
        step = switch (state) { 'login' => 0, 'home' => 1, _ => null };
      case GuideMode.bloquer:
        step = switch (state) {
          'login' => 0,
          'home' => 1,
          'filter' => 2,
          'adding' => 3,
          'listed' => last,
          _ => null,
        };
      case GuideMode.debloquer:
        step = switch (state) {
          'login' => 0,
          'home' => 1,
          'filter' || 'adding' || 'listed' => last,
          _ => null,
        };
    }
    setState(() {
      _pageState = state;
      if (state == 'listed') _macListed = true;
      if (state == 'filter' || state == 'adding') _macListed = false;
      if (step != null) _step = step.clamp(0, last).toInt();
    });
  }

  /// Avant d'accepter « C'est fait », on vérifie dans la page de la box.
  Future<void> _confirmDone() async {
    final blocking = widget.mode == GuideMode.bloquer;
    final onFilterPage = _pageState == 'filter' || _pageState == 'adding' || _pageState == 'listed';
    final ok = blocking ? _macListed : (onFilterPage && !_macListed);
    if (ok || _web == null) {
      Navigator.pop(context, true);
      return;
    }
    final force = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        title: Text(blocking ? 'Pas encore bloqué' : 'Pas encore débloqué'),
        content: Text(blocking
            ? 'Wifensor ne voit pas l\'adresse ${widget.mac ?? ''} dans la liste de blocage de ta box.\n\n'
                'Ouvre la liste de blocage, touche « Ajouter », puis « Sauvegarder ». '
                'Tant que ce n\'est pas fait, l\'appareil garde l\'accès au Wi-Fi.'
            : 'Ouvre la liste de blocage de ta box et vérifie que l\'adresse ${widget.mac ?? ''} '
                'n\'y est plus, puis touche « Sauvegarder ».'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('C\'est fait quand même'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Je termine'),
          ),
        ],
      ),
    );
    if (force == true && mounted) Navigator.pop(context, true);
  }

  void _onMacFromPage(String raw) {
    if (!mounted || widget.mode != GuideMode.trouverMac) return;
    final mac = raw.trim().toUpperCase();
    if (mac == _macCtrl.text) return;
    setState(() {
      _macCtrl.text = mac;
      _macError = null;
      _step = _steps.length - 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adresse MAC trouvée : $mac'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _macCtrl.dispose();
    super.dispose();
  }

  String _fill(String s) => s
      .replaceAll('{ip}', widget.deviceIp)
      .replaceAll('{mac}', widget.mac ?? 'de l\'appareil');

  Future<void> _openInBrowser() async {
    await launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication);
  }

  Future<void> _copyMac() async {
    final mac = widget.mac;
    if (mac == null) return;
    await Clipboard.setData(ClipboardData(text: mac));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adresse MAC copiée : $mac')),
    );
  }

  void _validateMac() {
    final mac = _macCtrl.text.trim().toUpperCase().replaceAll('-', ':');
    if (!RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(mac)) {
      setState(() => _macError =
          'Format attendu : 6 paires séparées par « : », par exemple A4:83:E7:12:34:56');
      return;
    }
    Navigator.pop(context, mac);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_web != null)
            IconButton(
              tooltip: 'Recharger',
              icon: const Icon(Icons.refresh),
              onPressed: () => _web!.reload(),
            ),
          IconButton(
            tooltip: 'Ouvrir dans le navigateur',
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: Column(
        children: [
          _banner(context),
          if (_web != null && _progress < 100)
            LinearProgressIndicator(value: _progress / 100),
          Expanded(child: _page(context)),
        ],
      ),
      bottomNavigationBar: SafeArea(child: _bottom(context)),
    );
  }

  Widget _banner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _steps.length;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primary,
              child: Text('${_step + 1}',
                  style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Étape ${_step + 1} sur $total',
                      style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
                  const SizedBox(height: 2),
                  Text(_fill(_steps[_step]),
                      style: TextStyle(fontSize: 15, color: cs.onPrimaryContainer)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Étape précédente',
              onPressed: _step > 0 ? () => setState(() => _step--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Étape suivante',
              onPressed: _step < total - 1 ? () => setState(() => _step++) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    if (_web == null) {
      return _message(
        context,
        'Sur cet appareil, la page de la box s\'ouvre dans ton navigateur.',
        'Ouvrir $_url',
        _openInBrowser,
      );
    }
    if (_loadError != null) {
      return _message(
        context,
        'La page de la box ne répond pas à l\'adresse $_url.\n\n'
        'Vérifie que tu es connecté au Wi-Fi de ta box, puis réessaie.',
        'Réessayer',
        () => _web!.loadRequest(Uri.parse(_url)),
      );
    }
    return WebViewWidget(controller: _web!);
  }

  Widget _message(BuildContext context, String text, String action, VoidCallback onTap) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.router, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    if (widget.mode == GuideMode.trouverMac) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _macCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Adresse MAC de ${widget.deviceIp}',
                  errorText: _macError,
                  errorMaxLines: 3,
                  border: const OutlineInputBorder(),
                  hintText: 'Se remplit toute seule depuis la page de la box',
                ),
                onChanged: (_) {
                  if (_macError != null) setState(() => _macError = null);
                },
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton(onPressed: _validateMac, child: const Text('Valider')),
            ),
          ],
        ),
      );
    }

    final blocking = widget.mode == GuideMode.bloquer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          if (widget.mac != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyMac,
                icon: const Icon(Icons.copy),
                label: Text(widget.mac!, overflow: TextOverflow.ellipsis),
              ),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: blocking ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            onPressed: _confirmDone,
            icon: Icon(blocking ? Icons.block : Icons.lock_open),
            label: const Text('C\'est fait'),
          ),
        ],
      ),
    );
  }
}
