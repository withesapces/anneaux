import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../estimate.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/ui.dart';
import 'history_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      TodayTab(),
      HistoryScreen(),
      ProgressScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_tab]),
      bottomNavigationBar: _NavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (navRings, 'Séance'),
      (navCalendar, 'Historique'),
      (navTrend, 'Progression'),
      (navList, 'Programme'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.surface2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LineIcon(items[i].$1, color: i == index ? C.accent : C.dim),
                        const SizedBox(height: 4),
                        D(items[i].$2,
                            size: 14,
                            w: FontWeight.w700,
                            ls: 0.08,
                            color: i == index ? C.accent : C.dim),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onglet « Séance » : démarrer ou reprendre.
class TodayTab extends StatefulWidget {
  const TodayTab({super.key});

  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le temps écoulé et l'heure de fin estimée.
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _open(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WorkoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final draft = store.draft;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        _header(store),
        const SizedBox(height: 18),
        if (draft == null) ..._idle(context, store) else ..._resume(context, store, draft),
      ],
    );
  }

  Widget _header(AppStore store) {
    final draft = store.draft;
    return Row(
      children: [
        const AnneauxLogo(size: 36),
        const SizedBox(width: 10),
        const D('Anneaux', size: 28, w: FontWeight.w900, ls: 0.02),
        const Spacer(),
        if (draft == null)
          D(fmtDayShort(DateTime.now()), size: 16, w: FontWeight.w700, ls: 0.12, color: C.muted)
        else
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: C.accentNight, borderRadius: BorderRadius.circular(15)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              D('En cours · ${fmtElapsed(DateTime.now().difference(draft.session.date).inSeconds)}',
                  size: 15, w: FontWeight.w800, ls: 0.1, color: C.accent),
            ]),
          ),
      ],
    );
  }

  List<Widget> _idle(BuildContext context, AppStore store) {
    final exs = store.routine
        .map((r) => ExerciseLog(name: r.name, unit: r.unit, perSide: r.perSide))
        .toList();
    final left = estimateRemaining(store, exs);
    final end = DateTime.now().add(Duration(seconds: left));
    final totalSets = exs.fold(0, (a, e) => a + targetSets(store, e));
    final now = DateTime.now();
    final streak = activeWeekStreak(store.sessions, now);
    final since = daysSinceLast(store.sessions, now);

    return [
      Row(children: [
        Expanded(flex: 2, child: BigStat('${store.routine.length}', 'exercices')),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: BigStat('~${(left / 60).round()}', 'durée estimée', unit: 'min')),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: BigStat(fmtHour(end), 'fin vers')),
      ]),
      const SizedBox(height: 14),
      Material(
        color: C.accent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: store.routine.isEmpty
              ? null
              : () {
                  store.startWorkout();
                  _open(context);
                },
          child: SizedBox(
            height: 148,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 28, 0),
              child: Row(children: [
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: D('Démarrer', size: 76, w: FontWeight.w900, color: C.bg, height: 1),
                  ),
                ),
                const SizedBox(width: 8),
                CustomPaint(size: const Size(64, 64), painter: _PlayPainter()),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child: StatTile('${sessionsInMonth(store.sessions, now)}',
                'séances en ${monthName(now.month)}')),
        const SizedBox(width: 8),
        Expanded(
            child: StatTile('$streak sem.', 'actives d\'affilée',
                color: streak > 0 ? C.accent : C.text)),
        const SizedBox(width: 8),
        Expanded(
            child: StatTile(
                since == null ? '—' : (since == 0 ? 'Auj.' : '$since j'),
                since == 0 ? 'dernière séance' : 'depuis la dernière')),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Lbl('Le programme · $totalSets séries')),
        const Lbl('Dernière fois'),
      ]),
      const SizedBox(height: 6),
      for (var i = 0; i < store.routine.length; i++)
        _ProgRow(
          lead: D((i + 1).toString().padLeft(2, '0'),
              size: 16, w: FontWeight.w700, color: C.faint),
          name: store.routine[i].name,
          detail: () {
            final last = store.lastLogFor(store.routine[i].name);
            return last == null ? 'Première fois' : compactSets(last);
          }(),
          height: store.routine[i].height,
          color: C.text,
        ),
      if (store.routine.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Ton programme est vide. Ajoute des exercices dans l\'onglet Programme.',
              style: body(15, color: C.muted)),
        ),
    ];
  }

  List<Widget> _resume(BuildContext context, AppStore store, WorkoutDraft draft) {
    final exs = draft.session.exercises;
    final idx = exs.isEmpty ? 0 : min(max(draft.exIndex, 0), exs.length - 1);
    final ex = exs.isEmpty ? null : exs[idx];
    final total = exs.fold(0, (a, e) => a + max(targetSets(store, e), e.sets.length));
    final done = draft.session.totalSets;
    final remaining = exs.fold(0, (a, e) => a + max(0, targetSets(store, e) - e.sets.length));
    final restLeft = draft.restEndsAt == null
        ? 0
        : max(0, draft.restEndsAt!.difference(DateTime.now()).inSeconds);
    final left = estimateRemaining(store, exs, start: draft.session.date, restLeft: restLeft);
    final end = DateTime.now().add(Duration(seconds: left));
    final height = ex == null
        ? null
        : (ex.sets.isNotEmpty
            ? ex.sets.last.height
            : (store.lastLogFor(ex.name)?.sets.first.height ?? store.defFor(ex.name)?.height));

    return [
      Material(
        color: C.accent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: SizedBox(
            height: 168,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 22, 0),
              child: Row(children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: D('Reprendre', size: 68, w: FontWeight.w900, color: C.bg, height: 0.95),
                      ),
                      const SizedBox(height: 6),
                      if (ex != null)
                        D('${ex.name} · série ${ex.sets.length + 1}/${targetSets(store, ex)} · ${fmtH(height, space: true)}',
                            size: 21, w: FontWeight.w800, color: C.bg, ls: 0.04, maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Ring(
                  progress: total == 0 ? 0 : done / total,
                  size: 104,
                  stroke: 10,
                  color: C.bg,
                  track: C.bg.withValues(alpha: 0.22),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    D('$done/$total', size: 30, w: FontWeight.w800, color: C.bg, height: 1),
                    const D('séries', size: 13, w: FontWeight.w700, color: C.bg, ls: 0.08),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SegmentedBar(segsFor(store, exs, idx)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: BigStat('$remaining', 'séries restantes', size: 44)),
        Expanded(child: BigStat('~${(left / 60).round()}', 'à ton rythme', unit: 'min', size: 44)),
        Expanded(child: BigStat(fmtHour(end), 'fin vers', size: 44)),
      ]),
      const SizedBox(height: 18),
      const Row(children: [
        Expanded(child: Lbl('Où tu en es')),
        Lbl('Aujourd\'hui'),
      ]),
      const SizedBox(height: 6),
      for (var i = 0; i < exs.length; i++)
        () {
          final e = exs[i];
          final t = targetSets(store, e);
          final isDone = e.sets.length >= t;
          final isCur = i == idx;
          final h = e.sets.isNotEmpty
              ? e.sets.last.height
              : (store.lastLogFor(e.name)?.sets.first.height ?? store.defFor(e.name)?.height);
          return _ProgRow(
            lead: isDone && !isCur
                ? Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: C.text, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 16, color: C.bg))
                : isCur
                    ? Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, border: Border.all(color: C.accent, width: 4)))
                    : D((i + 1).toString().padLeft(2, '0'),
                        size: 16, w: FontWeight.w700, color: C.faint),
            name: e.name,
            detail: e.sets.isEmpty
                ? '0/$t'
                : e.sets.map((s) => '${s.value}').join(' · ') + (isDone ? '' : ' · …'),
            height: h,
            color: isCur ? C.accent : (isDone ? C.muted : C.text),
          );
        }(),
      const SizedBox(height: 12),
      Center(
        child: LinkButton('Abandonner la séance', size: 17, onTap: () async {
          final ok = await confirmDialog(context, 'Abandonner ?',
              'Les séries saisies aujourd\'hui seront perdues. L\'historique ne bouge pas.',
              yes: 'Abandonner', danger: true);
          if (ok) store.discardDraft();
        }),
      ),
    ];
  }
}

class _ProgRow extends StatelessWidget {
  final Widget lead;
  final String name;
  final String detail;
  final double? height;
  final Color color;
  const _ProgRow(
      {required this.lead,
      required this.name,
      required this.detail,
      required this.height,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.surface2))),
        child: Row(children: [
          SizedBox(width: 30, child: Align(alignment: Alignment.centerLeft, child: lead)),
          Expanded(child: D(name, size: 22, w: FontWeight.w700, color: color, maxLines: 1)),
          const SizedBox(width: 8),
          Text(detail, style: body(14, color: C.muted)),
          SizedBox(
            width: 58,
            child: Align(
              alignment: Alignment.centerRight,
              child: D(fmtH(height), size: 20, w: FontWeight.w800, color: color == C.muted ? C.muted : C.text),
            ),
          ),
        ]),
      );
}

class _PlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 72;
    final c = size.center(Offset.zero);
    canvas.drawCircle(
        c,
        31 * k,
        Paint()
          ..color = C.bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * k);
    final path = Path()
      ..moveTo(29 * k, 22 * k)
      ..lineTo(50 * k, 36 * k)
      ..lineTo(29 * k, 50 * k)
      ..close();
    canvas.drawPath(path, Paint()..color = C.bg);
  }

  @override
  bool shouldRepaint(_PlayPainter old) => false;
}
