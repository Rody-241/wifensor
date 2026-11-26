import 'package:flutter/material.dart';

import '../models/device.dart';

/// Couleurs Wifensor, tirées du logo du guerrier.
class WfColors {
  static const navy = Color(0xFF0B1F3A);
  static const navy2 = Color(0xFF12305A);
  static const navyLine = Color(0xFF1D4479);
  static const blue = Color(0xFF1565C0);
  static const red = Color(0xFFD7262D);
  static const gold = Color(0xFFFFD27A);
  static const page = Color(0xFFF3F5F9);
  static const ink = Color(0xFF0B1F3A);
  static const mute = Color(0xFF5B6B80);

  static Color fg(DeviceStatus? s) => switch (s) {
        DeviceStatus.nouveau => const Color(0xFFA3191E),
        DeviceStatus.fiable => const Color(0xFF1D7A3D),
        DeviceStatus.bloque => gold,
        _ => const Color(0xFF0C447C),
      };

  static Color bg(DeviceStatus? s) => switch (s) {
        DeviceStatus.nouveau => const Color(0xFFFDE8E8),
        DeviceStatus.fiable => const Color(0xFFE2F5E8),
        DeviceStatus.bloque => navy,
        _ => const Color(0xFFE3EEFB),
      };

  /// Couleur d'un point sur le radar.
  static Color dot(DeviceStatus? s) => switch (s) {
        DeviceStatus.nouveau => red,
        DeviceStatus.fiable => const Color(0xFF5FD38A),
        DeviceStatus.bloque => gold,
        _ => const Color(0xFF85B7EB),
      };
}

/// Petite pastille de statut (« Nouveau », « Fiable »…).
class StatusPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const StatusPill({super.key, required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Carte d'appareil : icône colorée, nom, détail et pastille.
class DeviceCard extends StatelessWidget {
  final IconData icon;
  final Color iconFg;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool dimmed;

  const DeviceCard({
    super.key,
    required this.icon,
    required this.iconFg,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconFg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: WfColors.ink)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: WfColors.mute)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
