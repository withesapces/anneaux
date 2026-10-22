import 'models.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _monthsShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtDateLong(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtShort(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

String fmtHeight(double h) =>
    h == h.roundToDouble() ? h.toInt().toString() : h.toString();

String fmtClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String fmtValue(int v, Unit u) => u == Unit.seconds ? '$v s' : '$v';

/// "2x10 + 1x7 (hauteur 5)" — même format que tes notes.
String setsSummary(ExerciseLog e) {
  if (e.sets.isEmpty) return '—';
  final unit = e.unit == Unit.seconds ? 's' : '';
  final side = e.perSide ? ' de chaque côté' : '';
  final heights = e.sets.map((s) => s.height).toSet();

  if (heights.length == 1) {
    final groups = <List<int>>[]; // [compte, valeur]
    for (final s in e.sets) {
      if (groups.isNotEmpty && groups.last[1] == s.value) {
        groups.last[0]++;
      } else {
        groups.add([1, s.value]);
      }
    }
    final h = heights.first;
    final txt = groups.map((g) => '${g[0]}x${g[1]}$unit').join(' + ');
    return '$txt$side${h == null ? '' : ' (hauteur ${fmtHeight(h)})'}';
  }

  final parts = <String>[];
  var i = 0;
  while (i < e.sets.length) {
    var j = i;
    while (j + 1 < e.sets.length &&
        e.sets[j + 1].value == e.sets[i].value &&
        e.sets[j + 1].height == e.sets[i].height) {
      j++;
    }
    final h = e.sets[i].height;
    parts.add('${j - i + 1}x${e.sets[i].value}$unit'
        '${h == null ? '' : ' h${fmtHeight(h)}'}');
    i = j + 1;
  }
  return parts.join(' + ') + side;
}

String exportSession(Session s) {
  final b = StringBuffer(fmtDate(s.date));
  for (final e in s.exercises) {
    if (e.sets.isEmpty) continue;
    b.write('\n${e.name} : ${setsSummary(e)}');
  }
  return b.toString();
}

String exportAll(List<Session> sessions) =>
    sessions.reversed.map(exportSession).join('\n\n');
