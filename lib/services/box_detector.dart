import 'dart:convert';
import 'dart:io';

/// Reconnaît la marque de la box en lisant sa page d'accueil
/// (titre, logos, noms de fichiers, en-têtes). Renvoie l'identifiant d'un
/// guide de box_guides.dart, ou null si la marque n'est pas reconnue.
class BoxDetector {
  static const _patterns = <String, List<String>>{
    'airtel_zlt': ['airtel', 'zlt'],
    'canalbox': ['canalbox', 'canal+', 'gva'],
    'tplink': ['tp-link', 'tplink', 'tp link'],
    'huawei': ['huawei', 'hilink'],
    'zte': ['zte'],
    'tenda': ['tenda'],
  };

  Future<String?> detect(String gatewayIp) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final text = StringBuffer();
      for (final path in const ['/', '/index.html', '/login.html']) {
        try {
          final req = await client
              .getUrl(Uri.parse('http://$gatewayIp$path'))
              .timeout(const Duration(seconds: 4));
          req.followRedirects = true;
          final res = await req.close().timeout(const Duration(seconds: 5));
          res.headers.forEach((k, v) => text.write('$k: ${v.join(',')}\n'));
          final body = await res
              .transform(const Utf8Decoder(allowMalformed: true))
              .take(20)
              .join()
              .timeout(const Duration(seconds: 5));
          text.write(body);
          final found = _match(text.toString());
          if (found != null) return found;
        } catch (_) {
          // On essaie l'adresse suivante.
        }
      }
      return _match(text.toString());
    } finally {
      client.close(force: true);
    }
  }

  String? _match(String raw) {
    final t = raw.toLowerCase();
    for (final e in _patterns.entries) {
      for (final p in e.value) {
        final re = RegExp('(^|[^a-z])${RegExp.escape(p)}([^a-z]|\$)');
        if (re.hasMatch(t)) return e.key;
      }
    }
    return null;
  }
}
