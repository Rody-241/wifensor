import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'router_connector.dart';

/// Mode guidé : marche avec n'importe quelle box.
/// L'appli copie l'adresse MAC et ouvre la page d'administration du routeur ;
/// l'utilisateur colle la MAC dans la liste noire.
class GuidedConnector implements RouterConnector {
  final RouterBrandInfo info;
  String gatewayUrl;

  GuidedConnector(this.info, {String? gatewayIp})
      : gatewayUrl = gatewayIp != null ? 'http://$gatewayIp' : info.defaultUrl;

  @override
  String get brand => info.name;

  @override
  bool get isAutomatic => false;

  @override
  Future<bool> login(String gatewayIp, String username, String password) async {
    gatewayUrl = 'http://$gatewayIp';
    return true;
  }

  @override
  Future<Map<String, String>> listClients() async => {};

  @override
  Future<BlockResult> block(String mac, {String? name}) async {
    await Clipboard.setData(ClipboardData(text: mac));
    final opened = await launchUrl(
      Uri.parse(gatewayUrl),
      mode: LaunchMode.externalApplication,
    );
    return BlockResult(
      false,
      opened
          ? 'Adresse MAC $mac copiée. La page du routeur s\'ouvre : ${info.menuHint} Colle la MAC et enregistre.'
          : 'Adresse MAC $mac copiée. Ouvre $gatewayUrl dans ton navigateur. ${info.menuHint}',
    );
  }

  @override
  Future<BlockResult> unblock(String mac) async {
    await Clipboard.setData(ClipboardData(text: mac));
    await launchUrl(Uri.parse(gatewayUrl), mode: LaunchMode.externalApplication);
    return BlockResult(
      false,
      'Adresse MAC $mac copiée. Dans la page du routeur, retire-la de la liste noire.',
    );
  }
}
