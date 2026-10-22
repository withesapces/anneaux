import 'dart:math';

import 'models.dart';
import 'store.dart';

/// Temps de travail estimé pour une série (mise en place comprise).
int _work(ExerciseLog ex, int value) =>
    ex.unit == Unit.seconds ? value + 15 : value * 3 + 15;

int targetSets(AppStore store, ExerciseLog ex) =>
    max(1, store.lastLogFor(ex.name)?.sets.length ?? 3);

int _plannedValue(AppStore store, ExerciseLog ex, int k) {
  final last = store.lastLogFor(ex.name);
  if (last != null && last.sets.isNotEmpty) {
    return last.sets[min(k, last.sets.length - 1)].value;
  }
  if (ex.sets.isNotEmpty) return ex.sets.last.value;
  return ex.unit == Unit.seconds ? 30 : 10;
}

/// Secondes restantes avant la fin de la séance.
///
/// Modèle : chaque série restante = travail estimé + repos (sauf la dernière),
/// plus le repos en cours. Dès 3 séries faites, le modèle est recalé sur ton
/// rythme réel depuis le début de la séance.
int estimateRemaining(
  AppStore store,
  List<ExerciseLog> exercises, {
  int restLeft = 0,
  DateTime? start,
}) {
  var setsLeft = 0;
  var workLeft = 0;
  var setsDone = 0;
  var workDone = 0;
  for (final ex in exercises) {
    for (final s in ex.sets) {
      setsDone++;
      workDone += _work(ex, s.value);
    }
    final t = targetSets(store, ex);
    for (var k = ex.sets.length; k < t; k++) {
      setsLeft++;
      workLeft += _work(ex, _plannedValue(store, ex, k));
    }
  }
  if (setsLeft == 0) return max(0, restLeft);

  var ratio = 1.0;
  if (start != null && setsDone >= 3) {
    final elapsed = DateTime.now().difference(start).inSeconds - max(0, restLeft);
    final modelled = workDone + setsDone * store.restSeconds;
    if (modelled > 0 && elapsed > 0) {
      ratio = min(1.6, max(0.7, elapsed / modelled));
    }
  }
  final model = workLeft + (setsLeft - 1) * store.restSeconds;
  return (model * ratio).round() + max(0, restLeft);
}

String fmtDuration(int seconds) {
  final m = (seconds / 60).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

String fmtHour(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
