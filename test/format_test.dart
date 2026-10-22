import 'package:anneaux/format.dart';
import 'package:anneaux/models.dart';
import 'package:anneaux/seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('résumé au format des notes', () {
    final e = ExerciseLog(name: 'Pull ups', sets: [SetLog(10, 5), SetLog(10, 5), SetLog(7, 5)]);
    expect(setsSummary(e), '2x10 + 1x7 (hauteur 5)');
  });

  test('hauteurs différentes', () {
    final e = ExerciseLog(name: 'Low row', sets: [SetLog(15, 4), SetLog(15, 4.5), SetLog(15, 4.5)]);
    expect(setsSummary(e), '1x15 h4 + 2x15 h4.5');
  });

  test('secondes', () {
    final e = ExerciseLog(
        name: 'Planche', unit: Unit.seconds, sets: [SetLog(30, 11), SetLog(30, 11), SetLog(30, 11)]);
    expect(setsSummary(e), '3x30s (hauteur 11)');
  });

  test('historique pré-rempli', () {
    final s = seedSessions();
    expect(s.length, 13);
    final last = s.last;
    expect(exportSession(last).split('\n').first, '20 octobre 2026');
    expect(setsSummary(last.exercises.first), '2x10 + 1x7 (hauteur 5)');
  });

  test('aller-retour JSON', () {
    final s = seedSessions().first;
    final back = Session.fromJson(s.toJson());
    expect(exportSession(back), exportSession(s));
  });
}
