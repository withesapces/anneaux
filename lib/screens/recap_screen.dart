import 'package:flutter/material.dart';

import '../calories.dart';
import '../estimate.dart';
import '../health_sync.dart';
import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// « Séance bouclée » : récap avant d'enregistrer. Retourne true si la séance est enregistrée.
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  bool _busy = false;

  Future<void> _save({required bool sendHealth}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await store.finishWorkout();
    nav.pop(true);
    messenger.showSnackBar(SnackBar(
      content: Text(saved == null ? 'Séance vide, rien enregistré.' : 'Séance enregistrée.'),
    ));
    if (saved != null && (sendHealth || store.healthEnabled)) {
      if (sendHealth && !store.healthEnabled) {
        final ok = await HealthSync.authorize();
        if (ok) await store.setHealth(true);
      }
      final err = await HealthSync.writeSession(saved,
          weightKg: store.sendCalories ? store.weightKg : null);
      if (err == null) await store.markHealthSynced(saved);
      messenger.showSnackBar(SnackBar(
        content: Text(err ?? 'Séance envoyée à Samsung Health.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final draft = store.draft;
    if (draft == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final s = draft.session;
    final now = DateTime.now();
    final tmp = Session(id: s.id, date: s.date, end: now, exercises: s.exercises);
    final duration = now.difference(s.date).inSeconds;
    final reps = sessionReps(tmp);
    final hold = sessionHold(tmp);
    final kcal = estimateKcal(tmp, store.weightKg);

    final records = <(ExerciseLog, int)>[];
    for (final e in s.exercises) {
      if (e.sets.isEmpty) continue;
      final best = bestTotal(store.sessions, e.name);
      if (best != null && e.total > best) records.add((e, e.total));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BackLink('Continuer la séance', onTap: () => Navigator.pop(context, false)),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    SizedBox(
                      width: 68,
                      height: 56,
                      child: Stack(children: [
                        Positioned(
                          left: 0,
                          top: 6,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: C.text, width: 7)),
                          ),
                        ),
                        Positioned(
                          left: 22,
                          top: 6,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration:
                                const BoxDecoration(color: C.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: C.bg, size: 32),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: D('Séance\nbouclée', size: 60, w: FontWeight.w900, height: 0.88),
                        ),
                        const SizedBox(height: 6),
                        D('${fmtDayShort(s.date)} · ${fmtHour(s.date)} → ${fmtHour(now)}',
                            size: 17, w: FontWeight.w700, ls: 0.06, color: C.muted),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _Box(fmtMinSec(duration), 'Durée')),
                    const SizedBox(width: 8),
                    Expanded(child: _Box('${s.totalSets}', 'Séries')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Box('$reps', hold > 0 ? 'Reps · ${fmtMinSec(hold)} tenue' : 'Reps')),
                    const SizedBox(width: 8),
                    Expanded(child: _Box(kcal == null ? '—' : '~$kcal', 'Kcal est.')),
                  ]),
                  if (records.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      decoration: BoxDecoration(
                          color: C.accent, borderRadius: BorderRadius.circular(22)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        D('★ ${records.length} record${records.length > 1 ? 's' : ''}',
                            size: 30, w: FontWeight.w900, color: C.bg),
                        const SizedBox(height: 8),
                        Wrap(spacing: 24, runSpacing: 8, children: [
                          for (final r in records)
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              D(r.$1.name, size: 17, w: FontWeight.w700, color: C.bg),
                              D(r.$1.unit == Unit.seconds ? '${r.$2} s' : '${r.$2} reps',
                                  size: 30, color: C.bg, height: 1),
                            ]),
                        ]),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Row(children: [
                    Expanded(child: Lbl('Exercice · aujourd\'hui', size: 14)),
                    Lbl('vs dernière fois', size: 14),
                  ]),
                  const SizedBox(height: 4),
                  for (final e in s.exercises) _row(store, e),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(children: [
                BigButton('Enregistrer',
                    height: 80, fontSize: 36, onTap: _busy ? null : () => _save(sendHealth: false)),
                if (!store.healthEnabled) ...[
                  const SizedBox(height: 10),
                  TileButton('Envoyer à Samsung Health',
                      icon: Icons.favorite_border,
                      height: 56,
                      fontSize: 20,
                      bg: Colors.transparent,
                      border: C.line,
                      onTap: _busy ? null : () => _save(sendHealth: true)),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Envoi automatique à Samsung Health activé.',
                        style: body(13, color: C.muted)),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(AppStore store, ExerciseLog e) {
    final last = store.lastLogFor(e.name);
    final skipped = e.sets.isEmpty;
    Widget delta;
    if (skipped) {
      delta = const MiniDelta('—');
    } else if (last == null) {
      delta = const MiniDelta('Nouv.', up: true);
    } else {
      final d = e.total - last.total;
      delta = MiniDelta(fmtDelta(d, suffix: e.unit == Unit.seconds ? ' s' : ''),
          up: d > 0, down: d < 0);
    }
    final h = e.sets.isEmpty ? null : e.sets.last.height;
    return Container(
      height: 36,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.surface2))),
      child: Row(children: [
        Expanded(
          child: D(e.name,
              size: 20, w: FontWeight.w700, color: skipped ? C.faint : C.text, maxLines: 1),
        ),
        Text(skipped ? 'ignoré' : '${dottedSets(e)}${h == null ? '' : ' · ${fmtH(h)}'}',
            style: body(13, color: C.muted)),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: Align(alignment: Alignment.centerRight, child: delta)),
      ]),
    );
  }
}

class _Box extends StatelessWidget {
  final String value;
  final String label;
  const _Box(this.value, this.label);

  @override
  Widget build(BuildContext context) => Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: D(value, size: 34, height: 1),
          ),
          const SizedBox(height: 4),
          D(label, size: 12, w: FontWeight.w700, ls: 0.08, color: C.muted, maxLines: 2),
        ]),
      );
}
