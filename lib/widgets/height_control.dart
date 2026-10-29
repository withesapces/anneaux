import 'package:flutter/material.dart';

import '../stats.dart';
import '../theme.dart';
import 'ui.dart';

const double kMinHeight = 1;
const double kMaxHeight = 12;

/// Réglage de la hauteur de sangle : − H 10,5 + et une règle de 1 à 12 (pas de 0,5).
class HeightControl extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  const HeightControl({super.key, required this.value, required this.onChanged});

  double _clamp(double v) => v.clamp(kMinHeight, kMaxHeight).toDouble();

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      children: [
        Row(
          children: [
            RoundButton(
              plus: false,
              size: 72,
              onTap: v == null || v <= kMinHeight ? null : () => onChanged(_clamp(v - 0.5)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: v == null ? () => onChanged(5) : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: D(fmtH(v, space: true), size: 76, w: FontWeight.w900, height: 1),
                ),
              ),
            ),
            RoundButton(
              plus: true,
              size: 72,
              onTap: v != null && v >= kMaxHeight ? null : () => onChanged(_clamp((v ?? 4.5) + 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Ruler(value: v, onChanged: (x) => onChanged(x)),
      ],
    );
  }
}

class _Ruler extends StatelessWidget {
  final double? value;
  final ValueChanged<double> onChanged;
  const _Ruler({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const pad = 16.0;
      final w = box.maxWidth - 2 * pad;
      double toValue(double dx) {
        final t = ((dx - pad) / w).clamp(0.0, 1.0);
        final raw = kMinHeight + t * (kMaxHeight - kMinHeight);
        return (raw * 2).round() / 2;
      }

      void set(Offset p) {
        final nv = toValue(p.dx);
        if (nv != value) onChanged(nv);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => set(d.localPosition),
        onHorizontalDragUpdate: (d) => set(d.localPosition),
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: CustomPaint(painter: _RulerPainter(value, pad)),
        ),
      );
    });
  }
}

class _RulerPainter extends CustomPainter {
  final double? value;
  final double pad;
  _RulerPainter(this.value, this.pad);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - 2 * pad;
    double x(double v) => pad + (v - kMinHeight) / (kMaxHeight - kMinHeight) * w;
    final tick = Paint()
      ..color = C.faint
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var v = kMinHeight; v <= kMaxHeight; v += 0.5) {
      final whole = v == v.roundToDouble();
      canvas.drawLine(Offset(x(v), 6), Offset(x(v), whole ? 34 : 24), tick);
      if (whole && v.toInt().isOdd) {
        final tp = TextPainter(
          text: TextSpan(text: '${v.toInt()}', style: disp(14, w: FontWeight.w700, color: C.muted)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x(v) - tp.width / 2, 40));
      }
    }
    final v = value;
    if (v != null) {
      final p = Paint()
        ..color = C.accent
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x(v), 2), Offset(x(v), 38), p);
      canvas.drawCircle(Offset(x(v), 4), 7, Paint()..color = C.accent);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.value != value;
}

/// Feuille du bas pour régler la hauteur pendant la séance.
Future<double?> pickHeight(BuildContext context, double? initial,
    {required String title}) async {
  double? v = initial;
  var cleared = false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Lbl(title),
              const SizedBox(height: 16),
              HeightControl(value: v, onChanged: (x) => set(() => v = x)),
              const SizedBox(height: 20),
              BigButton('Valider', height: 72, fontSize: 32, onTap: () => Navigator.pop(c, true)),
              const SizedBox(height: 4),
              Center(
                child: LinkButton('Sans hauteur', size: 18, onTap: () {
                  cleared = true;
                  Navigator.pop(c, true);
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (ok != true) return initial;
  return cleared ? null : v;
}
