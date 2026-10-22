import 'package:flutter/material.dart';

/// Petit graphique en courbe, sans dépendance externe.
class SimpleLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const SimpleLineChart({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 180,
      child: CustomPaint(
        size: Size.infinite,
        painter: _ChartPainter(
          values: values,
          labels: labels,
          line: cs.primary,
          grid: cs.outlineVariant,
          text: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color line, grid, text;

  _ChartPainter({
    required this.values,
    required this.labels,
    required this.line,
    required this.grid,
    required this.text,
  });

  void _text(Canvas c, String s, Offset o, {bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, alignRight ? o - Offset(tp.width, 0) : o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 32.0, bottom = 18.0, top = 8.0, right = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi == lo) {
      hi += 1;
      lo = lo - 1 < 0 ? 0 : lo - 1;
    }
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = top + h * (1 - f);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      _text(canvas, (lo + (hi - lo) * f).round().toString(), Offset(left - 4, y - 6),
          alignRight: true);
    }
    Offset pt(int i) {
      final x = values.length == 1 ? left + w / 2 : left + w * i / (values.length - 1);
      final y = top + h * (1 - (values[i] - lo) / (hi - lo));
      return Offset(x, y);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(pt(i), 3.5, dot);
    }
    if (labels.isNotEmpty) {
      _text(canvas, labels.first, Offset(left, size.height - 12));
      if (labels.length > 1) {
        _text(canvas, labels.last, Offset(left + w, size.height - 12), alignRight: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values || old.line != line;
}
