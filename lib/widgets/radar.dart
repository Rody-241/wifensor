import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'wf_style.dart';

/// Radar du scan : un faisceau doré tourne pendant le scan, chaque appareil
/// trouvé est un point coloré selon son statut, et le nombre s'affiche au centre.
class RadarView extends StatefulWidget {
  final bool scanning;
  final int count;
  final List<Color> dots;
  final double size;

  const RadarView({
    super.key,
    required this.scanning,
    required this.count,
    required this.dots,
    this.size = 170,
  });

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.scanning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(RadarView old) {
    super.didUpdateWidget(old);
    if (widget.scanning && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.scanning && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              size: Size.square(widget.size),
              painter: _RadarPainter(
                angle: reduce ? 0 : _ctrl.value * 2 * math.pi,
                showBeam: widget.scanning,
                dots: widget.dots,
              ),
            ),
          ),
          Text(
            '${widget.count}',
            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double angle;
  final bool showBeam;
  final List<Color> dots;

  _RadarPainter({required this.angle, required this.showBeam, required this.dots});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = WfColors.navy2);
    final ring = Paint()
      ..color = WfColors.navyLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, r * 0.66, ring);
    canvas.drawCircle(c, r * 0.33, ring);

    if (showBeam) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(rect, angle - math.pi / 2, math.pi / 3, true,
          Paint()..color = WfColors.gold.withValues(alpha: 0.28));
    }

    for (var i = 0; i < dots.length; i++) {
      // Position fixe pour chaque appareil : la liste ne « danse » pas.
      final a = i * 2.39996 + 0.7;
      final d = r * (0.42 + 0.48 * ((i * 0.618) % 1));
      canvas.drawCircle(c + Offset(math.cos(a) * d, math.sin(a) * d), 5, Paint()..color = dots[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.angle != angle || old.showBeam != showBeam || old.dots != dots;
}
