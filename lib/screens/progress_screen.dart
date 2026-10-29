import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final names = store.allExerciseNames().where((n) => store.historyFor(n).isNotEmpty).toList();
    final sel = names.contains(_sel) ? _sel! : (names.isEmpty ? null : names.first);
    final weeks = weeklyVolume(store.sessions, now);
    final streak = activeWeekStreak(store.sessions, now);
    final perWeek = weeks.fold(0, (a, w) => a + w.sessions) / weeks.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        const D('Progression', size: 52, w: FontWeight.w900, height: 1),
        const SizedBox(height: 16),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  D('$streak sem.', size: 40, color: C.accent, height: 1),
                  Text('actives d\'affilée', style: body(13, color: C.muted)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: perWeek.toStringAsFixed(1).replaceAll('.', ',')),
                      TextSpan(text: ' /SEM.', style: disp(20)),
                    ]),
                    style: disp(40, height: 1),
                  ),
                  Text('séances en moyenne', style: body(13, color: C.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Lbl('Volume hebdo (reps)', size: 14)),
              Lbl('8 sem.', size: 14),
            ]),
            const SizedBox(height: 10),
            WeekBars(weeks),
          ]),
        ),
        const SizedBox(height: 18),
        if (sel == null)
          Text('Pas encore de séance enregistrée.', style: body(15, color: C.muted))
        else ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in names)
              GestureDetector(
                onTap: () => setState(() => _sel = n),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: n == sel ? C.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: n == sel ? C.accent : C.line, width: 2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    D(n, size: 19, color: n == sel ? C.bg : C.text),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          _ExerciseDetail(name: sel),
        ],
      ],
    );
  }
}

class _ExerciseDetail extends StatelessWidget {
  final String name;
  const _ExerciseDetail({required this.name});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final h = store.historyFor(name);
    final isSec = h.first.$2.unit == Unit.seconds;
    final u = isSec ? 's' : 'reps';
    final totals = h.map((e) => e.$2.total).toList();
    final best = totals.reduce((a, b) => a > b ? a : b);
    final diff = totals.last - totals.first;
    final lastH = h.last.$2.sets.last.height;
    final isRecord = totals.length > 1 && totals.last == best;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Stat('$best', 'Meilleur total')),
        const SizedBox(width: 12),
        Expanded(
          child: _Stat(fmtDelta(diff), '$u depuis le début',
              color: diff > 0 ? C.accent : C.text),
        ),
        const SizedBox(width: 12),
        Expanded(child: _Stat(fmtH(lastH, space: true), 'Dernière hauteur')),
      ]),
      const SizedBox(height: 14),
      ProgressChart(totals.map((t) => t.toDouble()).toList(), height: 190),
      const SizedBox(height: 8),
      Row(children: [
        Lbl(h.length == 1 ? '1 séance' : 'Il y a ${h.length} séances', size: 14),
        const Spacer(),
        Lbl('Dernière : ${totals.last}${isRecord ? ' · record' : ''}',
            size: 14, color: isRecord ? C.accent : C.muted),
      ]),
      const SizedBox(height: 18),
      Lbl(isSec ? 'Total de secondes par séance' : 'Total de reps par séance', size: 14),
      const SizedBox(height: 4),
      for (final e in h.reversed)
        Container(
          height: 48,
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.surface2))),
          child: Row(children: [
            SizedBox(width: 82, child: D(fmtShort(e.$1), size: 18, w: FontWeight.w700, color: C.muted)),
            Expanded(
              child: Text(
                  '${compactSets(e.$2)}${e.$2.sets.last.height == null ? '' : ' · ${fmtH(e.$2.sets.last.height)}'}',
                  style: body(14, color: C.muted)),
            ),
            D('${e.$2.total}', size: 24, color: e.$2.total == best ? C.accent : C.text),
          ]),
        ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat(this.value, this.label, {this.color = C.text});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: D(value, size: 44, color: color, height: 1),
        ),
        const SizedBox(height: 4),
        D(label, size: 13, w: FontWeight.w700, ls: 0.08, color: C.muted),
      ]);
}
