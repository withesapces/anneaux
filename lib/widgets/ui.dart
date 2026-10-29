import 'dart:math';

import 'package:flutter/material.dart';

import '../stats.dart';
import '../theme.dart';
import 'art.dart';

// ---------------------------------------------------------------------------
// Boutons
// ---------------------------------------------------------------------------

/// Gros bouton plein (« VALIDER LA SÉRIE »).
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  final Color bg;
  final Color fg;
  final double height;
  final double fontSize;
  final bool outline;
  final double radius;

  const BigButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.bg = C.accent,
    this.fg = C.bg,
    this.height = 92,
    this.fontSize = 40,
    this.outline = false,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: outline ? Colors.transparent : bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: outline ? BorderSide(color: fg, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon!, SizedBox(width: fontSize * 0.35)],
                      D(label, size: fontSize, w: FontWeight.w900, color: fg, ls: 0.02),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire plein gris (« −30 S », « EXPORTER »).
class TileButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final double fontSize;
  final Color bg;
  final Color fg;
  final Color? border;

  const TileButton(this.label,
      {super.key,
      this.onTap,
      this.icon,
      this.height = 72,
      this.fontSize = 30,
      this.bg = C.surface2,
      this.fg = C.text,
      this.border});

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: border == null ? BorderSide.none : BorderSide(color: border!, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[
                    Icon(icon, color: fg, size: fontSize * 0.85),
                    const SizedBox(width: 8)
                  ],
                  D(label, size: fontSize, w: FontWeight.w800, color: fg),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Bouton rond − / + (96 px). Le + est clair : c'est le geste le plus fréquent.
class RoundButton extends StatelessWidget {
  final bool plus;
  final VoidCallback? onTap;
  final double size;
  const RoundButton({super.key, required this.plus, this.onTap, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final bg = plus ? C.text : C.surface2;
    final fg = plus ? C.bg : C.text;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _PlusMinus(plus: plus, color: fg, k: size / 96)),
          ),
        ),
      ),
    );
  }
}

class _PlusMinus extends CustomPainter {
  final bool plus;
  final Color color;
  final double k;
  _PlusMinus({required this.plus, required this.color, required this.k});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 5.5 * k
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    final h = 11 * k;
    canvas.drawLine(c.translate(-h, 0), c.translate(h, 0), p);
    if (plus) canvas.drawLine(c.translate(0, -h), c.translate(0, h), p);
  }

  @override
  bool shouldRepaint(_PlusMinus old) => old.plus != plus || old.color != color;
}

/// Lien texte en capitales (« ‹ PRÉC. »).
class LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  const LinkButton(this.label,
      {super.key, this.onTap, this.color = C.muted, this.size = 21});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: D(label,
              size: size,
              w: FontWeight.w700,
              ls: 0.06,
              maxLines: 1,
              color: onTap == null ? C.faint : color),
        ),
      );
}

/// Bouton retour « ‹ HISTORIQUE ».
class BackLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const BackLink(this.label, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chevron_left, color: C.muted, size: 26),
            const SizedBox(width: 2),
            D(label, size: 18, w: FontWeight.w700, ls: 0.06, color: C.muted),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

enum TagStyle { white, accent, outlineAccent, outlineGray, dark }

class Tag extends StatelessWidget {
  final String text;
  final TagStyle style;
  final double size;
  const Tag(this.text, {super.key, this.style = TagStyle.white, this.size = 17});

  @override
  Widget build(BuildContext context) {
    final (Color? bg, Color fg, Color? border) = switch (style) {
      TagStyle.white => (C.text, C.bg, null),
      TagStyle.accent => (C.accent, C.bg, null),
      TagStyle.outlineAccent => (null, C.accent, C.accent),
      TagStyle.outlineGray => (null, C.text, C.faint),
      TagStyle.dark => (C.bg, C.accent, null),
    };
    return Container(
      height: size * 2.1,
      padding: EdgeInsets.symmetric(horizontal: size * 0.8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
      alignment: Alignment.center,
      child: D(text, size: size, w: FontWeight.w800, ls: 0.06, color: fg),
    );
  }
}

/// Badge hauteur de sangle « H 5 » (bord blanc épais).
class HeightBadge extends StatelessWidget {
  final double? height;
  final double size;
  final VoidCallback? onTap;
  final Color color;
  final bool icon;

  const HeightBadge(this.height,
      {super.key, this.size = 42, this.onTap, this.color = C.text, this.icon = true});

  @override
  Widget build(BuildContext context) {
    final h = size * 1.52;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(h / 2),
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: size * 0.45),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(h / 2),
          border: Border.all(color: color, width: 3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon) ...[
            LineIcon(strapIcon, size: size * 0.43, height: size * 0.72, color: color),
            SizedBox(width: size * 0.22),
          ],
          D(fmtH(height, space: true), size: size, w: FontWeight.w800, color: color),
        ]),
      ),
    );
  }
}

/// Écart vs la dernière fois : « ▲ +2 », « = égal », « ▼ −1 ».
class DeltaChip extends StatelessWidget {
  final int delta;
  final double size;
  const DeltaChip(this.delta, {super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final txt = delta > 0
        ? '▲ +$delta'
        : delta < 0
            ? '▼ −${delta.abs()}'
            : '= égal';
    return Container(
      height: size * 1.55,
      padding: EdgeInsets.symmetric(horizontal: size * 0.55),
      decoration: BoxDecoration(
        color: delta > 0 ? C.accentNight : C.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: D(txt,
          size: size,
          w: FontWeight.w800,
          color: delta > 0
              ? C.accent
              : delta < 0
                  ? C.muted
                  : C.text),
    );
  }
}

/// Petite pastille d'écart pour les tableaux (« +7 », « = », « −2 »).
class MiniDelta extends StatelessWidget {
  final String text;
  final bool up;
  final bool down;
  const MiniDelta(this.text, {super.key, this.up = false, this.down = false});

  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        constraints: const BoxConstraints(minWidth: 26),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: up ? C.accent : C.surface2,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: D(text,
            size: 17,
            w: FontWeight.w800,
            color: up
                ? C.bg
                : down
                    ? C.muted
                    : C.text),
      );
}

// ---------------------------------------------------------------------------
// Progression
// ---------------------------------------------------------------------------

/// Pastilles de séries : faites (pleines), en cours (accent + halo), restantes (contour).
class SetDots extends StatelessWidget {
  final int done;
  final int target;
  final bool showCurrent;
  final double size;
  final String? bonusLabel;
  final void Function(int index)? onTapDone;

  const SetDots({
    super.key,
    required this.done,
    required this.target,
    this.showCurrent = true,
    this.size = 22,
    this.bonusLabel,
    this.onTapDone,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final shown = min(done, target);
    for (var i = 0; i < max(target, shown); i++) {
      Widget dot;
      if (i < shown) {
        dot = _dot(fill: C.text);
        if (onTapDone != null) {
          final idx = i;
          dot = GestureDetector(onTap: () => onTapDone!(idx), child: dot);
        }
      } else if (i == done && showCurrent) {
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: C.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: C.bg, spreadRadius: size * 0.18),
              BoxShadow(color: C.accent, spreadRadius: size * 0.32),
            ],
          ),
        );
      } else {
        dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: C.faint, width: 3),
          ),
        );
      }
      items.add(dot);
    }
    final extra = bonusLabel ?? (done > target ? '+${done - target}' : null);
    if (extra != null) {
      items.add(Container(
        height: size * 1.27,
        padding: EdgeInsets.symmetric(horizontal: size * 0.45),
        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(size)),
        alignment: Alignment.center,
        child: D(extra, size: size * 0.77, w: FontWeight.w800, color: C.bg),
      ));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < items.length; k++) ...[
          if (k > 0) SizedBox(width: size * 0.55),
          items[k],
        ],
      ],
    );
  }

  Widget _dot({required Color fill}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      );
}

class SegSpec {
  final int done;
  final int target;
  final bool current;
  const SegSpec(this.done, this.target, this.current);
}

/// Barre segmentée : 1 segment = 1 exercice, 1 trait = 1 série.
class SegmentedBar extends StatelessWidget {
  final List<SegSpec> segs;
  final Color doneColor;
  final Color todoColor;
  final Color currentColor;

  const SegmentedBar(this.segs,
      {super.key,
      this.doneColor = C.text,
      this.todoColor = C.line,
      this.currentColor = C.accent});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final n = max(1, max(s.target, s.done + (s.current && s.done >= s.target ? 1 : 0)));
      if (i > 0) children.add(const SizedBox(width: 5));
      children.add(Expanded(
        flex: n,
        child: Row(children: [
          for (var j = 0; j < n; j++) ...[
            if (j > 0) const SizedBox(width: 2),
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: j < s.done
                      ? doneColor
                      : (s.current && j == s.done)
                          ? currentColor
                          : todoColor,
                ),
              ),
            ),
          ],
        ]),
      ));
    }
    return Row(children: children);
  }
}

/// Anneau (arc épais, bout arrondi, départ à midi).
class Ring extends StatelessWidget {
  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;
  final bool knob;
  final Color knobColor;

  const Ring({
    super.key,
    required this.progress,
    required this.size,
    this.stroke = 24,
    this.color = C.accent,
    this.track = C.surface2,
    this.child,
    this.knob = false,
    this.knobColor = C.accent,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: RingPainter(
              progress: progress,
              stroke: stroke,
              color: color,
              track: track,
              knob: knob,
              knobColor: knobColor),
          child: Center(child: child),
        ),
      );
}

class RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Color color;
  final Color track;
  final bool knob;
  final Color knobColor;

  RingPainter({
    required this.progress,
    required this.stroke,
    required this.color,
    required this.track,
    this.knob = false,
    this.knobColor = C.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    final p = progress.clamp(0.0, 1.0);
    if (p > 0) {
      canvas.drawArc(
          rect,
          -pi / 2,
          2 * pi * p,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round);
    }
    if (knob) {
      final a = -pi / 2 + 2 * pi * p;
      final o = c + Offset(cos(a), sin(a)) * r;
      canvas.drawCircle(o, stroke * 0.42, Paint()..color = knobColor);
    }
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

// ---------------------------------------------------------------------------
// Blocs
// ---------------------------------------------------------------------------

/// Gros chiffre + label en dessous (« 9 / EXERCICES »).
class BigStat extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final double size;
  final Color color;

  const BigStat(this.value, this.label,
      {super.key, this.unit, this.size = 56, this.color = C.text});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value.toUpperCase()),
                if (unit != null)
                  TextSpan(
                      text: ' ${unit!.toUpperCase()}',
                      style: disp(size * 0.46, color: color)),
              ]),
              style: disp(size, color: color, height: 0.95),
            ),
          ),
          D(label, size: 14, w: FontWeight.w700, ls: 0.12, color: C.muted, maxLines: 1),
        ],
      );
}

/// Tuile grise : chiffre + légende (régularité).
class StatTile extends StatelessWidget {
  final String value;
  final String caption;
  final Color color;
  const StatTile(this.value, this.caption, {super.key, this.color = C.text});

  @override
  Widget build(BuildContext context) => Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration:
            BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: D(value, size: 40, color: color, height: 1),
            ),
            const SizedBox(height: 2),
            Text(caption, style: body(13, color: C.muted, height: 1.3)),
          ],
        ),
      );
}

/// Bloc de surface arrondi.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.color = C.surface,
      this.border});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: border == null ? null : Border.all(color: border!, width: 2),
        ),
        child: child,
      );
}

/// Bordure en pointillés (cadre « première fois », bouton « ajouter »).
class DashedBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  const DashedBox({super.key, required this.child, this.radius = 18, this.color = C.faint});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashPainter(radius: radius, color: color),
        child: child,
      );
}

class _DashPainter extends CustomPainter {
  final double radius;
  final Color color;
  _DashPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)).deflate(1));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), p);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

// ---------------------------------------------------------------------------
// Graphiques
// ---------------------------------------------------------------------------

/// Mini-courbe (tendance volume dans l'historique).
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color dotColor;
  const Sparkline(this.values, {super.key, this.dotColor = C.accent});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 68,
        height: 30,
        child: CustomPaint(painter: _SparkPainter(values, dotColor)),
      );
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color dot;
  _SparkPainter(this.v, this.dot);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final lo = v.reduce(min), hi = v.reduce(max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    Offset at(int i) => Offset(
          v.length == 1 ? size.width : i * size.width / (v.length - 1),
          size.height - 3 - (v[i] - lo) / span * (size.height - 6),
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = C.muted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(at(v.length - 1), 4, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

/// Courbe de progression : trait blanc, dernier point cerclé d'orange.
class ProgressChart extends StatelessWidget {
  final List<double> values;
  final double height;
  const ProgressChart(this.values, {super.key, this.height = 200});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _ChartPainter(values)),
      );
}

class _ChartPainter extends CustomPainter {
  final List<double> v;
  _ChartPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = C.surface2
      ..strokeWidth = 1.5;
    for (var k = 0; k < 3; k++) {
      final y = size.height * (0.3 + 0.35 * k);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (v.isEmpty) return;
    final lo = v.reduce(min), hi = v.reduce(max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    const pad = 16.0;
    Offset at(int i) => Offset(
          v.length == 1 ? size.width - pad : pad + i * (size.width - 2 * pad) / (v.length - 1),
          pad + (1 - (v[i] - lo) / span) * (size.height - 2 * pad),
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = C.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    final last = at(v.length - 1);
    canvas.drawCircle(last, 11, Paint()..color = C.accent);
    canvas.drawCircle(last, 5, Paint()..color = C.bg);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// Barres de volume hebdo (dernière barre en accent).
class WeekBars extends StatelessWidget {
  final List<WeekVolume> weeks;
  const WeekBars(this.weeks, {super.key});

  @override
  Widget build(BuildContext context) {
    final hi = weeks.isEmpty ? 1 : max(1, weeks.map((w) => w.reps).reduce(max));
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < weeks.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: max(4, 84 * weeks[i].reps / hi),
                    decoration: BoxDecoration(
                      color: i == weeks.length - 1 ? C.accent : C.line,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  D('S${weeks[i].week}', size: 13, w: FontWeight.w700, color: C.muted),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogues
// ---------------------------------------------------------------------------

Future<bool> confirmDialog(BuildContext context, String title, String msg,
    {String yes = 'Oui', String no = 'Annuler', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: D(title, size: 30, w: FontWeight.w900),
      content: Text(msg, style: body(15, color: C.muted, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no.toUpperCase())),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5A4E))
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(yes.toUpperCase()),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<int?> numberDialog(BuildContext context, String title, int initial) {
  final ctrl = TextEditingController(text: '$initial');
  return showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      title: D(title, size: 28, w: FontWeight.w900),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: disp(48),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('ANNULER')),
        FilledButton(
          onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text.trim())),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
