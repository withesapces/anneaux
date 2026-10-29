import 'dart:math';

import 'models.dart';

/// Calculs d'affichage (volume, régularité, records). Aucun effet sur les données.

const _monthsFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _monthsShortFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _daysShortFr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

String monthName(int m) => _monthsFr[m - 1];

/// « jeu. 29 oct. »
String fmtDayShort(DateTime d) =>
    '${_daysShortFr[d.weekday - 1]} ${d.day} ${_monthsShortFr[d.month - 1]}';

String weekdayShort(DateTime d) => _daysShortFr[d.weekday - 1];

/// Hauteur au format français : « H4,5 ».
String fmtH(double? h, {bool space = false}) {
  if (h == null) return space ? 'H —' : 'H—';
  final v = h == h.roundToDouble() ? h.toInt().toString() : h.toString().replaceAll('.', ',');
  return space ? 'H $v' : 'H$v';
}

/// « 04:12 » ou « 1:04:12 ».
String fmtElapsed(int seconds) {
  final s = max(0, seconds);
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$sec';
  return '${m.toString().padLeft(2, '0')}:$sec';
}

/// « 49:10 » (minutes:secondes), « 1:02:10 » au-delà d'une heure.
String fmtMinSec(int seconds) {
  final s = max(0, seconds);
  if (s >= 3600) return fmtElapsed(s);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// « 2 268 » avec espace des milliers.
String fmtThousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '−' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// « +3 », « −2 », « = ».
String fmtDelta(int d, {String suffix = ''}) =>
    d == 0 ? '=' : (d > 0 ? '+$d$suffix' : '−${d.abs()}$suffix');

/// Résumé compact : « 2×10 + 1×7 », « 9 · 8 · 7 », « 20 · 18 · 15 s ».
String compactSets(ExerciseLog e) {
  if (e.sets.isEmpty) return '—';
  final unit = e.unit == Unit.seconds ? ' s' : '';
  final groups = <List<int>>[];
  for (final s in e.sets) {
    if (groups.isNotEmpty && groups.last[1] == s.value) {
      groups.last[0]++;
    } else {
      groups.add([1, s.value]);
    }
  }
  if (groups.length < e.sets.length) {
    return groups.map((g) => '${g[0]}×${g[1]}').join(' + ') + unit;
  }
  return e.sets.map((s) => '${s.value}').join(' · ') + unit;
}

/// « 10·10·9 »
String dottedSets(ExerciseLog e) {
  if (e.sets.isEmpty) return '—';
  return e.sets.map((s) => '${s.value}').join('·') + (e.unit == Unit.seconds ? ' s' : '');
}

int sessionReps(Session s) => s.exercises
    .where((e) => e.unit == Unit.reps)
    .fold(0, (a, e) => a + e.total);

int sessionHold(Session s) => s.exercises
    .where((e) => e.unit == Unit.seconds)
    .fold(0, (a, e) => a + e.total);

int? sessionDuration(Session s) {
  final end = s.end;
  if (end == null || !end.isAfter(s.date)) return null;
  return end.difference(s.date).inSeconds;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lundi de la semaine de [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Numéro de semaine ISO 8601.
int isoWeek(DateTime d) {
  // Arithmétique calendaire (pas de Duration) pour ignorer les changements d'heure.
  final thursday = DateTime(d.year, d.month, d.day + 4 - d.weekday);
  final firstJan = DateTime(thursday.year, 1, 1);
  return (thursday.difference(firstJan).inHours / 24).round() ~/ 7 + 1;
}

int sessionsInMonth(List<Session> sessions, DateTime month) =>
    sessions.where((s) => s.date.year == month.year && s.date.month == month.month).length;

/// Semaines consécutives avec au moins une séance, en finissant par la semaine en cours
/// (ou la précédente si rien encore cette semaine).
int activeWeekStreak(List<Session> sessions, DateTime now) {
  if (sessions.isEmpty) return 0;
  final weeks = sessions.map((s) => weekStart(s.date)).toSet();
  var w = weekStart(now);
  if (!weeks.contains(w)) w = DateTime(w.year, w.month, w.day - 7);
  var n = 0;
  while (weeks.contains(w)) {
    n++;
    w = DateTime(w.year, w.month, w.day - 7);
  }
  return n;
}

int? daysSinceLast(List<Session> sessions, DateTime now) {
  if (sessions.isEmpty) return null;
  final last = sessions.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);
  return (_day(now).difference(_day(last)).inHours / 24).round();
}

class WeekVolume {
  final DateTime start;
  final int week;
  final int reps;
  final int sessions;
  WeekVolume(this.start, this.week, this.reps, this.sessions);
}

/// Volume (reps) des [count] dernières semaines, de la plus ancienne à la plus récente.
List<WeekVolume> weeklyVolume(List<Session> sessions, DateTime now, {int count = 8}) {
  final current = weekStart(now);
  final out = <WeekVolume>[];
  for (var i = count - 1; i >= 0; i--) {
    final start = DateTime(current.year, current.month, current.day - 7 * i);
    final end = DateTime(start.year, start.month, start.day + 7);
    final inWeek = sessions.where((s) => !s.date.isBefore(start) && s.date.isBefore(end));
    out.add(WeekVolume(start, isoWeek(start), inWeek.fold(0, (a, s) => a + sessionReps(s)),
        inWeek.length));
  }
  return out;
}

bool _same(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// Meilleur total d'un exercice sur les séances données (hors [excludeId]).
int? bestTotal(List<Session> sessions, String name, {String? excludeId}) {
  int? best;
  for (final s in sessions) {
    if (s.id == excludeId) continue;
    for (final e in s.exercises) {
      if (_same(e.name, name) && e.sets.isNotEmpty) {
        best = best == null ? e.total : max(best, e.total);
      }
    }
  }
  return best;
}

/// Meilleure série isolée d'un exercice (pour le record au chrono).
int? bestSet(List<Session> sessions, String name) {
  int? best;
  for (final s in sessions) {
    for (final e in s.exercises) {
      if (_same(e.name, name) && e.sets.isNotEmpty) {
        best = best == null ? e.best : max(best, e.best);
      }
    }
  }
  return best;
}

/// Exercice précédent (même nom) dans une séance antérieure à [before].
ExerciseLog? previousLog(List<Session> sessions, String name, DateTime before) {
  ExerciseLog? out;
  DateTime? when;
  for (final s in sessions) {
    if (!s.date.isBefore(before)) continue;
    for (final e in s.exercises) {
      if (_same(e.name, name) && e.sets.isNotEmpty && (when == null || s.date.isAfter(when))) {
        out = e;
        when = s.date;
      }
    }
  }
  return out;
}
